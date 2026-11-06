"""Lua 5.1 data checks for the additive launch-source update."""
from pathlib import Path
import json,hashlib
from lupa.lua51 import LuaRuntime, lua_type

ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'ProfPaden'
data=json.loads((ROOT/'docs/launch-data/sources.json').read_text())

def runtime(include_patch):
    L=LuaRuntime(unpack_returned_tuples=True);P=L.table()
    load=L.eval('function(s,p) assert(loadstring(s))("ProfPaden",p) end')
    for line in (ADDON/'ProfPaden.toc').read_text().splitlines():
        if line.startswith('Data\\') and line.endswith('.lua'):
            # Isolate this historical module; the morning suite covers the full current load order.
            if line=='Data\\MorningSources.lua':continue
            if line=='Data\\LaunchSources.lua' and not include_patch:continue
            load((ADDON/line.replace('\\','/')).read_text(encoding='utf8'),P)
    return L,P,load

def plain(value):
    if lua_type(value)=='function':return str(value)
    return {str(k):plain(v) for k,v in value.items()} if hasattr(value,'items') else value

L,base,_=runtime(False);L,P,load=runtime(True)
checks=[]
def check(name,fn):
    fn();checks.append(dict(name=name,passed=True))

def unchanged():
    fields=['spell','item','learn','yellow','green','grey','mats','output','outputMax']
    for prof,entries in base.Catalog.items():
        assert len(entries)==len(P.Catalog[prof]),prof
        for i,r in entries.items():
            for f in fields:assert plain(r[f])==plain(P.Catalog[prof][i][f]),(prof,i,f)
    for key in ['GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps']:
        assert plain(base[key])==plain(P[key]),key
check('All recipe ranks, reagents, outputs and recorded map data are preserved',unchanged)

def acquisition():
    for item,expected in [(273098,[3671]),(273097,[260326]),(273106,[260325]),(273103,[250657,246020,4421]),(273109,[3974]),(289560,[256732])]:
        sources=list(P.ItemMeta[item].sources.values());assert set(expected)<={s.npc for s in sources}
    speed=next(r for r in P.Catalog.Enchanting.values() if r.spell==1328948)
    assert speed.sourceKind=='vendor' and speed.sourceVerified
    assert '180' in speed.source and 'Honored' in speed.source
    assert any(s.favor==180 for s in P.ItemMeta[289560].sources.values())
check('Six recipe acquisitions expose named providers and the enchant currency/reputation',acquisition)

def material_sources():
    matches=0
    for prof,entries in P.GatherAtlas.items():
        for entry in entries.values():
            record=data['items'].get(str(entry.item))
            if not record or not record['material']:continue
            assert entry.name==record['name']
            actual={(s.kind,s.id,s.method) for s in entry.sources.values()}
            for s in record['gatherSources']:assert (s['kind'],s['id'],s['method']) in actual,(prof,entry.item,s)
            old=next(e for e in base.GatherAtlas[prof].values() if e.key==entry.key)
            assert {(s.kind,s.id,s.method) for s in old.sources.values()}<=actual
            matches+=1
    assert matches>0
check('Every applicable profession receives new material sources without losing old ones',material_sources)

def npc_preservation():
    for id,npc in base.NPCSources.items():
        assert plain(npc.points)==plain(P.NPCSources[id].points)
        assert plain(npc.entrances)==plain(P.NPCSources[id].entrances)
    for id in [260326,260325,246020]:
        assert len(P.NPCSources[id].points)==0
check('NPC locations are descriptive; no coordinates or dungeon entrances are guessed',npc_preservation)

def repeat():
    before=plain(P)
    load((ADDON/'Data/LaunchSources.lua').read_text(encoding='utf8'),P)
    assert before==plain(P)
check('Reapplying the source module is idempotent',repeat)

def reproducible():
    import build_launch_sources
    before=(ADDON/'Data/LaunchSources.lua').read_bytes()
    assert build_launch_sources.build().read_bytes()==before
check('Runtime data rebuilds deterministically from reviewed JSON',reproducible)

def coverage():
    ledger=json.loads((ROOT/'docs/launch-data/coverage.json').read_text())
    audit=json.loads((ROOT/'docs/launch-data/bulk-audit.json').read_text())
    assert ledger['total']==966 and len(audit['items'])==966
    assert set(data['items'])=={str(r['id']) for r in audit['items']}
    assert not {'pending','blocked'} & set(ledger['counts'])
    known={e.item for entries in P.GatherAtlas.values() for e in entries.values()}
    for ident,r in data['items'].items():
        assert r['name'] and P.ItemMeta[int(ident)].name==r['name']
        if r['material']:assert int(ident) in known,(ident,r['name'])
    assert all(r.spell!=30021 for r in P.Catalog['First Aid'].values())
check('All 966 planned items were checked; all newer materials remain browsable',coverage)

def identities(table,field):
    return {(int(id),s.kind,s.npc or s.id,s.method) for id,entry in table.items() for s in (entry[field] or L.table()).values()}
before=identities(base.ItemMeta,'sources');after=identities(P.ItemMeta,'sources')
summary=dict(items=len(data['items']),newItemAcquisitions=len(after-before),newNpcRecords=len(list(P.NPCSources.keys()))-len(list(base.NPCSources.keys())))

report=dict(checks=len(checks),passed=len(checks),results=checks,summary=summary,liveClientVerified=False)
(ROOT/'docs/launch-data/data-tests.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
