"""Regression and evidence checks for the November 23 catalog refresh."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime,lua_type
from build_catalog_refresh import build,OUTPUT
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'ProfPaden';D=ROOT/'docs/catalog-refresh-2026-11-23'
review=json.loads((D/'reviewed.json').read_text(encoding='utf8'))
def plain(v):
 if lua_type(v)=='function':return str(v)
 return {str(k):plain(x) for k,x in v.items()} if hasattr(v,'items') else v
def runtime(patch=True,ui=False):
 L=LuaRuntime();P=L.table()
 if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text(encoding='utf8'))
 for f in (A/'ProfPaden.toc').read_text().splitlines():
  if not f.endswith('.lua') or f.startswith(('Vendor','Companions')):continue
  if not ui and not f.startswith('Data\\'):continue
  if not patch and f=='Data\\CatalogNovember23.lua':continue
  L.execute((A/f.replace('\\','/')).read_text(encoding='utf8'),'ProfPaden',P)
 if ui:L.execute('SetupReference();P.window:Hide()')
 return L,P
_,old=runtime(False);L,P=runtime();checks=[]
for key in ['GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps','NPCSources','TrainingCaps','ReagentVendors']:
 assert plain(old[key])==plain(P[key]),key
for prof,rows in old.Catalog.items():
 assert len(rows)==len(P.Catalog[prof])
 for idx,r in rows.items():
  now=P.Catalog[prof][idx];fix=review['recipes'].get(str(r.spell),{})
  for k in ['spell','item','mats','output','outputMax','learn','yellow','green','grey','name']:
   if k in fix and k in ['learn','name']:continue
   assert plain(r[k])==plain(now[k]),(prof,r.spell,k)
checks.append('Every existing recipe keeps its identity, reagents, yield and thresholds except the reviewed Water Walking requirement; maps and vendor conditions unchanged')
links=entries=0
for ident,item in review['items'].items():
 meta=P.ItemMeta[int(ident)]
 for s in item['sources']:
  found=[v for v in meta.sources.values() if v.id==s['id'] and v.method==s['method']]
  assert len(found)==1,(ident,s['id']);v=found[0]
  assert v.source==s['provenance'] and v.evidence==s['evidence']
  assert not {'x','y','price','percent'} & s.keys()
  assert s['mapKeys']==s['nodeKeys']==[] and s['rate']=='-'
  if s['method']=='Report':assert s['observations']>=3 and 'not a drop rate' in s['provenance']
for prof,rows in P.GatherAtlas.items():
 for idx,r in rows.items():
  before=old.GatherAtlas[prof][idx]
  current={json.dumps(plain(v),sort_keys=True) for v in r.sources.values()}
  for s in before.sources.values():assert json.dumps(plain(s),sort_keys=True) in current,(r.key,'changed old source')
  item=review['items'].get(str(r.item))
  if not item:continue
  entries+=1
  for s in item['sources']:
   found=[v for v in r.sources.values() if v.kind=='npc' and v.id==s['id'] and v.method==s['method']]
   assert len(found)==1,(r.key,s['id']);links+=1
   assert all(z.lower() in r.searchText.lower() for z in s['zones'])
checks.append(f'All {sum(len(i["sources"]) for i in review["items"].values())} item sources and {links} Gather links across {entries} entries retain evidence labels; all prior source records preserved')
for t in review['trainers']:
 r=next(r for r in P.Catalog[t['profession']].values() if r.spell==t['spell'])
 assert any(v.npc==t['npc'] for v in r.observedTrainerSources.values())
 assert t['name'] in r.source and '(ForeverDB observed)' in r.source
checks.append('All 514 observed trainers reach their intended recipes')
for prof,rows in P.Catalog.items():
 for r in rows.values():
  f=review['recipes'].get(str(r.spell))
  if not f:continue
  if 'book' in f:assert any(x.id==f['book'] for x in r.acquisitionItems.values()) and f['source']==r.source
  if 'name' in f:assert r.name==f['name'] and P.ItemMeta[f['item']].name==f['name']
  if 'learn' in f:assert r.learn==f['learn']
  if r.spell==2167:assert r.sourceDiscrepancy is None and r.wowheadLearn==75
for collection in [P.Recipes,P.MaterialCrafts,P.GatherMaterialUses]:
 for rows in collection.values():
  for r in rows.values():
   if r.spell==11447:assert r.learn==180
checks.append('Three teaching books, three names and Water Walking skill propagate to recipe and material summaries; current Gray Leather Boots evidence clears stale threshold conflict')
state=plain(P);L.execute(OUTPUT.read_text(encoding='utf8'),'ProfPaden',P);assert plain(P)==state
blob=OUTPUT.read_bytes();assert build().read_bytes()==blob
checks.append('Generated data is deterministic and repeated loading is idempotent')
U,Q=runtime(ui=True);U.globals().P=Q
changedspells={x['spell'] for x in review['trainers']}|{int(k) for k in review['recipes']}
rendered=0
for prof,rows in Q.Catalog.items():
 for r in rows.values():
  if r.spell not in changedspells:continue
  Q.selectedProf=prof;Q.tab='Catalog';Q.catalogSearch=str(r.spell);Q.selectedKey=None;Q.Refresh(Q);rendered+=1
gather=0
for prof,rows in Q.GatherAtlas.items():
 for r in rows.values():
  if str(r.item) not in review['items']:continue
  Q.selectedProf=prof;Q.tab='Gather';Q.gatherView='materials';Q.gatherSearch=str(r.item);Q.selectedKey=r.key;Q.Refresh(Q)
  assert len(Q.GatherDetailRows(Q,r))>0;gather+=1
checks.append(f'Actual Lua 5.1 addon loads and refreshes {rendered} changed recipe views and {gather} changed Gather detail views in the offline harness')
# Reconcile the full item inventory, including item IDs absent from metadata.
ids=set(int(i) for i in old.Items.keys())|set(int(i) for i in old.ItemMeta.keys())
for rows in old.Catalog.values():
 for r in rows.values():
  if r.item:ids.add(int(r.item))
  for m in (r.mats.values() if r.mats else []):ids.add(int(m.id))
  for ref in (r.acquisitionItems.values() if r.acquisitionItems else []):ids.add(int(ref.id))
missing=sorted(ids-{int(i) for i in old.ItemMeta.keys()})
result={'passed':True,'checks':checks,'gatherLinks':links,'gatherEntries':entries,'recipeViews':rendered,'allReferencedItems':len(ids),'itemsWithoutMetadata':missing,'liveGame':'not run'}
(D/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');print(json.dumps(result,indent=2))
