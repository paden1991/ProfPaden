local _,P=...
local initialized=setmetatable({},{__mode="k"})
-- Render client-resident map art. The package supplies only our separate overlays.
-- Layout follows the map API's row-major texture order and normalized map space.
function P:RenderNativeMap(frame,mapID,width,height)
    if not initialized[frame] then
        frame.nativeTiles={}
        frame.nativeMessage=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        frame.nativeMessage:SetPoint("CENTER");frame.nativeMessage:SetWidth(260)
        frame.nativeMessage:SetText("Map artwork is unavailable for this area.")
        initialized[frame]=true
    end
    for _,tile in ipairs(frame.nativeTiles) do tile:Hide() end
    frame.nativeMessage:Show();frame.nativeMapID=nil
    if not (mapID and width and height and width>0 and height>0 and C_Map
        and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return false end
    local ok,layers=pcall(C_Map.GetMapArtLayers,mapID)
    local layer=ok and layers and layers[1]
    if not layer then return false end
    local lw,lh,tw,th=layer.layerWidth,layer.layerHeight,layer.tileWidth,layer.tileHeight
    for _,n in ipairs({lw or false,lh or false,tw or false,th or false}) do
        if type(n)~="number" or n~=n or n<=0 or n==math.huge then return false end
    end
    local cols,rows=math.ceil(lw/tw),math.ceil(lh/th)
    if cols*rows>256 then return false end
    local success,textures=pcall(C_Map.GetMapArtLayerTextures,mapID,1)
    if not success or type(textures)~="table" then return false end
    -- Missing tiles must not leave an apparently complete map behind the data.
    for i=1,cols*rows do if type(textures[i])~="number" or textures[i]<=0 then return false end end
    for row=0,rows-1 do for col=0,cols-1 do
        local i=row*cols+col+1
        local tile=frame.nativeTiles[i]
        if not tile then tile=frame:CreateTexture(nil,"BACKGROUND",nil,-1);frame.nativeTiles[i]=tile end
        local cw,ch=math.min(tw,lw-col*tw),math.min(th,lh-row*th)
        tile:ClearAllPoints();tile:SetPoint("TOPLEFT",frame,"TOPLEFT",col*tw/lw*width,-row*th/lh*height)
        tile:SetSize(cw/lw*width,ch/lh*height)
        tile:SetTexture(textures[i]);tile:SetTexCoord(0,cw/tw,0,ch/th);tile:Show()
    end end
    frame.nativeMessage:Hide();frame.nativeMapID=mapID
    return true
end
