local _,P=...
function P:AuctionatorShoppingAvailable()
    return Auctionator and Auctionator.API and Auctionator.API.v1 and type(Auctionator.API.v1.MultiSearchAdvanced)=="function"
end
function P:ConnectAuctionator()
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if self.auctionatorDBHook or not api or not api.RegisterForDBUpdate then return end
    local ok=pcall(api.RegisterForDBUpdate,self.name,function()
        P:InvalidatePlan()
        if P.shoppingWindow and P.shoppingWindow:IsShown() then P:RefreshShopping() end
    end)
    self.auctionatorDBHook=ok
end
function P:ShopWithAuctionator(onlyItem)
    if self:IsAuctionatorScanning() then self:ShoppingNotice("Wait for Auctionator full scan to finish before exporting.");return false end
    if self.EnsureShoppingPlan then self:EnsureShoppingPlan() end
    if AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() or
        StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION") then
        self:ShoppingNotice("Finish or cancel the existing auction confirmation first.");return false
    end
    if not self:AuctionatorShoppingAvailable() then self:ShoppingNotice("Enable Auctionator to export this list. You can still use Check AH for price samples or shop manually.");return false end
    if not self.auctionOpen then self:ShoppingNotice("Open the auction house before sending this list to Auctionator.");return false end
    if InCombatLockdown() or self:ShoppingIsStale() or self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent then
        self:ShoppingNotice("Leave combat, rebuild a stale list, or resolve the outstanding purchase before searching.");return false
    end
    local terms,items={},{}
    for _,r in ipairs(self:ShoppingRows()) do if r.missing>0 and r.method~="vendor" and (not onlyItem or r.item==onlyItem) then
        -- Search in the client's locale; never export a guessed English name
        -- or the fallback 'Item 12345', which could match a different item.
        local info=C_Item and C_Item.GetItemInfo or GetItemInfo
        local name=info and info(r.item)
        if not name then
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.item) end
            self:ShoppingNotice("Loading item name for #"..r.item..". Retry Auctionator after item data loads; no partial list was exported.");return false
        end
        if name:find("[;^]") or name:match('^".*"$') then self:ShoppingNotice("This item name cannot be represented by Auctionator's search format. Use Check AH.");return false end
        terms[#terms+1]={searchString=name,isExact=true,quantity=r.missing}
        items[r.item]=true
    end end
    if #terms==0 then self:ShoppingNotice("No AH materials to export. Buy vendor supplies from the suppliers listed in Shopping.");return false end
    self:InstallShoppingHooks();self:ConnectAuctionator()
    if not self.shoppingHooks then self:ShoppingNotice("Purchase tracking is unavailable. Reload at the auction house before shopping.");return false end
    if self.priceScan then self:StopPriceScan("Cost scan paused for Auctionator shopping.") end
    self:CancelShoppingSearch()
    self.shoppingTransaction=nil
    self.auctionatorShopping={items=items,auctions={},profession=self.selectedProf}
    local ok=pcall(Auctionator.API.v1.MultiSearchAdvanced,self.name,terms)
    if not ok then self.auctionatorShopping=nil;self:ShoppingNotice("Auctionator could not start this search. Your list is retained; use Check AH or retry.");return false end
    local listName=AUCTIONATOR_L_TEMPORARY_LOWER_CASE and (self.name.." ("..AUCTIONATOR_L_TEMPORARY_LOWER_CASE..")")
    self.auctionatorShopping.listName=listName
    self.char.auctionatorExport={profession=self.selectedProf,listName=listName,items=items}
    self:ShoppingNotice("Sent "..#terms.." exact-name searches and missing quantities to Auctionator. Review current prices and buy there; /pp shop shows what remains.")
    if self.window then self.window:Hide() end
    if self.shoppingWindow then self.shoppingWindow:Hide() end
    return true
end
function P:ObserveAuctionatorResults(event,resultKey)
    local scope=self.auctionatorShopping
    if not scope or event:find("COMMODITY",1,true) or type(resultKey)~="table" or not scope.items[resultKey.itemID] then return end
    for i=1,C_AuctionHouse.GetNumItemSearchResults(resultKey) do
        local r=C_AuctionHouse.GetItemSearchResultInfo(resultKey,i)
        if r and r.auctionID and r.buyoutAmount and r.buyoutAmount>0 and r.quantity and r.quantity>0 and
            r.itemKey and scope.items[r.itemKey.itemID] and not r.containsOwnerItem and not r.containsAccountItem then
            scope.auctions[r.auctionID]={kind="item",item=r.itemKey.itemID,quantity=r.quantity,total=r.buyoutAmount,auctionID=r.auctionID,external=true}
        end
    end
end
function P:ObserveAuctionatorBuy(kind,id,quantityOrAmount)
    local scope=self.auctionatorShopping
    if not scope or self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent then return end
    local tx
    if kind=="commodity" and scope.items[id] then
        tx={kind=kind,item=id,quantity=quantityOrAmount,external=true}
    elseif kind=="item" then
        local found=scope.auctions[id]
        if found and found.total==quantityOrAmount then tx=found end
    end
    if tx then self.shoppingTransaction=tx;self:ReserveShoppingPurchase(tx) end
end
local frame=CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN");frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent",function()if P.char then P:ConnectAuctionator() end end)
