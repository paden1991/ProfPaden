local _,P=...
-- Add guide ranges to the native area subtitle without changing its name,
-- level colors, existing description, or higher-priority POI labels.
local hooked=setmetatable({},{__mode='k'})
function P:ZoneProfessionText(mapID)
    local ranges=self.ZoneProfessionRanges and self.ZoneProfessionRanges[mapID]
    if not ranges then return end
    local trained={};local signature={}
    for _,pr in ipairs(self.professions) do
        local name=pr[1];local skill=self.skills[name]
        if skill and (skill.rank or 0)>0 and ranges[name] then trained[#trained+1]=name;signature[#signature+1]=name end
    end
    if #trained==0 then return end
    signature=table.concat(signature,':')
    self.zoneProfessionTextCache=self.zoneProfessionTextCache or {}
    local cached=self.zoneProfessionTextCache[mapID]
    if cached and cached.signature==signature then return cached.text end
    local rows={};local line,plain,count='',0,0
    for _,name in ipairs(trained) do
        local b=ranges[name][1];local label=self:Localized(name)..' '..b[1]..'-'..b[2]
        if count>0 and (count==2 or plain+#label+5>48) then rows[#rows+1]=line;line='';plain=0;count=0 end
        line=line..(count>0 and '  /  ' or '')..label;plain=plain+#label+5;count=count+1
    end
    if line~='' then rows[#rows+1]=line end
    local text=table.concat(rows,'\n')
    self.zoneProfessionTextCache[mapID]={signature=signature,text=text};return text
end
function P:ZoneProfessionMap(map)
    if not map or not map.GetMapID then return end
    local id=map:GetMapID()
    if not id then return end
    if map.IsCanvasMouseFocus and not map:IsCanvasMouseFocus() then return end
    if self.StitchedMapAPI and self:StitchedMapAPI() then return self:StitchedHoverZone() end
    if map.GetNormalizedCursorPosition and C_Map and C_Map.GetMapInfoAtPosition then
        local x,y=map:GetNormalizedCursorPosition()
        if x and y then
            local last=self.zoneProfessionHover
            if last and last.map==id and last.x==x and last.y==y then return last.zone end
            local info=C_Map.GetMapInfoAtPosition(id,x,y)
            local zone=info and info.mapID or id
            self.zoneProfessionHover={map=id,x=x,y=y,zone=zone};return zone
        end
    end
    return id
end
function P:AttachZoneProfessionLabels()
    local map=WorldMapFrame
    if not map or not hooksecurefunc then return end
    if not self.zoneProfessionMapHooked and type(map.AddDataProvider)=='function' then
        self.zoneProfessionMapHooked=true
        hooksecurefunc(map,'AddDataProvider',function()P:AttachZoneProfessionLabels()end)
        map:HookScript('OnShow',function()P.zoneProfessionHover=nil;P:ReadSkills();P:AttachZoneProfessionLabels()end)
        if type(map.SetMapID)=='function' then hooksecurefunc(map,'SetMapID',function()P.zoneProfessionHover=nil end) end
    end
    for provider in pairs(type(map.dataProviders)=='table' and map.dataProviders or {}) do
        local label=provider.Label
        if label and type(label.SetLabel)=='function' and not hooked[label] then
            hooked[label]=true;local setting=false
            hooksecurefunc(label,'SetLabel',function(frame,kind,name,description,nameColor,descriptionColor,textureInfo)
                local areaType=MAP_AREA_LABEL_TYPE and MAP_AREA_LABEL_TYPE.AREA_NAME
                if setting or not name or not areaType or kind~=areaType then return end
                local text=P:ZoneProfessionText(P:ZoneProfessionMap(map))
                if not text then return end
                local full=description and description~='' and description..'\n'..text or text
                setting=true;frame:SetLabel(kind,name,full,nameColor,descriptionColor,textureInfo);setting=false
            end)
        end
    end
end
local events=CreateFrame('Frame');P.zoneProfessionEvents=events
events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('SKILL_LINES_CHANGED')
events:SetScript('OnEvent',function(_,event)
    if event=='SKILL_LINES_CHANGED' then P.zoneProfessionTextCache=nil;P.zoneProfessionHover=nil end
    P:AttachZoneProfessionLabels()
end)
