local _,P=...
local function label(parent,x,y,width,size)
    local f=parent:CreateFontString(nil,"OVERLAY",size or "GameFontHighlightSmall")
    f:SetPoint("TOPLEFT",x,y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetJustifyV("TOP");return f
end
local function button(parent,x,y,width,text,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,y);b:SetSize(width,26);b:SetText(text);b:SetScript("OnClick",callback);return b
end
local function backdrop(f)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    f:SetBackdropColor(.08,.07,.05,1);f:SetBackdropBorderColor(.72,.55,.28,1)
end
function P:CreateShoppingUI()
    local f=CreateFrame("Frame","ProfPadenShoppingWindow",UIParent,"BackdropTemplate");self.shoppingWindow=f
    f:SetSize(1000,720);f:SetPoint("CENTER");f:SetFrameStrata("HIGH");f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true)
    f:SetScale(math.min(1,(UIParent:GetWidth()-30)/1000,(UIParent:GetHeight()-30)/720))
    f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing);backdrop(f)
    f:SetScript("OnHide",function()P:CloseDropdown()end);tinsert(UISpecialFrames,"ProfPadenShoppingWindow")
    label(f,20,-20,900,"GameFontNormalLarge"):SetText("PROFPADEN  •  Plan your next skill levels")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-7,-7)
    f.prof=button(f,20,-54,230,"",function()
        P:ReadSkills();local options={}
        for _,pr in ipairs(P.professions) do local skill=P.skills[pr[1]];if skill then options[#options+1]={label=pr[1].."  "..skill.rank.."/"..skill.cap,value=pr[1]} end end
        if #options==0 then P:ShoppingNotice("Open a profession to record its skill first.");return end
        P:ToggleDropdown(f.prof,options,P.selectedProf,function(value)
            P.selectedProf=value;P.char.profession=value;P:CancelShoppingSearch();P.shoppingSelected=nil;P.shoppingOffset=0;P.shoppingMessage=nil
            P:ShoppingConfig(true);P:EnsureShoppingPlan();P:RefreshShopping()
        end)
    end);self:DecorateDropdown(f.prof)
    f.mode=button(f,262,-54,235,"",function()
        local current=P:ShoppingMode();if current=="profit" then current="profit:"..P:ShoppingSaleKey() end
        P:ToggleDropdown(f.mode,P:ShoppingModeOptions(),current,function(value)P:SetShoppingMode(value)end)
    end);self:DecorateDropdown(f.mode)
    label(f,518,-62,60):SetText("Target skill")
    f.levels=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.levels:SetPoint("TOPLEFT",584,-54);f.levels:SetSize(60,26);f.levels:SetAutoFocus(false);f.levels:SetNumeric(true)
    f.levels:SetScript("OnEnterPressed",function(s)s:ClearFocus();P:SetShoppingGoal(s:GetText())end)
    f.levels:SetScript("OnEscapePressed",function(s)s:ClearFocus();P:RefreshShopping()end)
    for i,n in ipairs({5,10,25}) do button(f,654+(i-1)*62,-54,54,"+"..n,function()f.levels:ClearFocus();P:SetShoppingGoal(n,true)end) end
    button(f,840,-54,138,"To trained cap",function()f.levels:ClearFocus();P:SetShoppingGoal("cap")end)
    f.skill=label(f,22,-94,230,"GameFontNormal")
    f.open=CreateFrame("Button","ProfPadenShoppingProfession",f,"SecureActionButtonTemplate,UIPanelButtonTemplate")
    f.open:SetPoint("TOPLEFT",262,-86);f.open:SetSize(130,26);f.open:SetText("Open profession");f.open:RegisterForClicks("AnyUp","AnyDown");f.open:SetAttribute("useOnKeyDown",false)
    f.build=button(f,402,-86,130,"Refresh route",function()P.shoppingMessage=nil;P:ReadSkills();P:EnsureShoppingPlan(true);P:RefreshShopping()end)
    f.scan=button(f,542,-86,110,"Full scan",function()
        P:StartAuctionatorScan();P:RefreshShopping()
    end)
    f.filter=button(f,664,-86,160,"Show: missing",function()
        P:ToggleDropdown(f.filter,{{label="Missing materials",value="missing"},{label="AH purchases",value="auction"},{label="Vendor purchases",value="vendor"},{label="All materials",value="all"}},P.shoppingShow or "missing",function(value)P.shoppingShow=value;P.shoppingOffset=0;P:RefreshShopping()end)
    end);self:DecorateDropdown(f.filter)
    button(f,840,-86,138,"Back to guide",function()f:Hide();if P.window then P.window:Hide() end;P:Toggle()end)
    f.help=label(f,22,-123,780);f.help:SetHeight(22)
    f.cancel=button(f,840,-118,138,"Cancel shopping",function()P:CancelShopping()end)
    f.cancel:SetScript("OnEnter",function(s)
        if GameTooltip then GameTooltip:SetOwner(s,"ANCHOR_TOP");GameTooltip:SetText("Cancel shopping");GameTooltip:AddLine("Clears this profession's list and cancels its exported Auctionator search and unconfirmed purchase. Sent purchases and mail credits are kept.",1,1,1,true);GameTooltip:Show() end
    end)
    f.cancel:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    f.summary=label(f,22,-151,680,"GameFontNormal");f.summary:SetSpacing(3)
    f.auctionator=button(f,720,-151,258,"Export missing to Auctionator",function()P:ShopWithAuctionator()end);f.auctionator:SetHeight(32)
    f.exportHint=label(f,722,-190,254);f.exportHint:SetHeight(24)
    local titles={"Material","Need","Bags","Mail","Buy","Cost to buy"};local xs={10,225,285,345,405,465};local widths={205,55,55,55,55,105}
    for i,title in ipairs(titles) do label(f,20+xs[i],-222,widths[i],"GameFontNormalSmall"):SetText(title) end
    f.rows={}
    for i=1,7 do
        local b=CreateFrame("Button",nil,f,"BackdropTemplate");b:SetPoint("TOPLEFT",20,-244-(i-1)*46);b:SetSize(580,44);backdrop(b);b.cells={}
        for j=1,6 do b.cells[j]=label(b,xs[j],-9,widths[j],j==1 and "GameFontNormal" or "GameFontHighlightSmall") end
        b.title=b.cells[1];b.title:SetHeight(16);b.title:SetWordWrap(false);b.sub=label(b,10,-28,550);b.sub:SetHeight(12);b.sub:SetWordWrap(false)
        b:SetScript("OnClick",function(s)if not s.entry then return end;P:CancelShoppingSearch();P.shoppingSelected=s.entry.item;P.shoppingClearID=nil;P.shoppingMessage=nil;P:RefreshShopping()end)
        b:SetScript("OnEnter",function(s)P:ShowListingTooltip(s,s.entry)end);b:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide() end end)
        f.rows[i]=b
    end
    f.prev=button(f,20,-580,80,"< Back",function()P.shoppingOffset=math.max(0,(P.shoppingOffset or 0)-7);P:RefreshShopping()end)
    f.page=label(f,118,-588,360)
    f.next=button(f,520,-580,80,"Next >",function()P.shoppingOffset=(P.shoppingOffset or 0)+7;P:RefreshShopping()end)
    f.route=label(f,22,-623,578);f.route:SetSpacing(3)
    f.title=label(f,630,-222,348,"GameFontNormalLarge")
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",630,-253);scroll:SetPoint("BOTTOMRIGHT",-33,155)
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(332,310);scroll:SetScrollChild(child)
    f.body=label(child,0,0,326,"GameFontHighlight");f.body:SetSpacing(5);f.child=child;f.scroll=scroll
    child:SetHyperlinksEnabled(true);child:EnableMouse(true)
    child:SetScript("OnHyperlinkEnter",function(s,link)P:ShowListingTooltip(s,{link=link})end)
    child:SetScript("OnHyperlinkLeave",function()if GameTooltip then GameTooltip:Hide() end end)
    child:SetScript("OnHyperlinkClick",function(_,link)local id=link:match("^profpaden:npc:(%d+)");if id then P:TrackNPC(tonumber(id),link:match(":drop$")~=nil,P:ShoppingNavigationGoal(tonumber(id))) end end)
    f.buy=button(f,630,-580,220,"Export selected item",function()P:SendShoppingItem()end)
    f.more=button(f,860,-580,118,"More",function()
        local uncertain=P.char.shoppingUncertain
        local options=uncertain and {{label="Received / used",value="received"},{label="Clear mail credit",value="credit"}} or {{label="Preview auction price",value="price"},{label="Clear mail credit",value="credit"}}
        P:ToggleDropdown(f.more,options,nil,function(value)
            if value=="price" then P:SearchShoppingItem(P.shoppingSelected) else P:ReconcileShoppingCredit(uncertain and uncertain.item or P.shoppingSelected,value=="received") end
        end)
    end);self:DecorateDropdown(f.more);f.more.dropdownAlignRight=true
    f.search=f.more -- compatibility with the existing read-only price-preview checks
    label(f,630,-623,348):SetText("Buy AH items in Auctionator; vendor items at suppliers.\nReopen this list with /pp shop.")
    f.status=label(f,22,-672,954);f.status:SetSpacing(3);f.status:SetHeight(38)
    f:Hide()
end
function P:ToggleShopping()
    if InCombatLockdown() then self:Print("Open shopping after combat.");return end
    if not self.shoppingWindow then self:CreateShoppingUI() end
    local f=self.shoppingWindow;if f:IsShown() then f:Hide();return end
    self:ReadSkills();if self.window then self.window:Hide() end
    self:ShoppingConfig(true);self.shoppingMessage=nil;self:EnsureShoppingPlan()
    self:InstallShoppingHooks();f:Show();self:RefreshShopping()
end
function P:RefreshShopping()
    local f=self.shoppingWindow;if not f then return end
    local plan=self:ShoppingPlan();local cfg=self:ShoppingConfig();local mode=self:ShoppingMode();local skill=self.skills[self.selectedProf]
    local canceled=cfg and cfg.cancelled
    local export=self.char.auctionatorExport or self.auctionatorShopping
    f.cancel:SetEnabled(not InCombatLockdown() and (plan~=nil or self.shoppingQuery~=nil or self.shoppingOffer~=nil or export and export.profession==self.selectedProf) or false)
    f.build:SetText(canceled and "Start new list" or "Refresh route")
    local all=self:ShoppingRows();self.shoppingRows=all;local rows={};local missing,ahMissing,vendorMissing=0,0,0
    for _,r in ipairs(all) do
        if r.missing>0 then missing=missing+1;if r.method=="vendor" then vendorMissing=vendorMissing+1 else ahMissing=ahMissing+1 end end
        if self.shoppingShow=="all" or r.missing>0 and (self.shoppingShow~="vendor" and self.shoppingShow~="auction" or self.shoppingShow==r.method) then rows[#rows+1]=r end
    end
    f.prof:SetText(self.selectedProf);f.mode:SetText(self.ShoppingModes[mode] or mode)
    f.skill:SetText(skill and ("Current skill "..skill.rank.." / "..skill.cap) or "Profession not detected")
    f.help:SetText(self.ShoppingModeHelp[mode] or "")
    if not f.levels:HasFocus() then f.levels:SetNumber(cfg and (cfg.goal=="cap" and skill and skill.cap or cfg.target) or plan and plan.target or skill and math.min(skill.cap,skill.rank+10) or 0) end
    if not InCombatLockdown() then
        local spell;for _,p in ipairs(self.professions) do if p[1]==self.selectedProf then spell=self.selectedProf=="Mining" and 2656 or p[2];break end end
        local name=C_Spell and C_Spell.GetSpellName and spell and C_Spell.GetSpellName(spell) or GetSpellInfo and spell and GetSpellInfo(spell)
        f.open:SetAttribute("type",name and skill and "spell" or nil);f.open:SetAttribute("spell",name);f.open:SetEnabled(name and skill and true or false)
    end
    f.prof:SetEnabled(not InCombatLockdown());f.scan:SetText(self:IsAuctionatorScanning() and ("Scan "..(self.auctionatorScanPercent or 0).."%") or "Full scan")
    f.filter:SetText(({all="Show: all materials",vendor="Show: vendor",auction="Show: AH"})[self.shoppingShow] or "Show: missing")
    local budget=self:ShoppingBudget(all,plan and plan.training)
    f.summary:SetText(plan and ((plan.reached<plan.target and "PARTIAL • " or "").."Skill "..plan.start.." to "..plan.reached.." / goal "..plan.target.." • "..ahMissing.." AH / "..vendorMissing.." vendor materials"..
        "\nMaterials: "..self:SmallMoney(budget.materials)..(budget.unpriced>0 and " (priced portion; "..budget.unpriced.." unpriced)" or "").." • Bags: "..self:SmallMoney(budget.owned).." • Mail: "..self:SmallMoney(budget.mail)..
        "\n"..(budget.missingUnknown>0 and "Known budget: " or "Budget to buy + train: ")..self:SmallMoney(budget.remaining).." • Training: "..self:SmallMoney(budget.training)) or "Choose your profession, route and target skill.\nYour list updates as you gain skill.\nExport missing materials to Auctionator when ready.")
    if canceled then f.summary:SetText("Shopping canceled for "..self.selectedProf..".\nStart a new list when ready.\nPurchased items and mail credits are kept.") end
    self.shoppingOffset=math.min(self.shoppingOffset or 0,math.max(0,math.floor((#rows-1)/7)*7))
    local selected;for _,r in ipairs(rows) do if r.item==self.shoppingSelected then selected=r;break end end
    if not selected then selected=rows[1];self.shoppingSelected=selected and selected.item end
    for i,b in ipairs(f.rows) do
        local r=rows[self.shoppingOffset+i];b.entry=r;b:SetShown(r~=nil)
        if r then
            local values={r.name,r.required,r.owned,r.pending,r.missing,self:SmallMoney(r.cost)}
            for j,value in ipairs(values) do b.cells[j]:SetText(value) end
            b.sub:SetText(r.missing==0 and "Covered by bags / mail" or ((r.method=="vendor" and "VENDOR" or "AH").." • "..r.source.." • "..self:PriceDate(r.stamp,r.source,r.item)))
            b:SetBackdropColor(r==selected and .32 or .13,r==selected and .23 or .11,r==selected and .1 or .08,1)
        end
    end
    f.page:SetText(#rows==0 and (missing==0 and "No missing materials" or "No matching materials") or (self.shoppingOffset+1).."-"..math.min(#rows,self.shoppingOffset+7).." of "..#rows)
    f.prev:SetEnabled(self.shoppingOffset>0);f.next:SetEnabled(self.shoppingOffset+7<#rows)
    f.route:SetText("Route: "..(self.ShoppingModes[plan and plan.routeMode or mode] or mode)..(plan and plan.objective=="profit" and (" • "..self:ProfitLabel(plan.saleKey).."\nSaved estimate: "..self:NetLabel(plan.net or 0).." "..self:SmallMoney(math.abs(plan.net or 0))) or "\nTarget stays fixed while your current skill advances."))
    local action,enabled,explanation=self:ShoppingActionState(all)
    f.auctionator:SetText(enabled and "Export missing to Auctionator" or action);f.auctionator:SetEnabled(enabled)
    f.exportHint:SetText(enabled and (ahMissing.." AH materials • vendor supplies excluded") or (canceled and "No active list" or "List saved locally • /pp shop"))
    local stale=self:ShoppingIsStale();local offer=self.shoppingOffer
    if offer and (not selected or offer.item~=selected.item or offer.profession~=self.selectedProf or offer.missing~=selected.missing or stale) then self.shoppingOffer=nil;self.shoppingQuery=nil;offer=nil end
    local lines={}
    if selected then
        local r=selected;f.title:SetText(r.name)
        lines={"Buy: "..r.missing.."   •   Need: "..r.required,"Bags: "..r.owned.."   •   Mail credit: "..r.pending,
            "Each: "..self:SmallMoney(r.price).."   •   To buy: "..self:Money(r.cost),r.source.." • "..self:PriceDate(r.stamp,r.source,r.item)}
        if r.missing>0 and r.method=="vendor" then
            local target=self:RouteVendor(r.item,r.missing)
            lines[#lines+1]="Buy from vendor"..(target and ": "..self:NPCSourceText(target.npc.id) or ": profession supply merchant")
            lines[#lines+1]="Excluded from Auctionator export."
        end
        lines[#lines+1]="\nUSED IN YOUR ROUTE"
        for _,step in ipairs(plan and plan.steps or {}) do for _,m in ipairs(step.mats or {}) do if m.id==r.item then lines[#lines+1]=step.start.."-"..step.stop.." • "..step.crafts.." x "..step.name;break end end end
        if offer and offer.quantity>0 then
            lines[#lines+1]="\nAH SAMPLE: "..offer.quantity.." for "..self:Money(offer.total)
            if offer.quantity<r.missing then lines[#lines+1]=(r.missing-offer.quantity).." still needed" end
            if offer.quantity>r.missing then lines[#lines+1]=(offer.quantity-r.missing).." extra in this stack" end
        end
    else
        f.title:SetText(action)
        lines={explanation}
        local uncertain=self.char.shoppingUncertain
        if uncertain then lines[#lines+1]="\nAwaiting result: "..uncertain.quantity.." x "..self:ItemName(uncertain.item)..". Check bags and mail. If the result stays unresolved, choose Resolve purchase > Received / used if you already collected it." end
        if plan and #plan.steps>0 then lines[#lines+1]="\nNEXT CRAFTS";for i=1,math.min(5,#plan.steps) do local s=plan.steps[i];lines[#lines+1]=s.crafts.." x "..s.name end end
        if skill and skill.rank>=skill.cap and self.TrainingStop then local stop=self:TrainingStop();if stop then lines[#lines+1]="\n"..stop end end
    end
    if selected and self.char.shoppingUncertain then
        local receipt=self.char.shoppingUncertain
        lines[#lines+1]="\nEARLIER PURCHASE: "..receipt.quantity.." x "..self:ItemName(receipt.item)..". Check bags/mail, then use Resolve purchase before exporting."
    end
    if plan and plan.preparation and #plan.preparation>0 then
        lines[#lines+1]="\nPREPARE BEFORE ROUTE CRAFTS"
        for _,step in ipairs(plan.preparation) do lines[#lines+1]=step.profession..": "..step.crafts.." x "..step.name end
        lines[#lines+1]="The shopping list includes their base inputs. Preparation skill-ups are not assumed."
    end
    f.body:SetText(table.concat(lines,"\n"));f.child:SetHeight(math.max(300,f.body:GetStringHeight()+12))
    f.buy:SetEnabled(enabled and selected and selected.method~="vendor" and selected.missing>0 or false);f.more:SetEnabled((selected~=nil or self.char.shoppingUncertain~=nil) and not InCombatLockdown())
    f.more:SetText(self.char.shoppingUncertain and "Resolve purchase" or "More")
    f.status:SetText(self.shoppingMessage or (plan and plan.reason and "PARTIAL: "..plan.reason) or explanation)
end
