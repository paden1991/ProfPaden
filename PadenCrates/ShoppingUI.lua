local _,P=...
local S,L=P.Shopping,P.L
local window,launcher
local function text(parent,font,x,y,width)
    local label=parent:CreateFontString(nil,"OVERLAY",font)
    label:SetPoint("TOPLEFT",x,y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetWordWrap(true)
    return label
end
local function money(value) return GetMoneyString(math.floor(value+0.5),true) end

function S.Refresh()
    if not window or not window:IsShown() then return end
    local plan=S.Plan()
    window.summary:SetText(string.format(L.SHOP_SUMMARY,plan.crates,plan.writs))
    window.total:SetText((plan.unknown>0 and L.SHOP_KNOWN_ESTIMATE or L.SHOP_ESTIMATE)..money(plan.estimate))
    window.crates:SetChecked(P.db.buyCrates); window.writs:SetChecked(P.db.buyWrits)
    local display={}
    for _,row in ipairs(plan.rows) do display[#display+1]=row end
    for _,row in ipairs(plan.blocked) do display[#display+1]=row end
    for i,row in ipairs(display) do
        local view=window.rows[i]
        if not view then
            view=CreateFrame("Frame",nil,window.content); view:SetSize(404,44)
            view:SetPoint("TOPLEFT",0,-(i-1)*44)
            view.name=text(view,"GameFontHighlightSmall",0,0,245)
            view.count=text(view,"GameFontHighlightSmall",248,0,45)
            view.cost=text(view,"GameFontHighlightSmall",295,0,105); view.cost:SetJustifyH("RIGHT")
            view.detail=text(view,"GameFontDisableSmall",0,-25,400)
            window.rows[i]=view
        end
        local name=(C_Item.GetItemNameByID and C_Item.GetItemNameByID(row.itemID)) or row.name
        view.name:SetText(name)
        if row.reason then
            view.count:SetText(""); view.cost:SetText("")
            view.detail:SetText(L["SHOP_REASON_"..row.reason]); view.detail:SetTextColor(1,.6,.25)
        else
            view.count:SetText(tostring(row.missing))
            view.cost:SetText(row.missing==0 and L.SHOP_READY or (row.cost and money(row.cost) or L.SHOP_UNKNOWN))
            view.detail:SetText(string.format(L.SHOP_ROW_COUNTS,row.needed,row.have)); view.detail:SetTextColor(.65,.7,.75)
        end
        view:Show()
    end
    for i=#display+1,#window.rows do window.rows[i]:Hide() end
    window.content:SetHeight(math.max(1,#display*44))
    local status
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if #plan.blocked>0 then status=L.SHOP_BLOCKED
    elseif plan.crates+plan.writs==0 then status=L.SHOP_EMPTY
    elseif plan.units==0 then status=L.SHOP_NOTHING
    elseif S.sentSignature==plan.signature then status=L.SHOP_ALREADY_SENT
    elseif not api or type(api.MultiSearchAdvanced)~="function" then status=L.SHOP_PROVIDER
    elseif InCombatLockdown() then status=L.SHOP_COMBAT
    elseif not S.IsAuctionOpen() then status=L.SHOP_OPEN_AH
    elseif plan.unknown>0 or plan.stale>0 then status=L.SHOP_ESTIMATE_CAUTION
    else status=L.SHOP_REVIEW end
    window.status:SetText(S.notice or status)
    window.shop:SetEnabled(not not (#plan.blocked==0 and plan.units>0 and S.IsAuctionOpen() and
        api and type(api.MultiSearchAdvanced)=="function" and not InCombatLockdown() and S.sentSignature~=plan.signature))
end

function S.Toggle()
    if not window then
        window=CreateFrame("Frame","PadenCratesShoppingFrame",UIParent,"BasicFrameTemplateWithInset")
        window:SetSize(460,490); window:SetPoint("CENTER"); window:SetFrameStrata("DIALOG")
        window:SetClampedToScreen(true); window:SetMovable(true); window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart",function(self) self:StartMoving() end)
        window:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
        window.TitleText:SetText(L.SHOP_TITLE)
        window:SetScript("OnShow",function() if launcher and launcher.isTab then PanelTemplates_SelectTab(launcher) end end)
        window:SetScript("OnHide",function() if launcher and launcher.isTab then PanelTemplates_DeselectTab(launcher) end end)
        window.intro=text(window,"GameFontDisableSmall",16,-34,426); window.intro:SetText(L.SHOP_SCOPE)
        local function checkbox(key,label,x)
            local b=CreateFrame("CheckButton",nil,window,"UICheckButtonTemplate")
            b:SetSize(26,26); b:SetPoint("TOPLEFT",x,-68)
            local caption=text(b,"GameFontHighlight",28,-6,105); caption:SetText(label)
            b:SetScript("OnClick",function(self) P.db[key]=self:GetChecked()==true; S.notice=nil; S.Refresh() end)
            return b
        end
        window.crates=checkbox("buyCrates",L.SHOP_CRATES,14)
        window.writs=checkbox("buyWrits",L.SHOP_WRITS,150)
        local refresh=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
        refresh:SetSize(90,24); refresh:SetPoint("TOPRIGHT",-17,-69); refresh:SetText(L.SHOP_REFRESH)
        refresh:SetScript("OnClick",function() S.notice=nil; S.Refresh() end)
        window.summary=text(window,"GameFontHighlightSmall",18,-105,420)
        window.total=text(window,"GameFontNormal",18,-126,420)
        local heading=text(window,"GameFontDisableSmall",18,-152,245); heading:SetText(L.SHOP_ITEM)
        local buy=text(window,"GameFontDisableSmall",266,-152,45); buy:SetText(L.SHOP_BUY)
        local estimate=text(window,"GameFontDisableSmall",313,-152,105); estimate:SetText(L.SHOP_COST); estimate:SetJustifyH("RIGHT")
        local scroll=CreateFrame("ScrollFrame",nil,window,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-174); scroll:SetPoint("BOTTOMRIGHT",-36,91)
        window.content=CreateFrame("Frame",nil,scroll); window.content:SetSize(404,1); scroll:SetScrollChild(window.content)
        window.rows={}
        window.status=text(window,"GameFontHighlightSmall",18,-403,422)
        window.shop=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
        window.shop:SetSize(180,26); window.shop:SetPoint("BOTTOMRIGHT",-18,15); window.shop:SetText(L.SHOP_ACTION)
        window.shop:SetScript("OnClick",function()
            local ok,key=S.Send(); S.notice=L[key]; S.Refresh()
            if ok then print(L.SHOP_SENT); window:Hide() end
        end)
        local close=CreateFrame("Button",nil,window,"UIPanelButtonTemplate")
        close:SetSize(90,26); close:SetPoint("BOTTOMLEFT",18,15); close:SetText(CLOSE)
        close:SetScript("OnClick",function() window:Hide() end)
        UISpecialFrames[#UISpecialFrames+1]="PadenCratesShoppingFrame"
        window:Hide()
    end
    if window:IsShown() then window:Hide() else S.notice=nil; window:Show(); S.Refresh() end
end

function S.UpdateLauncher()
    if InCombatLockdown() then return end
    if not S.IsAuctionOpen() then if launcher then launcher:Hide() end; return end
    local anchor=AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame or AuctionFrame
    if not launcher then
        local isTab=anchor==AuctionHouseFrame and anchor.Tabs and #anchor.Tabs>0
        launcher=CreateFrame("Button","PadenCratesShopLauncher",anchor,
            isTab and "AuctionHouseFrameDisplayModeTabTemplate" or "UIPanelButtonTemplate")
        launcher.isTab=isTab
        if not isTab then launcher:SetSize(148,25) end
        launcher:SetText(L.SHOP_LAUNCHER); launcher:SetScript("OnClick",S.Toggle)
    end
    launcher:ClearAllPoints()
    if launcher.isTab then
        local last=anchor.Tabs[#anchor.Tabs]
        -- LibAHTab owns the row used by Auctionator and other auction addons.
        -- Inspect its visible sibling buttons so we also leave room for later tabs.
        local tabs=AuctionatorAHTabsContainer and AuctionatorAHTabsContainer.Tabs
        if tabs and tabs[#tabs] then
            for _,button in ipairs({tabs[#tabs]:GetParent():GetChildren()}) do
                if button:IsObjectType("Button") and button:IsShown() and button:GetRight() and
                    button:GetRight()>(last:GetRight() or 0) then last=button end
            end
        end
        PanelTemplates_TabResize(launcher,20,nil,70)
        launcher:SetPoint("TOPLEFT",last,"TOPRIGHT",3,0)
        if window and window:IsShown() then PanelTemplates_SelectTab(launcher) else PanelTemplates_DeselectTab(launcher) end
    else
        launcher:SetPoint("TOPRIGHT",anchor,"BOTTOMRIGHT",0,-4)
    end
    launcher:Show()
end

function S.OnEvent()
    if not P.db then return end
    S.UpdateLauncher()
    S.Refresh()
end
