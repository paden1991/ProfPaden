local _,P=...
local function friendly(n)
    local faction=UnitFactionGroup("player")
    return not n.faction or n.faction=="" or n.faction=="AH" or n.faction==(faction=="Alliance" and "A" or "H")
end
function P:RememberNPC()
    local guid=UnitGUID and UnitGUID("npc");local id=guid and tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    local map=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos=map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map,"player")
    if not id or not pos then return id end
    local old=self.NPCSources[id]
    local npc={id=id,name=UnitName("npc"),faction=UnitFactionGroup("player")=="Alliance" and "A" or "H",cap=old and old.cap,
        title=old and old.title or "Visited NPC",source="Visited NPC",points={{map=map,x=pos.x or pos:GetX(),y=pos.y or pos:GetY(),zone=GetRealZoneText()}}}
    self.char.npcLocations=self.char.npcLocations or {};self.char.npcLocations[id]=npc;self.NPCSources[id]=npc
    return id
end
function P:WorldPoint(point)
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    local ok,continent,position=pcall(C_Map.GetWorldPosFromMapPos,point.map,CreateVector2D(point.x,point.y))
    if ok and position then local x,y=position:GetXY();return continent,x,y end
end
local pointWorldCache=setmetatable({},{__mode="k"})
local function npcWorldPoint(self,point)
    local cached=pointWorldCache[point]
    if cached and cached.map==point.map and cached.px==point.x and cached.py==point.y then return cached.c,cached.x,cached.y end
    local c,x,y=self:WorldPoint(point)
    if x and y then pointWorldCache[point]={map=point.map,px=point.x,py=point.y,c=c,x=x,y=y} end
    return c,x,y
end
function P:NearestNPC(ids,cap,allowHostile)
    local map=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos=map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map,"player")
    local player=pos and {map=map,x=pos.x or pos:GetX(),y=pos.y or pos:GetY()}
    local pc,px,py;if player then pc,px,py=self:WorldPoint(player) end
    local best,score
    for _,id in ipairs(ids or {}) do
        local n=self.NPCSources[id]
        if n and (allowHostile or friendly(n)) and (not cap or ((self.TrainingCaps or {})[id] or n.cap or 0)>=cap) then
            local points=n.points or {}
            if #points==0 then points=n.entrances or {} end
            for _,point in ipairs(points) do
                local distance,comparable=math.huge,false
                local c,x,y=npcWorldPoint(self,point)
                if px and x and pc==c then distance=(px-x)^2+(py-y)^2;comparable=true
                elseif player and map==point.map then distance=((player.x-point.x)^2+(player.y-point.y)^2)*100000000;comparable=true end
                if not best or distance<score then
                    best={npc=n,point=point,comparable=comparable};score=distance
                end
            end
        end
    end
    return best
end
function P:NPCLink(id,allowHostile)
    local n=self.NPCSources[id];if not n then return "NPC "..id end
    return "|cff78c8ff|Hprofpaden:npc:"..id..(allowHostile and ":drop" or "").."|h["..n.name.."]|h|r"
end
function P:NPCSourceText(id,allowHostile)
    local n=self.NPCSources[id]
    if not n then return "NPC "..id end
    -- Display source locations even for an opposing-faction vendor; directions
    -- remain limited to friendly services or explicitly selected drop targets.
    local target=self:NearestNPC({id},nil,true)
    local name=target and (allowHostile or friendly(n)) and self:NPCLink(id,allowHostile) or n.name
    if target then
        local p=target.point
        return name.."\n"..(p.entrance and p.entrance.."\nEntrance: " or "")..p.zone..string.format(" %.1f, %.1f",p.x*100,p.y*100)
    end
    local locations=n.locations or {}
    return name..(#locations>0 and "\n"..table.concat(locations,", ") or "")
end
-- Match only waypoints we placed; never clear another addon's/player's pin.
function P:NavigationPinMatches(pin,point)
    if not pin or not point or pin.uiMapID~=point.map or not pin.position then return false end
    local pos=pin.position;local x,y=pos.x,pos.y
    if (x==nil or y==nil) and type(pos.GetXY)=="function" then x,y=pos:GetXY() end
    return type(x)=="number" and type(y)=="number" and math.abs(x-point.x)<.00001 and math.abs(y-point.y)<.00001
end
function P:IsNavigationEnabled()
    if not self.char then return true end
    if self.char.navigationEnabled~=nil then return self.char.navigationEnabled end
    return self.char.autoRouteArrows~=false -- Respect the previous saved switch.
end
function P:NodeNavigationBlocked()
    return not self:IsNavigationEnabled() or self.nodeNavigationDismissed or self.navTarget~=nil
end
P.navigationCompanions={}
function P:DismissNavigation()
    self.dismissedRouteKey=self.navRouteKey or self.dismissedRouteKey
    -- Stop producers before removing their pins, including routes waiting for entry.
    self.nodeNavigationDismissed=true
    local function stopCompanion(stop)
        local ok,err=pcall(stop)
        if not ok then self:Print("Navigation cleanup: "..tostring(err)) end
    end
    -- A scanner may have saved the walking pin. Release it while navTarget
    -- still identifies that pin, before the walking companion clears its target.
    if self.navigationCompanions.NodeSight then stopCompanion(self.navigationCompanions.NodeSight) end
    for owner,stop in pairs(self.navigationCompanions) do
        if owner~="NodeSight" then stopCompanion(stop) end
    end
    self:ClearNavigation()
end
function P:SetNavigationEnabled(enabled)
    if not self.char then return end
    self.char.navigationEnabled=enabled==true
    self.char.autoRouteArrows=enabled==true
    if enabled then
        self.dismissedRouteKey=nil;self.nodeNavigationDismissed=nil
    else self:DismissNavigation() end
    if self.window and self.window:IsShown() then self:Refresh() end
end
function P:ClearNavigationPins()
    local t=self.navTarget
    self.ownedTomTom=self.ownedTomTom or {}
    if self.tomtomPoint then self.ownedTomTom[self.tomtomPoint]=true;self.tomtomPoint=nil end
    if TomTom and TomTom.RemoveWaypoint then
        for uid in pairs(self.ownedTomTom) do
            -- A third-party error must not strand the native pin or stop a route.
            if pcall(TomTom.RemoveWaypoint,TomTom,uid) then self.ownedTomTom[uid]=nil end
        end
    end
    if t and t.mapPin and C_Map and C_Map.GetUserWaypoint and C_Map.ClearUserWaypoint and self:NavigationPinMatches(C_Map.GetUserWaypoint(),t.point) then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(false) end
        C_Map.ClearUserWaypoint()
    end
    if t then t.mapPin=false end
end
function P:ClearNavigation()
    self:ClearNavigationPins()
    self.navTarget=nil;self.navRouteKey=nil;self.navGoal=nil
    if self.navigationArrow then self.navigationArrow:Hide() end
end
function P:TrackNPC(id,allowHostile,goal)
    if not self:IsNavigationEnabled() then self:Print("Tracking is off. Enable Tracking above or use /pp tracking on.");return false end
    local target=self:NearestNPC({id},nil,allowHostile)
    if not target then self:Print("No friendly location recorded for this NPC.");return false end
    return self:TrackNavigationTarget(target,goal)
end
function P:SourceLocationText(key,item)
    local location=self.SourceLocations and self.SourceLocations[key]
    if not location then return end
    local p=location.point
    return "|cff78c8ff|Hprofpaden:place:"..key..":"..tostring(item or 0).."|h"..location.name.."|h|r\n"..p.zone..string.format(" %.1f, %.1f",p.x*100,p.y*100)
end
function P:TrackSourceLocation(key,item)
    local location=self.SourceLocations and self.SourceLocations[key]
    if not location then return false end
    item=tonumber(item)
    return self:TrackNavigationTarget({npc={name=location.name},point=location.point},item and item>0 and {kind="item",item=item,target=self:Count(item)+1} or nil)
end
function P:TrackPoint(point,label,owner)
    if not point or not point.map or not point.x or not point.y or point.x<0 or point.x>1 or point.y<0 or point.y>1 then return false end
    return self:TrackNavigationTarget({npc={name=label or "Gathering route"},point={map=point.map,x=point.x,y=point.y,zone=point.zone or ""},owner=owner,arrivalRadius=point.arrivalRadius})
end
function P:TrackNavigationTarget(target,goal)
    if not self:IsNavigationEnabled() then return false end
    -- Release the embedded scanner's temporary pin before taking navigation over.
    if self.navigationCompanions.NodeSight then self.navigationCompanions.NodeSight() end
    self:ClearNavigation();self.navTarget=target;self.navGoal=goal
    local p=target.point
    if C_Map and C_Map.SetUserWaypoint and UiMapPoint and
        (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(p.map)) then
        local point=UiMapPoint.CreateFromCoordinates(p.map,p.x,p.y)
        local ok=pcall(C_Map.SetUserWaypoint,point)
        target.mapPin=ok
        if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
    if TomTom and TomTom.AddWaypoint then
        local ok,uid=pcall(TomTom.AddWaypoint,TomTom,p.map,p.x,p.y,{title=target.npc.name,persistent=false,minimap=true,world=true})
        if ok then self.tomtomPoint=uid end
    end
    if not self.navigationArrow then
        local f=CreateFrame("Button","ProfPadenNavigation",UIParent);self.navigationArrow=f
        f:SetFrameStrata("DIALOG")
        f:SetSize(44,44);f:SetPoint("TOP",UIParent,"TOP",100,-170);f:SetMovable(true);f:SetClampedToScreen(true);f:EnableMouse(true)
        f:RegisterForDrag("LeftButton");f:RegisterForClicks("RightButtonUp")
        f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
        f:SetScript("OnClick",function()P:DismissNavigation()end)
        f.icon=f:CreateTexture(nil,"ARTWORK");f.icon:SetAllPoints();f.icon:SetAtlas("MiniMap-QuestArrow")
        f.text=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");f.text:SetPoint("TOP",f,"BOTTOM",0,-4);f.text:SetWidth(250)
        local elapsed,routeElapsed=0,0
        f:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt;routeElapsed=routeElapsed+dt
            if elapsed<.2 then return end;elapsed=0
            if P:CheckNavigationCompletion() then return end
            if routeElapsed>=5 then routeElapsed=0;if P.navRouteKey and P.UpdateRouteNavigation then P:UpdateRouteNavigation() end end
            P:UpdateNavigation()
        end)
    end
    if self:CheckNavigationCompletion() then return false end
    self.navigationArrow:Show();self:UpdateNavigation()
    return true
end
function P:UpdateNavigation()
    local t=self.navTarget;local f=self.navigationArrow;if not t or not f then return end
    local p=t.point;local map=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local here=map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map,"player")
    t.label=t.label or t.npc.name.."\n"..(p.entrance and p.entrance.." entrance\n" or "")..p.zone..string.format(" %.1f, %.1f",p.x*100,p.y*100)
    local label=t.label
    if map==p.map and here and C_Map.GetMapWorldSize then
        if not t.mapWidth or not t.mapHeight then t.mapWidth,t.mapHeight=C_Map.GetMapWorldSize(map) end
        local width,height=t.mapWidth,t.mapHeight
        if width and height then
            local dx=(p.x-(here.x or here:GetX()))*width;local dy=(p.y-(here.y or here:GetY()))*height
            local distance=math.sqrt(dx*dx+dy*dy)
            -- Arrival clears only our pins. Buying/training is a separate goal;
            -- retain it so reaching a supplier never counts as a purchase.
            if distance<=(t.arrivalRadius or 10) and not t.arrived then
                self:ClearNavigationPins();t.arrived=true
            end
            local facing=GetPlayerFacing and GetPlayerFacing()
            if facing then f.icon:SetRotation(-math.atan2(dx,-dy)-facing);f.icon:Show() else f.icon:Hide() end
            label=label.."\n"..(distance<10 and "Arrived" or math.floor(distance).." yd").." - Right-click: dismiss"
        end
    else f.icon:Hide();label=label.."\nTravel to this zone"..(t.mapPin and " - Map pin set" or "") end
    if f.lastLabel~=label then f.lastLabel=label;f.text:SetText(label) end
end
function P:NextProfessionRank(prof,cap)
    local rank=({[75]={50,150,"Journeyman",10},[150]={125,225,"Expert",20},[225]={200,300,"Artisan",35}})[cap]
    if not rank then return end
    if prof=="Skinning" or prof=="Mining" or prof=="Herbalism" then rank[4]=1 end
    if prof=="First Aid" and cap<225 then rank[4]=1 end
    if (prof=="Cooking" or prof=="First Aid" or prof=="Fishing") and cap==225 then rank[1]=225 end
    return rank
end
function P:TrainingStop(recipe)
    local prof=self.selectedProf;local skill=self.skills[prof];if not skill then return end
    local nextRank=self:NextProfessionRank(prof,skill.cap)
    local needsRank=nextRank and (skill.rank>=nextRank[1] or recipe and recipe.stop and recipe.stop>=nextRank[1])
    local book=({Cooking=16072,["First Aid"]=16084,Fishing=16083})[prof]
    if book and skill.cap==150 and needsRank then
        local ids={}
        for _,s in ipairs((self.ItemMeta[book] or {}).sources or {}) do if s.kind=="Vendor" and s.npc then ids[#ids+1]=s.npc end end
        return "At skill 125: "..self:ItemName(book)..(nextRank[4]>1 and " (level "..nextRank[4]..")" or ""),self:NearestNPC(ids),"Book vendor"
    elseif book and skill.cap==225 and needsRank then
        local ids=prof=="Cooking" and {8125} or prof=="Fishing" and {12919} or UnitFactionGroup("player")=="Alliance" and {12939} or {12920}
        return "At skill 225 (level 35), Artisan quest: "..(prof=="Cooking" and "Clamlette Surprise" or prof=="Fishing" and "Nat Pagle, Angler Extreme" or "Triage"),self:NearestNPC(ids),"Quest"
    end
    local label
    if needsRank then label="At skill "..nextRank[1]..": "..nextRank[3]..(nextRank[4]>1 and " (level "..nextRank[4]..")" or "")
    elseif recipe and not recipe.live and not recipe.cached and (recipe.sourceKind=="trainer" or recipe.planTraining and recipe.planTraining>0) then label="Learn this recipe" end
    if not label then return end
    local ids=self.TrainerNPCs[prof]
    if needsRank then
        local teaching={}
        for _,id in ipairs(ids or {}) do
            local cap=(self.TrainingCaps or {})[id] or (self.NPCSources[id] or {}).cap
            if cap==nextRank[2] or (prof=="Skinning" or prof=="Mining" or prof=="Herbalism") and cap and cap>=nextRank[2] or (prof=="Cooking" or prof=="First Aid" or prof=="Fishing") and cap==150 then teaching[#teaching+1]=id end
        end
        ids=(self.RankTrainerNPCs and self.RankTrainerNPCs[prof] and self.RankTrainerNPCs[prof][nextRank[2]]) or teaching
    end
    if not needsRank and recipe and self.RouteTrainer then
        local observed=self:RouteTrainer(recipe);if observed then return label,observed end
    end
    local requiredCap=not needsRank and recipe and math.min(300,math.max(75,math.ceil((recipe.learn or recipe.required or 1)/75)*75))
    return label,self:NearestNPC(ids,needsRank and nextRank[2] or requiredCap)
end
