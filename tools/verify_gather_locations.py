"""Check all map/source joins and exercise the actual Gather UI in Lua 5.1."""
from pathlib import Path
import json,hashlib
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageChops
from build_gather_location_repair import runtime as baseline,vals,mask
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'ProfPaden';D=ROOT/'docs/gather-location-qa-2026-11-21'
L,P=baseline();L.globals().P=P
checks=[]
def check(name,fn):fn();checks.append(name)
def run(name,code):check(name,lambda:L.execute(code))
L.execute('''
local function clone(v)if type(v)~='table' then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
before={};for _,k in ipairs({'GatherAtlas','GatherAreas','GatherNodeData','NPCSources','GatherZoneMaps','GatherZoneAreas'})do before[k]=clone(P[k])end
function same(a,b)
 if type(a)~='table' then return a==b end;if type(b)~='table' then return false end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
''')
load=L.eval('function(s,p)assert(loadstring(s))("ProfPaden",p)end')
for f in ['Data/GatherLocationRepair.lua','GatherAtlas.lua','GatherDataAPI.lua']:load((A/f).read_text(encoding='utf8'),P)
run('All original sources, rates, coordinates and NPC records unchanged', '''
for _,k in ipairs({'GatherAtlas','GatherAreas','GatherNodeData','NPCSources'})do assert(same(before[k],P[k]),k)end
''')
run('Every source map has one selectable zone and is included in its overlay index', '''
entryCount=0;sourceCount=0;zoneCount=0
for _,entries in pairs(P.GatherAtlas)do for _,e in ipairs(entries)do
 entryCount=entryCount+1;sourceCount=sourceCount+#e.sources
 local maps={};for _,a in ipairs(P:GatherMapOptions(e))do assert(not maps[a.mapId],e.key);maps[a.mapId]=a;zoneCount=zoneCount+1 end
 local function covered(k)
  local a=P.GatherAreas[k];assert(a,k);local z=maps[a.mapId];assert(z,e.key..':'..k)
  local found=false;for _,s in ipairs(z.sourceKeys or {})do if s==k then found=true end end;assert(found,e.key..':'..k)
 end
 for _,k in ipairs(e.mapKeys or {})do covered(k)end
 for _,s in ipairs(e.sources)do for _,k in ipairs(s.mapKeys or {})do covered(k)end end
 local leaves=0;local function menu(rows)assert(#rows<=10);for _,r in ipairs(rows)do if r.children then menu(r.children)else assert(r.label==P:GatherMapOptions(e)[r.value].zone);leaves=leaves+1 end end end
 menu(P:GatherMapMenu(e));assert(leaves==#P:GatherMapOptions(e))
end end
''')
run('Every previous map choice remains selectable', '''
for _,entries in pairs(P.GatherAtlas)do for _,e in ipairs(entries)do
 local maps={};for _,a in ipairs(P:GatherMapOptions(e))do maps[a.mapId]=true end
 for _,k in ipairs(before.GatherZoneMaps[e.key] or {})do assert(maps[before.GatherZoneAreas[k].mapId],e.key)end
end end
''')
run('Source groups retain every record and map filtering excludes unrelated locations', '''
for _,entries in pairs(P.GatherAtlas)do for _,e in ipairs(entries)do
 local seen={};for _,g in ipairs(P:GatherSourceGroups(e,e.sources,1,#e.sources,nil))do for _,s in ipairs(g.records)do seen[s]=(seen[s] or 0)+1 end end
 for _,s in ipairs(e.sources)do assert(seen[s]==1,e.key)end
 if #e.sources>20 and (e.dropCoverage or e.skinReferenceCount) then for _,map in ipairs(P:GatherMapOptions(e))do
  P.currentMap=map;P.gatherSourceScope='map'
  local sources=P:GatherDisplaySources(e)
  for _,s in ipairs(sources)do
   local matches=false;for _,k in ipairs(s.mapKeys or {})do if P.GatherAreas[k].mapId==map.mapId then matches=true end end
   for _,z in ipairs(s.zones or {})do if z:lower()==map.zone:lower()then matches=true end end
   assert(matches,e.key)
  end
 end end
end end
''')
run('Node exports exclude sentinel coordinates and honor the selected map', '''
exportedNodes=0
for _,entries in pairs(P.GatherAtlas)do for _,e in ipairs(entries)do
 for _,set in ipairs(P:GetGatherNodeSets(e.key))do
  assert(set.walkability=='unassessed' and set.coordinateUnits=='percent')
  for _,n in ipairs(set.nodes)do assert(n.x>=0 and n.x<=100 and n.y>=0 and n.y<=100);exportedNodes=exportedNodes+1 end
 end
end end
assert(#P:GetGatherNodeSets('missing')==0)
for _,s in ipairs(P:GetGatherNodeSets('gather:Tailoring:2589',1431))do assert(s.mapId==1431)end
assert(#P:GetGatherNodeSets('gather:Tailoring:2589',1431)>0)
''')
def overlays():
    repair=json.loads((D/'map-repair.json').read_text())
    for key,textures in repair['maskInputs'].items():
        size=max(mask(t).width for t in textures)
        combined=mask(textures[0]).resize((size,size),Image.Resampling.NEAREST)
        for t in textures[1:]:combined=ImageChops.lighter(combined,mask(t).resize((size,size),Image.Resampling.NEAREST))
        actual=mask(P.GatherZoneAreas[key].overlay)
        assert actual.size==combined.size and actual.tobytes()==combined.tobytes(),key
        assert actual.getchannel('A').getbbox(),key
check('All 313 repaired overlays exactly combine their recorded inputs without lost cells',overlays)
run('Repeated repair load is idempotent','savedMaps=P.GatherZoneMaps;savedAreas=P.GatherZoneAreas')
before=json.dumps({k:vals(v) for k,v in P.GatherZoneMaps.items()},sort_keys=True)
load((A/'Data/GatherLocationRepair.lua').read_text(),P)
assert before==json.dumps({k:vals(v) for k,v in P.GatherZoneMaps.items()},sort_keys=True)

# Production UI with fake client APIs. This is not live-game proof.
U=LuaRuntime(unpack_returned_tuples=True);U.execute((ROOT/'tools/fixtures/snapshot.lua').read_text())
Q=U.table();uload=U.eval('function(s,p)assert(loadstring(s))("ProfPaden",p)end')
for f in (A/'ProfPaden.toc').read_text().splitlines():
    if f.endswith('.lua'):uload((A/f.replace('\\','/')).read_text(encoding='utf8'),Q)
U.execute('''SetupReference()
C_Map={GetMapArtLayers=function()return {{layerWidth=1000,layerHeight=668,tileWidth=256,tileHeight=256}}end,GetMapArtLayerTextures=function()return {1,2,3,4,5,6,7,8,9,10,11,12}end}
function gather(prof,id)P.selectedProf=prof;P.tab='Gather';P.gatherView='materials';P.gatherSearch=tostring(id);P.selectedKey=nil;P:Refresh();assert(P.selected.item==id)end
function findMap(id)for i,a in ipairs(P:GatherMapOptions(P.selected))do if a.mapId==id then P.mapChoiceIndex=i;P:RefreshDetail();return a end end;error('Missing map '..id)end
''')
def ui():
    U.execute('''
    gather('Tailoring',2589);local a=findMap(1431);assert(P.currentMap.zone=='Duskwood' and P.gatherMap.overlay.texture==a.overlay)
    P.gatherSourceScope='map';P:RefreshDetail();local sources=P:GatherDisplaySources(P.selected);local found={}
    for _,s in ipairs(sources)do found[s.id]=true end;assert(found[531] and found[202])
    local b=P.detailSourceButtons[1];assert(b and b.shown);b.scripts.OnClick(b);assert(P.gatherSourceExpanded[1]);b.scripts.OnClick(b);assert(not P.gatherSourceExpanded[1])
    P.detailChild.scripts.OnHyperlinkClick(nil,'profpaden:sourcescope:all');P.detailChild.scripts.OnHyperlinkClick(nil,'profpaden:sources:2');assert(P.gatherSourcePage==2)
    P.detailChild.scripts.OnHyperlinkClick(nil,'profpaden:sourcescope:map');assert(P.gatherSourcePage==1)
    for _,pair in ipairs({{'Mining',2770},{'Herbalism',2447},{'Skinning',2318},{'Cooking',769},{'Fishing',6522}})do gather(pair[1],pair[2]);assert(P.currentMap);P:ToggleGatherSourceGroup(1);assert(P.gatherSourceExpanded[1])end
    gather('Skinning',249429);assert(not P.currentMap and not P.gatherMap.shown)
    ''')
check('Gather UI selects repaired Duskwood, toggles details, pages sources and resets six material types',ui)
report={'version':Q.version,'passed':len(checks),'checks':checks,'entries':L.globals().entryCount,'sourceRecords':L.globals().sourceCount,
    'zoneChoices':L.globals().zoneCount,'exportedNodesChecked':L.globals().exportedNodes,'environment':'Offline Lua 5.1 and production UI with client stubs; not live gameplay'}
(D/'tests.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
