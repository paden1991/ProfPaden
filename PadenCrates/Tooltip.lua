local _, P = ...
P.Tooltip = {}
local T, L = P.Tooltip, P.L
local function itemName(row)
    return (C_Item.GetItemNameByID and C_Item.GetItemNameByID(row.itemID)) or row.name
end
local function money(value) return GetMoneyString(math.floor(value + 0.5), true) end
local function note(tooltip, text, r, g, b) tooltip:AddLine(text, r or .65, g or .7, b or .75, true) end

function T.Render(tooltip, entry, quote, ready, expanded)
    if not entry then return end
    tooltip:AddLine(" ")
    if not quote then
        note(tooltip, L.WRIT_CHANGED, 1,.65,.3)
        return
    end
    local best = quote.best
    if not best then
        note(tooltip, L.TITLE, .9,.78,.45)
        note(tooltip, L.NO_PRICE)
        return
    end
    local title = entry.kind == "writ" and L.WRIT_COST or (quote.complete and L.CHEAPEST or L.KNOWN)
    tooltip:AddDoubleLine(title, money(best.cost), .9,.78,.45, 1,1,1)
    note(tooltip, string.format(L.MATERIAL, best.quantity, itemName(best)), .9,.93,.95)
    tooltip:AddDoubleLine(string.format(L.OWNED, best.count, best.quantity), L.SOURCE, .65,.7,.75, .65,.7,.75)
    local knownAge = type(best.age)=="number" and best.age==best.age and best.age>=0 and best.age<math.huge
    local age = best.age == 0 and L.AGE_TODAY or (knownAge and string.format(L.AGE, best.age) or L.AGE_UNKNOWN)
    note(tooltip, age)
    if quote.missing > 0 then note(tooltip, string.format(L.PARTIAL, quote.missing, #quote.options), 1,.65,.3)
    elseif quote.stale > 0 then note(tooltip, L.STALE, 1,.65,.3)
    elseif entry.kind == "crate" then
        if ready then note(tooltip, L.READY, .35,1,.55)
        elseif best.count < best.quantity then note(tooltip, string.format(L.MISSING, best.quantity-best.count), 1,.65,.3)
        elseif not best.stack then note(tooltip, L.STACK, 1,.65,.3)
        else note(tooltip, L.MANUAL) end
    end
    if entry.kind == "writ" then
        if entry.requirementSource ~= "liveQuantity" then note(tooltip, L.WRIT_CATALOG, 1,.65,.3) end
    elseif expanded then
        local sorted = {}
        for _, option in ipairs(quote.options) do sorted[#sorted+1] = option end
        table.sort(sorted, function(a,b)
            if a.cost == b.cost then return a.itemID < b.itemID end
            return (a.cost or math.huge) < (b.cost or math.huge)
        end)
        for _, option in ipairs(sorted) do
            tooltip:AddDoubleLine(string.format(L.MATERIAL, option.quantity, itemName(option)),
                option.cost and money(option.cost) or "?", .75,.8,.85, .75,.8,.85)
        end
    else note(tooltip, L.SHIFT) end
end

function T.Init()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not P.db.enabled or not data or not P.Catalog[data.id] then return end
        local primary = tooltip.GetPrimaryTooltipData and tooltip:GetPrimaryTooltipData()
        if primary and primary.id ~= data.id then return end
        local entry, quote = P.Adapter.Quote(data.id, 3)
        local ready = entry.kind == "crate" and P.Fill.TryArm(tooltip, data.id)
        T.Render(tooltip, entry, quote, ready, IsShiftKeyDown())
    end)
end
