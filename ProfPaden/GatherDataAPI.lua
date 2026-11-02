local _,P=...
-- Versioned integration boundary for a future navigation companion. These are
-- harvest/catch locations, not a walkability graph. Return detached data so a
-- planner can sort, cluster or annotate it without damaging the atlas.
P.gatherDataAPIVersion=1
function P:GetGatherNodeSets(entryKey,mapID,provider)
    local entry
    for _,list in pairs(self.GatherAtlas or {}) do
        for _,e in ipairs(list) do if e.key==entryKey then entry=e;break end end
        if entry then break end
    end
    if not entry then return {} end
    local results,seen={},{}
    for _,source in ipairs(entry.sources or {}) do
        for _,key in ipairs(source.nodeKeys or {}) do
            local area=self.GatherNodeData and self.GatherNodeData.areas[key]
            if area and area.mapId and (not mapID or area.mapId==mapID) then
                local chosen=provider or (area.sets["wowhead-pins"] and "wowhead-pins" or area.sets.questiedb and "questiedb" or area.sets.classicdb and "classicdb" or area.sets.foreverchanges and "foreverchanges" or "wowhead-grid")
                local data=area.sets[chosen];local identity=key..":"..chosen
                if data and not seen[identity] then
                    seen[identity]=true
                    local result={key=key,provider=chosen,precision=data.precision,mapId=area.mapId,area=area.area,sourceKind=area.sourceKind,sourceID=area.sourceID,
                        method=source.method,zone=area.zone,name=area.name,url=data.url,coordinateUnits="percent",walkability="unassessed",nodes={}}
                    local duplicates={}
                    for _,xy in ipairs(data.points or {}) do
                        local x,y=tonumber(xy[1]),tonumber(xy[2])
                        if x and y and x>=0 and x<=100 and y>=0 and y<=100 then
                            local id=identity..":"..tostring(x)..":"..tostring(y)
                            local n=duplicates[id]
                            if n then n.observations=n.observations+1
                            else n={id=id,x=x,y=y,observations=1};duplicates[id]=n;result.nodes[#result.nodes+1]=n end
                        end
                    end
                    if #result.nodes>0 then results[#results+1]=result end
                end
            end
        end
    end
    table.sort(results,function(a,b)return a.key<b.key end)
    -- Supplement exact existing object identities. Never infer creature drops or
    -- pool locations from an ore/herb type. Original atlas records stay first.
    if not provider or provider=="gathermate-forever" then
        local maps={}
        for id in pairs(self.GatherMateNodes or {}) do if not mapID or id==mapID then maps[#maps+1]=id end end
        table.sort(maps)
        for _,id in ipairs(maps) do
            local data=self.GatherMateNodes[id]
            for _,source in ipairs(entry.sources or {}) do
                local types=source.kind=="object" and self.GatherMateObjectTypes and self.GatherMateObjectTypes[source.id]
                for _,typ in ipairs(types or {}) do
                    local coords=data[typ];local key="gathermate-forever:"..id..":"..typ
                    if coords and not seen[key] then
                        seen[key]=true
                        local info=self.GatherMateNodeTypes[typ]
                        local result={key=key,provider="gathermate-forever",precision="0.01 percent",mapId=id,zone=self.GatherMateMapNames[id],
                            sourceKind="object",sourceID=source.id,method=source.method,name=info.name,url=source.url,
                            coordinateUnits="percent",walkability="unassessed",nodes={}}
                        for _,coord in ipairs(coords) do
                            local x=math.floor(coord/1000000)/100
                            local y=math.floor((coord%1000000)/100)/100
                            result.nodes[#result.nodes+1]={id=key..":"..coord,x=x,y=y,observations=1}
                        end
                        results[#results+1]=result
                    end
                end
            end
        end
    end
    return results
end
