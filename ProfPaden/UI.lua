local _,P=...
function P:GatherTabLabel()
    return (self.selectedProf=="Mining" or self.selectedProf=="Herbalism" or self.selectedProf=="Skinning" or self.selectedProf=="Fishing" or self.selectedProf=="Cooking") and "Gather" or "Materials"
end

local GOLD="|cffffd100";local WHITE="|cffe8ddc5";local MUTED="|cffb1a58c";local GREEN="|cff72d58a";local RED="|cffff8a75"
local function label(parent,size,x,y,width,text)
    local f=parent:CreateFontString(nil,"OVERLAY",size or "GameFontNormal")
    f:SetPoint("TOPLEFT",x,y);if width then f:SetWidth(width) end
    f:SetJustifyH("LEFT");f:SetJustifyV("TOP");f:SetText(text or "");return f
end
local function panel(parent,x,y,w,h,parchment)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate");f:SetPoint("TOPLEFT",x,y);f:SetSize(w,h)
    -- QuestBG contains transparent/padded areas; it is not a scalable fill.
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=false,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    f:SetBackdropColor(parchment and .3 or .12,parchment and .25 or .1,parchment and .17 or .08,1);f:SetBackdropBorderColor(.65,.49,.24,1)
    return f
end
local function button(parent,x,y,w,text,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(w,24);b:SetText(text);b:SetScript("OnClick",fn);return b
end
local function edit(parent,x,y,w,numeric)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate");e:SetPoint("TOPLEFT",x,y);e:SetSize(w,24);e:SetAutoFocus(false)
    if numeric then e:SetNumeric(true) end
    e:SetScript("OnEscapePressed",function(s)s:ClearFocus()end);return e
end
function P:Toggle()
    if not self.window then self:CreateUI() end
    if self.window:IsShown() then self.window:Hide() else self:ReadSkills();self:ScanRecipes();self.window:Show();self:Refresh() end
end
function P:CreateUI()
    local f=CreateFrame("Frame","ProfPadenWindow",UIParent,"BackdropTemplate");self.window=f
    f:SetSize(1060,700);f:SetPoint("CENTER");f:SetFrameStrata("HIGH");f:SetClampedToScreen(true)
    f:SetScale(math.min(1,(UIParent:GetWidth()-30)/1060,(UIParent:GetHeight()-30)/700))
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=false,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}})
    f:SetBackdropColor(.055,.05,.04,1)
    f:EnableMouse(true);f:SetMovable(true);f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    tinsert(UISpecialFrames,"ProfPadenWindow")
    local portrait=f:CreateTexture(nil,"ARTWORK");self.brandIcon=portrait;portrait:SetSize(38,38);portrait:SetPoint("TOPLEFT",24,-21);portrait:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    self.brand=label(f,"GameFontNormalLarge",74,-22,600,"PROFPADEN  "..MUTED.."Artisan's Field Guide|r")
    self.tagline=label(f,"GameFontHighlightSmall",75,-45,900,"Recipes, journeys & provisions  |  WoW: Forever  |  Beta guide • 16 October 2026")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-12,-12)
    local left=panel(f,18,-76,168,556);self.sidebar=left
    self.sidebarTitle=label(left,"GameFontNormalSmall",13,-14,145,"YOUR PROFESSIONS")
    self.profButtons={}
    for i,pr in ipairs(self.professions) do
        local name=pr[1];local b=CreateFrame("Button",nil,left);b:SetPoint("TOPLEFT",8,-38-(i-1)*40);b:SetSize(152,38)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");local tex=b:CreateTexture(nil,"ARTWORK");b.icon=tex;tex:SetPoint("LEFT",5,0);tex:SetSize(25,25);tex:SetTexture("Interface\\Icons\\"..pr[3])
        b.title=label(b,"GameFontNormalSmall",36,-4,110,name);b.rank=label(b,"GameFontHighlightSmall",36,-20,110,"")
        b:SetScript("OnClick",function()P.selectedProf=name;P.char.profession=name;P.offset=0;P.selectedKey=nil;P:Refresh()end)
        self.profButtons[name]=b
    end
    self.heading=label(f,"GameFontNormalLarge",202,-80,600,"")
    self.rankText=label(f,"GameFontHighlightSmall",202,-106,400,"")
    self.tabs={}
    for i,name in ipairs({"Recipes","Catalog","Gather","Quests"}) do
        self.tabs[name]=button(f,202+(i-1)*106,-130,100,name=="Recipes" and "Leveling" or name,function()P.tab=name;P.offset=0;P.selectedKey=nil;if name=="Quests" then P:IndexQuests() end;P:Refresh()end)
    end
    self:CreateProfessionButton(f)
    self.autoArrows=button(f,856,-98,184,"",function()
        P:SetNavigationEnabled(not P:IsNavigationEnabled())
    end)
    self.autoArrows:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_TOP");GameTooltip:SetText("Waypoint tracking")
        GameTooltip:AddLine("Routes, recipe/NPC links, and gathering directions. Off clears active pins and pauses walking routes. Gathering icons remain visible.",1,1,1,true)
        GameTooltip:Show()
    end)
    self.autoArrows:SetScript("OnLeave",function()GameTooltip:Hide()end)
    self.scanButton=button(f,746,-130,100,"Full scan",function()P:StartAuctionatorScan();P:Refresh()end)
    self.campButton=button(f,852,-130,100,"Camp kit",function()P:ToggleCamp()end)
    self.shoppingButton=button(f,958,-130,82,"Shopping",function()P:ToggleShopping()end)
    local list=panel(f,198,-164,422,468);self.listPanel=list
    self.modeButton=button(list,12,-12,210,"",function()
        if P.tab=="Gather" then
            P:ToggleDropdown(P.modeButton,P:GatherOptions(),P:GatherView(),function(value)P.gatherView=value;P.offset=0;P.selectedKey=nil;P:Refresh()end);return
        end
        if P.tab=="Catalog" then
            P:ToggleDropdown(P.modeButton,{{label="All recipes",value="all"},{label="Favorites",value="favorites"},{label="Learned",value="known"},{label="Unlearned",value="unlearned"},{label="Trainer",value="trainer"},{label="Drops",value="drop"},{label="Vendors",value="vendor"}},P.catalogFilter or "all",function(value)
                P.catalogFilter=value;P.offset=0;P.selectedKey=nil;P:Refresh()
            end)
            return
        end
        P:ToggleDropdown(P.modeButton,{{label="Guided",value="guide"},{label="In my bags",value="bags"},{label="Cheapest",value="cost"},{label="Profit / minimal loss",children=P:ProfitOptions()},{label="Money-making",children=P:MoneyOptions()},{label="Live alternatives",value="live"},{label="All steps",value="all"}},P.mode=="money" and "money:"..(P.char.moneySale or "best5") or P.mode=="profit" and "profit:"..P:ProfitSetting() or P.mode,function(value)
            if value:find("^money:") then P.char.moneySale=value:sub(7);value="money" elseif value:find("^profit:") then P.char.profitSale=value:sub(8);value="profit" end;P.mode=value;P.offset=0;P.selectedKey=nil;P:Refresh()
        end)
    end)
    self:DecorateDropdown(self.modeButton)
    self.search=edit(list,240,-12,160,false)
    self.search:SetScript("OnTextChanged",function(s,user)if user then
        if P.tab=="Gather" then P.gatherSearch=s:GetText() elseif P.tab=="Quests" then P.questSearch=s:GetText() else P.catalogSearch=s:GetText() end
        P.offset=0;P.selectedKey=nil;P:Refresh()
    end end)
    self.listHint=label(list,"GameFontHighlightSmall",14,-42,392,"")
    self.planGoalLabel=label(list,"GameFontHighlightSmall",246,-19,48,"Goal:")
    self.planGoal=edit(list,298,-12,92,true)
    self.planGoal:SetScript("OnEnterPressed",function(s)
        local skill=P.skills[P.selectedProf]
        if P.mode=="money" then P:SetMoneyBatch(s:GetText())
        elseif skill then
            P.char.planTargets=P.char.planTargets or {}
            P.char.planTargets[P.selectedProf]=math.max(skill.rank,math.min(skill.cap,math.floor(tonumber(s:GetText()) or skill.cap)))
            P:InvalidatePlan();P.selectedKey=nil;P.offset=0
        end
        s:ClearFocus();P:Refresh()
    end)
    self:CreateFacetControls(list)
    self:CreateMaterialFilters(list)
    self:CreateFilterReset(list)
    self.rows={}
    for i=1,7 do
        local b=CreateFrame("Button",nil,list,"BackdropTemplate");b:SetPoint("TOPLEFT",10,-68-(i-1)*50);b:SetSize(402,48)
        b:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});b:SetBackdropColor(.13,.11,.08,.7)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetPoint("TOPLEFT",7,-8);b.icon:SetSize(30,30)
        b.title=label(b,"GameFontNormal",46,-7,348,"");b.sub=label(b,"GameFontHighlightSmall",46,-27,348,"")
        b.materialGroup=label(b,"GameFontNormalSmall",7,-1,385,"");b.materialGroup:SetHeight(13);b.materialGroup:SetWordWrap(false)
        b.materialRule=b:CreateTexture(nil,"ARTWORK");b.materialRule:SetPoint("TOPLEFT",7,-14);b.materialRule:SetSize(388,1);b.materialRule:SetColorTexture(.65,.48,.14,.65)
        b.title:SetHeight(18);b.title:SetWordWrap(false);b.sub:SetHeight(16);b.sub:SetWordWrap(false)
        b:SetScript("OnClick",function(s)if s.entry then P.selectedKey=s.entry.key;P.selected=s.entry;P:SetQuantity();P:Refresh() end end)
        b:SetScript("OnEnter",function(s)P:ShowListingTooltip(s,s.entry)end)
        b:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
        self.rows[i]=b
    end
    list:EnableMouseWheel(true);list:SetScript("OnMouseWheel",function(_,delta)P:Page(delta>0 and -1 or 1)end)
    self.prev=button(list,12,-430,70,"< Back",function()P:Page(-1)end)
    self.page=label(list,"GameFontHighlightSmall",105,-437,200,"")
    self.next=button(list,330,-430,80,"Next >",function()P:Page(1)end)
    self.clearFilters=self.resetFilters
    local detail=panel(f,630,-164,410,468,true);self.detail=detail
    self.detailTitle=label(detail,"GameFontNormalLarge",16,-16,375,"")
    self.detailTitle:SetHeight(20);self.detailTitle:SetWordWrap(false)
    self.pinRecipe=button(detail,16,-38,106,"Pin favorite",function()P:ToggleFavorite(P.selected)end)
    self.excludeRecipe=button(detail,128,-38,106,"Exclude",function()if P.selected then P:SetRouteChoice("exclude",P.selected) end end)
    self.resetChoices=button(detail,240,-38,150,"Reset route choices",function()P:SetRouteChoice("reset")end)
    local scroll=CreateFrame("ScrollFrame","ProfPadenDetailScroll",detail,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",16,-64);scroll:SetPoint("BOTTOMRIGHT",-32,78)
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(352,400);scroll:SetScrollChild(child);self.detailScroll=scroll;self.detailChild=child
    self.detailBody=label(child,"GameFontHighlight",0,0,350,"");self.detailBody:SetSpacing(4)
    child:SetHyperlinksEnabled(true);child:EnableMouse(true)
    child:SetScript("OnHyperlinkEnter",function(s,link)P:ShowListingTooltip(s,{link=link})end)
    child:SetScript("OnHyperlinkClick",function(_,link)
        local material=tonumber(link:match("^profpaden:material:(%d+)$"))
        if material then P:OpenMaterial(material);return end
        local producer=tonumber(link:match("^profpaden:make:(%d+)$"))
        if producer then P:OpenMaterialProducer(producer);return end
        local methodPage=tonumber(link:match("^profpaden:methods:(%d+)$"))
        if methodPage and P.selected and P.selected.gatherItem then P.materialCraftPage=methodPage;P:RefreshDetail();return end
        local spell=tonumber(link:match("^profpaden:recipe:(%d+)$"))
        if spell then P:OpenMaterialRecipe(spell);return end
        local page=tonumber(link:match("^profpaden:uses:(%d+)$"))
        if page and P.selected and P.selected.gatherItem then P.materialUsePage=page;P:RefreshDetail();return end
        local sourcePage=tonumber(link:match("^profpaden:sources:(%d+)$"))
        if sourcePage and P.selected and P.selected.gatherItem then P.gatherSourcePage=sourcePage;P:RefreshDetail();return end
        local sourceScope=link:match("^profpaden:sourcescope:(%a+)$")
        if (sourceScope=="all" or sourceScope=="map") and P.selected and P.selected.gatherItem then
            P.gatherSourceScope=sourceScope;P.gatherSourcePage=1;P:RefreshDetail();return
        end
        local place,item=link:match("^profpaden:place:([%w%-]+):(%d+)$")
        if place then P:TrackSourceLocation(place,tonumber(item));return end
        local id=link:match("^profpaden:npc:(%d+)")
        if id then P:TrackNPC(tonumber(id),link:match(":drop$")~=nil,not link:match(":drop$") and P:NPCNavigationGoal(P.selected,tonumber(id)) or nil) end
    end)
    child:SetScript("OnHyperlinkLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    self.qtyLabel=label(detail,"GameFontHighlightSmall",16,-404,100,"Crafts:")
    self.qty=edit(detail,70,-399,55,true);self.qty:SetNumber(1)
    self.qty:SetScript("OnTextChanged",function(_,user)if user and P.selected then P:RefreshDetail() end end)
    self.craft=button(detail,142,-399,146,"Craft batch",function()
        if not P.selected then return end
        local ok,msg=P:Craft(P.selected,tonumber(P.qty:GetText()));P.message=msg;P:Print(msg);P:Refresh()
    end)
    self.priceButton=button(detail,296,-399,99,"Set price",function()if P.selected and P.selected.money then P:ExportMoneyInputs(P.selected,tonumber(P.qty:GetText())) else P:PriceEditor() end end)
    self.routeAction=button(detail,16,-399,200,"",function()
        local r=P.selected;if not r or not r.journeyAction then return end
        if r.target then P.dismissedRouteKey=nil;if P:TrackNPC(r.target.npc.id,nil,P:NPCNavigationGoal(r,r.target.npc.id)) then P.navRouteKey=P.selectedProf..":"..r.key end
        elseif r.actionKind=="quest" then P.tab="Quests";P.selectedKey=nil;P.offset=0;P:Refresh()
        else P:OpenRouteShopping() end
    end)
    self.source=edit(detail,22,-432,278,false);self.source:SetScript("OnEditFocusGained",function(s)s:HighlightText()end)
    self.sourceNext=button(detail,310,-432,83,"Source >",function()
        P.sourceChoice=(P.sourceChoice or 1)+1;P:RefreshDetail()
    end)
    self.status=label(f,"GameFontHighlightSmall",26,-643,1006,"");self.status:SetSpacing(4)
    if self.Theme then self.Theme.Initialize(self) end
    f:Hide()
end
function P:Page(direction)
    self.offset=math.max(0,math.min(math.max(0,math.floor((#(self.entries or {})-1)/7)*7),self.offset+direction*7));self:Refresh()
end
function P:SetQuantity()
    if not self.selected or not self.selected.mats then return end
    local r=self.selected;local rank=(self.skills[self.selectedProf] or {}).rank or 1
    local count=r.crafts and math.ceil(r.crafts*math.max(0,(r.stop or rank+1)-math.max(rank,r.start or rank))/math.max(1,(r.stop or rank+1)-(r.start or rank))) or 1
    count=math.max(1,math.min(count, r.ready and r.ready>0 and r.ready or 9999,9999))
    if self.RouteBatchLimit then count=math.max(1,math.min(count,self:RouteBatchLimit(r))) end
    if r.api=="craft" or r.enchant then count=1 end
    self.qty:SetNumber(count);self.detailScroll:SetVerticalScroll(0)
end
function P:Entries()
    if self:IsGatherGuide() then return self:GatherGuideRows() end
    if self.tab=="Recipes" then local rows=self:Rows();return self.RouteEntries and self:RouteEntries(rows) or rows end
    if self.tab=="Catalog" then return self:CatalogRows() end
    local entries={};self.listTotal=0
    if self.tab=="Gather" then
        local atlas=self.GatherEntries and self:GatherEntries();if atlas then return atlas end
        local prof=self.selectedProf
        for i,r in ipairs(self.Gathering[prof] or {}) do
            entries[#entries+1]={key="g"..i,title=r[3],sub=r[1].."-"..r[2].." "..prof,body=GOLD..r[4].."|r\n\n"..r[5].."\n\n"..WHITE..r[6].."|r\n\n"..MUTED.."Classic route areas; Forever spawn locations and fish requirements are not fully verified. Blue areas in Materials and Fishing pools show recorded source locations. NodeSight symbols show live detections.|r",url="https://classicwowforever.com/professions/"..prof:lower().."/"}
            entries[#entries].gatherBand=i
        end
        if prof=="Cloth" then entries={{key="cloth",title="Cloth and thread",sub="World drops + trade suppliers",body=self.MaterialHints.cloth.."\n\nKeep cloth needed by First Aid before turning all of it into bolts. Threads and dyes come from trade suppliers. Humanoid drops do not require a gathering profession."}} end
        if prof=="Disenchanting" then entries={{key="de",title="Dusts, essences and rods",sub="Disenchanting + blacksmith support",body="Disenchant unwanted gear for enchanting reagents, or compare AH prices. Disenchanting destroys the item; use the game's own spell deliberately. Forever adds Mote of Magic and changes many reagent lists. Open Enchanting to use the live requirements. Buy metal rods from a blacksmith or the relevant supplier, then craft the runed rod."}} end
    elseif self.tab=="Quests" then
        local function append(q)
            if q.profession~=self.selectedProf or q.faction and q.faction~=UnitFactionGroup("player") then return end
            self.listTotal=self.listTotal+1
            local search=(self.questSearch or ""):lower()
            if search~="" and not (q.title.." "..q.where.." "..q.text.." "..tostring(q.id or "")):lower():find(search,1,true) then return end
            if not self:MatchesFacets(q,true) then return end
            local status=self:QuestStatus(q)
            entries[#entries+1]={quest=q,key="q"..(q.id or q.title),title=q.title..(q.id and q.title:find("Camping 101:",1,true) and " ["..q.id.."]" or ""),sub=status.."  •  Skill "..q.skill.." / Level "..q.level,
                body=GOLD..q.where.."|r\n\n"..q.text..(q.nextID and "\n\nLeads to: quest "..q.nextID or "").."\n\nStatus: "..status..". Meeting the displayed skill and level alone does not establish quest eligibility.",url=q.id and "https://www.wowhead.com/forever/quest="..q.id or "https://classicwowforever.com/professions/crafting/"}
        end
        for _,q in ipairs(self.QuestGuide) do append(q) end
        for _,q in ipairs(self.extraQuests or {}) do append(q) end

    end
    return entries
end
function P:Refresh()
    if self.dropdown and (self.dropdown.tab~=self.tab or self.dropdown.profession~=self.selectedProf) then self:CloseDropdown() end
    if not self.window then return end
    if self.tab=="Gather" and not self.Gathering[self.selectedProf] then self.tab="Recipes";self.offset=0;self.selectedKey=nil end
    local tabIndex=0
    for _,name in ipairs({"Recipes","Catalog","Gather","Quests"}) do
        local b=self.tabs[name];local visible=name~="Gather" or self.Gathering[self.selectedProf]~=nil
        b:SetShown(visible)
        if name=="Gather" then b:SetText(self:GatherTabLabel()) end
        if visible then b:ClearAllPoints();b:SetPoint("TOPLEFT",202+tabIndex*106,-130);tabIndex=tabIndex+1 end
    end
    local skill=self.skills[self.selectedProf]
    self.heading:SetText(self.selectedProf.."  "..MUTED..(self.tab=="Recipes" and "Workshop" or self.tab=="Gather" and self:GatherTabLabel() or self.tab).."|r")
    self.autoArrows:Show()
    self.autoArrows:SetText(self:IsNavigationEnabled() and "Tracking: On" or "Tracking: Off")
    self.rankText:SetText(skill and ("Skill "..skill.rank.." / "..skill.cap..(skill.rank>=skill.cap and self.mode~="money" and "  •  Train the next rank before gathering or crafting for skill." or "")) or "Browse mode • Profession not detected on this character")
    for name,b in pairs(self.profButtons) do
        local s=self.skills[name];b.rank:SetText(s and (s.rank.." / "..s.cap) or "Browse guide");b.title:SetText((name==self.selectedProf and GOLD or WHITE)..name.."|r")
    end
    for name,b in pairs(self.tabs) do b:SetEnabled(name~=self.tab) end
    self.modeButton:SetShown(self.tab=="Recipes" or self.tab=="Catalog" or self.tab=="Gather")
    self.modeButton:SetText(self.tab=="Gather" and ("Show: "..self:GatherViewLabel()) or self.tab=="Catalog" and ("Show: "..(self.catalogFilter or "all")) or ({guide="Route: Guided",bags="Route: In my bags",cost="Route: Cheapest",profit="Route: Profit",money="Route: Money-making",live="Route: Live alternatives",all="Route: All steps"})[self.mode])
    local cheapest=not self:IsGatherGuide() and self.tab=="Recipes" and (self:IsOptimizedRoute() or self.RouteEntries and self.mode=="guide")
    local money=self.tab=="Recipes" and self.mode=="money"
    self.planGoal:SetShown(cheapest or money);self.planGoalLabel:SetShown(cheapest or money);self.planGoalLabel:SetText(money and "Batch:" or "Goal:")
    self.search:SetShown(not self:IsGatherGuide() and (self.tab=="Catalog" or self.tab=="Quests" or self.tab=="Gather"))
    self.search:SetText(self.tab=="Gather" and (self.gatherSearch or "") or self.tab=="Quests" and (self.questSearch or "") or (self.catalogSearch or ""))
    self.scanButton:SetText(self:IsAuctionatorScanning() and ("Scan "..(self.auctionatorScanPercent or 0).."%") or "Full scan")
    self.listHint:SetText(self.tab=="Recipes" and "Click a recipe • scroll for more" or self.tab=="Catalog" and "Search name, source or ID • click Show to filter" or self.tab=="Quests" and "Search quest, starter, zone or ID • scroll for more" or "Choose an entry to read the field notes")
    if self:IsGatherGuide() then self.listHint:SetText("Suggested zones / choose a heatmap / train before your skill cap") end
    self.entries=self:Entries();self.offset=math.min(self.offset,math.max(0,math.floor((#self.entries-1)/7)*7))
    if cheapest and self.planSummary then
        local p=self.planSummary
        if not self.planGoal:HasFocus() then self.planGoal:SetNumber(p.target) end
        self.listHint:SetText("Plan "..p.start.."-"..p.reached..(p.reached<p.target and " (gap)" or "").." • "..(p.objective=="profit" and self:NetLabel(p.net).." "..self:SmallMoney(math.abs(p.net)) or self:Money(p.total)).." • Goal: Enter to apply")
    end
    if money then
        if not self.planGoal:HasFocus() then self.planGoal:SetNumber(self:MoneyBatch()) end
        self.listHint:SetText("Profit / "..self:MoneyBatch().." crafts, highest first / all inputs purchased")
    end
    local selected
    for _,r in ipairs(self.entries) do if r.key==self.selectedKey then selected=r;break end end
    if selected and selected.routeBand and self.selected and (selected.crafts~=self.selected.crafts or selected.start~=self.selected.start or selected.stop~=self.selected.stop) then
        self.selected=selected;self:SetQuantity()
    end
    if not selected then selected=self.entries[self.offset+1];self.selected=selected;self.selectedKey=selected and selected.key;self:SetQuantity() end
    self.selected=selected
    for i,b in ipairs(self.rows) do
        local r=self.entries[self.offset+i];b.entry=r;b:SetShown(r~=nil)
        self:RefreshMaterialRow(b,r,self.entries[self.offset+i-1],i==1)
        if r then
            b.title:SetText(r.name or r.title)
            b.icon:SetTexture(r.icon or (r.gatherItem and r.item and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.item)) or (r.pool and "Interface\\Icons\\Trade_Fishing") or "Interface\\Icons\\INV_Misc_Map_01")
            if r.routeSub then b.sub:SetText(r.routeSub)
            elseif r.acquisitionOnly then
                b.sub:SetText("Recipe / manual reference • acquisition details")
            elseif r.money then
                b.sub:SetText(self:SmallMoney(r.moneyProfit).." profit / "..r.crafts.." crafts / "..(r.planKnown and "Learned" or "Train first"))
            elseif r.planStep then
                b.sub:SetText(r.start.."-"..r.stop.." • "..r.crafts.." crafts • "..(r.planKnown and "Learned" or "Trainer").." • "..(r.planSale and self:NetLabel(r.planNet).." "..self:SmallMoney(math.abs(r.planNet)) or self:Money(r.planCost+r.planTraining)))
            elseif r.mats then
                local band=r.ownership and (r.ownership.."  •  ") or r.start and (r.start.."-"..r.stop.."  •  ") or "Live  •  "
                local state=r.live and "Live" or r.cached and "Cached" or "Guide"
                b.sub:SetText(band..(r.preparationReady and r.ready==0 and "Prepare from bag supplies" or (r.ready>0 and GREEN or MUTED)..r.ready.." crafts in bags|r").."  •  "..state)
            elseif r.gatherItem then b.sub:SetText(self:MaterialSubtitle(r))
            else b.sub:SetText(r.sub) end
            b:SetBackdropColor(r==selected and .38 or .13,r==selected and .27 or .11,r==selected and .1 or .08,.9)
        end
    end
    self.page:SetText(#self.entries==0 and "No entries" or string.format("%d-%d of %d",self.offset+1,math.min(#self.entries,self.offset+7),#self.entries))
    self.prev:SetEnabled(self.offset>0);self.next:SetEnabled(self.offset+7<#self.entries)
    self:RefreshFacets()
    self:RefreshFilterReset()
    if self.Theme then self.Theme.Refresh(self) end
    self:RefreshDetail()
    if self.UpdateRouteNavigation then self:UpdateRouteNavigation() end
    self.status:SetText(self.message or ((self.priceStatus or "Open profession to enable crafting • Shopping: /pp shop • Click blue NPC names for directions.").."\nPrice dates appear under each material • Source links below the detail panel."))
end
function P:RefreshDetail()
    self:HideDetailRows()
    self:RefreshProfessionButton()
    local r=self.selected
    local canChoose=r and r.mats and not r.journeyPrepare and (self.tab=="Catalog" or self.tab=="Recipes")
    local planning=self.tab=="Recipes" and self.mode=="cost"
    self.pinRecipe:SetShown(canChoose and true or false);self.excludeRecipe:SetShown(planning and canChoose and not r.acquisitionOnly or false)
    self.resetChoices:SetShown(planning)
    local choices=self:RouteChoices();local identity=canChoose and self:RecipeIdentity(r)
    self.pinRecipe:SetText(canChoose and self:IsFavorite(r) and "Unpin favorite" or "Pin favorite")
    self.excludeRecipe:SetText(identity and choices.excluded[identity] and "Include recipe" or "Exclude")
    local mapHeight=self:RefreshGatherMap(r)
    local craftView=r and r.mats~=nil and not r.acquisitionOnly or false
    self.qty:SetShown(craftView);self.qtyLabel:SetShown(craftView);self.craft:SetShown(craftView);self.priceButton:SetShown(craftView)
    self.routeAction:SetShown(r and r.journeyAction or false)
    if r and r.journeyAction then
        self.routeAction:SetText(r.target and "Show directions" or r.actionKind=="quest" and "View profession quests" or "Open shopping")
        self.routeAction:SetEnabled(r.gatherTraining and (r.target~=nil or r.actionKind=="quest") and self:RouteStopReady(r) or not r.gatherTraining and (not r.target or self:RouteStopReady(r)))
    end
    self.sourceNext:SetShown(false)
    self.priceButton:SetText(r and r.money and "Export inputs" or "Set price")
    if not r then
        self.detailTitle:SetText("Prepare your next journey")
        self.detailBody:SetText(self.tab=="Recipes" and "No recipes in this view.\n\nFor gathering professions, choose Gather. For crafting, open the profession window, clear filters and expand categories. Then try Guided or the Catalog tab.\n\nIn my bags requires live, non-grey recipes. Cheapest uses learned recipes and recorded trainer offerings." or "Choose another tab or profession to browse the guide.")
        if self:MaterialFiltersActive() then
            local f=self:MaterialFilters();self.detailTitle:SetText("No matching materials")
            self.detailBody:SetText("Change a filter or click Reset all to restore the materials list."..(f.knowledge and "\n\nOpen your profession to update which recipes are learned. Unlearned only includes recipes the game has recorded as unlearned." or "")..(f.skill=="current" and not self:MaterialSkillBand("current") and "\n\nThis profession is not trained. Choose a numbered skill range instead of Current." or ""))
        end
        if self.tab=="Recipes" and (self:IsOptimizedRoute() or self.RouteEntries and self.mode=="guide") then self.detailBody:SetText(self:PlanSummaryText()) end
        if self.tab=="Recipes" and self.mode=="money" then
            local s=self.moneySummary or {}
            self.detailTitle:SetText("No profitable crafts priced")
            self.detailBody:SetText("Money-making compares accessible recipes at your current skill, including gray recipes.\n\nOpen your profession, visit a trainer and run Full scan at the auction house. Visit supply merchants to record unlimited-stock gold prices.\n\n"..(s.unpriced or 0).." recipes need input prices\n"..(s.unsellable or 0).." need sale information\n"..(s.loss or 0).." have no profit at this batch size\n\nChoose a sale method or change Batch to include its one-time training fee. Bag supplies are never deducted.")
        end
        if self.tab=="Catalog" or self.tab=="Quests" then
            self.detailTitle:SetText("No matching "..(self.tab=="Quests" and "quests" or "recipes"))
            self.detailBody:SetText("No entries match the current search and filters.\n\nChoose Reset all to show all entries for this profession.\n\nType, Rarity and Forever apply together; Show also filters the Catalog.")
        end
        self.source:SetText("")
    else
        self.detailTitle:SetText(r.name or r.title);self.source:SetText(r.url or "https://classicwowforever.com/professions/crafting/")
        local urls={r.url or "https://classicwowforever.com/professions/crafting/"}
        for _,ref in ipairs(r.acquisitionItems or {}) do urls[#urls+1]="https://www.wowhead.com/forever/item="..ref.id end
        for _,url in ipairs(r.referenceURLs or {}) do urls[#urls+1]=url end
        if self.sourceEntryKey~=r.key then self.sourceEntryKey=r.key;self.sourceChoice=1 end
        self.sourceChoice=((self.sourceChoice or 1)-1)%#urls+1
        self.source:SetText(urls[self.sourceChoice]);self.sourceNext:SetShown(#urls>1)
        self.sourceNext:SetText("Source "..self.sourceChoice.."/"..#urls)
        if r.gatherBand and self.mapSourceURL then self.source:SetText(self.mapSourceURL) end
        if r.gatherItem then self:RenderDetailRows(self:GatherDetailRows(r),mapHeight);return end
        if r.journeyAction then self:RenderDetailRows(self:RouteDetailRows(r));return end
        if r.mats or r.quest then
            local n=math.max(1,math.min(9999,tonumber(self.qty:GetText()) or 1))
            self:RenderDetailRows(self:DetailRows(r,n))
            local live=self:Resolve(r);local amount=tonumber(self.qty:GetText());local valid=amount and amount>=1 and amount<=9999 and amount==math.floor(amount) and (not self.RouteBatchLimit or amount<=self:RouteBatchLimit(r))
            self.craft:SetText(live and (live.api=="craft" or live.enchant) and "Enchant once" or "Craft batch")
            self.craft:SetEnabled(not InCombatLockdown() and live~=nil and live.complete and not live.blocked and valid and amount<=self:Available(live) and (not (live.api=="craft" or live.enchant) or amount==1) and (not live.cooldown or live.cooldown<=0))
            return
        else self.detailBody:SetText(r.body or "") end
    end
    self.detailChild:SetHeight(math.max(325,self.detailBody:GetStringHeight()+20+mapHeight))
end
function P:PriceEditor()
    if not self.priceWindow then
        local f=panel(self.window,350,-220,360,180);self.priceWindow=f;f:SetFrameStrata("DIALOG")
        label(f,"GameFontNormalLarge",16,-15,330,"Set an item unit price")
        label(f,"GameFontHighlightSmall",16,-47,320,"Item ID (shown under each reagent)")
        f.item=edit(f,22,-65,130,true)
        label(f,"GameFontHighlightSmall",170,-47,165,"Copper per item")
        f.value=edit(f,178,-65,150,true)
        label(f,"GameFontHighlightSmall",16,-100,330,"100 copper = 1 silver. 10,000 copper = 1 gold.")
        button(f,16,-136,100,"Save",function()
            local id,value=tonumber(f.item:GetText()),tonumber(f.value:GetText())
            if id and id>0 and id==math.floor(id) and value and value>=0 and value<=10000000000 then
                P.market.prices[id]={value=value,time=time(),source="Manual"};P:InvalidatePlan();f:Hide();P:Refresh()
            else P:Print("Enter a positive item ID and a nonnegative copper price.") end
        end)
        button(f,126,-136,100,"Clear price",function()local id=tonumber(f.item:GetText());if id then P.market.prices[id]=nil end;P:InvalidatePlan();f:Hide();P:Refresh()end)
        button(f,236,-136,100,"Cancel",function()f:Hide()end)
    end
    local f=self.priceWindow;local r=self.selected;local id=r and r.mats[1] and r.mats[1].id
    f.item:SetText(id and tostring(id) or "");f.value:SetText("");f:Show()
end
