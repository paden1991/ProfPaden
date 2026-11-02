local _,P=...
-- Optional map integration; OpenMap itself stays unmodified.
function P:StitchedMapAPI()
    local api=OpenMapAPI
    if api and api.major==1 and api.IsStitched and api.IsStitched() then return api end
end
function P:MapOverlayLevel(layer,offset)
    local map=WorldMapFrame
    local canvas=map and map.GetCanvas and map:GetCanvas()
    if not layer or not canvas then return end
    local level=(canvas:GetFrameLevel() or 0)+offset
    if self:StitchedMapAPI() and map.GetPinFrameLevelsManager then
        local manager=map:GetPinFrameLevelsManager()
        if manager and manager.GetValidFrameLevel then
            -- OpenMap inserts its terrain below this standard map layer.
            local top=manager:GetValidFrameLevel('PIN_FRAME_LEVEL_MAP_HIGHLIGHT')
            if type(top)=='number' then level=math.max(level,top+offset) end
        end
    end
    layer:SetFrameLevel(level)
end
function P:StitchedHoverZone()
    local api=self:StitchedMapAPI()
    if not api then return end
    -- The native cursor position is clamped to the host zone. OpenMap's
    -- cursor includes neighbouring zones and its gamepad cursor as well.
    local mod=OpenMap and OpenMap.GetModule and OpenMap:GetModule('worldmap')
    if mod and mod.CursorWorld and api.MapAt then
        local u,v=mod.CursorWorld()
        if type(u)=='number' and type(v)=='number' then
            local last=self.stitchedProfessionHover
            if last and last.api==api and last.u==u and last.v==v then return last.zone end
            local zone=api.MapAt(u,v)
            self.stitchedProfessionHover={api=api,u=u,v=v,zone=zone}
            return zone
        end
    end
end
function P:SetupOpenMapBridge()
    local api=OpenMapAPI
    if not api or api.major~=1 or not api.RegisterCallback or self.openMapBridgeAPI==api then return end
    self.openMapBridgeAPI=api
    local function changed()
        P.zoneProfessionHover=nil;P.stitchedProfessionHover=nil
        if WorldMapFrame and WorldMapFrame:IsShown() then P:UpdateGatherWorldMap() end
    end
    api.RegisterCallback(self,'OpenMap_StitchedChanged',changed)
    api.RegisterCallback(self,'OpenMap_ViewChanged',changed)
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent',function(_,event,name)
    if event=='PLAYER_LOGIN' or name=='OpenMap' then P:SetupOpenMapBridge() end
end)
P:SetupOpenMapBridge()
