"""Exercise reviewed source additions in the real Lua 5.1 data and UI path."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'ProfPaden';D=ROOT/'docs/material-sources-2026-11-22'
review=json.loads((D/'sources.json').read_text(encoding='utf8'))
def plain(v):return {str(k):plain(x) for k,x in v.items()} if hasattr(v,'items') else v
def runtime(patch=True,ui=False):
 L=LuaRuntime();P=L.table()
 if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text(encoding='utf8'))
 for f in (A/'ProfPaden.toc').read_text().splitlines():
  if not f.endswith('.lua') or f.startswith(('Vendor','Companions')):continue
  if not ui and not f.startswith('Data\\'):continue
  if not patch and f=='Data\\MaterialSources.lua':continue
  L.execute((A/f.replace('\\','/')).read_text(encoding='utf8'),'ProfPaden',P)
 if ui:L.execute('SetupReference();P.window:Hide()')
 return L,P
_,old=runtime(False);L,P=runtime();checks=[]
for k in ['Catalog','GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps','TrainingCaps']:
 assert plain(old[k])==plain(P[k]),k
checks.append('Recipes, training thresholds, map areas, overlays and node coordinates unchanged')
entries=links=0
for prof,es in P.GatherAtlas.items():
 for idx,e in es.items():
  before=old.GatherAtlas[prof][idx];r=review['items'].get(str(e.item))
  if not r:assert plain(e)==plain(before),e.key;continue
  entries+=1
  for s in before.sources.values():
   if r.get('supersedePlayerReports') and s.kind=='report' and 'reddit.com/' in (s.url or ''):continue
   assert any(plain(s)==plain(v) for v in e.sources.values()),(e.key,'old source changed')
  for s in r['sources']:
   found=[v for v in e.sources.values() if (v.kind,v.id,v.name,v.method)==(s['kind'],s['id'],s['name'],s['method'])]
   assert len(found)==1,(e.key,s);v=found[0];links+=1
   assert set(s['zones'])==set(v.zones.values())
   assert len(v.mapKeys)==len(v.nodeKeys)==0
   assert v.rate=='-'
   if s['method']=='Report':assert v.observations>=3 and 'not distinguished' in v.provenance and 'not a drop rate' in v.provenance
   if s['kind']=='npc':assert P.NPCSources[s['id']].name==s['name']
   assert all(z.lower() in e.searchText for z in s['zones'])
  assert (' | '+str(len(e.sources))+' sources') in e.sub
  assert not e.sourceCoverage or not e.sourceCoverage.unavailable
  if e.item==268418:assert 'cannot be used' in e.note
checks.append(f'All {links} new links appear once across {entries} profession entries; existing sources preserved')
checks.append('Reports retain observation counts and uncertainty, with no invented rates or coordinates')
checks.append('Scarce Herb Seeds usage follows the November 19 official hotfix')
counts={e.key:(len(e.sources),e.searchText) for es in P.GatherAtlas.values() for e in es.values()}
L.execute((A/'Data/MaterialSources.lua').read_text(encoding='utf8'),'ProfPaden',P)
assert all((len(e.sources),e.searchText)==counts[e.key] for es in P.GatherAtlas.values() for e in es.values())
checks.append('Repeated merge preserves source counts and search text')
U,Q=runtime(ui=True);U.globals().P=Q
for i in review['items']:
 U.execute('''local id=...;local found=false
 for prof,es in pairs(P.GatherAtlas) do for _,e in ipairs(es) do if e.item==id then
  P.selectedProf=prof;P.tab='Gather';P.gatherView='materials';P.gatherSearch=tostring(id);P.selectedKey=e.key;P:Refresh();found=true
  local rows=P:GatherDetailRows(e);assert(#rows>0)
 end end end;assert(found,id)''',int(i))
checks.append(f'Actual Lua 5.1 addon loads and renders all {len(review["items"])} updated material detail views')
result={'passed':True,'checks':checks,'updatedMaterials':len(review['items']),'newRelationships':sum(len(x['sources']) for x in review['items'].values()),'affectedEntries':entries,'affectedLinks':links,'liveGame':'not run'}
(D/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8');print(json.dumps(result,indent=2))
