local _,P=...
P.QualityNames={[0]="Poor",[1]="Common",[2]="Uncommon",[3]="Rare",[4]="Epic",[5]="Legendary"}
P.ItemTypes={[0]="Consumable",[1]="Container",[2]="Weapon",[4]="Armor",[5]="Reagent",[7]="Trade goods",[9]="Recipe",[12]="Quest item",[15]="Miscellaneous"}
P.FacetTypes={"Armor","Consumable","Container","Miscellaneous","Other","Quest item","Reagent","Recipe","Trade goods","Weapon"}
P.Subtypes={
 Armor={{1,"Cloth"},{2,"Leather"},{3,"Mail"},{4,"Plate"},{6,"Shields"},{0,"Other armor"},{7,"Librams"},{8,"Idols"},{9,"Totems"}},
 Weapon={{0,"One-handed axes","One-handed"},{4,"One-handed maces","One-handed"},{7,"One-handed swords","One-handed"},{13,"Fist weapons","One-handed"},{15,"Daggers","One-handed"},
 {1,"Two-handed axes","Two-handed"},{5,"Two-handed maces","Two-handed"},{8,"Two-handed swords","Two-handed"},{6,"Polearms","Two-handed"},{10,"Staves","Two-handed"},
 {2,"Bows","Ranged"},{3,"Guns","Ranged"},{16,"Thrown","Ranged"},{18,"Crossbows","Ranged"},{19,"Wands","Ranged"},{20,"Fishing poles"},{14,"Miscellaneous weapons"}},
 Consumable={{0,"Other consumables"},{1,"Potions"},{2,"Elixirs"},{3,"Flasks"},{4,"Scrolls"},{5,"Food and drink"},{6,"Item enhancements"},{7,"Bandages"}},
 Container={{0,"Bags"},{1,"Soul bags"},{2,"Herb bags"},{3,"Enchanting bags"},{4,"Engineering bags"},{5,"Gem bags"},{6,"Mining bags"},{7,"Leatherworking bags"}},
 Recipe={{0,"Books"},{1,"Leatherworking"},{2,"Tailoring"},{3,"Engineering"},{4,"Blacksmithing"},{5,"Cooking"},{6,"Alchemy"},{7,"First Aid"},{8,"Enchanting"},{9,"Fishing"}},
 ["Trade goods"]={{0,"Other trade goods"},{1,"Parts"},{2,"Explosives"},{3,"Devices"},{4,"Jewelcrafting"},{5,"Cloth"},{6,"Leather"},{7,"Metal and stone"},{8,"Meat"},{9,"Herbs"},{10,"Elemental"},{12,"Enchanting"}}
}
function P:SubtypeName(kind,id)
    for _,sub in ipairs(self.Subtypes[kind] or {}) do if sub[1]==id then return sub[2] end end
end
function P:TypeOptions()
    local options={{label="All"}}
    for _,kind in ipairs(self.FacetTypes) do
        local option={label=kind,value=kind};options[#options+1]=option
        if self.Subtypes[kind] then
            option.children={{label="All "..kind,value=kind}};local groups={}
            for _,sub in ipairs(self.Subtypes[kind]) do
                local list=option.children
                if sub[3] then
                    if not groups[sub[3]] then
                        groups[sub[3]]={label=sub[3],children={}};list[#list+1]=groups[sub[3]]
                    end
                    list=groups[sub[3]].children
                end
                list[#list+1]={label=sub[2],value=kind..":"..sub[1]}
            end
        end
    end
    return options
end
function P:NormalizeFacets(filter)
    if not filter then return end
    if filter.quality~=nil and not self.QualityNames[filter.quality] then filter.quality=nil end
    if filter.type then
        local valid=false;for _,name in ipairs(self.FacetTypes) do if name==filter.type then valid=true;break end end
        if not valid then filter.type=nil end
    end
    if filter.subtype~=nil and not self:SubtypeName(filter.type,filter.subtype) then filter.subtype=nil end
    if filter.new~=true then filter.new=nil end
end
function P:ClearListingFilters()
    if self.tab=="Gather" then self:ClearMaterialFilters();self.gatherView="materials";self.gatherSearch=""
    elseif self.tab=="Quests" then self.questFacets={};self.questSearch=""
    else self.catalogFacets={};self.catalogFilter="all";self.catalogSearch="" end
    self.offset=0;self.selectedKey=nil;self:CloseDropdown();self:Refresh()
end
function P:ActiveFilters()
    local quest=self.tab=="Quests";local f=(quest and self.questFacets or self.catalogFacets) or {}
    self:NormalizeFacets(f);local out={}
    local function add(key,label)out[#out+1]={key=key,label=label} end
    if not quest and self.catalogFilter and self.catalogFilter~="all" then add("show","Show: "..self.catalogFilter) end
    if f.type then add("type",(quest and "Reward: " or "Type: ")..f.type) end
    if f.quality~=nil then add("quality",self.QualityNames[f.quality]) end
    if f.new then add("new","New in Forever") end
    local search=quest and self.questSearch or self.catalogSearch
    if search and search~="" then add("search","Search: "..search) end
    return out
end
function P:CreateFilterReset(parent)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");self.resetFilters=b
    b:SetPoint("TOPLEFT",310,-68);b:SetSize(96,22);b:SetText("Reset all")
    b:SetScript("OnClick",function()P:ClearListingFilters()end)
end
function P:RefreshFilterReset()
    self.resetFilters:ClearAllPoints();self.resetFilters:SetPoint("TOPLEFT",310,self.tab=="Gather" and not self:MaterialFiltersActive() and -38 or -68)
    if self.tab=="Gather" then
        self.resetFilters:Show();self.resetFilters:SetEnabled(self:GatherView()~="materials" or (self.gatherSearch or "")~="" or next(self:MaterialFilters())~=nil)
        self.listHint:SetWidth(280)
        local active=self:MaterialFiltersActive()
        local f=self:MaterialFilters()
        self.listHint:SetText(active and (("Showing "..#(self.entries or {}).." / "..(self.materialListTotal or 0).." materials")..(f.knowledge and " / open profession to update" or " / grouped by skill")) or "Search item, creature, pool or zone");return
    end
    local visible=self.tab=="Catalog" or self.tab=="Quests"
    self.resetFilters:SetShown(visible);self.resetFilters:SetEnabled(visible and #self:ActiveFilters()>0)
    self.listHint:SetWidth(visible and 280 or 392)
    if visible then self.listHint:SetText("Showing "..#(self.entries or {}).." of "..(self.listTotal or 0)..(self.tab=="Quests" and " quests" or " recipes")) end
end
function P:RecipeTooltipLines(id)
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok,tip=pcall(C_TooltipInfo.GetItemByID,id)
        if ok and tip and tip.lines then return tip.lines end
    end
    if not self.requirementTooltip then self.requirementTooltip=CreateFrame("GameTooltip","ProfPadenRequirementTooltip",UIParent,"GameTooltipTemplate") end
    local tip=self.requirementTooltip;tip:SetOwner(UIParent,"ANCHOR_NONE")
    local ok=pcall(tip.SetHyperlink,tip,"item:"..id);local lines={}
    if ok then for i=1,(tip:NumLines() or 0) do
        local text=_G["ProfPadenRequirementTooltipTextLeft"..i]
        if text then local r,g,b=text:GetTextColor();lines[#lines+1]={leftText=text:GetText(),leftColor={r=r,g=g,b=b}} end
    end end
    tip:Hide();return lines
end
function P:ItemFacts(id)
    local base=self.ItemMeta[id] or {};local meta={};for k,v in pairs(base) do meta[k]=v end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    if fn and id then
        local v={fn(id)}
        if v[1] then meta.name=v[1];meta.quality=v[3];meta.type=v[6];meta.subtype=v[7];meta.classID=v[12] or meta.classID;meta.subclassID=v[13] or meta.subclassID end
    end
    meta.type=self.ItemTypes[meta.classID] or meta.type or "Other"
    return meta
end
function P:RecipeFacts(r)
    local id=r.acquisitionItems and r.acquisitionItems[1] and r.acquisitionItems[1].id or r.item
    local facts=self:ItemFacts(id)
    local spell=self.SpellMeta[r.spell] or {}
    facts.change=facts.change or spell.change
    if facts.quality==nil then facts.quality=spell.quality end
    return facts
end
function P:MatchesFacets(entry,quest)
    local filter=quest and self.questFacets or self.catalogFacets
    if not filter then return true end
    self:NormalizeFacets(filter)
    if not filter.new and not filter.type and filter.subtype==nil and filter.quality==nil then return true end
    local meta=quest and self.QuestMeta[entry.id] or self:RecipeFacts(entry)
    if filter.new and (not meta or meta.change~="new") then return false end
    local function match(m)
        return (not filter.type or m.type==filter.type) and (filter.subtype==nil or m.subclassID==filter.subtype) and (filter.quality==nil or m.quality==filter.quality)
    end
    if not quest then
        if match(meta) then return true end
        if filter.type and entry.item and match(self:ItemFacts(entry.item)) then return true end
        for _,ref in ipairs(entry.acquisitionItems or {}) do if match(self:ItemFacts(ref.id)) then return true end end
        return false
    end
    if not filter.type and filter.quality==nil then return true end
    for _,id in ipairs(meta and meta.rewards or {}) do if match(self:ItemFacts(id)) then return true end end
    return false
end
function P:SmallMoney(value)
    if value==nil then return "-" end
    if value<0 then return "-"..self:SmallMoney(-value) end
    value=math.floor(value+.5)
    local g,s,c=math.floor(value/10000),math.floor(value/100)%100,value%100
    return (g>0 and g.."g " or "")..(s>0 and s.."s " or "")..((c>0 or value==0) and c.."c" or ""):gsub("%s+$","")
end
function P:PriceDate(stamp,source,id)
    if stamp and date then return date("%d %b %H:%M",stamp) end
    if source=="Auctionator estimate" and Auctionator and Auctionator.API and Auctionator.API.v1.GetAuctionAgeByItemID then
        local ok,days=pcall(Auctionator.API.v1.GetAuctionAgeByItemID,self.name,id)
        if ok and type(days)=="number" then return days==0 and "Today" or days.." day(s) ago" end
    end
    local ext=self.market.external and self.market.external[id]
    if ext and source==ext.source and date then return "Read "..date("%d %b %H:%M",ext.readTime) end
    return stamp and tostring(stamp) or "-"
end
local function plain(s)return (s or ""):gsub("\\n","\n"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","") end
function P:BriefSource(source)
    local out,seen={},{}
    for line in plain(source):gmatch("[^\n]+") do
        local low=line:lower()
        if not low:find("unconfirm") and not low:find("not publish") and not low:find("not yet") and not low:find("unknown") and
            not low:find("check the") and not low:find("source:") and not low:find("may ") and not low:find("not supplied") and
            not low:find("unavailable") and not seen[line] then out[#out+1]=line;seen[line]=true end
    end
    return table.concat(out,"\n"):gsub("≈","~"):gsub("–","-"):gsub("—","-")
end
function P:AcquisitionRows(r,learned,feeShown)
    local rows,seen,references={},{},{}
    local function add(label,value,key)
        if not value or value=="" then return end
        key=key or label..":"..value
        if seen[key] then return end;seen[key]=true
        rows[#rows+1]={cells={label,value},widths={108,242}}
    end
    local rank=(self.skills[self.selectedProf] or {}).rank or 0
    local function skill(required)
        if learned or not required then return end
        add("Skill required",(rank>=required and "|cff72d58aMet: " or "|cffff8a75Need: ")..self.selectedProf.." "..required.."|r","skill:"..required)
    end
    local meta=self.SpellMeta[r.spell] or {}
    local trainer=r.spell and self.char.trainers and self.char.trainers[self.selectedProf] and self.char.trainers[self.selectedProf]["s"..r.spell]
    local sourceCount=0
    if trainer then
        add("Trainer",trainer.npcID and self:NPCSourceText(trainer.npcID) or (trainer.trainer or "Trainer").."\n"..(trainer.zone or ""));sourceCount=sourceCount+1
        if not learned and not trainer.eligible and not trainer.known then add("Availability","|cffff8a75Unavailable at last trainer visit|r") end
        if not learned and not feeShown and trainer.cost~=nil then add("Training fee",self:SmallMoney(trainer.cost)) end
    elseif not learned and not feeShown and meta.training~=nil then add("Training fee",self:SmallMoney(meta.training).." (source)") end
    for _,observed in ipairs(r.observedTrainerSources or {}) do
        if not trainer or trainer.npcID~=observed.npc then
            add("Trainer",self:NPCSourceText(observed.npc),"observed-trainer:"..observed.npc)
            sourceCount=sourceCount+1
        end
        references["ForeverDB observed (checked "..observed.captured..")"]=true
    end
    local refs=r.acquisitionOnly and {{id=r.item}} or r.acquisitionItems or {}
    local requirements={};local costs={}
    for _,ref in ipairs(refs) do
        local item=self.ItemMeta[ref.id] or {};local vendor=self.char.vendors and self.char.vendors[ref.id]
        if vendor then
            costs[#costs+1]={label="Recipe price",value=self:SmallMoney(vendor.value).." • "..vendor.name}
            if vendor.stock==0 then costs[#costs+1]={label="Stock",value="|cffff8a75Sold out at last visit|r"} end
        end
        for _,source in ipairs(item.sources or {}) do
            local location=source.locationKey and self:SourceLocationText(source.locationKey,ref.id) or source.npc and self:NPCSourceText(source.npc,source.kind=="Drop") or source.name or source.zone
            if not source.npc and not source.locationKey and source.name and source.zone then location=source.name.."\n"..source.zone end
            if location and source.limited then location=location.." (limited stock)" end
            local sourceKey="source:"..(source.kind or "Source")..":"..tostring(source.locationKey or source.npc or source.id or location)
            if not seen[sourceKey] and location then
                add(source.kind or "Source",location,sourceKey);sourceCount=sourceCount+1
            end
            if source.source then references[source.source]=true end
            if source.copper and not vendor then costs[#costs+1]={label="Recipe price",value=self:SmallMoney(source.copper).." / "..(source.name or "Vendor")} end
            if source.favor then costs[#costs+1]={label="Recipe price",value=source.favor.." Merchant's Favor"} end
            requirements[#requirements+1]=source.skill
            if not learned and source.kind=="Quest" and source.id then
                local done=C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(source.id)
                add("Quest status",(done and "|cff72d58aCompleted" or "|cffff8a75Not completed").." ["..source.id.."]|r","quest:"..source.id)
                for _,q in ipairs(self.QuestGuide) do if q.id==source.id then
                    for line in (q.text or ""):gmatch("[^\n]+") do if line:find("^Prerequisite") then add("Prerequisite",(self:BriefSource(line):gsub("^Prerequisites?:%s*",""))) end end
                    break
                end end
                for _,npc in ipairs((self.QuestMeta[source.id] or {}).starters or {}) do add("Quest giver",self:NPCSourceText(npc),"npc:"..npc) end
            end
        end
    end
    if sourceCount==0 then
        local brief=self:BriefSource(r.source)
        if r.sourceKind=="trainer" then
            local _,nearby=self:TrainingStop(r)
            brief=nearby and self:NPCSourceText(nearby.npc.id) or "Profession trainer"
        end
        if brief~="" then add("Source",brief) end
    end
    for _,cost in ipairs(costs) do add(cost.label,cost.value) end
    skill(r.learn or meta.learn)
    for _,required in ipairs(requirements) do skill(required) end
    if not learned then for _,ref in ipairs(refs) do
        for _,line in ipairs(self:RecipeTooltipLines(ref.id)) do
            local text=(line.leftText or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            if text:find("^Requires ") then
                local profession,required=text:match("^Requires (.-) %((%d+)%)")
                if profession and self:Canonical(profession)==self.selectedProf then skill(tonumber(required))
                else
                    local color=line.leftColor;local red=color and color.r and color.r>.8 and (color.g or 1)<.3
                    add(text:find(" %- ") and "Reputation" or "Requirement",(red and "|cffff8a75Need: " or "")..text:gsub("^Requires ","")..(red and "|r" or ""),"require:"..text)
                end
            end
        end
    end end
    local names={};for name in pairs(references) do names[#names+1]=name end;table.sort(names)
    if #names>0 then rows[#rows+1]={cells={table.concat(names," • ")},widths={350},muted=true} end
    return rows
end
function P:AcquisitionChecks(r)return self:AcquisitionRows(r,false,false) end
function P:DetailRows(r,n)
    if r.money then return self:MoneyDetailRows(r,n) end
    local rows={}
    local function add(a,b)rows[#rows+1]={cells={a,tostring(b or "-")},widths={108,242}}end
    local function heading(text)rows[#rows+1]={cells={text},widths={350},heading=true}end
    if r.journeyPrepare then
        heading("PREPARATION STEP")
        add("Profession",r.profession)
        add("Total planned",r.crafts.." crafts")
        local limit=self:RouteBatchLimit(r)
        if limit<9999 then add("Batch limit",limit.." / recheck skill and route") end
    end
    if r.quest then
        local q=r.quest;local meta=self.QuestMeta[q.id] or {}
        add("Status",self:QuestStatus(q));add("Requires","Skill "..q.skill.." • Level "..q.level)
        if meta.change=="new" then add("Added in","Forever") end
        heading("START & OBJECTIVES")
        local count=0
        for _,id in ipairs(meta.starters or {}) do
            local target=self:NearestNPC({id})
            if target then add("Quest giver",self:NPCLink(id).."\n"..target.point.zone..string.format(" %.1f, %.1f",target.point.x*100,target.point.y*100));count=count+1 end
        end
        if count==0 then add("Start",self:BriefSource(q.where)) end
        for paragraph in (q.text or ""):gmatch("[^\n]+") do
            if paragraph:find("^Objectives:") or paragraph:find("^Turn in:") or paragraph:find("^Prerequisite") or paragraph:find("^Breadcrumb") or paragraph:find("^Recipe rewards:") then
                local label,value=paragraph:match("^([^:]+):%s*(.*)")
                add((label or "Next"):gsub(" %b()",""):gsub(" %b[]",""),value or paragraph)
            end
        end
        if q.nextID then add("Next quest",q.nextID) end
        if #(meta.rewards or {})>0 then
            heading("ITEM REWARDS / CHOICES")
            for _,id in ipairs(meta.rewards) do local m=self:ItemFacts(id);add(self.QualityNames[m.quality] or m.type,"|Hitem:"..id.."|h["..self:ItemName(id).."]|h") end
        end
        return rows
    end
    local facts=self:RecipeFacts(r)
    local learned=r.known or r.live or r.cached or r.planKnown
    local known=learned and "Learned" or r.ownership=="Unlearned" and "Unlearned" or "-"
    local rarityColor=({[0]="|cff9d9d9d",[1]="|cffffffff",[2]="|cff1eff00",[3]="|cff0070dd",[4]="|cffa335ee",[5]="|cffff8000"})[facts.quality] or ""
    add("Recipe",known.." • "..rarityColor..(self.QualityNames[facts.quality] or "-").."|r"..(facts.change=="new" and " • NEW" or ""))
    local outputType=r.item and not r.acquisitionOnly and self:ItemFacts(r.item).type
    add("Type / skill",facts.type..(outputType and outputType~=facts.type and " to "..outputType or "")..(learned and r.learn and " • Skill "..r.learn or ""))
    local one=self:Economy(r,1);local batch=self:Economy(r,n);local displayedTrainingFee
    if not r.acquisitionOnly then
        add("One craft",self:SmallMoney(one.cost).." • Output "..(r.output or 1))
        add("Material value",self:SmallMoney(batch.cost).." • "..n.." crafts")
        add("Materials owned",self:SmallMoney(batch.owned).." used from bags")
        add("Still to buy",self:SmallMoney(batch.missing))
        local recorded=r.spell and self.char.trainers and self.char.trainers[self.selectedProf] and self.char.trainers[self.selectedProf]["s"..r.spell]
        local fee=r.planTraining or (learned and 0 or recorded and recorded.cost or nil)
        displayedTrainingFee=fee~=nil
        add("Training fees",fee and self:SmallMoney(fee) or "See source requirements")
        add("Remaining cost",self:SmallMoney(batch.missing and fee and batch.missing+fee))
        if batch.unknown>0 then add("Unpriced",batch.unknown.." reagent(s) • Priced subtotal "..self:SmallMoney(batch.knownCost)) end
        if r.planSale then
            local sale=r.planSale;local net=one.cost and fee and batch.cost+fee-sale.net*n
            heading("SALE ESTIMATE")
            add("Sell via",sale.method.." • "..self:ProfitLabel())
            add("Output to sell",n*sale.output.." • Minimum yield")
            add("Gross / item",self:SmallMoney(sale.gross))
            add("AH cut",math.floor(sale.cut*100+.5).."% assumed")
            add("Proceeds",self:SmallMoney(sale.net*n).." after cut")
            if net then add(self:NetLabel(net),self:SmallMoney(math.abs(net))) end
            rows[#rows+1]={cells={sale.source.." • "..(sale.stamp and ("Updated "..self:PriceDate(sale.stamp,sale.source,r.item)) or "Price date unavailable")},widths={350},muted=true}
            rows[#rows+1]={cells={"Net includes all materials and training. AH assumes all output sells at this price; lost deposits, relisting and price changes are not included. Upfront spending is still required."},widths={350},muted=true}
        end
        heading("MATERIALS • "..n.." CRAFT(S)")
        rows[#rows+1]={cells={"Material","Have / Need","Each","Total"},widths={126,80,68,76},heading=true}
        for _,m in ipairs(r.mats or {}) do
            local price,source,stamp=self:Price(m.id);local need=m.count*n
            -- Recipe APIs may return a reagent before its item ID is cached.
            local supply=m.id and self:SourceNeeds({[m.id]=need},{blocked=r.item and {[r.item]=true} or {}}) or {steps={}}
            if #supply.steps>0 then price=supply.cost and supply.cost/need;source="Make from purchased inputs";stamp=nil end
            rows[#rows+1]={cells={m.id and "|Hitem:"..m.id.."|h["..self:ItemName(m.id).."]|h" or m.name or "Loading",self:Count(m.id).." / "..need,self:SmallMoney(price),self:SmallMoney(price and price*need)},widths={126,80,68,76}}
            local vendor=self.char.vendors and self.char.vendors[m.id]
            local provider=vendor and vendor.npcID and source=="Merchant: "..vendor.name and self:NPCLink(vendor.npcID) or source
            rows[#rows+1]={cells={provider.." • Updated "..self:PriceDate(stamp,source,m.id)},widths={350},muted=true}
        end
    end
    for _,row in ipairs(self:SourcingDetailRows(batch.missingPlan)) do rows[#rows+1]=row end
    if batch.missingPlan and #batch.missingPlan.steps>0 then
        heading("BASE MATERIALS TO BUY")
        for id,count in pairs(batch.missingPlan.buy) do if count>0 then
            local price,source,stamp=self:Price(id)
            add("|Hitem:"..id.."|h["..self:ItemName(id).."]|h",count.." / "..self:SmallMoney(price and price*count))
            rows[#rows+1]={cells={source.." / "..self:PriceDate(stamp,source,id)},widths={350},muted=true}
        end end
    end
    if r.start and r.stop then
        heading("ROUTE & SKILL GAINS")
        add("Skill range",r.start.." to "..r.stop)
        if r.crafts then add("Planned crafts",r.crafts.." • Minimum "..math.ceil((r.stop-r.start)/(r.numSkillUps or 1))) end
        local a=self:PlanChance(r,r.start,r.start);local b=self:PlanChance(r,r.stop-1,r.start)
        add("Skill chance",(a and math.floor(a*100+.5).."%" or "-").." to "..(b and math.floor(b*100+.5).."%" or "-").." conservative estimate")
        if r.crafts and r.crafts>(r.stop-r.start)/(r.numSkillUps or 1) then
            rows[#rows+1]={cells={"Extra attempts allow for missed yellow/green skill-ups. Non-orange chances include a 20% planning reduction; known yellow/green bands are capped at 40%/16% and decline toward gray. Skill gains remain random."},widths={350},muted=true}
        end
        if self.SkillBand then
            local bands={}
            for _,entry in ipairs({{"Yellow",r.yellow},{"Green",r.green},{"Gray",r.grey}}) do if entry[2] then bands[#bands+1]=entry[1].." "..entry[2] end end
            if #bands>0 then add("Color changes",table.concat(bands," / ")) end
            if r.routeBand then
                add("Reassess at",r.stop.." / "..r.routeBoundary)
                add("Batch limit",self:RouteBatchLimit(r).." crafts before rechecking")
            end
        end
        if r.prep and r.prep~="" then add("Prepare",r.prep) end
        if r.planStep then
            add("Why this recipe",(r.planKnown and "Learned" or "Recorded trainer recipe")..(r.planSale and " • Best estimated net return" or " • Lowest estimated route cost"))
            add(r.planSale and "Net cost / skill" or "Cost / skill",self:SmallMoney((r.planCost+r.planTraining-(r.planProceeds or 0))/math.max(1,r.stop-r.start)).." incl. training")
            local summary=self.planSummary
            if summary then
                add("Route materials",self:SmallMoney(summary.materials));add("Route owned",self:SmallMoney(summary.materials-summary.shopping))
                add("Route to buy",self:SmallMoney(summary.shopping));add("Route training",self:SmallMoney(summary.training))
                add("Route remaining",self:SmallMoney(summary.shopping+summary.training))
                if r.planSale then add("Route proceeds",self:SmallMoney(summary.proceeds));add(self:NetLabel(summary.net).." / route",self:SmallMoney(math.abs(summary.net))) end
                if summary.preferenceNotice then add("Route choice",summary.preferenceNotice) end
            end
            rows[#rows+1]={cells={r.planSale and "Profit ranks expected sale proceeds against full material value and training. Craft counts remain skill estimates; no extra stock is added for selling." or "Cheapest compares total material value plus training. Bag supplies reduce remaining spending, not the route's price ranking. Exclude recipes to recalculate; favorites do not affect planning."},widths={350},muted=true}
        end
    end
    if self.ObservedSkills and r.spell and learned and not r.acquisitionOnly then
        local rank=r.skillAtCapture or (self.skills[self.selectedProf] or {}).rank or 0
        local observed=self:ObservedSkills(r,rank)
        heading("YOUR CRAFTING RESULTS")
        if observed then
            add("Observed",observed.gains.." skill-ups / "..observed.attempts.." completed crafts ("..math.floor(100*observed.gains/observed.attempts+.5).."%)")
            add("Sample range",observed.start.." to "..observed.finish.." • "..(({optimal="Orange",medium="Yellow",easy="Green",trivial="Grey"})[observed.color] or ""))
            add("Planning use",observed.attempts<20 and "Collecting: 20 crafts needed" or "May lower estimates; never raises them")
        else add("Observed","No completed crafts recorded in this skill band") end
    end
    local stop,trainer,stopKind=self:TrainingStop(r)
    if r.blocked then add("Craft requires",r.blocked) end
    if stop and stop~="Learn this recipe" then
        heading("TRAINING STOP")
        add("When",stop)
        if trainer then add(stopKind or (trainer.comparable and "Nearest trainer" or "Trainer"),self:NPCLink(trainer.npc.id).."\n"..trainer.point.zone..string.format(" %.1f, %.1f",trainer.point.x*100,trainer.point.y*100)) end
    end
    local acquisition=self:AcquisitionRows(r,learned,displayedTrainingFee)
    if #acquisition>0 then
        heading("SOURCE & REQUIREMENTS")
        for _,row in ipairs(acquisition) do rows[#rows+1]=row end
    end
    return rows
end
function P:RenderDetailRows(rows,startY)
    self.detailCells=self.detailCells or {};local used=0;local y=startY or 0
    self.detailSourceButtons=self.detailSourceButtons or {};local sourceButtonsUsed=0
    local displayRows=self.Theme and self.Theme.DetailOrder(self,rows) or rows
    self.displayDetailRows=displayRows
    for index,row in ipairs(displayRows) do
        local x,maxHeight=0,18
        for col,value in ipairs(row.cells) do
            used=used+1;local cell=self.detailCells[used]
            if not cell then cell=self.detailChild:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");cell:SetJustifyH("LEFT");cell:SetJustifyV("TOP");self.detailCells[used]=cell end
            cell:ClearAllPoints();cell:SetPoint("TOPLEFT",x,-y);cell:SetWidth(row.widths[col]*(self.readableDetailWidth or 350)/350-10);cell:SetSpacing(4)
            if self.Theme and self.artisanReady then self.Theme.Font(cell,row.heading and #row.cells==1 and 22 or row.muted and 18 or 20,row.heading and #row.cells==1) end
            cell:SetText((row.heading and "|cffd8b15e" or row.muted and "|cffc8bfae" or col==1 and #row.cells==2 and "|cffd6ba7a" or "|cffe8ddc5")..tostring(value).."|r")
            cell:Show();maxHeight=math.max(maxHeight,cell:GetStringHeight());x=x+row.widths[col]*(self.readableDetailWidth or 350)/350
        end
        if row.sourceGroup then
            sourceButtonsUsed=sourceButtonsUsed+1
            local b=self.detailSourceButtons[sourceButtonsUsed]
            if not b then
                b=CreateFrame("Button",nil,self.detailChild,"UIPanelButtonTemplate")
                b:SetScript("OnClick",function(s)P:ToggleGatherSourceGroup(s.sourceGroup)end)
                self.detailSourceButtons[sourceButtonsUsed]=b
            end
            b.sourceGroup=row.sourceGroup;b:SetText(row.sourceAction)
            b:ClearAllPoints();b:SetPoint("TOPLEFT",(row.widths[1]+row.widths[2])*(self.readableDetailWidth or 350)/350,-y-maxHeight-4)
            b:SetSize(124,28)
            if self.Theme and self.artisanReady then self.Theme.Button(b) end
            b:Show();maxHeight=maxHeight+36
        end
        y=y+maxHeight+(row.heading and 7 or row.muted and 9 or 5)
    end
    for i=sourceButtonsUsed+1,#self.detailSourceButtons do self.detailSourceButtons[i]:Hide() end
    for i=used+1,#self.detailCells do self.detailCells[i]:Hide() end
    self.detailBody:SetText("");self.detailChild:SetHeight(math.max(325,y+12));self.currentDetailRows=rows
end
function P:HideDetailRows()
    for _,cell in ipairs(self.detailCells or {}) do cell:Hide() end
    for _,button in ipairs(self.detailSourceButtons or {}) do button:Hide() end
    self.currentDetailRows=nil
end
function P:CreateFacetControls(parent)
    self.facetButtons={}
    for i,kind in ipairs({"type","quality","new"}) do
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",12+(i-1)*133,-42);b:SetSize(130,24)
        self:DecorateDropdown(b)
        b.dropdownAlignRight=kind=="new"
        b:SetScript("OnClick",function()
            local field=P.tab=="Quests" and "questFacets" or "catalogFacets"
            local f=P[field] or {};P:NormalizeFacets(f);local options={{label="All"}}
            if kind=="new" then options[2]={label="New in Forever",value=true}
            elseif kind=="quality" then
                for quality=0,5 do options[#options+1]={label=P.QualityNames[quality],value=quality} end
            else
                options=P:TypeOptions()
            end
            local current=f[kind];if kind=="type" and f.subtype~=nil then current=f.type..":"..f.subtype end;if kind=="new" and not current then current=nil end
            P:ToggleDropdown(b,options,current,function(value)
                P[field]=P[field] or {};P[field][kind]=value
                if kind=="type" then
                    local category,sub;if value then category,sub=value:match("^(.+):(%d+)$") end
                    P[field].type=category or value;P[field].subtype=tonumber(sub)
                end
                P.offset=0;P.selectedKey=nil;P:Refresh()
            end)
        end)
        self.facetButtons[kind]=b
    end
end

-- One shared, addon-owned popup. No protected Blizzard menu state is modified.
function P:DecorateDropdown(button)
    local arrow=button:CreateTexture(nil,"OVERLAY")
    arrow:SetSize(18,18);arrow:SetPoint("RIGHT",-3,0)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    button.dropdownArrow=arrow
    -- Keep long filter labels out of the arrow; the full choice appears in the menu.
    local text=button:GetFontString()
    if text then text:ClearAllPoints();text:SetPoint("LEFT",7,0);text:SetPoint("RIGHT",-23,0);text:SetJustifyH("LEFT") end
end
function P:CloseDropdown()
    if self.dropdown then self.dropdown:Hide();self.dropdown.owner=nil end
end
function P:ToggleDropdown(owner,options,current,select,nested)
    local root=self.dropdown
    if not nested and root and root:IsShown() and root.owner==owner then self:CloseDropdown();return end
    if not root then
        root=CreateFrame("Button","ProfPadenDropdown",UIParent);self.dropdown=root
        root:SetAllPoints(UIParent);root:SetFrameStrata("FULLSCREEN_DIALOG");root:SetFrameLevel(200)
        root:RegisterForClicks("AnyDown");root:SetScript("OnClick",function()P:CloseDropdown()end)
        local menu=CreateFrame("Frame",nil,root,"BackdropTemplate");root.menu=menu;root.rows={}
        menu:SetFrameLevel(201);menu:EnableMouse(true);menu:SetClampedToScreen(true)
        menu:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
        menu:SetBackdropColor(.08,.065,.04,1);menu:SetBackdropBorderColor(.65,.49,.24,1)
        local scroll=CreateFrame("ScrollFrame",nil,menu,"UIPanelScrollFrameTemplate");root.scroll=scroll
        scroll:SetPoint("TOPLEFT",8,-8);scroll:SetPoint("BOTTOMRIGHT",-28,8)
        local list=CreateFrame("Frame",nil,scroll);root.list=list;scroll:SetScrollChild(list)
        tinsert(UISpecialFrames,"ProfPadenDropdown")
        if self.window then self.window:HookScript("OnHide",function()P:CloseDropdown()end) end
    end
    root.owner=owner;root.tab=self.tab;root.profession=self.selectedProf
    root.menu:ClearAllPoints()
    if owner.dropdownAlignRight then root.menu:SetPoint("TOPRIGHT",owner,"BOTTOMRIGHT",0,-2)
    else root.menu:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-2) end
    local width=math.max(360,owner:GetWidth())
    root.menu:SetSize(width,math.min(#options*42,math.max(84,UIParent:GetHeight()-64))+16)
    root.list:SetSize(width-36,#options*42);root.scroll:SetVerticalScroll(0)
    for i,option in ipairs(options) do
        local row=root.rows[i]
        if not row then
            row=CreateFrame("Button",nil,root.list);root.rows[i]=row;row:SetFrameLevel(204)
            row:SetPoint("TOPLEFT",0,-(i-1)*42);row:SetPoint("TOPRIGHT",root.list,"TOPRIGHT",0,-(i-1)*42);row:SetHeight(42)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row.check=row:CreateTexture(nil,"ARTWORK");row.check:SetSize(18,18);row.check:SetPoint("LEFT",1,0)
            row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
            row.label:SetPoint("LEFT",24,0);row.label:SetPoint("RIGHT",-6,0);row.label:SetJustifyH("LEFT")
        end
        if self.Theme then self.Theme.Panel(root.menu);self.Theme.Font(row.label,18) end
        row.label:SetText(option.label..(option.children and " >" or ""));row.label:SetTextColor(option.value==current and 1 or .91,option.value==current and .82 or .87,option.value==current and 0 or .77)
        row.check:SetShown(not option.back and not option.children and option.value==current);row:Show()
        row:SetScript("OnClick",function()
            if option.back then option.back()
            elseif option.children then
                local children={{label="< Back",back=function()P:ToggleDropdown(owner,options,current,select,true)end}}
                for _,child in ipairs(option.children) do children[#children+1]=child end
                P:ToggleDropdown(owner,children,current,select,true)
            else P:CloseDropdown();select(option.value) end
        end)
    end
    for i=#options+1,#root.rows do root.rows[i]:Hide() end
    root:Show()
end
function P:RefreshFacets()
    local visible=self.tab=="Catalog" or self.tab=="Quests";local f=(self.tab=="Quests" and self.questFacets or self.catalogFacets) or {}
    self:NormalizeFacets(f)
    for _,b in pairs(self.facetButtons) do b:SetShown(visible) end
    self.facetButtons.type:SetText((self.tab=="Quests" and "Reward: " or "Type: ")..(self:SubtypeName(f.type,f.subtype) or f.type or "All"))
    self.facetButtons.quality:SetText("Rarity: "..(self.QualityNames[f.quality] or "All"))
    self.facetButtons.new:SetText(f.new and "Forever: New" or "Forever: All")
    self:RefreshMaterialFilters()
    local expanded=visible or self:MaterialFiltersActive()
    self.listHint:ClearAllPoints();self.listHint:SetPoint("TOPLEFT",14,expanded and -72 or -42)
    for i,b in ipairs(self.rows) do b:ClearAllPoints();b:SetPoint("TOPLEFT",10,-(expanded and 96 or 68)-(i-1)*(expanded and 46 or 50));b:SetHeight(expanded and 44 or 48) end
end
