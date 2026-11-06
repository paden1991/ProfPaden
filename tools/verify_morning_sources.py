"""Test the November 6 data delta against the prior runtime, plus actual detail rendering."""
from pathlib import Path
import json,hashlib
from lupa.lua51 import LuaRuntime,lua_type
from build_morning_sources import ROOT,DATA,OUTPUT,build
D=ROOT/'docs/morning-data';A=ROOT/'ProfPaden';data=json.loads(DATA.read_text(encoding='utf8'))
def runtime(patch=True,ui=False):
    L=LuaRuntime(unpack_returned_tuples=True)
    if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text())
    P=L.table();load=L.eval('function(s,p) assert(loadstring(s))("ProfPaden",p) end')
    for line in (A/'ProfPaden.toc').read_text().splitlines():
        if not line.endswith('.lua') or line.startswith(('Vendor','Companions')):continue
        if not ui and not line.startswith('Data\\'):continue
        if not patch and line=='Data\\MorningSources.lua':continue
        load((A/line.replace('\\','/')).read_text(encoding='utf8'),P)
    if ui:L.execute('SetupReference();P.window:Hide()')
    return L,P,load
def plain(x):
    if lua_type(x)=='function':return str(x)
    return {str(k):plain(v) for k,v in x.items()} if hasattr(x,'items') else x
def values(x):return list(x.values()) if x is not None else []
def text(rows):return '\n'.join(' | '.join(str(v) for v in r.cells.values()) for r in rows.values() if r.cells)
L0,old,_=runtime(False);L,P,load=runtime();checks=[]
def check(name,fn):fn();checks.append(dict(name=name,passed=True))
def preservation():
    for key in ['GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps','TrainingCaps','LaunchSourceCoverage']:
        assert plain(old[key])==plain(P[key]),key
    for prof,entries in old.Catalog.items():
        assert len(entries)==len(P.Catalog[prof])
        for i,r in entries.items():
            for k in ['spell','item','learn','yellow','green','grey','mats','output','outputMax']:
                assert plain(r[k])==plain(P.Catalog[prof][i][k]),(prof,i,k)
    for ident,npc in old.NPCSources.items():
        assert plain(npc.points)==plain(P.NPCSources[ident].points)
        assert plain(npc.entrances)==plain(P.NPCSources[ident].entrances)
    for ident,npc in P.NPCSources.items():
        if old.NPCSources[ident] is None:assert not values(npc.points) and not values(npc.entrances)
    for ident,meta in old.ItemMeta.items():
        for src in values(meta.sources):assert plain(src) in [plain(x) for x in values(P.ItemMeta[ident].sources)]
check('Prior recipe numbers, sources, terrain, trainer caps, NPC coordinates and launch ledger remain intact',preservation)
def acquisitions():
    for ident,r in data['items'].items():
        actual=[plain(x) for x in P.ItemMeta[int(ident)].sources.values()]
        for s in r['sources']:assert s in actual,(ident,s)
    assert len(data['items'])==39
    assert sum(len(r['sources']) for r in data['items'].values())==102
check('All 102 reviewed item acquisitions load for 39 items',acquisitions)
def materials():
    for prof,entries in P.GatherAtlas.items():
        for e in entries.values():
            r=data['items'].get(str(e.item))
            if not r or not r['material']:continue
            keys={(s.kind,s.id,s.method) for s in values(e.sources)}
            for s in r['gatherSources']:assert (s['kind'],s['id'],s['method']) in keys
            before=next(x for x in old.GatherAtlas[prof].values() if x.key==e.key)
            assert {(s.kind,s.id,s.method) for s in values(before.sources)}<=keys
            for s in r['gatherSources']:assert s['name'].lower() in e.searchText
check('Every matching profession gets searchable sources without losing prior alternatives',materials)
def trainers():
    assert len(data['trainers'])==119
    for t in data['trainers']:
        r=next(r for r in P.Catalog[t['profession']].values() if r.spell==t['spell'])
        assert t['name'] in r.source and r.sourceKinds.trainer
        assert any(x.npc==t['npc'] and x.url==t['url'] for x in r.observedTrainerSources.values())
check('119 observed trainer relationships reach 87 recipe records with provenance',trainers)
def quality():
    review=json.loads((D/'review.json').read_text(encoding='utf8'))
    assert len(review['held'])==27
    for r in review['accepted']:
        assert r['source'].get('fv') or r['source'].get('src')=='forever'
        assert not r['resolvedName'].startswith('NPC ')
    for rec in data['items'].values():
        for s in rec['sources']:
            assert not {'x','y','percent','rate','price'} & s.keys()
        for s in rec['gatherSources']:assert s['method']!='Skin'
    assert all(s['method']=='Loot' for s in data['items']['2318']['gatherSources'])
check('Unknown NPCs/shared objects stay held; observations do not invent skinning, rates, prices or coordinates',quality)
def repeat():
    before=plain(P);load(OUTPUT.read_text(encoding='utf8'),P);after=plain(P)
    def diff(a,b,path=''):
        if isinstance(a,dict) and isinstance(b,dict):
            for k in a.keys()|b.keys():
                if a.get(k)!=b.get(k):diff(a.get(k),b.get(k),path+'/'+k)
        elif a!=b:raise AssertionError((path,a,b))
    diff(before,after)
check('Reloading the data module does not duplicate sources or trainers',repeat)
def deterministic():
    before=OUTPUT.read_bytes();assert build().read_bytes()==before
check('Reviewed JSON regenerates the exact runtime module',deterministic)
# Use the addon's detail rows and renderer; screenshots are a separate simulator check.
U,Q,_=runtime(ui=True);examples=[];rendered=0
def render():
    global rendered
    for prof,entries in Q.GatherAtlas.items():
        Q.selectedProf=prof
        for r in entries.values():
            if str(r.item) not in data['items']:continue
            Q.gatherSourceScope='all';Q.gatherSourcePage=1
            parts=[];pages=Q.GatherDisplaySources(Q,r)[3]
            for page in range(1,pages+1):
                Q.gatherSourcePage=page
                rows=Q.GatherDetailRows(Q,r);Q.RenderDetailRows(Q,rows,0);parts.append(text(rows))
            rendered+=1;content='\n'.join(parts)
            for s in data['items'][str(r.item)]['gatherSources']:assert s['name'] in content,(prof,r.item,s['name'])
            if (prof,r.item) in [('Tailoring',2589),('Leatherworking',2318),('Alchemy',2449),('Mining',3466)]:examples.append(dict(profession=prof,item=r.item,renderedRows=content))
    for t in data['trainers']:
        Q.selectedProf=t['profession'];r=next(r for r in Q.Catalog[t['profession']].values() if r.spell==t['spell'])
        rows=Q.AcquisitionRows(Q,r,False,False);Q.RenderDetailRows(Q,rows,0);content=text(rows)
        assert t['name'] in content,(t['spell'],t['name'],content)
        if t['spell']==1230564 and not any(e.get('spell')==t['spell'] for e in examples):examples.append(dict(profession=t['profession'],spell=t['spell'],renderedRows=content))
check('New material and trainer records appear in actual rendered detail rows',render)
def live_trainer():
    t=data['trainers'][0];prof=t['profession'];Q.selectedProf=prof
    r=next(r for r in Q.Catalog[prof].values() if r.spell==t['spell'])
    Q.char.trainers=U.table() if Q.char.trainers is None else Q.char.trainers
    # Create tables in the UI runtime, preserving the user's client-first acquisition order.
    Q.char.trainers[prof]=U.table_from({'s'+str(t['spell']):U.table_from(dict(npcID=t['npc'],cost=12345,eligible=False,known=False))})
    rows=Q.AcquisitionRows(Q,r,False,False);content=text(rows)
    assert 'Unavailable at last trainer visit' in content
    assert 'Training fee' in content
    trainerRows=[x for x in rows.values() if x.cells[1]=='Trainer']
    assert t['name'] in trainerRows[0].cells[2]
    assert sum(t['name'] in x.cells[2] for x in trainerRows)==1
check('Live trainer availability and fee remain first and do not duplicate observed alternatives',live_trainer)
report=dict(checks=len(checks),passed=len(checks),results=checks,materialEntriesRendered=rendered,examples=examples,environment='Offline Lua 5.1 frame mock; not live-game acceptance')
(D/'data-tests.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
print(json.dumps({k:v for k,v in report.items() if k not in ['examples','results']},indent=2))
