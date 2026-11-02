local _,P=...
local choices={
    knowledge={{label="All recipe knowledge"},{label="Used by known recipes",value="known"},{label="Used by unlearned recipes",value="unlearned"},{label="Recipe knowledge not checked",value="unchecked"}},
    skill={{label="All skill ranges"},{label="Current skill band",value="current"},{label="Skill 1-74",value="1"},{label="Skill 75-149",value="75"},{label="Skill 150-224",value="150"},{label="Skill 225-300",value="225"},{label="Skill 301+",value="301"},{label="No recorded skill requirement",value="unknown"}},
    source={{label="All acquisition sources"},{label="Bought from a vendor",value="vendor"},{label="Gathered / fished / skinned",value="gather"},{label="Creature / container drops",value="loot"},{label="Crafted components",value="craft"},{label="Disenchanting",value="disenchant"}},
    bags={{label="Any bag availability"},{label="In bags (any amount)",value="have"},{label="Not in bags",value="missing"}},
}
local short={knowledge={known="Known",unlearned="Unlearned",unchecked="Unchecked"},skill={current="Current",["1"]="1-74",["75"]="75-149",["150"]="150-224",["225"]="225-300",["301"]="301+",unknown="Unlisted"},source={vendor="Vendor",gather="Gather",loot="Drops",craft="Crafted",disenchant="Disench."},bags={have="In bags",missing="Missing"}}
function P:MaterialFiltersActive()
    return self.tab=="Gather" and self:GatherView()~="routes" and self:GatherView()~="pools" and self:GatherView()~="guide" and self:GatherView()~="guideall"
end
function P:MaterialFilters()
    self.materialFiltersByProf=self.materialFiltersByProf or {}
    local f=self.materialFiltersByProf[self.selectedProf] or {};self.materialFiltersByProf[self.selectedProf]=f
    for kind,value in pairs(f) do
        local valid=false;for _,o in ipairs(choices[kind] or {}) do if o.value==value then valid=true;break end end
        if kind=="skill" and self.selectedProf=="Herbalism" then
            for _,o in ipairs(self.GatherDifficultyChoices or {}) do if o.value==value then valid=true end end
        end
        if not valid then f[kind]=nil end
    end
    return f
end
function P:ClearMaterialFilters()
    self.materialFiltersByProf=self.materialFiltersByProf or {};self.materialFiltersByProf[self.selectedProf]={}
end
function P:MaterialSkillBand(value)
    if value=="current" then
        local rank=self.skills[self.selectedProf] and self.skills[self.selectedProf].rank
        if not rank or rank<=0 then return end
        value=rank<75 and "1" or rank<150 and "75" or rank<225 and "150" or rank<=300 and "225" or "301"
    end
    local lo=tonumber(value);if lo then return lo,({[1]=74,[75]=149,[150]=224,[225]=300,[301]=math.huge})[lo] end
end
function P:MaterialFilterOptions(kind)
    local out={}
    for _,o in ipairs(choices[kind]) do
        local label=o.label
        if o.value=="current" then local lo,hi=self:MaterialSkillBand("current");label=lo and label.." ("..lo..(hi==math.huge and "+" or "-"..hi)..")" or "Current band (not trained)" end
        out[#out+1]={label=label,value=o.value}
    end
    if kind=="skill" and self.selectedProf=="Herbalism" then out[#out+1]={label="Gathering difficulty",children=self.GatherDifficultyChoices} end
    return out
end
function P:MaterialFilterContext()
    local f=self:MaterialFilters();local context={filters=f}
    if not f.knowledge and not f.skill then return context end
    local prof=self.selectedProf;local known,legacyItems,legacyNames={},{},{}
    local function remember(r)
        if r.spell then known[r.spell]=true elseif r.item then legacyItems[r.item]=true elseif r.name then legacyNames[r.name]=true end
    end
    for _,r in pairs(self.char.recipes[prof] or {}) do remember(r) end
    for _,r in ipairs(self.live or {}) do if r.profession==prof then remember(r) end end
    local observed=self.char.catalog and self.char.catalog[prof] or {}
    for _,r in pairs(observed) do if r.learned then remember(r) end end
    local lo,hi=self:MaterialSkillBand(f.skill)
    local matches,hasSkill,children,gathered={},{},{},{}
    for _,e in ipairs(self.GatherAtlas[prof] or {}) do if self:HasGatherSkillSource(e) then gathered[e.item]=e end end
    local function record(item,r)
        if not item then return end
        local skill=r.learn and math.max(1,r.learn)
        if skill then hasSkill[item]=true end
        local obs=r.spell and observed["s"..r.spell]
        local state=(known[r.spell] or legacyItems[r.item] or legacyNames[r.name]) and "known" or obs and obs.learned==false and "unlearned" or "unchecked"
        local skillOK=gathered[item] or not f.skill or f.skill=="unknown" and not skill or lo and skill and skill>=lo and skill<=hi
        if (not f.knowledge or f.knowledge==state) and skillOK then matches[item]=true end
    end
    for _,e in ipairs(self.GatherAtlas[prof] or {}) do
        for _,use in ipairs(self.GatherMaterialUses[e.key] or {}) do record(e.item,use) end
        for _,parent in ipairs(self.MaterialParents[e.key] or {}) do
            children[parent.item]=children[parent.item] or {};children[parent.item][#children[parent.item]+1]=e.item
        end
    end
    -- Also honor learned recipes captured in game, including catalog additions.
    for _,r in pairs(self.char.recipes[prof] or {}) do for _,m in ipairs(r.mats or {}) do record(m.id,r) end end
    for _,r in ipairs(self.live or {}) do if r.profession==prof then for _,m in ipairs(r.mats or {}) do record(m.id,r) end end end
    local function expand(set)
        local pending={};for id in pairs(set) do pending[#pending+1]=id end
        local i=1;while i<=#pending do
            for _,id in ipairs(children[pending[i]] or {}) do if not set[id] then set[id]=true;pending[#pending+1]=id end end
            i=i+1
        end
    end
    expand(matches);expand(hasSkill)
    if f.skill=="unknown" then
        for _,e in ipairs(self.GatherAtlas[prof] or {}) do
            if e.item and not gathered[e.item] then matches[e.item]=not hasSkill[e.item] and (not f.knowledge or matches[e.item]) or nil end
        end
    end
    for id,e in pairs(gathered) do
        matches[id]=(not f.knowledge or matches[id]) and self:GatherSkillMatches(e,f.skill,lo,hi) or nil
    end
    context.matches=matches;return context
end
function P:MaterialMatchesFilters(entry,context)
    local f=context.filters
    if context.matches and not context.matches[entry.item] then return false end
    if f.bags then local count=self:Count(entry.item);if f.bags=="have" and count==0 or f.bags=="missing" and count>0 then return false end end
    if not f.source then return true end
    if f.source=="vendor" then
        return self:VendorSupply(entry.item)~=nil or #(self.ReagentVendors[entry.item] or {})>0
            or self.char.vendors and self.char.vendors[entry.item]~=nil or self.char.vendorOffers and self.char.vendorOffers[entry.item] and next(self.char.vendorOffers[entry.item])~=nil
    end
    if f.source=="craft" then return #(self.MaterialCrafts[entry.key] or {})>0 end
    if f.source=="disenchant" then return self.MaterialDisenchant[entry.item]~=nil end
    for _,s in ipairs(entry.sources or {}) do
        local method=(s.method or ""):lower()
        if f.source=="gather" and (method:find("mine",1,true) or method:find("herb",1,true) or method:find("skin",1,true) or method:find("fish",1,true) or method:find("gather",1,true)) then return true end
        if f.source=="loot" and (method:find("loot",1,true) or method:find("drop",1,true) or method:find("open",1,true)) then return true end
    end
    return false
end
function P:CreateMaterialFilters(parent)
    self.materialFilterButtons={}
    for i,kind in ipairs({"knowledge","skill","source","bags"}) do
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",12+(i-1)*100,-42);b:SetSize(98,24)
        self:DecorateDropdown(b);b.dropdownAlignRight=i>=3;self.materialFilterButtons[kind]=b
        b:SetScript("OnClick",function()
            P:ToggleDropdown(b,P:MaterialFilterOptions(kind),P:MaterialFilters()[kind],function(value)
                P:MaterialFilters()[kind]=value;P.offset=0;P.selectedKey=nil;P:Refresh()
            end)
        end)
        b:SetScript("OnEnter",function()
            if not GameTooltip then return end
            GameTooltip:SetOwner(b,"ANCHOR_TOP")
            GameTooltip:SetText(({knowledge="Recipe knowledge",skill="Profession skill requirement",source="How to acquire the material",bags="Bag availability"})[kind])
            local tip=({knowledge="Matches recipes that use this material, including preparation inputs. Open your profession to refresh learned recipes.",skill="Matches recipe requirements in this band, including preparation inputs. Current band follows your profession skill, not character level.",source="Materials can have more than one source. Vendor directions remain available in the detail panel.",bags="In bags means at least one item, not enough for a planned batch. Bank contents are excluded."})[kind]
            if kind=="skill" and P.selectedProf=="Herbalism" then tip="Herbs match their plant's minimum gathering skill. Bonus drops match each recorded plant. Gathering difficulty compares thresholds with your base Herbalism skill; equipment bonuses are not included. Other ingredients use recipe requirements." end
            GameTooltip:AddLine(tip,1,1,1,true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    end
end
function P:RefreshMaterialFilters()
    local visible=self:MaterialFiltersActive();local f=self:MaterialFilters()
    for kind,b in pairs(self.materialFilterButtons or {}) do
        b:SetShown(visible)
        local difficulty=kind=="skill" and ({orange="Orange",yellow="Yellow",green="Green",gray="Gray",leveling="Non-gray"})[f[kind]]
        b:SetText(difficulty or f[kind] and short[kind][f[kind]] or ({knowledge="All recipes",skill="Skill: All",source="Source: All",bags="Bags: All"})[kind])
    end
end
