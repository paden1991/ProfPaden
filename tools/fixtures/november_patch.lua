-- Observed services are samples; disappearance from a sample is not a removal.
for _,record in ipairs(trainers) do
    for _,recipe in ipairs(P.Catalog[record.profession] or {}) do
        if recipe.spell==record.spell then
            local line='Trainer: '..record.name
            if record.zone~='' then line=line..' — '..record.zone end
            line=line..' (ForeverDB observed)'
            local text=recipe.source or ''
            text=text:gsub('Acquisition source not yet published; check the linked Forever spell record%.','')
            if not text:find(line,1,true) then recipe.source=text..(text~='' and '\n' or '')..line end
            recipe.sourceKinds=recipe.sourceKinds or {};recipe.sourceKinds.trainer=true
            if not recipe.sourceKind or recipe.sourceKind=='unknown' then recipe.sourceKind='trainer' end
            recipe.acquisitionChecked='2026-11-12'
            recipe.observedTrainerSources=recipe.observedTrainerSources or {}
            local exists=false
            for _,old in ipairs(recipe.observedTrainerSources) do if old.npc==record.npc then exists=true end end
            if not exists then recipe.observedTrainerSources[#recipe.observedTrainerSources+1]=clone(record) end
        end
    end
end
local function apply(recipe,id)
    local fix=fixes[id]
    if not fix then return end
    for _,key in ipairs({'learn','yellow','green','grey','tools','bagSlots'}) do
        if fix[key]~=nil then recipe[key]=clone(fix[key]) end
    end
    for _,mat in ipairs(recipe.mats or {}) do
        local count=fix.materialCounts and fix.materialCounts[tostring(mat.id)]
        if count then mat.count=count end
    end
    recipe.hotfixNote=fix.note
    recipe.hotfixURL=hotfixURL;recipe.hotfixChecked='2026-11-12'
    if fix.learn then recipe.sourceDiscrepancy=nil;recipe.wowheadLearn=nil end
    if id==3326 then recipe.note=fix.note end
    if fix.learn or fix.grey then recipe.skillFactsURL=hotfixURL;recipe.skillFactsChecked='2026-11-12' end
end
for _,collection in ipairs({P.Catalog or {},P.Recipes or {}}) do
    for _,rows in pairs(collection) do for _,r in ipairs(rows) do
        apply(r,r.spell)
        for _,ref in ipairs(r.acquisitionItems or {}) do
            local fix=itemFixes[ref.id]
            if fix and fix.name then
                ref.name=fix.name
                if fix.oldName then r.source=(r.source or ''):gsub(fix.oldName,fix.name) end
            end
        end
    end end
end
for id in pairs(fixes) do if P.SpellMeta and P.SpellMeta[id] then apply(P.SpellMeta[id],id) end end
for id,fix in pairs(itemFixes) do
    local meta=P.ItemMeta[id] or {};P.ItemMeta[id]=meta
    for key,value in pairs(fix) do if key~='oldName' and key~='previousRequiredSkill' then meta[key]=value end end
    meta.hotfixURL=hotfixURL;meta.hotfixChecked='2026-11-12'
    if fix.previousRequiredSkill then
        for _,source in ipairs(meta.sources or {}) do
            if source.skill==fix.previousRequiredSkill then source.skill=fix.requiredSkill;source.skillFactsURL=hotfixURL end
        end
    end
    if fix.name then
        if P.Items[id] then P.Items[id].name=fix.name end
        if P.GatherItemNames then P.GatherItemNames[id]=fix.name end
        for _,rows in pairs(P.GatherAtlas or {}) do for _,r in ipairs(rows) do
            if r.item==id then
                r.name=fix.name
                if fix.oldName then r.searchText=(r.searchText or ''):gsub(fix.oldName:lower(),fix.name:lower()) end
            end
        end end
    end
end
-- Keep derived material/recipe summaries aligned with the authoritative catalog.
for _,rows in pairs(P.MaterialCrafts or {}) do for _,r in ipairs(rows) do apply(r,r.spell) end end
for key,rows in pairs(P.GatherMaterialUses or {}) do
    local changed,first,last=false,nil,nil
    for _,r in ipairs(rows) do
        local fix=fixes[r.spell]
        if fix then
            apply(r,r.spell)
            local item=tonumber(key:match(':(%d+)$'))
            if item and fix.materialCounts and fix.materialCounts[tostring(item)] and r.count then r.count=fix.materialCounts[tostring(item)] end
            changed=true
        end
        if r.learn then first=math.min(first or r.learn,r.learn);last=math.max(last or r.learn,r.learn) end
    end
    local range=P.MaterialSkillRanges and P.MaterialSkillRanges[key]
    if changed and first and range and not range.indirect then range.first=first;range.last=last end
end
P.NovemberHotfixes={checked='2026-11-12',source=hotfixURL,recipes=clone(fixes),items=clone(itemFixes)}
