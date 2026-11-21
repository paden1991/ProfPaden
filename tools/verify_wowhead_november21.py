"""Validate reviewed acquisition changes, preservation, and real detail-row rendering."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime,lua_type
ROOT=Path(__file__).resolve().parents[1]
A=ROOT/'ProfPaden';D=ROOT/'docs/wowhead-2026-11-21'
PATCH='Data\\WowheadNovember21.lua'
def plain(x):
    if lua_type(x)=='function':return str(x)
    return {str(k):plain(v) for k,v in x.items()} if hasattr(x,'items') else x
def runtime(patch=True,ui=False):
    L=LuaRuntime(unpack_returned_tuples=True)
    if ui:L.execute((ROOT/'tools/fixtures/snapshot.lua').read_text())
    P=L.table();load=L.eval('function(s,p)assert(loadstring(s))("ProfPaden",p)end')
    for line in (A/'ProfPaden.toc').read_text().splitlines():
        if not line.endswith('.lua') or line.startswith(('Vendor','Companions')):continue
        if not ui and not line.startswith('Data\\'):continue
        if not patch and line==PATCH:continue
        load((A/line.replace('\\','/')).read_text(encoding='utf8'),P)
    if ui:L.execute('SetupReference();P.window:Hide()')
    return L,P,load
L0,old,_=runtime(False);L,P,load=runtime();checks=[]
def check(name,condition):
    assert condition,name
    checks.append(name)
def recipe(p,spell):return next(r for rows in p.Catalog.values() for r in rows.values() if r.spell==spell)
automatic=[1245250,1245246,1245287,1245320,1245321]
accepted=set(automatic+[9957,2740,1263070])
for prof,rows in old.Catalog.items():
    check(prof+' recipe count unchanged',len(rows)==len(P.Catalog[prof]))
    for index,r in rows.items():
        n=P.Catalog[prof][index]
        for k in ['spell','item','learn','yellow','green','grey','mats','output','outputMax']:
            assert plain(r[k])==plain(n[k]),(prof,r.spell,k)
        if r.spell not in accepted:assert plain(r)==plain(n),r.spell
check('All recipes retain quantities, ingredients, thresholds and outputs',True)
for key in ['GatherAreas','GatherNodeData','GatherAtlas','NPCSources','MaterialCrafts','GatherMaterialUses']:
    check(key+' unchanged',plain(old[key])==plain(P[key]))
for ident,x in old.ItemMeta.items():
    if ident!=2848:assert plain(x)==plain(P.ItemMeta[ident]),ident
check('Unrelated item metadata unchanged',True)
for spell in automatic:
    r=recipe(P,spell)
    check(str(spell)+' automatic learning is visible and verified',r.sourceKind=='automatic' and r.sourceVerified and 'automatically' in r.source)
r=recipe(P,9957)
check('Orcish War Leggings points to plans',r.acquisitionItems[1].id==7994 and r.sourceKinds.quest and r.sourceKinds.vendor)
check('Orcish plans requirement is 205 and stale disagreement removed',P.ItemMeta[7994].requiredSkill==205 and r.wowheadLearn==205 and r.sourceDiscrepancy is None)
check('Conditional vendor is Sumi, after quest 2756',any(s.npc==3356 and s.requiredQuest==2756 for s in P.ItemMeta[7994].sources.values()))
check('Quest reward metadata includes plans',7994 in list(P.QuestMeta[2756].rewards.values()))
check('Bronze Mace binds on equip',P.ItemMeta[2848].bindOnEquip is True)
check('Seed Hybridizer warning covers failure and excluded seeds','can fail' in recipe(P,1263070).hotfixNote and 'Scarce Herb Seeds' in recipe(P,1263070).hotfixNote)
check('Unresolved guide links excluded',all(P.ItemMeta[i] is None for i in [250362,249533,263505,252949]))
check('Conflicting Spinefin source left unchanged',plain(recipe(old,1247741))==plain(recipe(P,1247741)))
before=plain(P);load((A/PATCH.replace('\\','/')).read_text(),P)
check('Repeated patch load is idempotent',before==plain(P))
U,Q,_=runtime(ui=True);examples=[]
for prof,rows in Q.Catalog.items():
    for r in rows.values():
        if r.spell not in accepted:continue
        Q.selectedProf=prof
        rendered=Q.AcquisitionRows(Q,r,False,False);Q.RenderDetailRows(Q,rendered,0)
        text='\n'.join(' | '.join(str(v) for v in row.cells.values()) for row in rendered.values() if row.cells)
        if r.spell in automatic:assert 'Learned automatically' in text
        elif r.spell==9957:assert 'Sumi' in text and 'require completion' in text and '205' in text
        else:assert r.hotfixNote in text
        examples.append({'profession':prof,'spell':r.spell,'name':r.name,'text':text})
check('All eight updated recipes render through production detail controls',len(examples)==8)
Q.selectedProf='Alchemy'
Q.char.trainers=U.table_from({'Alchemy':U.table_from({'s1245250':U.table_from({'trainer':'Live trainer fixture','cost':123,'eligible':True})})})
rows=Q.AcquisitionRows(Q,recipe(Q,1245250),False,False)
check('Live trainer observation still takes precedence',any('Live trainer fixture' in str(v) for row in rows.values() for v in row.cells.values()))
report={'passed':len(checks),'checks':checks,'examples':examples,'environment':'Offline Lua 5.1 frame fixture; not live gameplay'}
(D/'tests.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'passed':len(checks),'updatedRecipes':len(examples)}))
