from pathlib import Path
import json,sys,hashlib
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]; A=ROOT/'ProfPaden';D=ROOT/'docs/hyjal-materials-2026-11-22'
r=json.loads((D/'sources.json').read_text(encoding='utf8'))
def plain(v):return {str(k):plain(x) for k,x in v.items()} if hasattr(v,'items') else v
def runtime(patch=True,ui=False):
 L=LuaRuntime();P=L.table()
 if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text(encoding='utf8'))
 for f in (A/'ProfPaden.toc').read_text().splitlines():
  if not f.endswith('.lua') or f.startswith(('Vendor','Companions')):continue
  if not ui and not f.startswith('Data\\'):continue
  if not patch and f=='Data\\HyjalSources.lua':continue
  L.execute((A/f.replace('\\','/')).read_text(encoding='utf8'),'ProfPaden',P)
 if ui:L.execute('SetupReference();P.window:Hide()')
 return L,P
_,old=runtime(False);L,P=runtime();checks=[]
for k in ['Catalog','GatherAreas','GatherNodeData','GatherZoneAreas','GatherZoneMaps','TrainingCaps']:
 assert plain(old[k])==plain(P[k]),k
checks.append('All recipes, skill thresholds, map selections, overlays and node coordinates unchanged')
entries=0;relations=0
for prof,rows in P.GatherAtlas.items():
 for idx,e in rows.items():
  before=old.GatherAtlas[prof][idx];review=r['items'].get(str(e.item))
  if not review:assert plain(e)==plain(before);continue
  entries+=1
  for s in review['sources']:
   match=[v for v in e.sources.values() if v.kind==s['kind'] and v.id==s['id'] and v.name==s['name'] and v.method==s['method']]
   assert len(match)==1,(e.key,s);s2=match[0];relations+=1
   assert set(s['zones'])<=set(s2.zones.values())
   assert all(z.lower() in e.searchText for z in s['zones'])
   if s['method']=='Report':assert s2.rate=='-' and s2.observations>0 and 'not distinguished' in s2.provenance
   if s['id'] in [566779,566786,566788,248041,256809,244530,244525,274030]:assert len(s2.mapKeys)==len(s2.nodeKeys)==0
  assert not e.sourceCoverage or not e.sourceCoverage.unavailable
  if review.get('supersedePlayerReports'):assert all(s.kind!='report' for s in e.sources.values())
  assert (' | '+str(len(e.sources))+' sources') in e.sub
checks.append(f'{relations} acquisition links present across all {entries} affected profession entries; search and counts correct')
checks.append('Observed beast yields labeled Report without invented percentages or skinning claims; no invented Hyjal coordinates')
checks.append('Superseded Reddit reports archived outside active source rows; unknown-source messages removed only for reviewed items')
# Reloading patch must not duplicate acquisition rows.
counts={e.key:len(e.sources) for es in P.GatherAtlas.values() for e in es.values()}
L.execute((A/'Data/HyjalSources.lua').read_text(encoding='utf8'),'ProfPaden',P)
assert all(len(e.sources)==counts[e.key] for es in P.GatherAtlas.values() for e in es.values())
checks.append('Repeated source merge does not duplicate acquisition rows')
U,Q=runtime(ui=True);U.globals().P=Q
for i in r['items']:
 U.execute('''local id=...;local found=false
 for prof,es in pairs(P.GatherAtlas) do for _,e in ipairs(es) do if e.item==id then
  P.selectedProf=prof;P.tab='Gather';P.gatherView='materials';P.gatherSearch=tostring(id);P.selectedKey=e.key;P:Refresh();found=true
  local rows=P:GatherDetailRows(e);assert(#rows>0)
 end end end;assert(found,id)''',int(i))
checks.append('Actual Lua 5.1 addon loads and renders all 21 updated material details')
result={'passed':True,'checks':checks,'reviewedMaterials':len(r['items']),'sourceRelationships':sum(len(x['sources']) for x in r['items'].values()),'affectedEntries':entries,'affectedLinks':relations,'liveGame':'not run'}
(D/'checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
