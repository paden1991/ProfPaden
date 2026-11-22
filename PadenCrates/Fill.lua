local _, P = ...
P.Fill = {}
local F = P.Fill
local button, owner, bagID, slotID, armedID
local serviceFrames = {"MerchantFrame", "BankFrame", "GuildBankFrame", "MailFrame", "TradeFrame",
    "AuctionFrame", "AuctionHouseFrame", "ItemInteractionFrame", "ScrappingMachineFrame"}

function F.Context()
    local service = false
    for _, name in ipairs(serviceFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then service = true; break end
    end
    -- These IDs are recorded from native interaction events, also covering replacement bag UIs.
    service = service or F.interactionOpen
    return { enabled=P.db and P.db.enabled, autoFill=P.db and P.db.autoFill,
        combat=InCombatLockdown(), modifier=IsModifierKeyDown(), cursor=GetCursorInfo() ~= nil,
        targeting=SpellIsTargeting(), service=service }
end

function F.Plan(bag, slot)
    if type(bag) ~= "number" or bag < 0 or bag > 5 or type(slot) ~= "number" or slot < 1 then return nil end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return nil end
    local entry, result = P.Adapter.Quote(info.itemID, 3)
    return P.Engine.FillPlan(entry, result, {itemID=info.itemID, isLocked=info.isLocked, bag=bag, slot=slot}, F.Context())
end

function F.Hide()
    if InCombatLockdown() then return end
    if button then button:Hide(); button:SetAttribute("type2", nil) end
    owner, bagID, slotID, armedID = nil, nil, nil, nil
end

local function currentPlan()
    if not owner or not owner:IsVisible() or owner:GetBagID() ~= bagID or owner:GetID() ~= slotID then return nil end
    local plan = F.Plan(bagID, slotID)
    if plan and plan.crateID == armedID then return plan end
end

local function attributes(plan)
    button:SetAttribute("type2", plan and "item" or nil)
    button:SetAttribute("item2", plan and (plan.crateBag.." "..plan.crateSlot) or nil)
    button:SetAttribute("target-bag2", plan and plan.targetBag or nil)
    button:SetAttribute("target-slot2", plan and plan.targetSlot or nil)
end

function F.Init()
    button = CreateFrame("Button", "PadenCratesFillButton", UIParent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:Hide()
    button:SetFrameStrata("DIALOG")
    button:RegisterForClicks("RightButtonUp")
    button:SetAttribute("useOnKeyDown", false)
    button:SetPassThroughButtons("LeftButton", "MiddleButton", "Button4", "Button5")
    button:SetAttribute("_onstate-combat", [[if newstate == "1" then self:Hide() end]])
    RegisterStateDriver(button, "combat", "[combat] 1; 0")
    button:SetScript("PreClick", function(self, mouseButton)
        if InCombatLockdown() then return end
        local plan = mouseButton == "RightButton" and currentPlan()
        attributes(plan)
    end)
    button:SetScript("PostClick", function()
        -- Never repeat consumption, chain uses, or call protected item APIs from a timer.
        F.Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnEnter", function()
        if not bagID or not slotID then return end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(bagID, slotID)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() F.Hide(); GameTooltip:Hide() end)
    local elapsed = 0
    button:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        if InCombatLockdown() then return end
        if not currentPlan() then F.Hide() end
    end)
end

function F.TryArm(tooltip, itemID)
    if not button or tooltip ~= GameTooltip or InCombatLockdown() then return false end
    local candidate = tooltip:GetOwner()
    if candidate == button then return currentPlan() ~= nil end
    if not candidate or not candidate.GetBagID or not candidate.GetID or not candidate:IsVisible() then return false end
    local bag, slot = candidate:GetBagID(), candidate:GetID()
    if type(bag) ~= "number" or type(slot) ~= "number" then return false end
    local plan = F.Plan(bag, slot)
    if not plan or plan.crateID ~= itemID then F.Hide(); return false end
    owner, bagID, slotID, armedID = candidate, bag, slot, itemID
    attributes(plan)
    button:ClearAllPoints()
    button:SetAllPoints(candidate)
    button:SetFrameLevel(candidate:GetFrameLevel()+10)
    button:Show()
    return true
end
