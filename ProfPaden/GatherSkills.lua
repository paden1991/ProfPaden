local _,P=...
-- Gathering difficulty belongs to the harvested node, not its bonus loot or
-- the crafting recipes that happen to consume the resulting material.
local colors={orange="ffff8040",yellow="ffffff00",green="ff40c040",gray="ffaaaaaa",locked="ffff6060"}
local labels={orange="Orange",yellow="Yellow",green="Green",gray="Gray",locked="Requires skill"}
P.GatherDifficultyChoices={{label="Non-gray (leveling)",value="leveling"},{label="Orange now",value="orange"},{label="Yellow now",value="yellow"},{label="Green now",value="green"},{label="Gray now",value="gray"}}
function P:GatherSkillOptions(entry)
    local options,seen={},{}
    if self.selectedProf~="Herbalism" or not entry or not entry.gatherItem then return options end
    for _,s in ipairs(entry.sources or {}) do
        local t=s.kind=="object" and s.method=="Herb" and self.HerbSkillThresholds and self.HerbSkillThresholds[s.name]
        if t and not seen[s.name] then
            seen[s.name]=true;options[#options+1]={name=s.name,thresholds=t,bonus=t.item~=entry.item}
        end
    end
    table.sort(options,function(a,b)if a.thresholds.orange~=b.thresholds.orange then return a.thresholds.orange<b.thresholds.orange end;return a.name<b.name end)
    return options
end
function P:HasGatherSkillSource(entry)
    if self.selectedProf~="Herbalism" or not entry then return false end
    for _,s in ipairs(entry.sources or {}) do if s.method=="Herb" then return true end end
    -- New seed/rare-herb entries can have no confirmed source node yet.
    return entry.item and ({[268418]=true,[268417]=true,[249274]=true})[entry.item] or false
end
function P:GatherDifficulty(t,rank)
    if not rank or rank<=0 then return end
    if rank<t.orange then return "locked" end
    if rank<t.yellow then return "orange" end
    if rank<t.green then return "yellow" end
    if rank<t.gray then return "green" end
    return "gray"
end
function P:GatherSkillMatches(entry,value,lo,hi)
    local options=self:GatherSkillOptions(entry)
    if not value then return true end
    if value=="unknown" then return #options==0 end
    local rank=self.skills.Herbalism and self.skills.Herbalism.rank
    for _,o in ipairs(options) do
        local t=o.thresholds
        if lo and t.orange>=lo and t.orange<=hi then return true end
        local state=self:GatherDifficulty(t,rank)
        if state==value or value=="leveling" and (state=="orange" or state=="yellow" or state=="green") then return true end
    end
    return false
end
function P:GatherSkillSubtitle(entry)
    if not self:HasGatherSkillSource(entry) then return end
    local options=self:GatherSkillOptions(entry)
    if #options==0 then return "Gathering skill not confirmed" end
    if #options>1 then return "Bonus yield / nodes require "..options[1].thresholds.orange.."-"..options[#options].thresholds.orange end
    local o=options[1];local t=o.thresholds
    local rank=self.skills.Herbalism and self.skills.Herbalism.rank
    local state=self:GatherDifficulty(t,rank)
    return (o.bonus and "Bonus yield / skill " or "Gather at ")..t.orange..(state and " / |c"..colors[state]..labels[state].."|r" or "")
end
function P:GatherSkillRows(entry)
    if not self:HasGatherSkillSource(entry) then return {} end
    local rows={};local options=self:GatherSkillOptions(entry)
    local function add(a,b,heading) rows[#rows+1]={cells=b and {a,b} or {a},widths=b and {92,258} or {350},heading=heading} end
    add("HERBALISM / GATHERING SKILL",nil,true)
    if #options==0 then add("No confirmed gathering thresholds for this material yet.");return rows end
    local bonus=#options>1 or options[1].bonus
    if bonus then add("Additional yield: difficulty and skill gains come from the harvested plant.") end
    local rank=self.skills.Herbalism and self.skills.Herbalism.rank
    for _,o in ipairs(options) do
        local t=o.thresholds
        if bonus then add("Plant",o.name) end
        local state=self:GatherDifficulty(t,rank)
        add("Requires",t.orange.." Herbalism"..(state and " / "..labels[state].." at base skill "..rank or " / profession not trained"))
        for _,r in ipairs({{"orange",t.orange,t.yellow-1},{"yellow",t.yellow,t.green-1},{"green",t.green,t.gray-1},{"gray",t.gray}}) do
            add("|c"..colors[r[1]]..labels[r[1]].."|r",tostring(r[2])..(r[3] and "-"..r[3] or "+ / no gathering skill gain"))
        end
        if t.note then add(t.note) end
    end
    add("Thresholds: Wowhead Forever herb guide, "..self.HerbSkillSource.captured..". Current colors use base skill; equipment and temporary bonuses are not included.")
    return rows
end
