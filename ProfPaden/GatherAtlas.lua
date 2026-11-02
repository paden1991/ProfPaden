local _,P=...
P.GatherViews={{label="Guided leveling",value="guide"},{label="All gathering steps",value="guideall"},{label="Materials",value="materials"},{label="Rare / specialty",value="rare"},{label="Quest supplies",value="quests"},{label="Fishing pools",value="pools"},{label="Leveling circuits",value="routes"}}
function P:GatherView()
    local view=self.gatherView or "materials"
    if (view=="guide" or view=="guideall") and not (self.GatherGuides and self.GatherGuides[self.selectedProf]) then view="materials" end
    if view=="pools" and self.selectedProf~="Fishing" then view="materials" end
    if view=="routes" and #(self.Gathering[self.selectedProf] or {})==0 then view="materials" end
    return view
end
function P:GatherViewLabel()
    for _,v in ipairs(self.GatherViews) do if v.value==self:GatherView() then return v.label end end
end
function P:GatherOptions()
    local options={}
    for _,v in ipairs(self.GatherViews) do
        if ((v.value~="guide" and v.value~="guideall") or self.GatherGuides and self.GatherGuides[self.selectedProf]) and (v.value~="pools" or self.selectedProf=="Fishing") and (v.value~="routes" or #(self.Gathering[self.selectedProf] or {})>0) then options[#options+1]=v end
    end
    return options
end
function P:GatherEntries()
    local view=self:GatherView();if view=="guide" or view=="guideall" then return self:GatherGuideRows() end
    if view=="routes" then return nil end
    local context=self:MaterialFiltersActive() and self:MaterialFilterContext()
    self.materialListTotal=0
    local rows={};local search=(self.gatherSearch or ""):lower():match("^%s*(.-)%s*$")
    for _,e in ipairs(self.GatherAtlas[self.selectedProf] or {}) do
        local include=view=="materials" and not e.pool or view=="rare" and e.rare or view=="quests" and e.questSupply or view=="pools" and e.pool
        if include then
            self.materialListTotal=self.materialListTotal+1
            if (search=="" or e.searchText:find(search,1,true) or tostring(e.item or ""):find(search,1,true)) and (not context or self:MaterialMatchesFilters(e,context)) then rows[#rows+1]=e end
        end
    end
    table.sort(rows,function(a,b)
        local _,ag=self:MaterialGroup(a);local _,bg=self:MaterialGroup(b)
        if (ag or 9999)~=(bg or 9999) then return (ag or 9999)<(bg or 9999) end
        if self.selectedProf=="Herbalism" then
            local ao,bo=self:GatherSkillOptions(a),self:GatherSkillOptions(b)
            local ar=ao[1] and ao[1].thresholds.orange or (self.MaterialSkillRanges[a.key] or {}).first or 9999
            local br=bo[1] and bo[1].thresholds.orange or (self.MaterialSkillRanges[b.key] or {}).first or 9999
            if ar~=br then return ar<br end
        end
        if a.name~=b.name then return a.name<b.name end
        return a.key<b.key
    end)
    return rows
end
function P:GatherMapOptions(entry)
    if entry and entry.gatherGuide then return self:GatherGuideMaps(entry) end
    if not entry or not entry.gatherItem then return nil end
    local options={}
    local zones=self.GatherZoneMaps and self.GatherZoneMaps[entry.key]
    if zones then
        for _,key in ipairs(zones) do if self.GatherZoneAreas[key] then options[#options+1]=self.GatherZoneAreas[key] end end
        return options
    end
    for _,key in ipairs(entry.mapKeys or {}) do if self.GatherAreas[key] then options[#options+1]=self.GatherAreas[key] end end
    return options
end
function P:GatherMapMenu(entry)
    local order={}
    for i,r in ipairs(self:GatherMapOptions(entry) or {}) do
        order[#order+1]={label=r.zone..(entry.gatherGuide and r.target and (" / "..r.target) or ""),value=i}
    end
    -- The shared dropdown has fixed-height rows, so bound every menu to ten.
    local function pages(list,label)
        if #list<=10 then return list end
        local groups={}
        for start=1,#list,10 do
            local children={};for i=start,math.min(start+9,#list) do children[#children+1]=list[i] end
            groups[#groups+1]={label=label.." "..start.."-"..math.min(start+9,#list),children=children}
        end
        return pages(groups,label)
    end
    return pages(order,"Zones")
end
function P:GatherItemLink(id,name)
    name=name or self.GatherItemNames[id] or self:ItemName(id)
    return "|cff78c8ff|Hitem:"..id.."|h["..name.."]|h|r"
end
function P:MaterialUsageRows(entry)
    local uses=self.GatherMaterialUses and self.GatherMaterialUses[entry.key] or {}
    if #uses==0 then return {} end
    if self.materialUseKey~=entry.key then self.materialUseKey=entry.key;self.materialUsePage=1 end
    local pages=math.ceil(#uses/8);local page=math.max(1,math.min(pages,self.materialUsePage or 1));self.materialUsePage=page
    local rows={{cells={"USED IN "..self.selectedProf:upper().." / "..#uses..(#uses==1 and " RECIPE" or " RECIPES")},widths={350},heading=true},
        {cells={"Recipe","Skill","Per craft"},widths={236,50,64},heading=true}}
    for i=(page-1)*8+1,math.min(page*8,#uses) do
        local r=uses[i]
        rows[#rows+1]={cells={"|cff78c8ff|Hprofpaden:recipe:"..r.spell.."|h"..r.name.."|h|r",tostring(r.learn or "-"),tostring(r.count)},widths={236,50,64}}
    end
    if pages>1 then
        local back=page>1 and "|cff78c8ff|Hprofpaden:uses:"..(page-1).."|h< Back|h|r" or ""
        local next=page<pages and "|cff78c8ff|Hprofpaden:uses:"..(page+1).."|hNext >|h|r" or ""
        rows[#rows+1]={cells={back,"Page "..page.." / "..pages,next},widths={115,120,115}}
    end
    return rows
end
function P:OpenMaterialRecipe(spell)
    local uses=self.selected and self:MaterialPreparationUses(self.selected) or {}
    for _,r in ipairs(uses) do if r.spell==spell then
        self:CloseDropdown();self.tab="Catalog";self.catalogSearch=tostring(spell);self.catalogFilter="all";self.catalogFacets={}
        self.offset=0;self.selectedKey="catalog:s"..spell;self:Refresh();return true
    end end
    return false
end
function P:GatherDisplaySources(entry)
    local all=entry.sources or {}
    if not (entry.dropCoverage or entry.skinReferenceCount) or #all<=20 then return all,1,#all,1,nil end
    local map=self.currentMap
    local scoped=map and self.gatherSourceScope~="all"
    local key=entry.key..":"..tostring(scoped and map.mapId or "all")
    if self.gatherSourceKey~=key then self.gatherSourceKey=key;self.gatherSourcePage=1 end
    local sources={}
    for _,s in ipairs(all) do
        local include=not scoped
        if scoped then
            for _,k in ipairs(s.mapKeys or {}) do
                local a=self.GatherAreas[k]
                if a and a.mapId==map.mapId then include=true;break end
            end
            if not include then
                for _,zone in ipairs(s.zones or {}) do if zone:lower()==map.zone:lower() then include=true;break end end
            end
        end
        if include then sources[#sources+1]=s end
    end
    local pages=math.max(1,math.ceil(#sources/20))
    local page=math.max(1,math.min(pages,self.gatherSourcePage or 1));self.gatherSourcePage=page
    return sources,(page-1)*20+1,math.min(page*20,#sources),pages,scoped and map.zone or "All zones"
end
function P:GatherSourcePageRows(page,pages)
    if pages<=1 then return nil end
    local back=page>1 and "|cff78c8ff|Hprofpaden:sources:"..(page-1).."|h< Back|h|r" or ""
    local next=page<pages and "|cff78c8ff|Hprofpaden:sources:"..(page+1).."|hNext >|h|r" or ""
    return {cells={back,"Page "..page.." / "..pages,next},widths={115,120,115}}
end
-- Group only the presentation. Each original record keeps its own locations,
-- provenance and reported rate in the disclosure; rates are never aggregated.
function P:GatherSourceGroups(entry,sources,first,last,scope)
    local key=tostring(entry.key)..":"..tostring(self.currentMap and self.currentMap.mapId)..":"..tostring(scope)..":"..first
    if self.gatherSourceDetailKey~=key then
        self.gatherSourceDetailKey=key;self.gatherSourceExpanded={}
    end
    local groups,byKey={},{}
    for i=first,last do
        local s=sources[i]
        local identity=table.concat({s.kind or "",s.kind=="npc" and tostring(s.id) or s.name or "",s.method or "",tostring(s.viaItem or "")},"\031")
        local group=byKey[identity]
        if not group then
            group={source=s,records={},zones={},zoneSeen={}}
            byKey[identity]=group;groups[#groups+1]=group
        end
        group.records[#group.records+1]=s
        for _,zone in ipairs(s.zones or {}) do
            local z=zone:lower()
            if not group.zoneSeen[z] then group.zoneSeen[z]=true;group.zones[#group.zones+1]=zone end
        end
    end
    self.gatherSourceGroups=groups
    return groups
end
function P:ToggleGatherSourceGroup(index)
    if not (self.selected and self.selected.gatherItem and self.gatherSourceGroups and self.gatherSourceGroups[index]) then return end
    self.gatherSourceExpanded[index]=not self.gatherSourceExpanded[index]
    self:RefreshDetail()
end
function P:GatherDetailRows(entry)
    local rows={};local hasRate=false
    local function add(a,b,heading)rows[#rows+1]={cells=b and {a,b} or {a},widths=b and {92,258} or {350},heading=heading}end
    if entry.item then add("Item / bags",self:GatherItemLink(entry.item,entry.name).."  x"..self:Count(entry.item)) end
    if entry.yields and #entry.yields>0 then
        add("POOL CATCHES",nil,true)
        for _,id in ipairs(entry.yields) do add("Catch",self:GatherItemLink(id)) end
    end
    if entry.contents and #entry.contents>0 then
        add("POSSIBLE CONTENTS",nil,true)
        for _,id in ipairs(entry.contents) do add("Contains",self:GatherItemLink(id)) end
    end
    if entry.containers then
        for _,id in ipairs(entry.containers) do add("Open clam",self:GatherItemLink(id)) end
    end
    if entry.note then add(entry.note) end
    for _,row in ipairs(self:MaterialAcquisitionRows(entry)) do rows[#rows+1]=row end
    for _,row in ipairs(self:MaterialUsageRows(entry)) do rows[#rows+1]=row end
    local displaySources,sourceStart,sourceEnd,sourcePages,sourceScope=self:GatherDisplaySources(entry)
    if #(entry.sources or {})>0 then
        add("SOURCES",nil,true)
        if entry.dropCoverage then
            local c=entry.dropCoverage
            if c.currentCount>0 then add(c.currentCount.." published drop entries checked: "..c.captured..". Wowhead rates pool seasons.") end
            if c.capped then add("The published table stops at 200 results. Labeled reference sources supplement it.") end
            if c.totalCount>c.currentCount then add("Older/reference sources remain labeled; missing rates are not guessed.") end
        end
        if sourceScope then
            local mode=sourceScope=="All zones" and "map" or "all"
            local label=mode=="all" and "Show all zones" or "Use selected map"
            add(sourceScope..": "..#displaySources.." sources. |cff78c8ff|Hprofpaden:sourcescope:"..mode.."|h"..label.."|h|r")
            local nav=self:GatherSourcePageRows(self.gatherSourcePage,sourcePages);if nav then rows[#rows+1]=nav end
        end
        if entry.skinReferenceCount then add(entry.skinReferenceCount.." additional Classic reference sources; their yields are unverified in Forever.") end
        if entry.sourceCoverage and entry.sourceCoverage.count then
            local c=entry.sourceCoverage
            add(c.count.." "..(c.method=="Skin" and "skinning" or "loot").." sources checked: "..c.captured.." (Wowhead Forever).")
            if #entry.sources>c.count then add("Additional previously recorded sources are retained.") end
        end
        rows[#rows+1]={cells={"Source","Method","Locations"},widths={160,55,135},heading=true}
    end
    local groups=self:GatherSourceGroups(entry,displaySources,sourceStart,sourceEnd,sourceScope)
    for index,group in ipairs(groups) do
        local s=group.source
        local name=s.kind=="npc" and self:NPCLink(s.id,true) or s.name
        if s.viaItem then name=name.."\nvia "..self:GatherItemLink(s.viaItem) end
        local locations=#group.zones==1 and group.zones[1] or #group.zones>1 and (#group.zones.." locations") or "Unrecorded"
        local expanded=self.gatherSourceExpanded[index]
        rows[#rows+1]={cells={name,s.method,locations},widths={160,55,135},sourceGroup=index,sourceAction=expanded and "Hide details" or "Details"}
        if expanded then
            rows[#rows+1]={cells={"Location / source record","Reported"},widths={282,68},heading=true}
            for record,s in ipairs(group.records) do
                if s.rate and s.rate~="-" then hasRate=true end
                local detail=table.concat(s.zones or {},", ")
                if detail=="" then detail="Location unrecorded" end
                if #group.records>1 then detail="Record "..record.." · "..detail end
                if s.level then detail=detail.."\nLv "..s.level end
                if s.provenance then detail=detail.."\n"..s.provenance end
                if s.reportedBy then detail=detail.." / "..s.reportedBy end
                if s.reportedAt then detail=detail.." / "..s.reportedAt end
                rows[#rows+1]={cells={detail,s.rate and s.rate~="-" and (s.rate.."%") or "-"},widths={282,68}}
            end
        end
    end
    if sourceScope then local nav=self:GatherSourcePageRows(self.gatherSourcePage,sourcePages);if nav then rows[#rows+1]=nav end end
    if #(entry.sources or {})==0 and entry.dropResearch then
        local r=entry.dropResearch
        if r.status=='Item page unavailable' then
            add('Source page unavailable when checked '..r.captured..'. Game availability is unconfirmed.')
        else
            add('No creature-drop table published when checked '..r.captured..'. Other acquisition methods may apply.')
        end
    end
    if entry.sourceCoverage and entry.sourceCoverage.unavailable then
        add("No acquisition table published on Wowhead Forever as of "..entry.sourceCoverage.captured..". Sources are not yet confirmed.")
    elseif #(entry.sources or {})==0 and not self:VendorSupply(entry.item) and not self.ReagentVendors[entry.item] and not (self.MaterialDisenchant and self.MaterialDisenchant[entry.item]) and #(self.MaterialCrafts and self.MaterialCrafts[entry.key] or {})==0 then add("Acquisition details: open the item source below.") end
    if hasRate then rows[#rows+1]={cells={"Reported sample rates; multiple materials can drop together."},widths={350},muted=true} end
    return rows
end
-- One texture on the map canvas, updated only on selection/map/show events.
-- Historical areas are deliberately separate from live NodeSight detections.
function P:UpdateGatherWorldMap()
    local overlay=self.gatherWorldOverlay;local r=self.gatherWorldArea
    if not overlay then return end
    local map=WorldMapFrame
    local show=r and map and map:GetMapID()==r.mapId
    local api=self.StitchedMapAPI and self:StitchedMapAPI()
    local x0,y0,x1,y1
    if r and api then
        show=false
        if api.WorldFromMap and api.MapFromWorld then
            local u0,v0=api.WorldFromMap(r.mapId,0,0)
            local u1,v1=api.WorldFromMap(r.mapId,1,1)
            if u0 and u1 then
                x0,y0=api.MapFromWorld(map:GetMapID(),u0,v0)
                x1,y1=api.MapFromWorld(map:GetMapID(),u1,v1)
                show=type(x0)=='number' and type(y0)=='number' and type(x1)=='number' and type(y1)=='number'
                    and x0==x0 and y0==y0 and x1==x1 and y1==y1 and x1>x0 and y1>y0
            end
        end
    end
    overlay:SetShown(show and true or false)
    if show then
        overlay:SetTexture(r.overlay)
        overlay:ClearAllPoints()
        if api then
            local canvas=map:GetCanvas();local w,h=canvas:GetWidth(),canvas:GetHeight()
            overlay:SetPoint('TOPLEFT',self.gatherWorldLayer,'TOPLEFT',x0*w,-y0*h)
            overlay:SetPoint('BOTTOMRIGHT',self.gatherWorldLayer,'TOPLEFT',x1*w,-y1*h)
        else overlay:SetAllPoints(self.gatherWorldLayer) end
        if self.MapOverlayLevel then self:MapOverlayLevel(self.gatherWorldLayer,1) end
    end
    if self.gatherWorldClear then self.gatherWorldClear:SetShown(r~=nil) end
end
function P:ClearGatherWorldMap()
    self.gatherWorldArea=nil;self:UpdateGatherWorldMap()
end
function P:ShowGatherWorldMap(area)
    if not area or not area.mapId or InCombatLockdown() then return end
    if not WorldMapFrame then
        local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
        if load then pcall(load,"Blizzard_WorldMap") end
    end
    if not WorldMapFrame or not WorldMapFrame.SetMapID then return end
    if not self.gatherWorldOverlay and WorldMapFrame.GetCanvas then
        local canvas=WorldMapFrame:GetCanvas()
        if canvas then
            -- Map artwork lives in child frames at the canvas level. Use a
            -- higher, non-interactive child so tiles cannot cover the mask.
            local layer=CreateFrame("Frame",nil,canvas);layer:SetAllPoints(canvas)
            layer:SetFrameLevel((canvas:GetFrameLevel() or 0)+1);layer:EnableMouse(false)
            self.gatherWorldLayer=layer
            self.gatherWorldOverlay=layer:CreateTexture(nil,"ARTWORK",nil,1)
            self.gatherWorldOverlay:SetAllPoints(layer)
            local clear=CreateFrame("Button",nil,WorldMapFrame,"UIPanelButtonTemplate")
            clear:SetPoint("BOTTOM",WorldMapFrame,"BOTTOM",0,5);clear:SetSize(172,24);clear:SetText("Clear gathering area")
            clear:SetScript("OnClick",function()P:ClearGatherWorldMap()end);self.gatherWorldClear=clear
            if hooksecurefunc then hooksecurefunc(WorldMapFrame,"SetMapID",function()P:UpdateGatherWorldMap()end) end
            WorldMapFrame:HookScript("OnShow",function()P:UpdateGatherWorldMap()end)
            layer:SetScript("OnSizeChanged",function()P:UpdateGatherWorldMap()end)
        end
    end
    self.gatherWorldArea=area.overlay and area or nil
    ShowUIPanel(WorldMapFrame);WorldMapFrame:SetMapID(area.mapId);self:UpdateGatherWorldMap()
end
