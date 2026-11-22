local addonName, P = ...
P.Shopping = {}
local S = P.Shopping

-- Sum obligations first, then deduct each carried item only once across all orders.
function S.Build(owned, stock, getEntry, getPrice, options)
    local plan = {rows={}, blocked={}, crates=0, writs=0, estimate=0, unknown=0, stale=0, units=0}
    local needed, names, ids = {}, {}, {}
    for id in pairs(owned) do ids[#ids+1]=id end
    table.sort(ids)
    for _,id in ipairs(ids) do
        local entry, count = getEntry(id), owned[id]
        if entry and count>0 and ((entry.kind=="crate" and options.buyCrates) or (entry.kind=="writ" and options.buyWrits)) then
            local bucket = entry.kind=="crate" and "crates" or "writs"
            plan[bucket] = plan[bucket]+count
            local reason, selected
            if entry.kind=="writ" then
                if not entry.options or #entry.options~=1 then reason="requirements"
                else selected=entry.options[1] end
            else
                local quote=P.Engine.Compare(entry,getPrice,function(item,qty)
                    local remaining=math.max(0,(stock[item] or 0)-(needed[item] or 0))
                    return remaining, remaining>=qty and {} or nil
                end,3)
                if not quote or not quote.complete then reason="prices"
                elseif quote.stale>0 then reason="stale"
                else selected=quote.best end
            end
            if selected then
                needed[selected.itemID]=(needed[selected.itemID] or 0)+selected.quantity*count
                names[selected.itemID]=selected.name
            else
                plan.blocked[#plan.blocked+1]={itemID=id,name=entry.name,count=count,reason=reason}
            end
        end
    end
    for id,quantity in pairs(needed) do
        local have=stock[id] or 0
        local missing=math.max(0,quantity-have)
        local unit,age=getPrice(id)
        local priced=type(unit)=="number" and unit==unit and unit>0 and unit<math.huge
        local stale=type(age)~="number" or age~=age or age<0 or age>3
        local row={itemID=id,name=names[id],needed=quantity,have=have,missing=missing,
            cost=priced and missing*unit or nil,stale=stale}
        plan.rows[#plan.rows+1]=row
        if missing>0 then
            plan.units=plan.units+missing
            if row.cost then plan.estimate=plan.estimate+row.cost else plan.unknown=plan.unknown+1 end
            if stale then plan.stale=plan.stale+1 end
        end
    end
    table.sort(plan.rows,function(a,b) return a.itemID<b.itemID end)
    local signature={tostring(options.buyCrates),tostring(options.buyWrits)}
    for _,row in ipairs(plan.rows) do signature[#signature+1]=row.itemID..":"..row.needed..":"..row.have end
    for _,row in ipairs(plan.blocked) do signature[#signature+1]="blocked:"..row.itemID..":"..row.count..":"..row.reason end
    plan.signature=table.concat(signature,";")
    return plan
end

function S.Snapshot()
    local owned,stock={},{}
    for _,bag in ipairs(P.Adapter.Bags()) do
        for slot=1,C_Container.GetContainerNumSlots(bag) do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info and info.itemID and info.stackCount and info.stackCount>0 then
                stock[info.itemID]=(stock[info.itemID] or 0)+info.stackCount
                if P.Catalog[info.itemID] then owned[info.itemID]=(owned[info.itemID] or 0)+info.stackCount end
            end
        end
    end
    return owned,stock
end

function S.Plan()
    local owned,stock=S.Snapshot()
    return S.Build(owned,stock,P.Adapter.Entry,P.Adapter.Price,P.db)
end

function S.IsAuctionOpen()
    return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown()) or false
end

function S.PurchaseDialogOpen()
    local function visible(frame)
        if not frame then return false end
        if frame.IsVisible then return frame:IsVisible() end
        return frame.IsShown and frame:IsShown() or false
    end
    if visible(AuctionHouseFrame and AuctionHouseFrame.BuyDialog) or
        visible(AuctionatorBuyItemFrame and AuctionatorBuyItemFrame.BuyDialog) then return true end
    -- Read-only visibility checks for the installed Auctionator 351 confirmation frames.
    local commodity=AuctionatorBuyCommodityFrame
    if commodity and (visible(commodity.FinalConfirmationDialog) or visible(commodity.QuantityCheckConfirmationDialog) or
        visible(commodity.WidePriceRangeWarningDialog)) then return true end
    return StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION") or false
end

function S.Send()
    if InCombatLockdown() then return false,"SHOP_COMBAT" end
    if not S.IsAuctionOpen() then return false,"SHOP_OPEN_AH" end
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or type(api.MultiSearchAdvanced)~="function" then return false,"SHOP_PROVIDER" end
    local plan=S.Plan() -- Rebuild on click; never export quantities from a stale window.
    if #plan.blocked>0 then return false,"SHOP_BLOCKED" end
    if plan.units==0 then return false,"SHOP_NOTHING" end
    if S.sentSignature==plan.signature then return false,"SHOP_ALREADY_SENT" end
    if S.PurchaseDialogOpen() then return false,"SHOP_FINISH_PURCHASE" end
    local terms={}
    for _,row in ipairs(plan.rows) do
        if row.missing>0 then
            local name=C_Item.GetItemNameByID(row.itemID)
            if not name then
                if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(row.itemID) end
                return false,"SHOP_NAMES"
            end
            if name:find("[;^]") or name:match('^".*"$') then return false,"SHOP_NAME_FORMAT" end
            terms[#terms+1]={searchString=name,isExact=true,quantity=row.missing}
        end
    end
    local ok=pcall(api.MultiSearchAdvanced,addonName,terms)
    if not ok then return false,"SHOP_FAILED" end
    S.sentSignature=plan.signature
    return true,"SHOP_SENT"
end
