local addon, P = ...
_G.ProfPaden = P
P.name, P.version = addon, "0.20.31-rc1"
P.skillChanceModel = 3
BINDING_HEADER_PROFPADEN="ProfPaden"
BINDING_NAME_PROFPADEN_TOGGLE="Open Artisan's Field Guide"
P.skills, P.live = {}, {}
P.skillIDs={[171]="Alchemy",[164]="Blacksmithing",[333]="Enchanting",[202]="Engineering",[182]="Herbalism",[165]="Leatherworking",[186]="Mining",[393]="Skinning",[197]="Tailoring",[185]="Cooking",[129]="First Aid",[356]="Fishing"}
P.professions = {
    {"Alchemy",2259,"Trade_Alchemy"}, {"Blacksmithing",2018,"Trade_BlackSmithing"},
    {"Enchanting",7411,"Trade_Engraving"}, {"Engineering",4036,"Trade_Engineering"},
    {"Herbalism",2366,"Trade_Herbalism"}, {"Leatherworking",2108,"Trade_LeatherWorking"},
    {"Mining",2575,"Trade_Mining"}, {"Skinning",8613,"INV_Misc_Pelt_Wolf_01"},
    {"Tailoring",3908,"Trade_Tailoring"}, {"Cooking",2550,"INV_Misc_Food_15"},
    {"First Aid",3273,"Spell_Holy_SealOfSacrifice"}, {"Fishing",7620,"Trade_Fishing"},
}
function P:Print(s) print("|cffffd100ProfPaden:|r "..s) end
function P:ItemID(link) return link and tonumber(link:match("item:(%d+)")) end
function P:SpellID(link) return link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)")) end
function P:Localized(name)
    for _,v in ipairs(self.professions) do
        if v[1]==name then
            return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(v[2])) or (GetSpellInfo and GetSpellInfo(v[2])) or name
        end
    end
    return name
end
function P:Canonical(name)
    if name=="Gardening" then return "Herbalism" elseif name=="Tanning" then return "Skinning" end
    if name=="Smelting" or (C_Spell and C_Spell.GetSpellName and name==C_Spell.GetSpellName(2656)) then return "Mining" end
    for _,v in ipairs(self.professions) do if name==v[1] or name==self:Localized(v[1]) then return v[1] end end
end
function P:Count(id, bank)
    local f = C_Item and C_Item.GetItemCount or GetItemCount
    return (id and f and f(id, bank or false)) or 0
end
function P:ItemName(id)
    if not id then return "Loading item" end
    local f = C_Item and C_Item.GetItemInfo or GetItemInfo
    return (f and f(id)) or (self.ItemMeta and self.ItemMeta[id] and self.ItemMeta[id].name) or (self.GatherItemNames and self.GatherItemNames[id]) or (self.Items[id] and self.Items[id].name) or ("Item "..tostring(id))
end
function P:Money(c)
    if c==nil then return "Unknown" end
    local sign=c<0 and "-" or "";c=math.floor(math.abs(c)+0.5)
    return string.format("%s%dg %02ds %02dc",sign,math.floor(c/10000),math.floor(c/100)%100,c%100)
end
function P:Init()
    ProfPadenDB=ProfPadenDB or {};ProfPadenCharDB=ProfPadenCharDB or {}
    self.db,self.char=ProfPadenDB,ProfPadenCharDB
    self.db.realms=self.db.realms or {}
    local realm=(GetRealmName and GetRealmName() or "Unknown")..":"..(UnitFactionGroup("player") or "Neutral")
    self.db.realms[realm]=self.db.realms[realm] or {prices={}}
    self.market=self.db.realms[realm];self.market.prices=self.market.prices or {}
    self.char.recipes=self.char.recipes or {};self.char.checked=self.char.checked or {}
    if self.MigrateFavoritePins then self:MigrateFavoritePins() end
    if self.NPCSources then for id,npc in pairs(self.char.npcLocations or {}) do self.NPCSources[id]=npc end end
    self.selectedProf=self.char.profession or "Alchemy";self.mode="guide";self.tab="Recipes";self.offset=0
    self:ReadSkills()
end
local frame=CreateFrame("Frame")
P.events=frame
for _,e in ipairs({"SPELLS_CHANGED","SPELL_UPDATE_COOLDOWN"}) do pcall(frame.RegisterEvent,frame,e) end
for _,e in ipairs({"TRAINER_SHOW","TRAINER_UPDATE","TRAINER_SERVICE_INFO_NAME_UPDATE","TRAINER_CLOSED","COMMODITY_SEARCH_RESULTS_ADDED","ITEM_SEARCH_RESULTS_ADDED","AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED"}) do pcall(frame.RegisterEvent,frame,e) end
for _,e in ipairs({"ADDON_LOADED","PLAYER_LOGIN","SKILL_LINES_CHANGED","TRADE_SKILL_SHOW","TRADE_SKILL_UPDATE","TRADE_SKILL_CLOSE","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED","TRADE_SKILL_DETAILS_UPDATE","NEW_RECIPE_LEARNED","CRAFT_SHOW","CRAFT_UPDATE","CRAFT_CLOSE","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED","QUEST_LOG_UPDATE","PLAYER_REGEN_ENABLED","AUCTION_ITEM_LIST_UPDATE","COMMODITY_SEARCH_RESULTS_UPDATED","ITEM_SEARCH_RESULTS_UPDATED","AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","MERCHANT_SHOW","MERCHANT_UPDATE","BAG_UPDATE_COOLDOWN","UNIT_AURA","PLAYER_ENTERING_WORLD"}) do
    pcall(frame.RegisterEvent,frame,e)
end
frame:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" then if arg==addon then P:Init() end;return end
    if not P.db then return end
    if event=="SPELLS_CHANGED" then P:RefreshCamp();return end
    if event=="SPELL_UPDATE_COOLDOWN" then P:RefreshCampCooldowns();return end
    if event=="UNIT_AURA" then
        if arg=="player" then P:UpdateCampProximity() end
        return
    end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" then P:CreateMinimapButtons() end
    if event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_REGEN_ENABLED" then P:UpdateCampProximity() end
    if event=="TRADE_SKILL_SHOW" then P.openKind="trade"
    elseif event=="CRAFT_SHOW" then P.openKind="craft"
    elseif event=="TRADE_SKILL_CLOSE" or event=="CRAFT_CLOSE" then P.openKind=nil;P.live={}
    elseif event=="AUCTION_ITEM_LIST_UPDATE" then P:CaptureAuctionPage()
    elseif event=="COMMODITY_SEARCH_RESULTS_UPDATED" or event=="ITEM_SEARCH_RESULTS_UPDATED" or event=="COMMODITY_SEARCH_RESULTS_ADDED" or event=="ITEM_SEARCH_RESULTS_ADDED" then P:CaptureModernAuction(event,arg);P:PriceQueryResult(arg)
    elseif event=="AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED" then P:PriceThrottleEvent(event)
    elseif event=="TRAINER_SHOW" then P.trainerOpen=true;P:CaptureTrainer()
    elseif event=="TRAINER_UPDATE" or event=="TRAINER_SERVICE_INFO_NAME_UPDATE" then if P.trainerOpen then P:CaptureTrainer() end
    elseif event=="TRAINER_CLOSED" then P.trainerOpen=false
    elseif event=="AUCTION_HOUSE_SHOW" then P.auctionOpen=true;P:ConnectAuctionatorScan();P:ConnectAuctionator()
    elseif event=="AUCTION_HOUSE_CLOSED" then P.auctionOpen=false;P:StopPriceScan("Auction house closed; saved price samples retained.")
    elseif event=="MERCHANT_SHOW" or event=="MERCHANT_UPDATE" then P:CaptureMerchant() end
    if event=="PLAYER_LOGIN" or event=="SKILL_LINES_CHANGED" then P:ReadSkills() end
    if event=="BAG_UPDATE_DELAYED" or event=="GET_ITEM_INFO_RECEIVED" or event=="BAG_UPDATE_COOLDOWN" then P:RefreshCamp() end
    local recipeEvent=event:find("TRADE_SKILL") or event:find("CRAFT") or event=="BAG_UPDATE_DELAYED" or event=="NEW_RECIPE_LEARNED"
    if event=="TRADE_SKILL_CLOSE" or event=="CRAFT_CLOSE" then
        P.recipeScanPending=nil
    elseif event=="TRADE_SKILL_SHOW" or event=="CRAFT_SHOW" or event=="NEW_RECIPE_LEARNED" then
        P.recipeScanPending=nil;P:ScanRecipes()
    elseif recipeEvent then
        -- Profession APIs often send one update per recipe/reagent. Read the
        -- final snapshot once per burst; Craft still performs its own fresh scan.
        P.recipeScanPending=true
    end
    if P.CheckNavigationCompletion then P:CheckNavigationCompletion(event,arg) end
    if event=="TRADE_SKILL_SHOW" or event=="TRADE_SKILL_CLOSE" then
        if P.campRoot and P.campRoot:IsShown() then P:RefreshCamp() end
    elseif event=="TRADE_SKILL_DATA_SOURCE_CHANGED" or event=="TRADE_SKILL_LIST_UPDATE" then
        P.pendingCampRefresh=true
    end
    -- Cooldowns do not change materials, skills or prices. Quest changes only
    -- affect the quest pane. Item-cache responses must not rebuild hidden routes.
    if event=="BAG_UPDATE_COOLDOWN" and not P.navigationRouteCompleted then return end
    if event=="QUEST_LOG_UPDATE" and not P.navigationRouteCompleted and (not P.window or not P.window:IsShown() or P.tab~="Quests") then return end
    local routeChanged=event~="GET_ITEM_INFO_RECEIVED" and event~="QUEST_LOG_UPDATE" and event~="PLAYER_REGEN_ENABLED" and event~="BAG_UPDATE_COOLDOWN"
    if event~="QUEST_LOG_UPDATE" and event~="PLAYER_REGEN_ENABLED" and event~="BAG_UPDATE_COOLDOWN" and P.InvalidatePlan then P:InvalidatePlan() end
    P.pendingRouteRefresh=P.pendingRouteRefresh or routeChanged
    if P.ShoppingChanged then P:ShoppingChanged(event) end
    if not P.pendingRefresh then
        P.pendingRefresh=true
        C_Timer.After(0.15,function()
            P.pendingRefresh=false
            local routeChanged=P.pendingRouteRefresh;P.pendingRouteRefresh=nil
            if P.recipeScanPending then
                P.recipeScanPending=nil;P:ScanRecipes()
                if P.CheckNavigationCompletion then P:CheckNavigationCompletion() end
            end
            if P.pendingCampRefresh then
                P.pendingCampRefresh=nil
                if P.campRoot and P.campRoot:IsShown() then P:RefreshCamp() end
            end
            local completedRoute=P.navigationRouteCompleted;P.navigationRouteCompleted=nil
            if P.window and P.window:IsShown() then P:Refresh()
            elseif (routeChanged or completedRoute) and (P.navRouteKey or completedRoute) and P.RouteEntries then
                local entries=P:Entries();local current
                for _,r in ipairs(entries) do if r.key==P.selectedKey then current=r;break end end
                P.selected=current or entries[1];P.selectedKey=P.selected and P.selected.key
                P:UpdateRouteNavigation()
            end end)
    end
end)
SLASH_PROFPADEN1="/pp";SLASH_PROFPADEN2="/profpaden"
SlashCmdList.PROFPADEN=function(msg)
    if not P.db then return end
    if msg=="tracking" or msg=="tracking on" or msg=="tracking off" then
        P:SetNavigationEnabled(msg=="tracking on" or msg=="tracking" and not P:IsNavigationEnabled())
        P:Print(P:IsNavigationEnabled() and "Tracking on. Resume walking routes with Start." or "Tracking off. Waypoints cleared; walking routes paused.");return
    end
    if msg=="gamepad" or msg=="gamepad on" then P:GamepadFocus();return end
    if msg=="gamepad off" or msg=="gamepad auto" then
        if msg=="gamepad off" then P.char.gamepadEnabled=false else P.char.gamepadEnabled=nil end
        if P.gamepad then P.gamepad:Sync() end
        P:Print(msg=="gamepad off" and "Controller navigation off." or "Controller navigation follows the gamepad setting.");return
    end
    if msg=="shop" or msg=="shopping" then P:ToggleShopping();return end
    if msg=="camp" then P:ToggleCamp();return end
    local id,price=msg:match("^price%s+(%d+)%s+(%d+)$")
    if id then
        id,price=tonumber(id),tonumber(price)
        if price>10000000000 then P:Print("Price is too large.");return end
        P.market.prices[id]={value=price,source="Manual",time=time()};P:InvalidatePlan();P:Print("Unit price saved for "..P:ItemName(id));if P.window then P:Refresh() end;return
    end
    id=msg:match("^clearprice%s+(%d+)$")
    if id then P.market.prices[tonumber(id)]=nil;P:InvalidatePlan();P:Print("Price override cleared.");if P.window then P:Refresh() end;return end
    if msg=="diagnostics" then
        P:Print("Build "..tostring(select(4,GetBuildInfo())).."; recipe API: "..(C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and "Forever modern" or GetTradeSkillInfo and "Classic" or "unavailable").."; active window: "..tostring(P.openKind).."; recipes: "..#P.live);return
    end
    P:Toggle()
end
