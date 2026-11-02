local _,P=...

function P:ShoppingCancelled()
    local cfg=self:ShoppingConfig()
    return cfg and cfg.cancelled==true or false
end

-- Cancel only the temporary list exported by ProfPaden. Auctionator's own
-- OnHide handlers release unconfirmed commodity quotes and reset item dialogs.
-- Never manipulate Blizzard's private purchase dialog or issue purchase calls.
function P:CancelAuctionatorExport(profession)
    local export=self.char.auctionatorExport
    local scope=self.auctionatorShopping
    if not export and scope then export=scope end
    if not export or export.profession~=profession then return true end
    local ok=true
    local function invoke(object,method,...)
        if not object or type(object[method])~="function" then return false end
        local success,result=pcall(object[method],object,...)
        if not success then ok=false end
        return success,result
    end
    local manager=Auctionator and Auctionator.Shopping and Auctionator.Shopping.ListManager
    local frame=AuctionatorShoppingFrame
    local container=frame and frame.ListsContainer
    local _,expanded=invoke(container,"GetExpandedList")
    local _,expandedName=invoke(expanded,"GetName")
    if export.listName and expandedName==export.listName and not invoke(frame,"StopSearch") then ok=false end
    local state=Auctionator and Auctionator.State
    local sent=self.shoppingTransaction and self.shoppingTransaction.sent or self.char.shoppingUncertain
    if state and not sent and export.listName and expandedName==export.listName then
        for _,entry in ipairs({{state.BuyCommodityFrameRef,"expectedItemID"},{state.BuyItemFrameRef,"expectedItemKey"}}) do
            local buy=entry[1];local item=buy and buy[entry[2]]
            if type(item)=="table" then item=item.itemID end
            if item and export.items and export.items[item] then
                local _,shown=invoke(buy,"IsShown")
                if shown and not invoke(buy,"Hide") then ok=false end
            end
        end
    end
    if export.listName then
        if manager and manager.GetIndexForName and manager.GetByName and manager.Delete then
            local _,index=invoke(manager,"GetIndexForName",export.listName)
            if index then
                local _,list=invoke(manager,"GetByName",export.listName)
                local _,temporary=invoke(list,"IsTemporary")
                if temporary then invoke(manager,"Delete",export.listName) end
            end
        elseif Auctionator then ok=false end
    end
    if scope and scope.profession==profession then self.auctionatorShopping=nil end
    if ok then self.char.auctionatorExport=nil end
    return ok
end

function P:CancelShopping()
    if InCombatLockdown() then self:ShoppingNotice("Leave combat before canceling shopping.");return false end
    local prof=self.selectedProf
    local cfg=self:ShoppingConfig(true);cfg.cancelled=true
    if self.char.shoppingPlans then self.char.shoppingPlans[prof]=nil end
    self:CancelShoppingSearch();self:CloseDropdown()
    self.shoppingSelected=nil;self.shoppingOffset=0;self.shoppingClearID=nil;self.shoppingDirty=nil
    -- A sent transaction must still receive its success/failure event. Keep
    -- uncertain sends and earned mail credit, including across a reload.
    if self.shoppingTransaction and not self.shoppingTransaction.sent then self.shoppingTransaction=nil end
    local stopped=self:CancelAuctionatorExport(prof)
    local message=prof.." shopping canceled. Choose Start new list or a new target to begin again. Purchased items and mail credits are kept."
    if self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent then
        message="List canceled; a purchase was already sent and cannot be recalled. Its result and mail credit remain tracked."
    elseif not stopped then message=message.." Cancel any remaining Auctionator confirmation/search there." end
    if AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() or StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION") then
        message=message.." Cancel the game's open purchase confirmation in its own window."
    end
    self:ShoppingNotice(message)
    return true
end
