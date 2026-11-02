local _,P=...
-- Client-resident map art with separately drawn, attributed reference paths.
-- A path is a suggested circuit, never a guarantee that a node exists at a point.
function P:RefreshGatherMap(entry)
    local options=self.GatherMapOptions and self:GatherMapOptions(entry) or entry and entry.gatherBand and self.GatherVisuals and self.GatherVisuals[self.selectedProf] and self.GatherVisuals[self.selectedProf][entry.gatherBand]
    self.detailBody:ClearAllPoints()
    if not options or #options==0 then
        self.currentMap=nil;self.mapSourceURL=nil
        if self.gatherMap then self.gatherMap:Hide();self.mapChoice:Hide();self.mapCaption:Hide();self.mapOpen:Hide() end
        self.detailBody:SetPoint("TOPLEFT",0,0);return 0
    end
    if not self.gatherMap then
        local parent=self.detailChild
        local map=CreateFrame("Frame",nil,parent);map:SetPoint("TOPLEFT",0,-32);map:SetSize(350,234);map.lines={};self.gatherMap=map
        map.image=map:CreateTexture(nil,"BACKGROUND",nil,-2);map.image:SetAllPoints();map.image:SetColorTexture(.08,.09,.09,1)
        map.overlay=map:CreateTexture(nil,"ARTWORK");map.overlay:SetAllPoints()
        self.mapChoice=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");self.mapChoice:SetPoint("TOPLEFT",0,0);self.mapChoice:SetSize(252,24)
        self.mapChoice:SetScript("OnClick",function()
            if P.selected and (P.selected.gatherItem or P.selected.gatherGuide) then
                local opts=P:GatherMapMenu(P.selected)
                P:ToggleDropdown(P.mapChoice,opts,P.mapChoiceIndex,function(i)P.mapChoiceIndex=i;P:RefreshDetail()end)
            else P.mapChoiceIndex=(P.mapChoiceIndex or 1)+1;P:RefreshDetail() end
        end)
        self.mapOpen=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");self.mapOpen:SetPoint("TOPLEFT",258,0);self.mapOpen:SetSize(90,24);self.mapOpen:SetText("World map")
        self.mapOpen:SetScript("OnClick",function()
            local r=P.currentMap
            if r and r.mapId and not InCombatLockdown() then
                if P.ShowGatherWorldMap then P:ShowGatherWorldMap(r)
                elseif WorldMapFrame and WorldMapFrame.SetMapID then ShowUIPanel(WorldMapFrame);WorldMapFrame:SetMapID(r.mapId) end
            end
        end)
        self.mapCaption=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");self.mapCaption:SetPoint("TOPLEFT",0,-272);self.mapCaption:SetWidth(350);self.mapCaption:SetJustifyH("LEFT")
    end
    local key=entry.key or self.selectedProf..":"..entry.gatherBand
    if self.mapEntryKey~=key then self.mapEntryKey=key;self.mapChoiceIndex=1 end
    self.mapChoiceIndex=(self.mapChoiceIndex-1)%#options+1
    local r=options[self.mapChoiceIndex];self.currentMap=r
    self.gatherMap:Show();self.mapChoice:Show();self.mapCaption:Show();self.mapOpen:Show()
    self.mapChoice:SetText(r.zone.." ("..self.mapChoiceIndex.."/"..#options..")")
    self.mapOpen:SetEnabled(r.mapId~=nil and not InCombatLockdown())
    for _,line in ipairs(self.gatherMap.lines) do line:Hide() end
    local mapWidth=self.readableDetailWidth or 350
    local mapHeight=mapWidth*234/350
    local top=self.artisanReady and 44 or 32
    self.gatherMap:ClearAllPoints();self.gatherMap:SetPoint("TOPLEFT",0,-top);self.gatherMap:SetSize(mapWidth,mapHeight)
    local artReady=self:RenderNativeMap(self.gatherMap,r.mapId,mapWidth,mapHeight)
    self.gatherMap.overlay:SetTexture(r.overlay);self.gatherMap.overlay:SetShown(artReady and r.overlay~=nil)
    if self.Theme and self.artisanReady then
        self.Theme.Place(self.mapChoice,0,0,mapWidth-150,34);self.Theme.Button(self.mapChoice)
        self.Theme.Place(self.mapOpen,mapWidth-138,0,138,34);self.Theme.Button(self.mapOpen)
        self.Theme.Place(self.mapCaption,0,top+mapHeight+10,mapWidth);self.Theme.Font(self.mapCaption,17)
    end
    local points=r.points or {}
    for i=1,artReady and #points-1 or 0 do
        local line=self.gatherMap.lines[i]
        if not line then line=self.gatherMap:CreateLine(nil,"OVERLAY");self.gatherMap.lines[i]=line;line:SetThickness(2);line:SetColorTexture(1,.78,.16,.9) end
        line:SetStartPoint("TOPLEFT",self.gatherMap,points[i][1]*mapWidth/100,-points[i][2]*mapHeight/100)
        line:SetEndPoint("TOPLEFT",self.gatherMap,points[i+1][1]*mapWidth/100,-points[i+1][2]*mapHeight/100);line:Show()
    end
    local caption
    if entry.gatherGuide then
        caption=r.overlay and ("Blue: "..(r.target or r.label).." / "..r.zone..". Recorded locations; not live spawns.") or "Fishing area reference. Safe low-level water can still give skill-ups."
    elseif entry.gatherItem and r.zoneAggregate then
        caption="Blue: "..entry.name.." / "..r.zone.." ("..r.sourceCount..(r.sourceCount==1 and " source). " or " sources). ")..r.source..". Recorded areas; scroll for sources."
    else
        caption=r.overlay and ("Blue: "..r.label.." / "..r.source..". Recorded areas; not live spawns. Scroll for sources.") or (#points>0 and "Gold line: Classic reference circuit; Forever spawns unverified." or "Area reference only; no verified spawn or catch overlay.").." Scroll down for route notes."
    end
    self.mapCaption:SetText(caption)
    local bodyY=self.artisanReady and (top+mapHeight+20+self.mapCaption:GetStringHeight()) or 310
    self.detailBody:SetPoint("TOPLEFT",0,-bodyY)
    if r.url then self.mapSourceURL=r.url else self.mapSourceURL=nil end
    return bodyY
end
