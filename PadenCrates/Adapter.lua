local addonName, P = ...
P.Adapter = {}
local A = P.Adapter
local requests = {}

local function isWritObjective(objective, entry)
    local text = objective.text or ""
    local linkedID = tonumber(text:match("|Hitem:(%d+)"))
    if linkedID then return linkedID == entry.itemID end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.itemID)
    name = name or entry.name
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- Match the complete localized name, never a substring of the requested item.
    return text == name or text:sub(1, #name + 1) == name .. ":"
end

function A.Price(itemID)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.GetAuctionPriceByItemID then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
    if not ok then return nil end
    local age
    if api.GetAuctionAgeByItemID then
        local ageOK, value = pcall(api.GetAuctionAgeByItemID, addonName, itemID)
        if ageOK then age = value end
    end
    return price, age
end

function A.Bags()
    local bags = {0,1,2,3,4}
    -- Forever currently has four equipped bags; include a reagent bag only if the client exposes one.
    local reagent = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if reagent and reagent > 4 then bags[#bags + 1] = reagent end
    return bags
end

function A.Inventory(itemID, quantity)
    return P.Engine.Inventory(itemID, quantity, A.Bags(),
        C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo)
end

function A.Entry(itemID)
    local entry = P.Catalog[itemID]
    if not entry or entry.kind ~= "writ" then return entry end
    local result = { itemID=entry.itemID, kind=entry.kind, name=entry.name,
        questID=entry.questID, options=entry.options, requirementSource="catalog" }
    if not C_QuestLog or not C_QuestLog.GetQuestObjectives then return result end
    local objectives = C_QuestLog.GetQuestObjectives(entry.questID)
    if not objectives or #objectives == 0 then
        local now = GetTime()
        if C_QuestLog.RequestLoadQuestByID and (not requests[entry.questID] or now - requests[entry.questID] >= 30) then
            requests[entry.questID] = now
            C_QuestLog.RequestLoadQuestByID(entry.questID)
        end
        return result
    end
    local requirement
    for _, objective in ipairs(objectives) do
        if objective.type == "item" and not isWritObjective(objective, entry) then
            -- Multiple required items invalidate this catalog's single-item cost.
            if requirement then result.options=nil; result.requirementSource="mismatch"; return result end
            requirement = objective
        end
    end
    if requirement and type(requirement.numRequired) == "number" and requirement.numRequired > 0 then
        local item = entry.options[1]
        result.options = {{ itemID=item.itemID, name=item.name, quantity=requirement.numRequired }}
        -- API confirms quantity, not target item ID: QuestObjectiveInfo has no item-ID field.
        result.requirementSource="liveQuantity"
    end
    return result
end

function A.Quote(itemID, maxAge)
    local entry = A.Entry(itemID)
    return entry, P.Engine.Compare(entry, A.Price, A.Inventory, maxAge or 3)
end
