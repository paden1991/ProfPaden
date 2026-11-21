"""Reconcile derived zone masks with all already-recorded material sources."""
from pathlib import Path
from functools import lru_cache
import hashlib,json
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageChops
from build_launch_sources import lua

ROOT=Path(__file__).resolve().parents[1];A=ROOT/'ProfPaden'
D=ROOT/'docs/gather-location-qa-2026-11-21';D.mkdir(exist_ok=True)
PATCH='Data\\GatherLocationRepair.lua'

def runtime():
    L=LuaRuntime();P=L.table();load=L.eval('function(s,p)assert(loadstring(s))("ProfPaden",p)end')
    for line in (A/'ProfPaden.toc').read_text().splitlines():
        if line.startswith('Data\\') and line.endswith('.lua') and line!=PATCH:
            load((A/line.replace('\\','/')).read_text(encoding='utf8'),P)
    return L,P

def vals(x):return list(x.values()) if x is not None else []

@lru_cache(maxsize=4096)
def mask(texture):
    path=A/(texture.split('ProfPaden\\')[1].replace('\\','/')+'.tga')
    with Image.open(path) as im:
        assert im.width==im.height and im.width in (128,256,512,1024),str(path)
        return im.convert('RGBA')

def build():
    L,P=runtime();areas={};options={};changes=[];inputs={}
    for prof,entries in sorted(P.GatherAtlas.items()):
        for e in sorted(vals(entries),key=lambda e:e.key):
            oldkeys=vals(P.GatherZoneMaps[e.key])
            old={P.GatherZoneAreas[k].mapId:P.GatherZoneAreas[k] for k in oldkeys}
            grouped={}
            for key in set(vals(e.mapKeys)+[k for s in vals(e.sources) for k in vals(s.mapKeys)]):
                area=P.GatherAreas[key];assert area,key
                grouped.setdefault(area.mapId,set()).add(key)
            replacements={};added=[]
            for mapid,keys in sorted(grouped.items()):
                prior=old.get(mapid);priorKeys=set(vals(prior.sourceKeys)) if prior else set()
                if not keys-priorKeys:continue
                keys=sorted(keys|priorKeys)
                first=P.GatherAreas[keys[0]]
                assert all(P.GatherAreas[k].mapId==mapid for k in keys)
                textures=sorted({P.GatherAreas[k].overlay for k in keys}|({prior.overlay} if prior else set()))
                digest=hashlib.sha256(('\n'.join(keys+textures)).encode()).hexdigest()[:20]
                key='reconciled:'+digest
                if key not in areas:
                    size=max(mask(t).width for t in textures)
                    def aligned(t):return mask(t).resize((size,size),Image.Resampling.NEAREST)
                    combined=aligned(textures[0])
                    for texture in textures[1:]:combined=ImageChops.lighter(combined,aligned(texture))
                    target=A/'Assets/GatherReconciled'/f'{digest}.tga'
                    target.parent.mkdir(exist_ok=True);combined.save(target)
                    areas[key]={'key':key,'mapId':mapid,'zone':first.zone,'area':first.area,'texture':first.texture,
                        'overlay':'Interface\\AddOns\\ProfPaden\\Assets\\GatherReconciled\\'+digest,
                        'source':'Recorded source locations; historical/reference records included',
                        'sourceCount':len(keys),'sourceKeys':keys,'label':first.zone,'url':first.url,'zoneAggregate':True}
                    inputs[key]=textures
                if prior:replacements[prior.key]=key
                else:added.append(key)
                changes.append({'entry':e.key,'item':e.item,'mapId':mapid,'zone':first.zone,'newZone':prior is None,
                    'addedSources':sorted(set(keys)-priorKeys),'areaKey':key})
            if replacements or added:options[e.key]=[replacements.get(k,k) for k in oldkeys]+added
    body='-- Generated from existing source masks; no new coordinates or drop claims.\nlocal _,P=...\n'
    body+='local areas='+lua(areas)+'\nlocal maps='+lua(options)+'\n'
    body+='for key,area in pairs(areas) do P.GatherZoneAreas[key]=area end\n'
    body+='for key,zones in pairs(maps) do P.GatherZoneMaps[key]=zones end\n'
    (A/PATCH.replace('\\','/')).write_text(body,encoding='utf8',newline='\n')
    report={'entriesRepaired':len(options),'zoneChoicesRepaired':len(changes),'newZoneChoices':sum(c['newZone'] for c in changes),
        'masks':len(areas),'method':'Per-channel maximum of existing source masks and prior aggregate. Smaller masks only upscale with nearest-neighbor to preserve occupied cells; no inferred points.',
        'changes':changes,'maskInputs':inputs}
    (D/'map-repair.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['changes','maskInputs']}))
    return report

if __name__=='__main__':build()
