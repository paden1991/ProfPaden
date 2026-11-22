local addonName, P = ...
local L = P.L
local frame = CreateFrame("Frame")
local initialized, category

local function settings()
    if category or not P.db or not Settings or not Settings.RegisterVerticalLayoutCategory then return end
    category = Settings.RegisterVerticalLayoutCategory(L.TITLE)
    for _, option in ipairs({{"enabled", L.ENABLED, L.ENABLED_HELP}, {"autoFill", L.AUTOFILL, L.AUTOFILL_HELP},
        {"buyCrates",L.SHOP_INCLUDE_CRATES,L.SHOP_INCLUDE_HELP},{"buyWrits",L.SHOP_INCLUDE_WRITS,L.SHOP_INCLUDE_HELP}}) do
        local setting = Settings.RegisterAddOnSetting(category, "PadenCrates_"..option[1], option[1], P.db,
            Settings.VarType.Boolean, option[2], true)
        setting:SetValueChangedCallback(function() P.Fill.Hide(); P.Shopping.OnEvent() end)
        Settings.CreateCheckbox(category, setting, option[3])
    end
    Settings.RegisterAddOnCategory(category)
end

local function refresh()
    P.Fill.Hide()
    P.Shopping.OnEvent()
    -- A visible bag tooltip is rebuilt by its native owner on the next hover/update.
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg == addonName and not initialized then
            initialized = true
            if type(PadenCratesDB) ~= "table" then PadenCratesDB = {} end
            P.db = PadenCratesDB
            for _, key in ipairs({"enabled", "autoFill", "buyCrates", "buyWrits"}) do
                if type(P.db[key]) ~= "boolean" then P.db[key] = true end
            end
            P.Fill.Init()
            P.Tooltip.Init()
            for _, name in ipairs({"BAG_UPDATE_DELAYED", "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_ENABLED",
                "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "AUCTION_HOUSE_SHOW",
                "AUCTION_HOUSE_CLOSED", "QUEST_DATA_LOAD_RESULT", "QUEST_LOG_UPDATE", "GET_ITEM_INFO_RECEIVED", "PLAYER_REGEN_DISABLED"}) do frame:RegisterEvent(name) end
            SLASH_PADENCRATES1 = "/pcrates"
            SlashCmdList.PADENCRATES = function(command)
                if command == "status" then
                    local api = Auctionator and Auctionator.API and Auctionator.API.v1
                    print(string.format(L.STATUS, api and L.AVAILABLE or L.UNAVAILABLE, P.db.autoFill and L.ON or L.OFF))
                elseif command == "shop" then P.Shopping.Toggle()
                elseif command == "help" then print(L.HELP)
                else settings(); if category then Settings.OpenToCategory(category:GetID()) else print(L.OPTIONS_UNAVAILABLE) end end
            end
        end
        settings()
        if initialized then P.Shopping.OnEvent() end
        if initialized and not P.priceHooked and Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.RegisterForDBUpdate then
            P.priceHooked = pcall(Auctionator.API.v1.RegisterForDBUpdate, addonName, refresh)
        end
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
        C_Timer.After(0,P.Shopping.OnEvent)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        P.Fill.interactionOpen = true; refresh()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        P.Fill.interactionOpen = false; refresh()
    else refresh() end
end)
