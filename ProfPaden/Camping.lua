local _,P=...
BINDING_NAME_PROFPADEN_CAMP="Expand camp supplies"
P.campfireAuraID=1283391
P.basicCampfireSpellID=1229737
P.legacyCampfireSpellID=818
function P:CampCookingOpen()
    if self.openKind~="trade" then return false end
    local api=C_TradeSkillUI
    if api and api.GetBaseProfessionInfo then
        if api.IsDataSourceChanging and api.IsDataSourceChanging() or api.IsTradeSkillLinked and api.IsTradeSkillLinked() or api.IsTradeSkillGuild and api.IsTradeSkillGuild() then return false end
        local info=api.GetBaseProfessionInfo()
        return info and (info.professionID==185 or info.parentProfessionID==185 or self:Canonical(info.professionName)=="Cooking") or false
    end
    if GetTradeSkillLine then return self:Canonical(GetTradeSkillLine())=="Cooking" end
    return false
end
function P:CraftCampfireKit()
    if InCombatLockdown() then return false,"Leave combat before making a campfire kit." end
    local fire=self:ReadyBasicCampfire()
    if not fire or fire.spell~=self.basicCampfireSpellID then return false,"Basic Campfire needs the learned recipe, Simple Wood and Flint and Tinder in your bags." end
    if not self:CampCookingOpen() then return false,"Open Cooking, then click Make kit again." end
    -- Resolve freshly through the same checked adapter as the guide. A learned
    -- trade recipe is not necessarily a castable spellbook action.
    return self:Craft({spell=self.basicCampfireSpellID,item=279981,profession="Cooking",journeyPrepare=true},1)
end
function P:ReadyBasicCampfire()
    local wood=self:Count(4470);local tinder=self:Count(4471)
    if wood<1 or tinder<1 then return end
    local known=C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell or IsSpellKnown
    if not known then return end
    local spell=known(self.basicCampfireSpellID) and self.basicCampfireSpellID
        or known(self.legacyCampfireSpellID) and self.legacyCampfireSpellID
    if not spell then return end
    local name=C_Spell and C_Spell.GetSpellName or GetSpellInfo
    return {spell=spell,count=math.floor(wood),name=name and name(spell) or "Basic Campfire"}
end
function P:UpdateCampButtonCooldown(b)
    local start,duration,enabled
    if b.spellID then
        if C_Spell and C_Spell.GetSpellCooldown then
            local cd=C_Spell.GetSpellCooldown(b.spellID)
            if cd then start,duration,enabled=cd.startTime,cd.duration,cd.isEnabled end
        elseif GetSpellCooldown then start,duration,enabled=GetSpellCooldown(b.spellID) end
    elseif b.itemID then
        local cooldown=C_Item and C_Item.GetItemCooldown or GetItemCooldown
        if cooldown then start,duration,enabled=cooldown(b.itemID) end
    end
    b.cooldown:SetCooldown(start or 0,duration or 0)
    b.cooldown:SetShown(enabled~=false and enabled~=0 and (duration or 0)>0)
end
function P:RefreshCampCooldowns()
    if not self.campRoot or not self.campRoot:IsShown() then return end
    for _,b in ipairs(self.campButtons or {}) do if b:IsShown() then self:UpdateCampButtonCooldown(b) end end
end
function P:HasCampfireAura()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,self.campfireAuraID)
        if ok then return aura~=nil end
        return nil -- Preserve the last state while aura data is unavailable.
    end
    for i=1,255 do
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,"player",i,"HELPFUL")
            if not ok then return nil end
            if not aura then return false end
            if aura.spellId==self.campfireAuraID then return true end
        elseif UnitBuff then
            local name,_,_,_,_,_,_,_,_,id=UnitBuff("player",i)
            if not name then return false end
            if id==self.campfireAuraID then return true end
        else return nil end
    end
    return false
end
function P:UpdateCampProximity()
    local nearby=self:HasCampfireAura()
    if nearby~=nil and nearby~=self.campNearby then
        self.campNearby=nearby;self.campManualOpen=nil
    end
    self:RefreshCamp()
end
function P:CampShouldOpen()
    if self.campManualOpen~=nil then return self.campManualOpen end
    return self.campNearby==true
end
function P:ApplyCampVisibility()
    if InCombatLockdown() or not self.campRoot then return end
    local show=self:CampShouldOpen()
    local driver=show and "[combat] hide; show" or "hide"
    if self.campVisibilityDriver~=driver then
        if RegisterStateDriver then RegisterStateDriver(self.campRoot,"visibility",driver) end
        self.campVisibilityDriver=driver
    end
    self.campRoot:SetShown(show);self.campHolder:SetShown(show)
end
function P:OwnedCampItems()
    local result={}
    local fire=self:ReadyBasicCampfire();if fire then result[#result+1]=fire end
    for _,id in ipairs(self.CampItems) do
        local count=self:Count(id)
        if count>0 then
            local usable=C_Item and C_Item.IsUsableItem or IsUsableItem
            local canUse=not usable or usable(id)
            if canUse then result[#result+1]={id=id,count=count,name=self:ItemName(id)} end
        end
    end
    for _,food in ipairs(self:OwnedBuffFoods()) do result[#result+1]=food end
    return result
end
function P:CreateCampMenu()
    if self.campRoot or InCombatLockdown() then return end
    local root=CreateFrame("Frame","ProfPadenCampRoot",UIParent,"SecureHandlerStateTemplate")
    root:SetSize(52,52);root:SetClampedToScreen(true);root:SetMovable(true)
    local pos=self.char.campPosition
    root:SetPoint("CENTER",UIParent,"CENTER",pos and pos.x or 330,pos and pos.y or -180)
    root:Hide()
    local toggle=CreateFrame("Button","ProfPadenCampToggle",root,"BackdropTemplate");toggle:SetAllPoints();toggle:RegisterForClicks("LeftButtonUp","RightButtonUp");toggle:RegisterForDrag("LeftButton")
    toggle:SetNormalTexture("Interface\\Icons\\Spell_Fire_Fire")
    toggle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    -- TrackingBorder is offset artwork for a tiny minimap button, not this icon.
    toggle:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    toggle:SetBackdropBorderColor(.8,.62,.28,1)
    local icon=toggle:GetNormalTexture();icon:ClearAllPoints();icon:SetPoint("TOPLEFT",4,-4);icon:SetPoint("BOTTOMRIGHT",-4,4);icon:SetTexCoord(.07,.93,.07,.93)
    toggle:SetScript("OnClick",function(_,button)if button=="RightButton" then P:Toggle() else P:ToggleCamp() end end)
    toggle:SetScript("OnDragStart",function()if not InCombatLockdown() then root:StartMoving() end end)
    toggle:SetScript("OnDragStop",function()
        if InCombatLockdown() then return end
        root:StopMovingOrSizing();local x,y=root:GetCenter();local px,py=UIParent:GetCenter()
        if x and px then P.char.campPosition={x=x-px,y=y-py} end
    end)
    toggle:SetScript("OnEnter",function(s)
        GameTooltip:SetOwner(s,"ANCHOR_LEFT");GameTooltip:SetText("Camp supplies & buff food")
        GameTooltip:AddLine("Left-click: expand usable supplies in bags.\nRight-click: profession guide. Drag to move.\nHidden in combat; each placement needs a click.",1,.85,.55,true);GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave",function()GameTooltip:Hide()end)
    local holder=CreateFrame("Frame",nil,root);holder:SetAllPoints();holder:Hide()
    local sit=CreateFrame("Button","ProfPadenCampSit",holder,"SecureActionButtonTemplate,UIPanelButtonTemplate")
    sit:SetSize(52,20);sit:SetPoint("TOP",root,"BOTTOM",0,-4);sit:SetText("Sit")
    sit:RegisterForClicks("AnyUp","AnyDown");sit:SetAttribute("useOnKeyDown",false)
    sit:SetAttribute("type","macro");sit:SetAttribute("macrotext","/sit")
    sit:SetScript("OnEnter",function(s)GameTooltip:SetOwner(s,"ANCHOR_RIGHT");GameTooltip:SetText("Sit by the fire");GameTooltip:AddLine("Click to /sit.",1,.85,.55);GameTooltip:Show()end)
    sit:SetScript("OnLeave",function()GameTooltip:Hide()end)
    self.campSit=sit
    holder.empty=holder:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");holder.empty:SetPoint("TOP",sit,"BOTTOM",0,-12);holder.empty:SetWidth(220)
    self.campRoot=root;self.campToggle=toggle;self.campHolder=holder;self.campButtons={}
end
function P:RefreshCamp()
    if InCombatLockdown() then self.campDirty=true;return end
    self:CreateCampMenu();if not self.campRoot then return end
    self.campDirty=false;local items=self:OwnedCampItems();self.campOwned=items
    for i=1,math.max(#items,#self.campButtons) do
        local b=self.campButtons[i]
        if not b then
            b=CreateFrame("Button","ProfPadenCampItem"..i,self.campHolder,"SecureActionButtonTemplate")
            b:SetSize(38,38);b:RegisterForClicks("AnyUp","AnyDown");b:SetAttribute("useOnKeyDown",false)
            -- Capture the action before the secure click: opening Cooking can
            -- synchronously rebuild the wheel. Never craft on that same release
            -- by accidentally observing its newly assigned action.
            b:SetScript("PreClick",function(s,button,down)s.campCraftClick=button=="LeftButton" and not down and s.campAction=="craft" end)
            b:SetScript("PostClick",function(s,button,down)
                if down or not s.campCraftClick then return end
                s.campCraftClick=nil
                local ok,message=P:CraftCampfireKit()
                P:Print(ok and "Making 1 Basic Campfire Kit. Use the kit on the wheel to place your fire." or message)
            end)
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            b.count=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmall");b.count:SetPoint("BOTTOMRIGHT",-2,2)
            b.foodLabel=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");b.foodLabel:SetPoint("TOP",b,"BOTTOM",0,-1);b.foodLabel:SetText("|cff72d58aFood|r")
            b.cooldown=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate");b.cooldown:SetAllPoints()
            b:SetScript("OnEnter",function(s)
                GameTooltip:SetOwner(s,"ANCHOR_RIGHT")
                if s.spellID then
                    GameTooltip:SetSpellByID(s.spellID)
                    GameTooltip:AddLine("Consumes: 1 "..P:ItemName(4470).." ("..P:Count(4470).." in bags)",1,.85,.55,true)
                    GameTooltip:AddLine("Tool: "..P:ItemName(4471).." - not consumed",1,.85,.55,true)
                    local help="Click to cast Basic Campfire."
                    if s.spellID==P.basicCampfireSpellID then
                        help=s.campAction=="craft" and "Click Make kit to craft a Basic Campfire Kit. Use the kit to place your fire." or "Click to open Cooking. Then click Make kit here to craft a Basic Campfire Kit. Use the kit to place your fire."
                    end
                    GameTooltip:AddLine(help,1,1,1,true)
                else GameTooltip:SetItemByID(s.itemID) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function()GameTooltip:Hide()end);self.campButtons[i]=b
        end
        local item=items[i]
        if item then
            local ring=math.floor((i-1)/10);local index=(i-1)%10;local slots=math.min(10,#items-ring*10)
            local angle=-math.pi/2+2*math.pi*index/slots;local radius=78+ring*54
            b:ClearAllPoints();b:SetPoint("CENTER",self.campRoot,"CENTER",math.cos(angle)*radius,-math.sin(angle)*radius)
            b.itemID=item.id;b.spellID=item.spell
            -- Pooled buttons may switch between a spell, supply and food after bag updates.
            b:SetAttribute("item",nil);b:SetAttribute("spell",nil)
            b:SetAttribute("type",nil);b.campAction=nil;b:Enable()
            local icon
            if item.spell then
                if item.spell==self.basicCampfireSpellID then
                    if self:CampCookingOpen() then b.campAction="craft"
                    else
                        local getName=C_Spell and C_Spell.GetSpellName or GetSpellInfo
                        local cooking=getName and getName(2550)
                        b.campAction="open"
                        b:SetAttribute("type",cooking and "spell" or nil);b:SetAttribute("spell",cooking)
                        b:SetEnabled(cooking~=nil)
                    end
                else
                    b.campAction="spell";b:SetAttribute("type","spell");b:SetAttribute("spell",item.spell)
                end
                local texture=C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
                icon=texture and texture(item.spell) or "Interface\\Icons\\Spell_Fire_Fire"
            else
                b.campAction="item"
                b:SetAttribute("type","item");b:SetAttribute("item","item:"..item.id)
                local getIcon=C_Item and C_Item.GetItemIconByID or GetItemIcon
                icon=getIcon and getIcon(item.id) or self.Items[item.id] and self.Items[item.id].icon or "Interface\\Icons\\INV_Misc_QuestionMark"
            end
            b:SetNormalTexture(icon)
            b.count:SetText(item.count)
            local label=b.campAction=="open" and "Cooking" or b.campAction=="craft" and "Make kit" or "Fire"
            b.foodLabel:SetText(item.spell and ("|cffffd100"..label.."|r") or "|cff72d58aFood|r")
            b.foodLabel:SetShown(item.food==true or item.spell~=nil)
            self:UpdateCampButtonCooldown(b)
            b:Show()
        else b.itemID=nil;b.spellID=nil;b.campAction=nil;b:SetAttribute("type",nil);b:SetAttribute("item",nil);b:SetAttribute("spell",nil);b.cooldown:Hide();b:Hide() end
    end
    self.campHolder.empty:SetText(#items==0 and "No camp supplies or buff food.\nBasic Campfire needs Simple Wood and Flint and Tinder in your bags." or "")
    self:ApplyCampVisibility()
end
function P:ToggleCamp()
    if InCombatLockdown() then self:Print("Camp supplies open outside combat.");return end
    self.campManualOpen=not self:CampShouldOpen();self:RefreshCamp()
end
