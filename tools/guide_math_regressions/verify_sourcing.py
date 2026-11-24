"""Shared buy-vs-make sourcing checks across all planning modes."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=[x.strip().replace('\\','/') for x in (ROOT/'ProfPaden.toc').read_text().splitlines() if x.strip().endswith('.lua') and not x.startswith(('Vendor','Companions'))]
SETUP='''
SetupReference();P.selectedProf='Blacksmithing';P.skills={Blacksmithing={rank=100,cap=150},Mining={rank=100,cap=150},Tailoring={rank=100,cap=150}}
P.live={};P.char.recipes={};P.char.trainers={};P.Catalog={};P.Recipes={};P.char.vendors={};P.char.unlimitedVendors={};P.market.prices={};P.market.observed={};P.char.shoppingTransit={}
Auctionator=nil;AucAdvanced=nil;TSM_API=nil
for _,id in ipairs({2840,2770,2996,2589,10001})do Bag[id]=0 end
function quote(id,p)P.market.prices[id]={value=p,time=time()};P.market.observed[id]={value=p,time=time(),source='Viewed AH'} end
quote(2840,100);quote(2770,20);quote(2996,100);quote(2589,10);quote(10001,500)
root={name='Test cloak',spell=900001,item=10001,profession='Blacksmithing',mats={{id=2840,count=2},{id=2996,count=1}},complete=true,yellow=130,grey=150,start=100,stop=110,crafts=10,kind='guide'}
bar={name='Smelt Copper',spell=900002,item=2840,profession='Mining',mats={{id=2770,count=1}},complete=true,output=1}
bolt={name='Bolt of Linen',spell=900003,item=2996,profession='Tailoring',mats={{id=2589,count=2}},complete=true,output=1}
P.char.recipes.Blacksmithing={s900001=root};P.char.recipes.Mining={s900002=bar};P.char.recipes.Tailoring={s900003=bolt}
P.Catalog.Blacksmithing={root};P.Catalog.Mining={bar};P.Catalog.Tailoring={bolt};P.Recipes.Blacksmithing={root}
C_Item.GetItemInfo=function(id)return 'Item '..id,'item:'..id,1,1,1,'Armor','Cloth',20,'',1,500,4,1,0 end
P:InvalidatePlan();P.mode='cost';P.tab='Recipes';P.ReadSkills=function()end
'''
results=[]
def run(name,code):
 try:
  L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
  loader=L.eval('function(code,p)assert(loadstring(code))("ProfPaden",p)end')
  for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
  L.execute(SETUP);L.execute(code);results.append(dict(name=name,passed=True))
 except Exception as e:results.append(dict(name=name,passed=False,error=str(e)));traceback.print_exc()
run('Ore and cloth conversions lower recipe costs across professions', '''
local e=P:Economy(root,10);assert(e.cost==600 and e.missing==600 and #e.sourcePlan.steps==2)
assert(e.sourcePlan.needs[2770]==20 and e.sourcePlan.needs[2589]==20 and not e.sourcePlan.needs[2840])
''')
run('Direct purchase wins when cheaper and intermediate quotes can be absent', '''
quote(2840,5);local s=P:SourceRecipe(root,1);assert(s.cost==30 and s.needs[2840]==2 and #s.steps==1)
P.market.prices[2840]=nil;P.market.observed[2840]=nil;assert(P:SourceRecipe(root,1).cost==60)
''')
run('Owned intermediate and raw inputs are allocated once', '''
Bag[2840]=1;Bag[2770]=1;Bag[2589]=1;local e=P:Economy(root,1)
assert(e.cost==60 and e.missing==10 and e.owned==50)
assert(e.missingPlan.needs[2840]==1 and e.missingPlan.buy[2770]==0 and e.missingPlan.buy[2589]==1)
''')
run('Minimum yields round whole batches and do not credit surplus', '''
bar.output=2;bar.outputMax=10;P:InvalidatePlan();local s=P:SourceNeeds({[2840]=3})
assert(s.cost==40 and s.needs[2770]==2 and s.steps[1].crafts==2 and s.steps[1].output==4)
''')
run('Nested conversion steps are ordered before their consumers', '''
bar.mats={{id=2996,count=1}};P:InvalidatePlan();local s=P:SourceNeeds({[2840]=3})
assert(s.cost==60 and #s.steps==2 and s.steps[1].item==2996 and s.steps[2].item==2840)
''')
run('Unavailable professions, unlearned conversions and active cooldowns stay out', '''
P.skills.Mining=nil;P:InvalidatePlan();assert(P:Economy(root).cost==220)
P.skills.Mining={rank=100,cap=150};P.char.recipes.Mining={};P:InvalidatePlan();assert(P:Economy(root).cost==220)
P.char.recipes.Mining.s900002=bar;bar.cooldown=100;P:InvalidatePlan();assert(P:Economy(root).cost==220)
''')
run('Cycles terminate without treating missing prices as free', '''
bar.mats={{id=2996,count=1}};bolt.mats={{id=2840,count=1}};P.market.prices={};P.market.observed={};P:InvalidatePlan()
local s=P:SourceNeeds({[2840]=3});assert(s.cost==nil and s.unknown>0 and #s.steps==0)
''')
run('Cheapest and profit routes use shared conversion costs', '''
P.char.profitSale='vendor';local c=P:BuildCheapestPlan(105,'cost');assert(c.materials==300 and c.shopping==300)
local p=P:BuildCheapestPlan(105,'profit');assert(p.materials==300 and p.proceeds==2500 and p.net==-2200)
''')
run('Every shopping mode exports base inputs and exposes preparation steps', '''
P.char.shoppingOptions={Blacksmithing={mode='guide',saleKey='vendor',target=105,goal='fixed'}}
for _,mode in ipairs({'guide','cost','profit','bags','all','live'})do
 P.char.shoppingOptions.Blacksmithing.mode=mode
 if mode=='live' then root.profession='Blacksmithing';P.live={root};root.skillAtCapture=100 end
 P:InvalidatePlan();P:EnsureShoppingPlan(true);local rows=P:ShoppingRows();assert(#rows==2,mode)
 local found={};for _,r in ipairs(rows)do found[r.item]=r.required end
 assert(found[2770]==10 and found[2589]==10 and #P:ShoppingPlan().preparation==2,mode)
end
P.auctionOpen=true;P.shoppingHooks=true;local terms;Auctionator={API={v1={MultiSearchAdvanced=function(_,v)terms=v end}}}
assert(P:ShopWithAuctionator());assert(#terms==2 and terms[1].quantity==10 and terms[2].quantity==10)
''')
run('Bag and mail updates reconcile raw and intermediate supplies without double credit', '''
P.char.shoppingOptions={Blacksmithing={mode='cost',saleKey='vendor',target=101,goal='fixed'}};P:EnsureShoppingPlan(true)
P:ShoppingTransit(2770).count=2;local rows=P:ShoppingRows();local missing={};for _,r in ipairs(rows)do missing[r.item]=r.missing end
assert(missing[2770]==0 and missing[2589]==2)
Bag[2770]=2;rows=P:ShoppingRows();assert(P:ShoppingTransit(2770).count==0)
Bag[2770]=0;Bag[2840]=2;rows=P:ShoppingRows();missing={};for _,r in ipairs(rows)do missing[r.item]=r.missing end
assert(missing[2840]==0 and not missing[2770])
''')
run('Money-making buys base inputs despite bags and excludes vendor leaves on export', '''
P.mode='money';P.char.moneySale='auction5';Bag[2840]=999;Bag[2770]=999
P.char.vendors[2589]={stock=-1,value=2,name='Test supplier',time=time()};P.char.moneyBatches={Blacksmithing=10}
local r=P:Rows()[1];assert(r.moneyCost==440 and r.moneyProfit==4310)
P.auctionOpen=true;local terms;Auctionator={API={v1={MultiSearchAdvanced=function(_,v)terms=v end}}}
assert(P:ExportMoneyInputs(r,10));assert(#terms==1 and terms[1].quantity==20 and terms[1].searchString=='Item 2770')
''')
run('Catalog and ordinary guide details show conversions and base-material needs', '''
local rows=P:DetailRows(root,2);local hasPrep,hasBase=false,false
for _,r in ipairs(rows)do if r.cells[1]=='MAKE INTERMEDIATE MATERIALS FIRST' then hasPrep=true end;if r.cells[1]=='BASE MATERIALS TO BUY' then hasBase=true end end
assert(hasPrep and hasBase)
''')
run('Live cooldown prevents stale cached conversion fallback', '''
P.live={{name=bar.name,spell=bar.spell,item=bar.item,profession='Mining',mats=bar.mats,complete=true,cooldown=60}}
P:InvalidatePlan();assert(P:Economy(root).cost==220)
''')
run('Shared raw inventory is consumed once across different conversion branches', '''
bolt.mats={{id=2770,count=2}};Bag[2770]=3;P:InvalidatePlan()
local s=P:SourceRecipe(root,1,{bags=true});assert(s.needs[2770]==4 and s.buy[2770]==1 and s.cost==20)
''')
run('In-my-bags guide includes learned preparation from owned base inputs', '''
P.mode='bags';root.skillAtCapture=100;root.difficulty='optimal';P.live={root};Bag[2770]=2;Bag[2589]=2;P:InvalidatePlan()
local rows=P:Rows();assert(#rows==1 and rows[1].ready==0 and rows[1].preparationReady)
Bag[2770]=1;assert(#P:Rows()==0)
''')
report=dict(tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'sourcing-test-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));sys.exit(report['tests']!=report['passed'])
