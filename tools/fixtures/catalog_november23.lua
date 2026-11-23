local checked=reviewed.checked
local function clone(v)
 if type(v)~='table' then return v end
 local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r
end
local function add(list,value)
 for _,old in ipairs(list) do if old==value then return end end;list[#list+1]=value
end
local function merge(list,s)
 for _,old in ipairs(list) do
  if old.kind==s.kind and (old.npc or old.id)==(s.npc or s.id) and old.name==s.name and old.method==s.method then return end
 end
 list[#list+1]=clone(s)
end
for id,r in pairs(reviewed.items) do
 local meta=P.ItemMeta[id] or {name=r.name,url=r.url,sources={}};P.ItemMeta[id]=meta
 meta.sources=meta.sources or {}
 for _,s in ipairs(r.sources) do
  merge(meta.sources,{kind=s.method=='Vendor' and 'Vendor' or 'Report',id=s.id,npc=s.id,name=s.name,method=s.method,zones=clone(s.zones),zone=table.concat(s.zones,', '),url=s.url,source=s.provenance,evidence=s.evidence,checked=checked,observations=s.observations})
 end
end
for _,rows in pairs(P.GatherAtlas) do for _,e in ipairs(rows) do
 local r=reviewed.items[e.item]
 if r then
  e.sources=e.sources or {};e.referenceURLs=e.referenceURLs or {}
  for _,s in ipairs(r.sources) do
   merge(e.sources,s);add(e.referenceURLs,s.url)
   local text=(s.name..' '..table.concat(s.zones,' ')):lower()
   if not (e.searchText or ''):lower():find(text,1,true) then e.searchText=(e.searchText or '')..' '..text end
  end
  if e.sourceCoverage and e.sourceCoverage.unavailable then e.sourceCoverage=nil end
  e.sub=(e.sub or 'Material'):gsub(' | %d+ sources','')..' | '..#e.sources..' sources'
  e.catalogSourceChecked=checked
 end
end end
for id,book in pairs(reviewed.books) do
 local meta=P.ItemMeta[id] or {sources={}};P.ItemMeta[id]=meta
 for k,v in pairs(book) do if k~='sources' then meta[k]=clone(v) end end
 meta.sources=meta.sources or {};for _,s in ipairs(book.sources) do merge(meta.sources,s) end
 meta.acquisitionChecked=checked
 P.Items[id]=P.Items[id] or {name=book.name};P.Items[id].name=book.name
end
local function fix(r,id)
 local f=reviewed.recipes[id];if not f then return end
 if f.name then r.name=f.name end
 if f.learn then r.learn=f.learn;r.skillFactsURL=f.url;r.skillFactsChecked=checked end
 if f.clearThresholdConflict then r.wowheadLearn=75;r.sourceDiscrepancy=nil;r.skillFactsURL=f.url;r.skillFactsChecked=checked end
end
for _,collection in ipairs({P.Catalog or {},P.Recipes or {}}) do
 for _,rows in pairs(collection) do for _,r in ipairs(rows) do
  fix(r,r.spell)
  local f=reviewed.recipes[r.spell]
  if f then
   r.referenceURLs=r.referenceURLs or {};add(r.referenceURLs,f.url)
   if f.book then
    r.acquisitionItems=r.acquisitionItems or {};local exists=false
    for _,ref in ipairs(r.acquisitionItems) do if ref.id==f.book then exists=true end end
    if not exists then r.acquisitionItems[#r.acquisitionItems+1]={id=f.book,kind='item',name=reviewed.books[f.book].name} end
    r.source=f.source;r.sourceKind=f.sourceKind;r.sourceKinds=r.sourceKinds or {};r.sourceKinds[f.sourceKind]=true
    r.acquisitionChecked=checked
   end
  end
 end end
end
for _,record in ipairs(reviewed.trainers) do
 for _,r in ipairs(P.Catalog[record.profession] or {}) do if r.spell==record.spell then
  local line='Trainer: '..record.name..' — '..record.zone..' (ForeverDB observed)'
  local text=r.source or ''
  text=text:gsub('Acquisition source not yet published; check the linked Forever spell record%.',''):gsub('Source not found yet','')
  if not text:find(line,1,true) then r.source=text..(text~='' and '\n' or '')..line end
  r.sourceKinds=r.sourceKinds or {};r.sourceKinds.trainer=true
  if not r.sourceKind or r.sourceKind=='unknown' then r.sourceKind='trainer' end
  r.acquisitionChecked=checked;r.observedTrainerSources=r.observedTrainerSources or {}
  local exists=false;for _,old in ipairs(r.observedTrainerSources) do if old.npc==record.npc then exists=true end end
  if not exists then r.observedTrainerSources[#r.observedTrainerSources+1]=clone(record) end
 end end
end
-- Add observed vendor alternatives to recipe-item descriptions without erasing conditions.
for _,rows in pairs(P.Catalog) do for _,r in ipairs(rows) do
 for _,ref in ipairs(r.acquisitionItems or {}) do
  local item=reviewed.items[ref.id]
  if item then for _,s in ipairs(item.sources) do if s.method=='Vendor' then
   local line='Vendor: '..s.name..' — '..table.concat(s.zones,', ')..' (ForeverDB observed; check live requirements and stock)'
   if not (r.source or ''):find(line,1,true) then r.source=(r.source or '')..'\n'..line end
   r.sourceKinds=r.sourceKinds or {};r.sourceKinds.vendor=true
  end end end
 end
end end
for id,f in pairs(reviewed.recipes) do
 if P.SpellMeta[id] then fix(P.SpellMeta[id],id) end
 if f.name and f.item then
  if P.ItemMeta[f.item] then P.ItemMeta[f.item].name=f.name end
  if P.Items[f.item] then P.Items[f.item].name=f.name end
  if P.GatherItemNames then P.GatherItemNames[f.item]=f.name end
  for _,rows in pairs(P.GatherAtlas) do for _,r in ipairs(rows) do if r.item==f.item then
   r.name=f.name;if not (r.searchText or ''):lower():find(f.name:lower(),1,true) then r.searchText=(r.searchText or '')..' '..f.name:lower() end
  end end end
 end
end
for _,rows in pairs(P.MaterialCrafts or {}) do for _,r in ipairs(rows) do fix(r,r.spell) end end
for key,rows in pairs(P.GatherMaterialUses or {}) do
 local changed,first,last=false,nil,nil
 for _,r in ipairs(rows) do
  fix(r,r.spell);if reviewed.recipes[r.spell] and reviewed.recipes[r.spell].learn then changed=true end
  if r.learn then first=math.min(first or r.learn,r.learn);last=math.max(last or r.learn,r.learn) end
 end
 local range=P.MaterialSkillRanges and P.MaterialSkillRanges[key]
 if changed and first and range and not range.indirect then range.first=first;range.last=last end
end
P.CatalogRefresh={checked=checked,recipes=clone(reviewed.recipes),items={}}
for id,r in pairs(reviewed.items) do P.CatalogRefresh.items[id]=#r.sources end
