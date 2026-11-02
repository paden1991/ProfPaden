local _,P=...
-- Version-checked bridge to the installed Auctionator scan button's behavior.
-- Auctionator has a public price API, but no public full-scan start API.
function P:IsAuctionatorScanning()
    local state=Auctionator and Auctionator.State
    return self.auctionatorScanActive or state and
        (state.FullScanFrameRef and state.FullScanFrameRef.inProgress or state.IncrementalScanFrameRef and state.IncrementalScanFrameRef.doingFullScan) or false
end
function P:ConnectAuctionatorScan()
    if self.auctionatorScanListener then return true end
    local a=Auctionator;if not a or not a.EventBus or type(a.EventBus.Register)~="function" then return false end
    local names,lookup={},{}
    for _,system in ipairs({"FullScan","IncrementalScan"}) do
        local events=a[system] and a[system].Events
        if events then for _,kind in ipairs({"ScanStart","ScanProgress","ScanComplete","ScanFailed"}) do
            if events[kind] then names[#names+1]=events[kind];lookup[events[kind]]=kind end
        end end
    end
    if #names==0 then return false end
    local listener={ReceiveEvent=function(_,event,value)
        if not P.char then return end
        local kind=lookup[event]
        if kind=="ScanStart" then
            P.auctionatorScanActive=true;P.auctionatorScanStarted=time();P.auctionatorScanPercent=0
            if P.priceScan then P:StopPriceScan("Auctionator full scan owns the price search.") end
            P:CancelShoppingSearch()
        elseif kind=="ScanProgress" then
            local percent=math.floor(math.max(0,math.min(1,tonumber(value) or 0))*100)
            if percent==P.auctionatorScanPercent then return end;P.auctionatorScanPercent=percent
        elseif kind=="ScanComplete" then
            P.auctionatorScanActive=nil;P.auctionatorScanPercent=nil
            -- An older individual AH sample must not mask the database refresh.
            P.market.auctionatorScanStarted=P.auctionatorScanStarted or time();P.auctionatorScanStarted=nil
            P.auctioneerCache=nil;P:InvalidatePlan();P.shoppingDirty=true;P.shoppingDataRevision=(P.shoppingDataRevision or 0)+1
            P.priceStatus="Auctionator full scan complete. Prices and shopping route refreshed."
            if P.shoppingWindow and P.shoppingWindow:IsShown() then P:EnsureShoppingPlan(true) end
            P.shoppingMessage=P.priceStatus
        elseif kind=="ScanFailed" then
            P.auctionatorScanActive=nil;P.auctionatorScanPercent=nil;P.auctionatorScanStarted=nil
            P.priceStatus="Auctionator scan did not complete. Saved prices remain available; retry from the auction house."
            P.shoppingMessage=P.priceStatus
        end
        if kind=="ScanStart" or kind=="ScanProgress" then
            P.priceStatus="Auctionator full scan: "..(P.auctionatorScanPercent or 0).."%. Keep the auction house open."
            P.shoppingMessage=P.priceStatus
        end
        if P.shoppingWindow and P.shoppingWindow:IsShown() then P:RefreshShopping() end
        if P.window and P.window:IsShown() then P:Refresh() end
    end}
    local ok=pcall(a.EventBus.Register,a.EventBus,listener,names)
    if ok then self.auctionatorScanListener=listener end;return ok
end
function P:StartAuctionatorScan()
    local function notice(message)self:ScanStatus(message);self:ShoppingNotice(message)end
    if not Auctionator then self:ScanStatus("Enable Auctionator to run a full scan.");notice(self.priceStatus);return false end
    if not self.auctionOpen then self:ScanStatus("Open the auction house, then choose Full scan.");notice(self.priceStatus);return false end
    if InCombatLockdown() or self.char.shoppingUncertain or
        AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() or
        StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION") then
        notice("Finish the current purchase or combat before starting a full scan.");return false
    end
    if not self:ConnectAuctionatorScan() then notice("Use Auctionator's Full Scan button; this version does not expose compatible scan events.");return false end
    if self:IsAuctionatorScanning() then notice("Auctionator already has a full scan running.");return false end
    local a=Auctionator;local state=a.State or {};local frame=state.FullScanFrameRef
    if state.IncrementalScanFrameRef then
        if not (a.Config and a.Config.Options and a.Config.Options.REPLICATE_SCAN and type(a.Config.Get)=="function") then
            notice("Use Auctionator's Full Scan button; scan settings are unavailable in this version.");return false
        end
        local ok,replicate=pcall(a.Config.Get,a.Config.Options.REPLICATE_SCAN)
        if not ok then notice("Could not read Auctionator scan settings. Use its Full Scan button.");return false end
        frame=replicate and state.FullScanFrameRef or state.IncrementalScanFrameRef
    end
    if not frame or type(frame.InitiateScan)~="function" then notice("Auctionator is still initializing, or this version changed its scan interface. Use its Full Scan button.");return false end
    if frame.CanInitiate then
        local ok,ready=pcall(frame.CanInitiate,frame)
        if not ok or not ready then
            local good,message=false,nil;if frame.NextScanMessage then good,message=pcall(frame.NextScanMessage,frame) end
            notice(good and message or "Auctionator is not ready for another full scan yet.");return false
        end
    end
    if self.priceScan then self:StopPriceScan("Reagent scan stopped for Auctionator full scan.") end
    self:CancelShoppingSearch();self:ConnectAuctionator()
    local ok=pcall(frame.InitiateScan,frame)
    if not ok then notice("Auctionator could not start the full scan. Check its scan panel and retry.");return false end
    return true
end
local frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED"}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent",function(_,event)
    if not P.char then return end
    if event=="AUCTION_HOUSE_CLOSED" then P.auctionatorScanActive=nil;P.auctionatorScanPercent=nil
    else P:ConnectAuctionatorScan() end
end)
