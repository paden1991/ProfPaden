local _,P=...
-- Independent lightweight launchers; no shared broker library is required.
local defaults={guide=225,camp=265}
function P:PositionMinimapButton(key)
    local b=self.minimapButtons and self.minimapButtons[key];if not b then return end
    local angle=math.rad(self.char.minimapAngles[key]);local x,y=math.cos(angle),math.sin(angle)
    local rx,ry=Minimap:GetWidth()/2+8,Minimap:GetHeight()/2+8
    if GetMinimapShape and GetMinimapShape()=="SQUARE" then
        local scale=math.max(math.abs(x),math.abs(y));x=x/scale;y=y/scale
    end
    b:ClearAllPoints();b:SetPoint("CENTER",Minimap,"CENTER",rx*x,ry*y)
end
function P:DragMinimapButton(key)
    local x,y=GetCursorPosition();local scale=Minimap:GetEffectiveScale()
    local cx,cy=Minimap:GetCenter();if not cx or not cy then return end
    x=x/scale-cx;y=y/scale-cy
    if x==0 and y==0 then return end
    local angle
    if x==0 then angle=y>0 and math.pi/2 or -math.pi/2
    else angle=math.atan(y/x);if x<0 then angle=angle+math.pi end end
    self.char.minimapAngles[key]=math.deg(angle)%360;self:PositionMinimapButton(key)
end
function P:CreateMinimapButtons()
    if self.minimapButtons or not Minimap then return end
    self.char.minimapAngles=self.char.minimapAngles or {}
    self.minimapButtons={}
    for _,key in ipairs({"guide","camp"}) do
        local saved=self.char.minimapAngles[key]
        if type(saved)~="number" or saved~=saved or math.abs(saved)==math.huge then saved=defaults[key] end
        self.char.minimapAngles[key]=saved%360
        local b=CreateFrame("Button",key=="guide" and "ProfPadenGuideMinimap" or "ProfPadenCampMinimap",Minimap)
        self.minimapButtons[key]=b;b:SetSize(32,32);b:SetFrameStrata("MEDIUM");b:SetFrameLevel(Minimap:GetFrameLevel()+8)
        b:RegisterForClicks("LeftButtonUp");b:RegisterForDrag("LeftButton")
        local icon=b:CreateTexture(nil,"ARTWORK");icon:SetSize(20,20);icon:SetPoint("CENTER",0,0)
        icon:SetTexture(key=="guide" and "Interface\\Icons\\INV_Misc_Book_09" or "Interface\\Icons\\Spell_Fire_Fire")
        b.icon=icon
        local border=b:CreateTexture(nil,"OVERLAY");border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");border:SetSize(54,54);border:SetPoint("TOPLEFT",0,0)
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:SetScript("OnClick",function()if key=="guide" then P:Toggle() else P:ToggleCamp() end end)
        b:SetScript("OnDragStart",function(s)s:SetScript("OnUpdate",function()P:DragMinimapButton(key)end)end)
        b:SetScript("OnDragStop",function(s)s:SetScript("OnUpdate",nil)end)
        b:SetScript("OnHide",function(s)s:SetScript("OnUpdate",nil)end)
        b:SetScript("OnEnter",function(s)
            GameTooltip:SetOwner(s,"ANCHOR_LEFT")
            GameTooltip:SetText(key=="guide" and "ProfPaden - Profession guide" or "ProfPaden - Camp supplies")
            GameTooltip:AddLine(key=="guide" and "Click to open the guide. Drag around the minimap to move." or "Click to open or close camp supplies. Opens automatically with Campfire Nearby. Drag around the minimap to move.",1,.85,.55,true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function()GameTooltip:Hide()end)
        self:PositionMinimapButton(key)
    end
    Minimap:HookScript("OnSizeChanged",function()for key in pairs(P.minimapButtons) do P:PositionMinimapButton(key) end end)
end
