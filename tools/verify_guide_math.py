"""Independent numeric fixtures for purchase prices, skill forecasts and margins."""
from pathlib import Path
import json,sys,traceback
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1];A=ROOT/'ProfPaden';D=ROOT/'docs/guide-math-2026-11-24';D.mkdir(exist_ok=True)
results=[]
SETUP='''
Clock=100000;function time()return Clock end
Bag={};C_Item={GetItemCount=function(id)return Bag[id] or 0 end,GetItemInfo=function(id)return 'Output','item:'..id,1,1,1,'Armor','Cloth',20,'',1,50,4,1,2 end}
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
C_Timer={After=function()end};function InCombatLockdown()return false end
P={name='ProfPaden',mode='cost',selectedProf='Alchemy',skills={Alchemy={rank=100,cap=150}},live={},Catalog={Alchemy={}},Recipes={Alchemy={}},Items={},VendorSupplies={},SpellMeta={},ItemMeta={},
char={recipes={Alchemy={}},trainers={},vendors={},planTargets={Alchemy=105}},market={prices={},observed={}}}
function P:Count(id)return Bag[id] or 0 end
function P:Resolve(r)for _,x in ipairs(self.live)do if x.spell==r.spell then return x end end end
function P.SameRecipe(a,b)return a.spell==b.spell end
function P:ShoppingTransit(id)return {count=0} end
function P:NextProfessionRank()end
function P:Money(n)return n and tostring(n) or 'Unknown' end
function P:SmallMoney(n)return self:Money(n)end
function P:ItemName(id)return 'Item '..id end
function P:ScanStatus(s)self.priceStatus=s end
function P:CancelShoppingSearch()end
function P:IsAuctionatorScanning()return false end
function recipe(id,mat,count)
 local r={spell=id,item=id+1000,name='Recipe '..id,profession='Alchemy',learn=1,yellow=130,green=140,grey=150,mats={{id=mat,count=count or 1}},complete=true,output=1}
 P.Catalog.Alchemy[#P.Catalog.Alchemy+1]=r;P.char.recipes.Alchemy['s'..id]=r;return r
end
'''
def run(name,code):
 try:
  L=LuaRuntime();L.execute(SETUP);P=L.globals().P
  for f in ['Planner.lua','Cheapest.lua','MarketRoutes.lua','MoneyRoutes.lua','Sourcing.lua','Costs.lua','AuctionatorBridge.lua','RouteStops.lua']:
   L.execute((A/f).read_text(encoding='utf8'),'ProfPaden',P)
  L.execute(code);results.append({'name':name,'passed':True})
 except Exception as e:results.append({'name':name,'passed':False,'error':str(e)})
run('Cheapest compares unlimited vendor and AH prices; explicit overrides still win','''
P.VendorSupplies[1]={value=100};P.market.observed[1]={value=40,time=Clock,source='AH'}
local price,_,_,method=P:Price(1,5);assert(price==40 and method=='auction')
assert(P:MoneyInputPrice(1)==40);P.market.prices[1]={value=0,time=Clock};assert(P:Price(1)==0)
''')
run('Missing timestamps and invalid prices are ignored; stale Auctionator data is excluded','''
P.market.observed[1]={value=3};assert(P:Price(1)==nil)
P.market.prices[1]={value=-1};assert(P:Price(1)==nil)
Auctionator={API={v1={GetAuctionPriceByItemID=function()return 1 end,GetAuctionAgeByItemID=function()return 20 end}}};assert(P:Price(1)==nil)
TSM_API={GetCustomPriceValue=function()return 70 end};AucAdvanced={API={GetMarketValue=function()return 60 end}};assert(P:Price(1)==60)
''')
run('A newer database refresh invalidates route and shopping estimates and refreshes visible guide','''
local cb;Auctionator={API={v1={RegisterForDBUpdate=function(_,f)cb=f end}}};P:ConnectAuctionator()
P.planCache={};P.journeyGuideCache={};P.shoppingDirty=false;local refreshed=0;P.window={IsShown=function()return true end};function P:Refresh()refreshed=refreshed+1 end
cb();assert(not P.planCache and not P.journeyGuideCache and P.shoppingDirty and refreshed==1)
''')
run('One three-point orange craft crosses a yellow boundary and reaches 103','''
local r=recipe(1,10);r.numSkillUps=3;r.yellow=101;r.green=102;r.grey=110;P.market.prices[10]={value=100}
local p=P:BuildCheapestPlan(103);assert(p.reached==103 and #p.rows==1 and p.rows[1].crafts==1 and p.total==100)
local rows=P:SplitRouteBands(p.rows);assert(#rows==1 and rows[1].start==100 and rows[1].stop==103 and rows[1].crafts==1)
''')
run('Multi-point recipes cannot hand off at an unreachable intermediate skill','''
local r=recipe(1,10);r.numSkillUps=3;P.market.prices[10]={value=100}
local b=recipe(2,11);P.market.prices[11]={value=1};P.char.recipes.Alchemy.s2=nil;P.char.trainers.Alchemy={s2={eligible=true,required=101,cost=0}}
local p=P:BuildCheapestPlan(104);assert(p.total==101 and p.rows[1].stop==103 and p.rows[2].start==103)
''')
run('Yellow craft count integrates declining chances and remaining count is recalculated','''
P.skills.Alchemy.rank=95;local r=recipe(1,10);r.yellow=85;r.grey=125;r.green=nil;r.difficulty='medium';r.skillAtCapture=95;P.market.prices[10]={value=100}
local p=P:BuildCheapestPlan(100);assert(#p.rows==1 and p.rows[1].crafts==14 and p.total==1400)
P.skills.Alchemy.rank=99;assert(P:StepCrafts(p.rows[1])==3)
''')
run('A price for one limited-stock item cannot price an unquoted larger batch at zero','''
recipe(1,10);P.char.vendors[10]={value=100,name='Limited',stock=1};local p=P:BuildCheapestPlan(105)
assert(p.reached<105 and p.total>0 and p.reason)
''')
run('Shared limited vendor stock is checked for the combined route, not reused per step','''
local a=recipe(1,10);a.grey=101;a.yellow=101;recipe(2,10)
P.char.vendors[10]={value=10,name='Limited',stock=1}
local p=P:BuildCheapestPlan(102);assert(p.reached==101 and p.total==10)
''')
run('Duplicate raw inputs from separate conversions use the aggregate purchase quote','''
local a=recipe(1,10,2);a.item=20;local b=recipe(2,10,2);b.item=21
P.char.vendors[10]={value=10,name='Limited',stock=3};P.market.observed[10]={value=100,time=Clock,source='AH'}
local p=P:SourceNeeds({[20]=1,[21]=1});assert(p.cost==400 and p.buy[10]==4)
''')
run('Owned inputs reduce spending once and do not turn full-cost profit into free profit','''
recipe(1,10,2);P.market.prices[10]={value=100};Bag[10]=3
local p=P:BuildCheapestPlan(102);assert(p.total==400 and p.shopping==100 and p.owned==300)
''')
run('Scan covers live-only recipes, transitive conversion inputs and money-making outputs','''
local a=recipe(1,20);local b=recipe(2,10);b.item=20
P.Catalog.Alchemy={a};P.live={{spell=3,item=1003,profession='Alchemy',mats={{id=30,count=1}},complete=true}}
P.mode='money';P.auctionOpen=true;C_AuctionHouse={SendSearchQuery=function()end};function P:NextPriceQuery()end
P:StartPriceScan();local found={};for _,id in ipairs(P.priceScan.ids)do assert(not found[id]);found[id]=true end
assert(found[10] and found[20] and found[30] and found[1001] and found[1003])
P:StopPriceScan();recipe(4,40);P:StartPriceScan();found={};for _,id in ipairs(P.priceScan.ids)do found[id]=true end;assert(found[40])
''')
run('Margins use all materials, training once, minimum yield and selected auction cut','''
local r=recipe(1,10,2);r.output=2;r.outputMax=5;P.market.observed[10]={value=100,time=Clock};P.market.observed[r.item]={value=300,time=Clock};P.char.profitSale='auction5'
local s=P:SaleEstimate(r);assert(s.net==570 and s.output==2)
P.char.recipes.Alchemy.s1=nil;P.char.trainers.Alchemy={s1={eligible=true,required=100,cost=500}}
local p=P:BuildCheapestPlan(102,'profit');assert(p.materials==400 and p.training==500 and p.proceeds==1140 and p.net==-240)
P.char.profitSale='auction15';assert(P:SaleEstimate(r).net==510)
''')
run('Unknown or invalid output quantities never become a fabricated profit opportunity','''
local r=recipe(1,10);P.market.observed[r.item]={value=500,time=Clock};P.char.profitSale='auction5';r.output=0;assert(P:SaleEstimate(r)==nil)
r.output=0/0;assert(P:SaleEstimate(r)==nil)
''')
run('Guided unknown prices are subtotal-labelled and invalid reagent counts cannot enter a route','''
local r=recipe(1,10);local p=P:BuildCheapestPlan(102,'cost',{kind='guide',bands={s1={{start=100,stop=105,order=1}}}})
assert(p.priceIncomplete and p.reached==102);P.planSummary=p;assert(P:PlanSummaryText():find('Priced materials subtotal',1,true))
r.mats[1].count=-1;P:InvalidatePlan();p=P:BuildCheapestPlan(102,'cost',{kind='guide',bands={s1={{start=100,stop=105,order=1}}}});assert(p.reached==100)
''')
run('Allocated step costs sum to the aggregate route when limited vendor stock runs out','''
local a=recipe(1,10);a.grey=101;a.yellow=101;recipe(2,10)
P.char.vendors[10]={value=10,name='Limited',stock=1};P.market.observed[10]={value=100,time=Clock}
local p=P:BuildCheapestPlan(102);local total=0;for _,r in ipairs(p.rows)do total=total+r.planCost end
assert(p.reached==102 and p.materials==200 and total==200)
''')
run('Returning to a previously trained recipe does not charge its fee twice','''
recipe(1,10);recipe(2,11);P.market.prices[10]={value=10};P.market.prices[11]={value=20};P.char.recipes.Alchemy={}
P.char.trainers.Alchemy={s1={eligible=true,required=100,cost=500},s2={eligible=true,required=101,cost=700}}
function P:PlanChance(r,s)return (r.spell==1 and s~=101 or r.spell==2 and s==101) and 1 or 0 end
local p=P:BuildCheapestPlan(103);assert(p.reached==103 and #p.rows==3 and p.training==1200 and p.materials==40 and p.total==1240)
''')
report={'tests':len(results),'passed':sum(x['passed'] for x in results),'results':results,'scope':'Actual production Lua 5.1 with deterministic independent numeric fixtures; no live transactions'}
(D/('math-baseline.json' if '--baseline' in sys.argv else 'math-checks.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(report['passed']!=report['tests'])
