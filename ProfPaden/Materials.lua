local _,P=...
-- Group by the first skill that needs a material, never by character level.
function P:MaterialGroup(entry)
    if not entry or not entry.gatherItem or entry.pool then return end
    local gathering=self:HasGatherSkillSource(entry)
    local options=gathering and self:GatherSkillOptions(entry)
    if gathering and #options==0 then return "UNCONFIRMED GATHERING SKILL",9998 end
    if self:MaterialFiltersActive() then
        local lo,hi=self:MaterialSkillBand(self:MaterialFilters().skill)
        if lo then return (gathering and "GATHER AT SKILL " or "USED AT SKILL ")..lo..(hi==math.huge and "+" or "-"..hi),lo end
    end
    local range=gathering and {first=options[1].thresholds.orange} or self.MaterialSkillRanges and self.MaterialSkillRanges[entry.key]
    if not range then return "OTHER MATERIALS",9999 end
    local first=range.first
    if first<75 then return "SKILL 1-74",1 end
    if first<150 then return "SKILL 75-149",75 end
    if first<225 then return "SKILL 150-224",150 end
    if first<=300 then return "SKILL 225-300",225 end
    return "SKILL 301+",301
end
function P:MaterialSubtitle(entry)
    local gathering=self:GatherSkillSubtitle(entry);if gathering then return gathering end
    local range=self.MaterialSkillRanges and self.MaterialSkillRanges[entry.key]
    local kind=self.VendorSupplies and self.VendorSupplies[entry.item] and "Vendor"
        or #(self.MaterialCrafts and self.MaterialCrafts[entry.key] or {})>0 and "Crafted" or nil
    if range then
        return (range.indirect and "Indirect / skill " or "Used at ")..range.first..(range.last~=range.first and "-"..range.last or "")..(kind and " / "..kind or "")
    end
    return entry.sub or "Material"
end
function P:RefreshMaterialRow(button,entry,previous,firstOnPage)
    local group=self:MaterialGroup(entry)
    local prior=self:MaterialGroup(previous)
    local show=group and (firstOnPage or group~=prior)
    button.materialGroup:SetShown(show and true or false)
    button.materialRule:SetShown(show and true or false)
    button.materialGroup:SetText(show and group or "")
    button.title:ClearAllPoints();button.sub:ClearAllPoints();button.icon:ClearAllPoints()
    local compact=self:MaterialFiltersActive()
    button.title:SetPoint("TOPLEFT",46,show and (compact and -16 or -17) or -7)
    button.sub:SetPoint("TOPLEFT",46,show and (compact and -31 or -34) or -27)
    button.title:SetHeight(show and (compact and 14 or 16) or 18);button.sub:SetHeight(show and (compact and 12 or 13) or 16)
    button.icon:SetPoint("TOPLEFT",7,show and -19 or -8);button.icon:SetSize(show and (compact and 24 or 26) or 30,show and (compact and 24 or 26) or 30)
end
function P:MaterialBrowseLink(id,name)
    return "|cff78c8ff|Hprofpaden:material:"..id.."|h["..(name or self.GatherItemNames[id] or self:ItemName(id)).."]|h|r"
end
function P:OpenMaterial(id)
    for _,e in ipairs(self.GatherAtlas[self.selectedProf] or {}) do if e.item==id and not e.pool then
        self:ClearMaterialFilters();self:CloseDropdown();self.tab="Gather";self.gatherView="materials";self.gatherSearch=tostring(id)
        self.offset=0;self.selectedKey=e.key;self:Refresh();return true
    end end
    return false
end
function P:OpenMaterialProducer(spell)
    for _,r in ipairs(self.MaterialCrafts and self.selected and self.MaterialCrafts[self.selected.key] or {}) do
        if r.spell==spell then
            self:CloseDropdown();self.selectedProf=r.profession;self.tab="Catalog";self.catalogSearch=tostring(spell)
            self.catalogFilter="all";self.catalogFacets={};self.offset=0;self.selectedKey="catalog:s"..spell;self:Refresh();return true
        end
    end
    return false
end
function P:MaterialVendor(entry)
    if not entry or not entry.item then return end
    if self:VendorSupply(entry.item) then return self:RouteVendor(entry.item,1) end
    local ids,seen={},{}
    local offers=self.char.vendorOffers and self.char.vendorOffers[entry.item] or {}
    local last=self.char.vendors and self.char.vendors[entry.item]
    local function add(id)
        local offer=offers[id] or last and last.npcID==id and last
        if not seen[id] and (not offer or offer.stock==-1 or (offer.stock or 0)>0) then ids[#ids+1]=id;seen[id]=true end
    end
    for _,id in ipairs(self.ReagentVendors[entry.item] or {}) do add(id) end
    for id in pairs(offers) do add(id) end
    if last and last.npcID then add(last.npcID) end
    table.sort(ids);return self:NearestNPC(ids)
end
-- Follow only this profession's ingredient graph. Cycles (e.g. transmutes)
-- must terminate, and each consuming recipe should appear only once.
function P:MaterialPreparationUses(entry)
    local byItem={};for _,e in ipairs(self.GatherAtlas[self.selectedProf] or {}) do if e.item and not e.pool then byItem[e.item]=e end end
    local pending={entry};local seen,spells,uses={},{},{};local i=1
    while i<=#pending do
        local e=pending[i];i=i+1
        if e and not seen[e.key] then
            seen[e.key]=true
            for _,r in ipairs(self.GatherMaterialUses and self.GatherMaterialUses[e.key] or {}) do
                if not spells[r.spell] then spells[r.spell]=true;uses[#uses+1]=r end
            end
            for _,parent in ipairs(self.MaterialParents and self.MaterialParents[e.key] or {}) do
                local nextEntry=byItem[parent.item];if nextEntry and not seen[nextEntry.key] then pending[#pending+1]=nextEntry end
            end
        end
    end
    table.sort(uses,function(a,b)if a.name~=b.name then return a.name<b.name end;return a.spell<b.spell end)
    return uses
end
function P:MaterialAcquisitionRows(entry)
    local rows={};local function add(a,b,heading)
        rows[#rows+1]={cells=b and {a,b} or {a},widths=b and {92,258} or {350},heading=heading}
    end
    for _,row in ipairs(self:GatherSkillRows(entry)) do rows[#rows+1]=row end
    local range=not self:HasGatherSkillSource(entry) and self.MaterialSkillRanges and self.MaterialSkillRanges[entry.key]
    if range then add(self.selectedProf,"Skill "..range.first..(range.last~=range.first and "-"..range.last or "")..(range.indirect and " / indirect ingredient" or " / recipe requirements")) end
    local supply,observed
    if entry.item then supply,observed=self:VendorSupply(entry.item) end
    if supply then
        add("BUY FROM A VENDOR",nil,true)
        add(observed and "Each" or "Base each",self:SmallMoney(supply.value).." / unlimited stock")
    end
    local target=self:MaterialVendor(entry)
    if target then
        add(target.comparable and "Nearest vendor" or "Vendor",self:NPCLink(target.npc.id).."\n"..(target.point.zone or "")..string.format(" %.1f, %.1f",target.point.x*100,target.point.y*100))
        rows[#rows+1]={cells={"Click the vendor for directions; buying clears the waypoint."},widths={350},muted=true}
    end
    local de=self.MaterialDisenchant and self.MaterialDisenchant[entry.item]
    if de then
        add("DISENCHANT / ENCHANTING",nil,true)
        add("Equipment",de.quality.." / requires level "..de.level)
        add("Result",de.kind.."; equipment is consumed.")
    end
    local crafts=self.MaterialCrafts and self.MaterialCrafts[entry.key] or {}
    if #crafts>0 then
        add("MAKE OR COMMISSION",nil,true)
        -- Paginate alternatives: transmute families can have many producers.
        if self.materialCraftKey~=entry.key then self.materialCraftKey=entry.key;self.materialCraftPage=1 end
        local pages=math.ceil(#crafts/4);local page=math.max(1,math.min(pages,self.materialCraftPage or 1));self.materialCraftPage=page
        for i=(page-1)*4+1,math.min(page*4,#crafts) do
            local r=crafts[i]
            add(r.profession.." "..(r.learn or ""),"|cff78c8ff|Hprofpaden:make:"..r.spell.."|h"..r.name.."|h|r".." / x"..r.output)
            local inputs={};for _,m in ipairs(r.mats or {}) do inputs[#inputs+1]=m.count.."x "..self:MaterialBrowseLink(m.id) end
            add("Inputs",table.concat(inputs,"\n"))
        end
        if pages>1 then
            add("Methods "..page.."/"..pages,(page>1 and "|cff78c8ff|Hprofpaden:methods:"..(page-1).."|h< Back|h|r  " or "")..(page<pages and "|cff78c8ff|Hprofpaden:methods:"..(page+1).."|hNext >|h|r" or ""))
        end
    end
    local parents=self.MaterialParents and self.MaterialParents[entry.key] or {}
    if #parents>0 then
        add("INGREDIENT CHAIN",nil,true)
        local byItem={};for _,e in ipairs(self.GatherAtlas[self.selectedProf] or {}) do if e.item and not e.pool then byItem[e.item]=e end end
        for _,v in ipairs(parents) do
            local parent=byItem[v.item];local professions,seen={},{}
            for _,r in ipairs(parent and self.MaterialCrafts[parent.key] or {}) do
                if not seen[r.profession] then seen[r.profession]=true;professions[#professions+1]=r.profession end
            end
            table.sort(professions)
            add("Make",self:MaterialBrowseLink(v.item,v.name)..(#professions>0 and "\n"..table.concat(professions," / ") or ""))
            local links={}
            for _,r in ipairs(parent and self:MaterialPreparationUses(parent) or {}) do
                links[#links+1]="|cff78c8ff|Hprofpaden:recipe:"..r.spell.."|h"..r.name.."|h|r".." ("..(r.learn or "-")..")"
            end
            if #links>0 then add("For "..self.selectedProf,table.concat(links,"\n")) end
        end
    end
    return rows
end
