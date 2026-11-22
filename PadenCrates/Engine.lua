local _, P = ...
P.Engine = {}
local E = P.Engine

local function validNumber(n)
    return type(n) == "number" and n == n and n > 0 and n < math.huge
end

-- A whole bundle is the unit of comparison. Inventory never changes its value.
function E.Compare(entry, getPrice, getInventory, maxAge)
    if not entry or not entry.options or #entry.options == 0 then return nil end
    local result = { options = {}, missing = 0, stale = 0, complete = true }
    for _, option in ipairs(entry.options) do
        local unit, age = getPrice(option.itemID)
        local total, stack = getInventory(option.itemID, option.quantity)
        local row = { itemID = option.itemID, quantity = option.quantity,
            name = option.name, count = total or 0, stack = stack, age = age }
        row.available = stack ~= nil and row.count >= row.quantity
        if validNumber(unit) then
            row.cost = unit * option.quantity
            row.unitPrice = unit
            if not validNumber(row.cost) then row.cost = nil end
        end
        if not row.cost then
            result.missing = result.missing + 1
            result.complete = false
        elseif type(age) ~= "number" or age ~= age or age < 0 or age > maxAge then
            row.stale = true
            result.stale = result.stale + 1
        end
        result.options[#result.options + 1] = row
        local best = result.best
        if row.cost and (not best or row.cost < best.cost or
            (row.cost == best.cost and ((row.available and not best.available) or
                (row.available == best.available and row.itemID < best.itemID)))) then result.best = row end
    end
    -- Unknown or stale alternatives could be cheaper. Leave ordinary manual use available.
    if entry.kind == "crate" and result.complete and result.stale == 0 and result.best then
        local best = result.best
        if best.count >= best.quantity and best.stack then result.fill = best end
    end
    return result
end

-- Prefer a sufficient stack, otherwise target the largest unlocked stack of the same material.
-- Some bundles exceed an item's stack limit; the server must aggregate the carried quantity.
-- Never rearrange bags or issue multiple uses. The actual cross-stack consumption is client-tested separately.
function E.Inventory(itemID, quantity, bags, slots, info)
    local count, unlocked, chosen, largest = 0, 0, nil, nil
    for _, bag in ipairs(bags) do
        for slot = 1, slots(bag) do
            local item = info(bag, slot)
            if item and item.itemID == itemID then
                local n = item.stackCount or 0
                count = count + n
                if not item.isLocked then
                    unlocked = unlocked + n
                    if not largest or n > largest.count then largest = {bag=bag,slot=slot,count=n} end
                end
                if not item.isLocked and n >= quantity and (not chosen or n < chosen.count) then
                    chosen = { bag = bag, slot = slot, count = n }
                end
            end
        end
    end
    return count, unlocked >= quantity and (chosen or largest) or nil
end

function E.FillPlan(entry, result, crate, context)
    if not entry or entry.kind ~= "crate" or not result or not result.fill then return nil end
    if not crate or crate.itemID ~= entry.itemID or crate.isLocked then return nil end
    if not context.enabled or not context.autoFill or context.combat or context.modifier or
        context.cursor or context.targeting or context.service then return nil end
    local fill = result.fill
    return { crateBag = crate.bag, crateSlot = crate.slot, crateID = entry.itemID,
        targetBag = fill.stack.bag, targetSlot = fill.stack.slot,
        targetID = fill.itemID, quantity = fill.quantity, cost = fill.cost }
end
