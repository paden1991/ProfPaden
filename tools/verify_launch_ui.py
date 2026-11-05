"""Exercise the actual addon detail functions in the existing Lua 5.1 frame mock."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
L=LuaRuntime(unpack_returned_tuples=True)
L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text())
P=L.table();load=L.eval('function(c,p) assert(loadstring(c))("ProfPaden",p) end')
for line in (ROOT/'ProfPaden/ProfPaden.toc').read_text().splitlines():
    if line.endswith('.lua') and not line.startswith(('Vendor','Companions')):
        load((ROOT/'ProfPaden'/line.replace('\\','/')).read_text(encoding='utf8'),P)
L.execute('SetupReference(); P.window:Hide()')
def text(rows):
    return '\n'.join(' | '.join(str(v) for _,v in r.cells.items()) for _,r in rows.items() if r.cells)
results=[]
cases=[('Enchanting',1328948,['Alynsia','180', 'Honored']),('Skinning',1262985,['Lady Anacondra','Wailing Caverns']),('Mining',1262975,['Relic Guardian','Excavation']),('Herbalism',1262980,['Shadetooth','Excavation']),('Enchanting',1263056,["Rath'mael",'Charlga','Shade of the Archmage'])]
for prof,spell,expected in cases:
    P.selectedProf=prof
    r=next(r for r in P.Catalog[prof].values() if r.spell==spell)
    rows=P.AcquisitionRows(P,r,False,False);content=text(rows)
    assert all(s in content for s in expected),(spell,content)
    P.RenderDetailRows(P,rows,0)
    results.append(dict(profession=prof,spell=spell,passed=True,renderedRows=content))
for prof,item in [('Engineering',255007),('Blacksmithing',249391),('Leatherworking',249427)]:
    P.selectedProf=prof
    r=next(r for r in P.GatherAtlas[prof].values() if r.item==item)
    rows=P.GatherDetailRows(P,r);P.RenderDetailRows(P,rows,0)
    results.append(dict(profession=prof,item=item,passed=True,sources=len(r.sources),renderedRows=text(rows)))
# Broad display contract: every acquisition and material detail remains renderable.
counts=dict(recipes=0,materials=0)
for prof,entries in P.Catalog.items():
    P.selectedProf=prof
    for r in entries.values():
        rows=P.AcquisitionRows(P,r,False,False);P.RenderDetailRows(P,rows,0);counts['recipes']+=1
for prof,entries in P.GatherAtlas.items():
    P.selectedProf=prof
    for r in entries.values():
        rows=P.GatherDetailRows(P,r);P.RenderDetailRows(P,rows,0);counts['materials']+=1
results.append(dict(name='All acquisition and material detail rows render',passed=True,**counts))
L.execute('''
P.selectedProf='Mining';P.tab='Catalog';P.catalogSearch='3304';P.catalogFilter='all'
local old=P.Resolve
P.Resolve=function(self,r)if r.spell==3304 then return {spell=3304,name='Observed Tin',mats={{id=2771,count=2}},complete=true,difficulty='optimal',available=1} end end
local rows=P:CatalogRows();assert(#rows==1 and rows[1].live and rows[1].mats[1].count==2 and rows[1].difficulty=='optimal')
P.Resolve=old
''')
results.append(dict(name='Live client recipes still take precedence over static data',passed=True))
report=dict(checks=len(results),passed=len(results),environment='Offline Lua 5.1 frame mock; not live-game or browser-simulator proof',results=results)
(ROOT/'docs/launch-data/functional-tests.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(checks=len(results),passed=len(results),**counts)))
