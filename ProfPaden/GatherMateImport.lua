local _,P=...
-- Optional, read-only integration. No GatherMate records are distributed or saved
-- by ProfPaden. The installed Forever addons remain the source of this data.
P.GatherMateNodes={};P.GatherMateNodeTypes={};P.GatherMateObjectTypes={};P.GatherMateMapNames={}
P.gatherMateImportStatus='not loaded'
local rawMine,rawHerb,queued,loading,subscribed
local function library(name)
    if not LibStub then return end
    local ok,lib=pcall(LibStub,name,true);if ok then return lib end
end
local function locale(name)
    local ace=library('AceLocale-3.0');if not ace then return end
    local ok,value=pcall(ace.GetLocale,ace,name,true)
    if ok and type(value)=='table' then return value end
end
local function compatible(name)
    if not C_AddOns or not C_AddOns.GetAddOnMetadata then return false end
    local ok,value=pcall(C_AddOns.GetAddOnMetadata,name,'Interface')
    if not ok or type(value)~='string' then return false end
    for number in value:gmatch('%d+') do
        local n=tonumber(number);if n>=16000 and n<16100 then return true end
    end
    return false
end
local function forever()
    if not GetBuildInfo then return false end
    local _,_,_,interface=GetBuildInfo()
    return type(interface)=='number' and interface>=16000 and interface<16100
end
local schedule
function P:ImportGatherMateNodes()
    if loading then return end
    local gm=GatherMate2
    if not forever() or not compatible('GatherMate2') or type(gm)~='table' or type(gm.nodeIDs)~='table' then
        self.gatherMateImportStatus='GatherMate2 for Forever not loaded';return
    end
    -- Do not enable disabled addons or load anything during combat.
    if InCombatLockdown and InCombatLockdown() then
        self.gatherMateImportStatus='waiting for combat to end';return
    end
    local hasData=compatible('GatherMate2_Data')
    if hasData and C_AddOns.LoadAddOn then
        loading=true
        local ok,loaded,reason=pcall(C_AddOns.LoadAddOn,'GatherMate2_Data')
        loading=false
        self.gatherMateDataLoadReason=not ok and 'load failed' or (not loaded and reason or nil)
    end
    if hasData then
        if type(GatherMateData2MineDB)=='table' then rawMine=GatherMateData2MineDB end
        if type(GatherMateData2HerbDB)=='table' then rawHerb=GatherMateData2HerbDB end
    end
    local nodes,types,objects,maps={},{},{},{}
    for _,area in pairs(self.GatherAreas or {}) do if area.mapId then maps[area.mapId]=area.zone end end
    local translations,vanilla=locale('GatherMate2Nodes'),locale('GatherMate2NodesVanilla')
    for _,entries in pairs(self.GatherAtlas or {}) do for _,entry in ipairs(entries) do
        for _,source in ipairs(entry.sources or {}) do
            if source.kind=='object' and source.id and type(source.name)=='string' then
                for _,category in ipairs({'Mining','Herb Gathering'}) do
                    local lookup=gm.nodeIDs[category]
                    local name=source.name
                    local translated=vanilla and vanilla[name] or translations and translations[name]
                    if type(translated)~='string' then translated=name end
                    local typ=type(lookup)=='table' and (lookup[translated] or lookup[name])
                    if type(typ)=='number' then
                        types[typ]={name=name,category=category}
                        objects[source.id]=objects[source.id] or {}
                        local found=false;for _,v in ipairs(objects[source.id]) do if v==typ then found=true end end
                        if not found then table.insert(objects[source.id],typ) end
                    end
                end
            end
        end
    end end
    local seen,count={},0
    local function import(db,category)
        if type(db)~='table' then return end
        for map,records in pairs(db) do
            if maps[map] and type(records)=='table' then
                for coord,oldType in pairs(records) do
                    local typ=type(oldType)=='number' and (gm.nodeIDReplacementMap and gm.nodeIDReplacementMap[oldType] or oldType)
                    if types[typ] and types[typ].category==category and type(coord)=='number' and coord==coord and coord>=0 and coord<10000000000 and coord==math.floor(coord) then
                        local x,y=math.floor(coord/1000000),math.floor(coord%1000000/100)
                        if x>0 and x<10000 and y>0 and y<10000 then
                            local canonical=x*1000000+y*100
                            local key=map..':'..typ..':'..canonical
                            if not seen[key] then
                                seen[key]=true;nodes[map]=nodes[map] or {};nodes[map][typ]=nodes[map][typ] or {}
                                table.insert(nodes[map][typ],canonical);count=count+1
                            end
                        end
                    end
                end
            end
        end
    end
    import(rawMine,'Mining');import(rawHerb,'Herb Gathering')
    import(GatherMate2MineDB,'Mining');import(GatherMate2HerbDB,'Herb Gathering')
    for _,byType in pairs(nodes) do for _,coords in pairs(byType) do table.sort(coords) end end
    self.GatherMateNodes=nodes;self.GatherMateNodeTypes=types;self.GatherMateObjectTypes=objects;self.GatherMateMapNames=maps
    self.gatherMateImportedCount=count
    self.gatherMateImportStatus=count>0 and 'imported from installed addons' or 'no matching local records'
    if not subscribed then
        local events=library('AceEvent-3.0')
        if events and events.RegisterMessage then
            for _,message in ipairs({'GatherMateData2Import','GatherMate2NodeAdded','GatherMate2NodeDeleted','GatherMate2Cleanup'}) do
                events.RegisterMessage(self,message,function() schedule() end)
            end
            subscribed=true
        end
    end
end
schedule=function()
    if queued or loading then return end
    if C_Timer and C_Timer.After then
        queued=true;C_Timer.After(0,function() queued=false;P:ImportGatherMateNodes() end)
    else P:ImportGatherMateNodes() end
end
local events=CreateFrame('Frame');P.gatherMateImportEvents=events
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('ADDON_LOADED');events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function(_,event,name)
    if event~='ADDON_LOADED' or name=='ProfPaden' or name=='GatherMate2' or name=='GatherMate2_Data' then schedule() end
end)
