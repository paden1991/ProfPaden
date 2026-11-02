local _,P=...
-- Only observes/searches prices. This module never buys, bids, posts or sells.
function P:CaptureMerchant()
    if not GetMerchantNumItems or not GetMerchantItemInfo then return end
    self.char.vendors=self.char.vendors or {}
    local merchant=UnitName and UnitName("npc") or "Visited merchant"
    local npcID=self.RememberNPC and self:RememberNPC()
    local zone=GetRealZoneText and GetRealZoneText() or ""
    for index=1,GetMerchantNumItems() do
        local id=self:ItemID(GetMerchantItemLink(index))
        local name,_,price,bundle,stock,_,extended=GetMerchantItemInfo(index)
        if id and price and price>0 and bundle and bundle>0 and not extended then
            self.char.vendors[id]={value=price/bundle,name=merchant or "Merchant",zone=zone,time=time(),stock=stock,bundle=bundle,npcID=npcID}
            if npcID then
                self.char.vendorOffers=self.char.vendorOffers or {}
                self.char.vendorOffers[id]=self.char.vendorOffers[id] or {}
                self.char.vendorOffers[id][npcID]=self.char.vendors[id]
            end
            if stock==-1 then
                self.char.unlimitedVendors=self.char.unlimitedVendors or {}
                self.char.unlimitedVendors[id]=self.char.vendors[id]
            end
        end
    end
end
function P:ScanStatus(text)
    self.priceStatus=text
    if self.shoppingWindow and self.shoppingWindow:IsShown() then self:ShoppingNotice(text) end
    if self.window and self.window:IsShown() then self:Refresh() end
end
function P:StopPriceScan(message,complete)
    local scan=self.priceScan
    if scan then
        scan.resumeIndex=scan.pending and scan.index-1 or scan.index
        scan.complete=complete==true;self.lastPriceScan=scan
        if complete and self.ShoppingConfig and self:ShoppingConfig() then self.shoppingDirty=true end
    end
    self.scanGeneration=(self.scanGeneration or 0)+1;self.priceScan=nil
    self:ScanStatus(message or "Price scan paused; Scan costs resumes where it stopped.")
end
function P:StartPriceScan()
    if self:IsAuctionatorScanning() then self:ScanStatus("Wait for Auctionator full scan to finish.");return end
    self.auctioneerCache=nil -- Re-read Auctioneer's public prices on each cost scan.
    if AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue then
        for _,r in ipairs(self.Catalog[self.selectedProf] or {}) do for _,m in ipairs(r.mats or {}) do if m.id then self:Price(m.id) end end end
        self:InvalidatePlan()
    end
    if self.CancelShoppingSearch then self:CancelShoppingSearch() end
    if self.priceScan then self:StopPriceScan() end
    if not self.auctionOpen then self:ScanStatus(AucAdvanced and "Auctioneer estimates refreshed. Open the AH for live prices." or "Visit an auction house to scan reagent prices.");return end
    if not C_AuctionHouse or not C_AuctionHouse.SendSearchQuery then self:ScanStatus("Browse AH results to record prices on this client.");return end
    -- Detect a competing search at dispatch, rather than mistaking delayed
    -- results from our previous reagent for a new user search.
    if hooksecurefunc and not self.priceQueryHook then
        self.priceQueryHook=true
        hooksecurefunc(C_AuctionHouse,"SendSearchQuery",function()
            if P.priceScan and not P.sendingPriceQuery then P:StopPriceScan("Another AH search started. Scan costs resumes this queue.") end
        end)
    end
    local ids,seen={},{}
    local function add(r)if (self.shoppingScanMode or self.mode)=="profit" and r.item and not r.acquisitionOnly and not seen[r.item] then seen[r.item]=true;ids[#ids+1]=r.item end;for _,m in ipairs(r.mats or {}) do if m.id and not seen[m.id] then seen[m.id]=true;ids[#ids+1]=m.id end end end
    if self.selected then add(self.selected) end
    for _,r in ipairs(self.Recipes[self.selectedProf] or {}) do add(r) end
    for _,r in pairs(self.char.recipes[self.selectedProf] or {}) do add(r) end
    for _,r in ipairs(self.Catalog[self.selectedProf] or {}) do add(r) end
    self.scanGeneration=(self.scanGeneration or 0)+1
    local old=self.lastPriceScan
    local resume=old and not old.complete and old.profession==self.selectedProf and old.profit==((self.shoppingScanMode or self.mode)=="profit")
    self.priceScan={ids=resume and old.ids or ids,index=resume and old.resumeIndex or 0,generation=self.scanGeneration,
        profession=self.selectedProf,profit=(self.shoppingScanMode or self.mode)=="profit",completed=resume and old.completed or {},failures=resume and old.failures or {},serial=0}
    self:NextPriceQuery()
end
function P:SchedulePriceQuery(scan,delay)
    if scan.scheduled then return end
    scan.scheduled=true
    C_Timer.After(delay,function()
        if P.priceScan~=scan or P.scanGeneration~=scan.generation then return end
        scan.scheduled=false;P:NextPriceQuery()
    end)
end
function P:NextPriceQuery()
    local scan=self.priceScan;if not scan or not self.auctionOpen or scan.inFlight then return end
    local api=C_AuctionHouse
    if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
        scan.waits=(scan.waits or 0)+1
        if scan.waits>=75 then self:StopPriceScan("AH remains busy. Scan costs resumes this queue.");return end
        self:ScanStatus("AH throttled; waiting to continue item "..(scan.pending and scan.index or scan.index+1).." / "..#scan.ids)
        self:SchedulePriceQuery(scan,1.2);return
    end
    scan.waits=0
    if not scan.pending then scan.index=scan.index+1;scan.pending=scan.ids[scan.index];scan.attempt=0 end
    if not scan.pending then
        self:StopPriceScan("Price scan finished: "..#scan.ids.." checked, "..#scan.failures.." unavailable/timed out. Prices are samples.",true);return
    end
    scan.attempt=scan.attempt+1;scan.serial=scan.serial+1;scan.inFlight=true
    local token,id=scan.serial,scan.pending
    self:ScanStatus("Scanning "..scan.index.." / "..#scan.ids.." • "..self:ItemName(id)..(scan.attempt>1 and " (retry)" or ""))
    local key={itemID=id,itemLevel=0,itemSuffix=0,battlePetSpeciesID=0}
    self.sendingPriceQuery=true
    local sorts=Enum and Enum.AuctionHouseSortOrder and {{sortOrder=Enum.AuctionHouseSortOrder.Price,reverseSort=false}} or {}
    local ok=pcall(api.SendSearchQuery,key,sorts,true)
    self.sendingPriceQuery=false
    if not ok then self:PriceQueryFailed(scan,token,"Query rejected");return end
    C_Timer.After(30,function()
        if P.priceScan==scan and scan.serial==token and scan.inFlight then P:PriceQueryFailed(scan,token,"No response") end
    end)
end
function P:PriceQueryFailed(scan,token,reason)
    if self.priceScan~=scan or scan.serial~=token or not scan.inFlight then return end
    scan.inFlight=false;scan.serial=scan.serial+1
    if scan.attempt<2 then
        self:ScanStatus(reason.." for "..self:ItemName(scan.pending).."; retrying after backoff.")
        self:SchedulePriceQuery(scan,6)
    else
        scan.failures[#scan.failures+1]={id=scan.pending,reason=reason};scan.completed[scan.pending]=true;scan.pending=nil
        self:ScanStatus(reason.."; skipping this item and continuing. Unknown prices stay unknown.")
        self:SchedulePriceQuery(scan,2)
    end
end
function P:PriceQueryResult(key)
    local scan=self.priceScan;if not scan then return end
    local id=type(key)=="table" and key.itemID or key
    if id~=scan.pending then
        if id and scan.pending and not scan.completed[id] then self:StopPriceScan("Another AH result arrived. Scan costs resumes this queue.") end
        return
    end
    if not scan.inFlight then return end
    scan.completed[id]=true;scan.pending=nil;scan.inFlight=false;scan.serial=scan.serial+1
    self:SchedulePriceQuery(scan,2)
end
function P:PriceThrottleEvent(event)
    local scan=self.priceScan
    if event=="AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" and scan and scan.inFlight then self:PriceQueryFailed(scan,scan.serial,"AH dropped the request") end
end
