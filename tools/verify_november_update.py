"""Check the November data update in Lua 5.1 and the actual addon detail renderer."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'docs/november-12';A=ROOT/'ProfPaden'
try:from lupa.lua51 import LuaRuntime,lua_type
except ImportError:
 sys.path.insert(0,str(ROOT.parent/'deps'));from lupa.lua51 import LuaRuntime,lua_type
from build_november_update import build,OUTPUT
src=json.loads((D/'sources.json').read_text(encoding='utf8'));fix=json.loads((D/'hotfixes.json').read_text(encoding='utf8'))
def vals(t):return list(t.values()) if t is not None else []
def plain(x):
 if lua_type(x)=='function':return str(x)
 return {str(k):plain(v) for k,v in x.items()} if hasattr(x,'items') else x
def runtime(patch=True,ui=False):
 L=LuaRuntime(unpack_returned_tuples=True)
 if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text())
 P=L.table();load=L.eval('function(s,p) assert(loadstring(s))("ProfPaden",p) end')
 for line in (A/'ProfPaden.toc').read_text().splitlines():
  if not line.endswith('.lua') or line.startswith(('Vendor','Companions')):continue
  if not ui and not line.startswith('Data\\'):continue
  if not patch and line=='Data\\NovemberUpdate.lua':continue
  load((A/line.replace('\\','/')).read_text(encoding='utf8'),P)
 if ui:L.execute('SetupReference();P.window:Hide()')
 return L,P,load
L0,old,_=runtime(False);L,P,load=runtime();checks=[]
def check(name,fn):fn();checks.append(name)
def preservation():
 for key in ['GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps','TrainingCaps','LaunchSourceCoverage','MorningSourceCoverage']:assert plain(old[key])==plain(P[key]),key
 for prof,entries in old.Catalog.items():
  assert len(entries)==len(P.Catalog[prof])
  for index,r in entries.items():
   current=P.Catalog[prof][index];f=fix['recipes'].get(str(r.spell),{})
   for k in ['spell','item','learn','yellow','green','grey','mats','output','outputMax']:
    if k in f or k=='mats' and 'materialCounts' in f:continue
    assert plain(r[k])==plain(current[k]),(prof,index,k)
 for id,npc in old.NPCSources.items():
  assert plain(npc.points)==plain(P.NPCSources[id].points),(id,'points')
  assert plain(npc.entrances)==plain(P.NPCSources[id].entrances),(id,'entrances')
 for id,npc in P.NPCSources.items():
  if old.NPCSources[id] is None:assert not vals(npc.points) and not vals(npc.entrances)
check('Unrelated recipe values, map data, coordinates and earlier coverage preserved',preservation)
def acquisitions():
 for ident,record in src['items'].items():
  actual=vals(P.ItemMeta[int(ident)].sources)
  for s in record['sources']:assert any(x.kind==s['kind'] and (x.npc or x.id)==s.get('npc',s.get('id')) and x.name==s['name'] for x in actual),(ident,s)
 for prof,entries in P.GatherAtlas.items():
  for r in entries.values():
   record=src['items'].get(str(r.item))
   if not record or not record['material']:continue
   keys={(x.kind,x.id,x.method) for x in vals(r.sources)}
   for s in record['gatherSources']:assert (s['kind'],s['id'],s['method']) in keys
check('All reviewed item and material sources reach runtime',acquisitions)
def trainers():
 for t in src['trainers']:
  r=next(r for r in P.Catalog[t['profession']].values() if r.spell==t['spell'])
  assert any(x.npc==t['npc'] for x in vals(r.observedTrainerSources)) and t['name'] in r.source
check('All observed trainers reach the correct recipe',trainers)
def corrections():
 for prof,rows in P.Catalog.items():
  for r in rows.values():
   f=fix['recipes'].get(str(r.spell))
   if not f:continue
   for k,v in f.items():
    if k in ['note','materialCounts']:continue
    expected={str(i+1):x for i,x in enumerate(v)} if isinstance(v,list) else v
    assert plain(r[k])==expected,(r.spell,k)
   for ident,count in f.get('materialCounts',{}).items():assert next(x.count for x in r.mats.values() if x.id==int(ident))==count
   assert r.hotfixNote==f['note']
 for ident,f in fix['items'].items():
  for k,v in f.items():
   if k not in ['oldName','previousRequiredSkill']:assert P.ItemMeta[int(ident)][k]==v,(ident,k)
 assert next(r for r in P.Catalog['Alchemy'].values() if r.spell==26277).acquisitionItems[1].name=='Recipe: Elixir of Holy Power'
 for collection in [P.MaterialCrafts,P.GatherMaterialUses]:
  for rows in collection.values():
   for r in rows.values():
    if r.spell==1263031:assert r.learn==125
    for m in vals(r.mats):
     f=fix['recipes'].get(str(r.spell),{}).get('materialCounts',{})
     if str(m.id) in f:assert m.count==f[str(m.id)]
check('Official hotfix fields and derived material summaries agree',corrections)
def quality():
 review=json.loads((D/'review.json').read_text(encoding='utf8'))
 for r in review['accepted']:assert r['source'].get('fv') or r['source'].get('src')=='forever'
 for r in src['items'].values():
  for s in r['sources']+r['gatherSources']:
   assert not {'x','y','rate','percent','price'} & s.keys()
   assert s.get('method')!='Skin'
check('Source provenance retained without invented skinning, rates or coordinates',quality)
def repeat():
 before=plain(P);load(OUTPUT.read_text(encoding='utf8'),P);after=plain(P)
 def difference(a,b,path=''):
  if a==b:return
  if isinstance(a,dict) and isinstance(b,dict):
   for k in a.keys()|b.keys():
    if a.get(k)!=b.get(k):difference(a.get(k),b.get(k),path+'/'+k)
  else:raise AssertionError((path,str(a)[:500],str(b)[:500]))
 difference(before,after)
check('Repeated module load is idempotent',repeat)
def deterministic():
 before=OUTPUT.read_bytes();assert build().read_bytes()==before
check('Reviewed ledger regenerates byte-identical Lua',deterministic)
U,Q,_=runtime(ui=True);examples=[];counts={'recipes':0,'materials':0}
def text(rows):return '\n'.join(' | '.join(str(v) for v in r.cells.values()) for r in rows.values() if r.cells)
def render():
 for prof,entries in Q.Catalog.items():
  Q.selectedProf=prof
  for r in entries.values():
   rows=Q.AcquisitionRows(Q,r,False,False);Q.RenderDetailRows(Q,rows,0);counts['recipes']+=1
   if str(r.spell) in fix['recipes']:
    assert r.hotfixNote in text(rows),(r.spell,'hotfix not visible')
    if r.spell==1263031:
     assert 'Leatherworking 140' not in text(rows),text(rows)
     assert 'Leatherworking 125' in text(rows),text(rows)
    if r.spell in [3758,3326,1263031,1263056]:
     full=Q.DetailRows(Q,r,1);Q.RenderDetailRows(Q,full,0)
     examples.append(dict(profession=prof,spell=r.spell,name=r.name,renderedRows=text(full)))
 for prof,entries in Q.GatherAtlas.items():
  Q.selectedProf=prof
  for r in entries.values():
   Q.gatherSourceScope='all';Q.gatherSourcePage=1
   rows=Q.GatherDetailRows(Q,r);Q.RenderDetailRows(Q,rows,0);counts['materials']+=1
 for t in src['trainers']:
  Q.selectedProf=t['profession'];r=next(r for r in Q.Catalog[t['profession']].values() if r.spell==t['spell'])
  assert t['name'] in text(Q.AcquisitionRows(Q,r,False,False)),t
check('Every recipe/material detail renders; new trainers and hotfix notes are visible',render)
def planning():
 Q.selectedProf='Tailoring';r=next(r for r in Q.Catalog['Tailoring'].values() if r.spell==3758)
 rows=Q.DetailRows(Q,r,3);content=text(rows)
 assert ' / 15' in content,content
 Q.RenderDetailRows(Q,rows,0)
 examples.append(dict(profession='Tailoring',spell=3758,name='Three Green Woolen Bags',renderedRows=content))
check('Three bags require fifteen bolts in the actual material detail calculation',planning)
report=dict(passed=len(checks),checks=checks,counts=counts,examples=examples,environment='Offline Lua 5.1 frame mock, not live gameplay')
(D/'tests.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
print(json.dumps({k:v for k,v in report.items() if k not in ['checks','examples']}))
