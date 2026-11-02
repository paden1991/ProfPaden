-- Reviewed skill facts, 2026-10-18. Loaded after generated research/source data.
-- Learning rank is independent of yellow/green/gray transitions.
-- Runtime trainer observations and learned-recipe data are not modified here.
local _,P=...
local copper="https://hyjal.cc/recipe/2657/smelt-copper"
local camp="https://hyjal.cc/recipe/1229737/basic-campfire"
local corrections={
    [2657]={learn=1,yellow=25,green=47,grey=70},
    [1229737]={learn=1,yellow=1,green=3,grey=5,item=279981,output=1,outputMax=1},
    -- Legacy spell fallback: skill 1 confirmed in game; retain its own color data.
    [818]={learn=1},
}
local urls={[2657]=copper,[1229737]=camp,[818]="https://classicwowforever.com/professions/camping/"}
local function apply(r,id)
    local fix=corrections[id]
    if not fix then return end
    for key,value in pairs(fix) do r[key]=value end
    r.sourceDiscrepancy=nil
    r.skillFactsURL=urls[id];r.skillFactsChecked="2026-10-18"
end
for _,collection in ipairs({P.Catalog or {},P.Recipes or {}}) do
    for _,rows in pairs(collection) do
        for _,r in ipairs(rows) do apply(r,r.spell) end
    end
end
for id in pairs(corrections) do
    if P.SpellMeta and P.SpellMeta[id] then apply(P.SpellMeta[id],id) end
end
-- Generated material summaries carry their own copies of learning requirements.
for _,rows in pairs(P.MaterialCrafts or {}) do
    for _,r in ipairs(rows) do
        local fix=corrections[r.spell]
        if fix then r.learn=fix.learn;if fix.output then r.output=fix.output end end
    end
end
for key,rows in pairs(P.GatherMaterialUses or {}) do
    local changed,first,last=false,nil,nil
    for _,r in ipairs(rows) do
        local fix=corrections[r.spell]
        if fix then r.learn=fix.learn;changed=true end
        if r.learn then first=math.min(first or r.learn,r.learn);last=math.max(last or r.learn,r.learn) end
    end
    local range=P.MaterialSkillRanges and P.MaterialSkillRanges[key]
    if changed and first and range and not range.indirect then range.first=first;range.last=last end
end
