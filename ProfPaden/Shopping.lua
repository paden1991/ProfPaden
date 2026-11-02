local _,P=...
local function clock()return GetTime and GetTime() or time() end
local function call(fn,...)if fn then local ok,a=pcall(fn,...);if ok then return a end end end
local function key(id)return {itemID=id,itemLevel=0,itemSuffix=0,battlePetSpeciesID=0} end
local function nativeDialogOpen()
    return AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() or
        StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION")
end
function P:ShoppingNotice(message)
    self.shoppingMessage=message
    if self.shoppingWindow then self:RefreshShopping() end
end
function P:ShoppingPlan()
    return self.char.shoppingPlans and self.char.shoppingPlans[self.selectedProf]
end
function P:ShoppingTransit(id)
    self.char.shoppingTransit=self.char.shoppingTransit or {}
    local t=self.char.shoppingTransit[id]
    local owned=self:Count(id);local existing=t~=nil
    if not t then
        local receipt=self.char.shoppingUncertain
        t={count=receipt and receipt.item==id and receipt.quantity or 0,bags=owned}
        self.char.shoppingTransit[id]=t
    end
    -- Delivery replaces credit with inventory, instead of counting both.
    if owned>t.bags then t.count=math.max(0,t.count-(owned-t.bags)) end
    t.bags=owned
    -- A fully consumed delivery credit must not leave its receipt blocking exports.
    -- Missing credit records are not evidence of delivery; preserve those receipts.
    local receipt=self.char.shoppingUncertain
    if receipt and receipt.item==id and t.count==0 and existing then
        self.char.shoppingUncertain=nil
        if self.shoppingTransaction and self.shoppingTransaction.item==id then self.shoppingTransaction=nil end
    end
    return t
end
function P:ShoppingRows()
    local plan=self:ShoppingPlan();local rows={}
    local sourcing=self:SourceNeeds(plan and plan.needs or {},{bags=true,mail=true})
    if plan then plan.preparation=sourcing.steps end
    for id,required in pairs(sourcing.needs) do
        local t=self:ShoppingTransit(id);local owned=self:Count(id)
        local missing=math.max(0,required-owned-t.count)
        local price,source,stamp,method=self:Price(id,missing)
        rows[#rows+1]={item=id,name=self:ItemName(id),required=required,owned=owned,pending=t.count,
            missing=missing,price=price,source=source,stamp=stamp,method=method or "auction",cost=price and price*missing or missing==0 and 0 or nil}
    end
    table.sort(rows,function(a,b)
        if (a.missing>0)~=(b.missing>0) then return a.missing>0 end
        if a.name~=b.name then return a.name<b.name end
        return a.item<b.item
    end)
    return rows
end
function P:ShoppingBudget(rows,training)
    local out={materials=0,owned=0,mail=0,buy=0,training=training or 0,unpriced=0,missingUnknown=0}
    for _,r in ipairs(rows) do
        if r.price then
            local owned=math.min(r.required,r.owned);local mail=math.min(math.max(0,r.required-owned),r.pending)
            out.materials=out.materials+r.required*r.price;out.owned=out.owned+owned*r.price
            out.mail=out.mail+mail*r.price;out.buy=out.buy+r.missing*r.price
        else out.unpriced=out.unpriced+1;if r.missing>0 then out.missingUnknown=out.missingUnknown+1 end end
    end
    out.remaining=out.buy+out.training;return out
end
function P:ShoppingRow(id)
    for _,r in ipairs(self:ShoppingRows()) do if r.item==id then return r end end
end
function P:ShoppingIsStale()
    local plan=self:ShoppingPlan();local skill=self.skills[self.selectedProf];local cfg=self.ShoppingConfig and self:ShoppingConfig()
    return plan and (plan.purchaseModel~=self.purchaseModel or not skill or plan.start~=skill.rank or cfg and ((plan.dataRevision or 0)~=(self.shoppingDataRevision or 0) or plan.cap~=skill.cap or (plan.routeMode or plan.objective)~=cfg.mode or plan.target~=(cfg.goal=="cap" and skill.cap or math.min(cfg.target,skill.cap))) or plan.chanceModel~=self.skillChanceModel or (plan.choiceRevision or 0)~=self:RouteChoices().revision or (plan.objective or "cost")~=(self:ShoppingMode()=="profit" and "profit" or "cost") or plan.objective=="profit" and plan.saleKey~=self:ShoppingSaleKey())
end
function P:BuildShopping(levels,explicitPlanning)
    levels=tonumber(levels)
    if not levels or levels<1 or levels>300 or levels~=math.floor(levels) then
        self:ShoppingNotice("Enter a whole number of skill levels from 1 to 300.");return false
    end
    if self.char.shoppingUncertain and not explicitPlanning then self:ShoppingNotice("Resolve the outstanding purchase first.");return false end
    local skill=self.skills[self.selectedProf]
    if not skill then self:ShoppingNotice("Open this profession first to record its skill and learned recipes.");return false end
    if skill.rank>=skill.cap then self:ShoppingNotice("Train the next profession rank before planning more skill levels.");return false end
    self:CancelShoppingSearch()
    local plan=self:BuildShoppingRoute(skill.rank+levels)
    local saved={profession=self.selectedProf,start=plan.start,target=plan.target,reached=plan.reached,
        requested=levels,purchaseModel=self.purchaseModel,dataRevision=self.shoppingDataRevision or 0,cap=skill.cap,routeMode=plan.routeMode,needs={},training=plan.training,reason=plan.reason,steps={},created=time(),chanceModel=self.skillChanceModel,choiceRevision=self:RouteChoices().revision,objective=plan.objective,saleKey=plan.saleKey,proceeds=plan.proceeds,net=plan.net}
    for _,r in ipairs(plan.rows) do
        saved.steps[#saved.steps+1]={name=r.name,spell=r.spell,crafts=r.crafts,start=r.start,stop=r.stop,access=r.planAccess,mats=r.mats}
        for _,m in ipairs(r.mats) do saved.needs[m.id]=(saved.needs[m.id] or 0)+m.count*r.crafts end
    end
    local cfg=self:ShoppingConfig();if cfg then cfg.cancelled=nil end
    self.char.shoppingPlans=self.char.shoppingPlans or {};self.char.shoppingPlans[self.selectedProf]=saved
    self.shoppingOffset=0;self.shoppingSelected=nil
    self:ShoppingNotice(plan.reason and ("PARTIAL LIST: only skill "..plan.start.."-"..plan.reached.." is covered. "..plan.reason) or
        ("List updated for skill "..plan.start.."-"..plan.target..". Missing quantities exclude bags and tracked mail."))
    return true
end
function P:CancelShoppingSearch(message)
    self.shoppingQuery=nil;self.shoppingOffer=nil
    if message then self:ShoppingNotice(message) end
end
function P:InstallShoppingHooks()
    if self.shoppingHooks or not hooksecurefunc or not C_AuctionHouse then return end
    self.shoppingHooks=true
    for _,name in ipairs({"SendSearchQuery","SendBrowseQuery","SendSellSearchQuery"}) do
        if C_AuctionHouse[name] then hooksecurefunc(C_AuctionHouse,name,function()
            if not P.shoppingSending and (P.shoppingQuery or P.shoppingOffer) then
                P:CancelShoppingSearch("Another auction search started. Check AH again for this material.")
            end
        end) end
    end
    if C_AuctionHouse.ConfirmCommoditiesPurchase then hooksecurefunc(C_AuctionHouse,"ConfirmCommoditiesPurchase",function(id,quantity)
        if P.ObserveAuctionatorBuy then P:ObserveAuctionatorBuy("commodity",id,quantity) end
    end) end
    if C_AuctionHouse.PlaceBid then hooksecurefunc(C_AuctionHouse,"PlaceBid",function(id,amount)
        if P.ObserveAuctionatorBuy then P:ObserveAuctionatorBuy("item",id,amount) end
    end) end
end
function P:ReserveShoppingPurchase(tx)
    tx.sent=true
    local transit=self:ShoppingTransit(tx.item);transit.count=transit.count+tx.quantity
    -- Persist unresolved sends too; a disconnect must not offer duplicate buys.
    self.char.shoppingUncertain={item=tx.item,quantity=tx.quantity,kind=tx.kind,auctionID=tx.auctionID}
end
function P:FinishShoppingPurchase(success)
    local tx=self.shoppingTransaction;if not tx or not tx.sent then return end
    if not success then
        local transit=self:ShoppingTransit(tx.item);transit.count=math.max(0,transit.count-tx.quantity)
    end
    self.char.shoppingUncertain=nil;self.shoppingTransaction=nil
    self.shoppingOffer=nil;self.shoppingQuery=nil
    self:ShoppingNotice(success and ("Purchased "..tx.quantity.." "..self:ItemName(tx.item)..". Collect auction mail; quantities are credited until they reach your bags.") or
        "Purchase failed. No successful purchase was credited; check AH again.")

end
function P:SearchShoppingItem(id)
    if self:IsAuctionatorScanning() then self:ShoppingNotice("Wait for Auctionator full scan to finish before previewing another auction.");return end
    local api=C_AuctionHouse;local r=self:ShoppingRow(id)
    if r and r.method=="vendor" then self:ShoppingNotice("Buy this supply from a vendor. Select its supplier link for directions.");return end
    if nativeDialogOpen() then self:ShoppingNotice("Finish or cancel the existing auction confirmation first.");return end
    if self.char.shoppingUncertain then self:ShoppingNotice("Purchase result unresolved. Check your mail and reconcile the selected item's credit.");return end
    if not self.auctionOpen or not api or not api.SendSearchQuery then self:ShoppingNotice("Visit the auction house to check live listings.");return end
    if InCombatLockdown() then self:ShoppingNotice("Leave combat before shopping.");return end
    if not r or r.missing<=0 then self:ShoppingNotice("This material is already covered by bags and mail credit.");return end
    if self:ShoppingIsStale() then self:ShoppingNotice("Build the list again for your current skill and planning estimates.");return end
    if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then self:ShoppingNotice("Auction house is busy. Check AH again shortly.");return end
    self:InstallShoppingHooks()
    if not self.shoppingHooks then self:ShoppingNotice("Purchase tracking is unavailable on this client. Use the list with the game's auction window.");return end
    if self.priceScan then self:StopPriceScan("Cost scan paused while shopping.") end
    self.auctionatorShopping=nil
    self.shoppingTransaction=nil
    local q={item=id,key=key(id),profession=self.selectedProf,missing=r.missing,started=clock()}
    self.shoppingQuery=q;self.shoppingOffer=nil;self.shoppingSending=true
    self:ShoppingNotice("Checking live auctions for "..r.name.."...")
    local sorts=Enum and Enum.AuctionHouseSortOrder and {{sortOrder=Enum.AuctionHouseSortOrder.Price,reverseSort=false}} or {}
    local ok=pcall(api.SendSearchQuery,q.key,sorts,true);self.shoppingSending=false
    if not ok then self:CancelShoppingSearch("Search rejected. Try Check AH again.");return end
    C_Timer.After(30,function()if P.shoppingQuery==q and not P.shoppingOffer then P:CancelShoppingSearch("Search timed out. Check AH to retry; nothing was purchased.") end end)
end
function P:ReceiveShoppingResults(event,resultKey)
    local q=self.shoppingQuery;if not q then return end
    local id=type(resultKey)=="table" and resultKey.itemID or resultKey
    if id~=q.item then return end
    if self.selectedProf~=q.profession or self:ShoppingIsStale() then self:CancelShoppingSearch();return end
    local r=self:ShoppingRow(id);if not r or r.missing~=q.missing then self:CancelShoppingSearch("Materials changed. Check AH again.");return end
    local api=C_AuctionHouse;local offer={item=id,profession=q.profession,missing=r.missing,key=q.key,stamp=clock(),quantity=0,total=0}
    if event:find("COMMODITY",1,true) then
        offer.kind="commodity"
        local levels={}
        for i=1,(call(api.GetNumCommoditySearchResults,id) or 0) do
            local v=call(api.GetCommoditySearchResultInfo,id,i)
            if v and v.unitPrice and v.unitPrice>0 and not v.containsAccountItem then
                local available=math.max(0,(v.quantity or 0)-(v.numOwnerItems or 0))
                if not v.containsOwnerItem or v.numOwnerItems then levels[#levels+1]={price=v.unitPrice,quantity=available} end
            end
        end
        table.sort(levels,function(a,b)return a.price<b.price end)
        for _,v in ipairs(levels) do
            local amount=math.min(r.missing-offer.quantity,v.quantity)
            offer.quantity=offer.quantity+amount;offer.total=offer.total+amount*v.price
            if offer.quantity>=r.missing then break end
        end
    else
        offer.kind="item";local best
        for i=1,(call(api.GetNumItemSearchResults,q.key) or 0) do
            local v=call(api.GetItemSearchResultInfo,q.key,i)
            if v and v.auctionID and v.quantity and v.quantity>0 and v.buyoutAmount and v.buyoutAmount>0 and
                not v.containsOwnerItem and not v.containsAccountItem and v.itemKey and v.itemKey.itemID==id then
                -- Prefer a stack that does not exceed the shortfall; otherwise
                -- show the lowest total-cost stack and its explicit surplus.
                local fits=v.quantity<=r.missing
                if not best or fits and not best.fits or fits==best.fits and
                    (fits and v.buyoutAmount/v.quantity<best.total/best.quantity or not fits and v.buyoutAmount<best.total) then
                    best={fits=fits,quantity=v.quantity,total=v.buyoutAmount,auctionID=v.auctionID}
                end
            end
        end
        if best then offer.quantity=best.quantity;offer.total=best.total;offer.auctionID=best.auctionID end
    end
    self.shoppingOffer=offer
    self:ShoppingNotice(offer.quantity>0 and "Live price sample ready. Send this item or the full list to Auctionator to buy." or
        "No purchasable stock in these results. Try again later or use the listed supplier.")
end
-- Purchases are owned by Auctionator's UI. Never seed Blizzard's private
-- purchase dialog from addon code: its secure state can become tainted.
function P:SendShoppingItem()
    if self.shoppingSelected then return self:ShopWithAuctionator(self.shoppingSelected) end
    self:ShoppingNotice("Select a material to send to Auctionator.");return false
end
function P:ReconcileShoppingCredit(id,received)
    if not id then return end
    if nativeDialogOpen() then self:ShoppingNotice("Finish or cancel the existing auction confirmation first.");return end
    local uncertain=self.char.shoppingUncertain
    if uncertain and uncertain.item~=id then self:ShoppingNotice("Select the item with the unresolved purchase first.");return end
    -- Explicit two-click control; never automatically erase outstanding mail.
    if not received and self.shoppingClearID~=id then
        self.shoppingClearID=id;self:ShoppingNotice("Check mail and bags first. Click Clear credit again to forget this item's outstanding mail/purchase credit.");return
    end
    self.shoppingClearID=nil;self:ShoppingTransit(id).count=0
    if uncertain then self.char.shoppingUncertain=nil end
    self.shoppingTransaction=nil;self:CancelShoppingSearch((received and "Marked received / used: " or "Mail credit cleared for ")..self:ItemName(id)..". Bags are still counted.")
end
local events=CreateFrame("Frame")
for _,event in ipairs({"COMMODITY_SEARCH_RESULTS_ADDED","COMMODITY_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_ADDED","ITEM_SEARCH_RESULTS_UPDATED",
    "COMMODITY_PURCHASED","COMMODITY_PURCHASE_SUCCEEDED","COMMODITY_PURCHASE_FAILED","AUCTION_HOUSE_PURCHASE_COMPLETED","AUCTION_HOUSE_CLOSED","BAG_UPDATE_DELAYED",
    "SKILL_LINES_CHANGED","PLAYER_MONEY","AUCTION_HOUSE_SHOW_ERROR"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,a,b)
    if not P.char then return end
    if event:find("SEARCH_RESULTS",1,true) then
        if P.ObserveAuctionatorResults then P:ObserveAuctionatorResults(event,a) end
        P:ReceiveShoppingResults(event,a)
    elseif event=="COMMODITY_PURCHASE_SUCCEEDED" then
        -- This client success event has no item/quantity payload. Match only
        -- the active commodity send, never an unresolved receipt from a reload.
        local tx=P.shoppingTransaction
        if tx and tx.sent and tx.kind=="commodity" then P:FinishShoppingPurchase(true) end
    elseif event=="COMMODITY_PURCHASED" then
        local tx=P.shoppingTransaction
        if tx and tx.sent and tx.kind=="commodity" and tx.item==a and tx.quantity==b then P:FinishShoppingPurchase(true) end
    elseif event=="AUCTION_HOUSE_PURCHASE_COMPLETED" then
        local tx=P.shoppingTransaction;if tx and tx.sent and tx.kind=="item" and tx.auctionID==a then P:FinishShoppingPurchase(true) end
    elseif event=="COMMODITY_PURCHASE_FAILED" then
        local tx=P.shoppingTransaction;if tx and tx.sent and tx.kind=="commodity" then P:FinishShoppingPurchase(false) end
    elseif event=="AUCTION_HOUSE_CLOSED" then P.auctionatorShopping=nil;P:CancelShoppingSearch("Auction house closed. Your list and purchase credits are saved.")
    elseif event=="AUCTION_HOUSE_SHOW_ERROR" and P.char.shoppingUncertain then
        P:ShoppingNotice("Auction error: purchase result uncertain. Check mail/bags before clearing credit or buying again.")
    elseif event=="BAG_UPDATE_DELAYED" then
        for id in pairs(P.char.shoppingTransit or {}) do P:ShoppingTransit(id) end
    end
    if P.ShoppingChanged then P:ShoppingChanged(event) end
    if P.shoppingWindow and P.shoppingWindow:IsShown() then P:RefreshShopping() end
end)
P.shoppingEvents=events

