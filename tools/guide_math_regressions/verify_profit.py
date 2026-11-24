"""Behavioral regressions for filter clarity, route choices, budgets, observations and acquisition."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=[x.strip().replace('\\','/') for x in (ROOT/'ProfPaden.toc').read_text().splitlines() if x.strip().endswith('.lua') and not x.startswith(('Vendor','Companions'))]
results=[]
PLAN='''
P.selectedProf='Alchemy';P.skills.Alchemy={rank=95,cap=150};P.char.planTargets={Alchemy=100}
P.Catalog.Alchemy={};P.Recipes.Alchemy={};P.char.recipes.Alchemy={};P.char.trainers={}
Bag[765]=10;P.market.prices[765]={value=100,time=time()}
local cheap={spell=900001,name='Cheap',profession='Alchemy',mats={{id=765,count=1}},complete=true,yellow=120,grey=150,difficulty='optimal',skillAtCapture=95}
local dear={spell=900002,name='Preferred',profession='Alchemy',mats={{id=765,count=2}},complete=true,yellow=120,grey=150,difficulty='optimal',skillAtCapture=95}
P.Catalog.Alchemy={cheap,dear};P.char.recipes.Alchemy.s900001=cheap;P.char.recipes.Alchemy.s900002=dear;P.live={}
P.tab='Recipes';P.mode='cost'
'''
OBS='''
P.selectedProf='Alchemy';P.skills.Alchemy={rank=95,cap=150};P.ReadSkills=function()end
local r={spell=900001,name='Observed recipe',profession='Alchemy',mats={{id=765,count=1}},complete=true,live=true,difficulty='medium',skillAtCapture=95,yellow=75,grey=115}
P.live={r};P.window:Hide();timers={};C_Timer.After=function(delay,fn)timers[#timers+1]=fn end
function start(guid)P:ObserveCraftEvent('UNIT_SPELLCAST_SENT','player','target',guid,900001)end
function succeed(guid)P:ObserveCraftEvent('UNIT_SPELLCAST_SUCCEEDED','player',guid,900001)end
function flush()local queue=timers;timers={};for _,fn in ipairs(queue)do fn()end end
function stats()return P:ObservedSkills(r,95)end
'''
def run(name,code,setup=''):
 try:
  L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
  loader=L.eval('function(code,ns)assert(loadstring(code))("ProfPaden",ns)end')
  for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
  L.execute('SetupReference();P.window:Hide()');L.execute(setup);L.execute(code)
  results.append(dict(name=name,passed=True))
 except Exception as e:results.append(dict(name=name,passed=False,error=str(e)));traceback.print_exc()

SALE=PLAN+'''
P.mode='profit';P.char.profitSale='vendor'
local a=P.Catalog.Alchemy[1];local b=P.Catalog.Alchemy[2]
a.item=10001;b.item=10002;a.output=1;b.output=2
prices={[10001]=50,[10002]=150};binding={[10001]=2,[10002]=2}
C_Item.GetItemInfo=function(id) if prices[id]~=nil then return 'Output '..id,'item:'..id,1,1,1,'Armor','Mail',20,'',1,prices[id],4,3,binding[id] end end
function choose(label)for _,row in ipairs(P.dropdown.rows)do if row.shown and row.label.text==label then row.scripts.OnClick();return end end;error('Missing menu choice: '..label)end
'''
run('Weapon submenu drills down, preserves parent until selection, and Reset all clears subtype',r'''
P.tab='Catalog';P.catalogFacets={};P:Refresh();P.facetButtons.type.scripts.OnClick()
choose('Weapon >');assert(P.catalogFacets.type==nil);choose('One-handed >');choose('One-handed swords')
assert(P.catalogFacets.type=='Weapon' and P.catalogFacets.subtype==7 and P.facetButtons.type.text=='Type: One-handed swords')
P.facetButtons.type.scripts.OnClick();choose('Armor >');choose('Mail')
assert(P.catalogFacets.type=='Armor' and P.catalogFacets.subtype==3)
P.resetFilters.scripts.OnClick();assert(not next(P.catalogFacets))
''',SALE)
run('Output and quest reward subclasses combine with rarity and reject other types',r'''
P.ItemMeta[10001]={classID=2,subclassID=7,quality=2};P.ItemMeta[10002]={classID=4,subclassID=3,quality=2};C_Item.GetItemInfo=function()end
P.catalogFacets={type='Weapon',subtype=7,quality=2}
assert(P:MatchesFacets({item=10001},false));assert(not P:MatchesFacets({item=10002},false))
P.catalogFacets.quality=3;assert(not P:MatchesFacets({item=10001},false))
P.QuestMeta[123]={rewards={10001,10002}};P.questFacets={type='Armor',subtype=3,quality=2}
assert(P:MatchesFacets({id=123},true));P.questFacets.subtype=4;assert(not P:MatchesFacets({id=123},true))
local f={type='Armor',subtype=99};P:NormalizeFacets(f);assert(f.subtype==nil)
''',SALE)
run('Trainer Show includes structured catalog and recorded offerings, excludes drops',r'''
P.Catalog.Alchemy[1].source='Learned from a master';P.Catalog.Alchemy[1].sourceKind='trainer'
P.Catalog.Alchemy[2].source='World drop';P.tab='Catalog';P.catalogFilter='trainer';P:Refresh()
assert(#P.entries==1 and P.entries[1].spell==900001)
P.Catalog.Alchemy[1].sourceKind='drop';P.char.trainers={Alchemy={s900002={eligible=true,cost=10}}};P:Refresh()
assert(#P.entries==1 and P.entries[1].spell==900002)
P.modeButton.scripts.OnClick();choose('All recipes');assert(#P.entries==2)
P.modeButton.scripts.OnClick();choose('Trainer');assert(#P.entries==1)
''',SALE)
run('Vendor Profit prefers higher net returns, Cheapest remains unchanged',r'''
local p=P:BuildCheapestPlan();assert(p.rows[1].spell==900002 and p.materials==1000 and p.proceeds==1500 and p.net==-500 and p.remaining==0)
assert(#p.rows==1 and p.rows[1].crafts==5 and p.reached==100)
local c=P:BuildCheapestPlan(nil,'cost');assert(c.rows[1].spell==900001 and c.total==500 and c.proceeds==0)
''',SALE)
run('Minimal loss and training fees are included in the route score',r'''
prices[10002]=75;local p=P:BuildCheapestPlan();assert(p.net==250)
P.char.recipes.Alchemy.s900002=nil;P.char.trainers={Alchemy={s900002={eligible=true,required=95,cost=1000}}}
p=P:BuildCheapestPlan();assert(p.rows[1].spell==900001 and p.net==250)
''',SALE)
run('AH proceeds use auction data, output minimum and selected fee, not reagent overrides',r'''
P.char.profitSale='auction5';P.market.prices[10002]={value=999999};P.char.vendors={[10002]={value=999999,stock=-1}}
P.market.observed={[10002]={value=200,time=time(),source='Viewed AH'}}
local s=P:SaleEstimate(P.Catalog.Alchemy[2]);assert(s.gross==200 and s.net==380 and s.cut==.05)
P.char.profitSale='auction15';s=P:SaleEstimate(P.Catalog.Alchemy[2]);assert(s.net==340)
P.Catalog.Alchemy[2].outputMax=10;assert(P:SaleEstimate(P.Catalog.Alchemy[2]).output==2)
''',SALE)
run('Best method compares net proceeds and never sums both sale destinations',r'''
P.char.profitSale='best5';P.market.observed={[10002]={value=100,time=time(),source='AH'}}
assert(P:SaleEstimate(P.Catalog.Alchemy[2]).method=='Vendor')
P.market.observed[10002].value=200;assert(P:SaleEstimate(P.Catalog.Alchemy[2]).net==380)
''',SALE)
run('BoP and unknown binding cannot be auctioned; missing sales create an explained gap',r'''
P.char.profitSale='auction5';P.market.observed={[10001]={value=100,time=time()},[10002]={value=200,time=time()}}
binding[10001]=1;binding[10002]=nil
local p=P:BuildCheapestPlan();assert(#p.rows==0 and p.unsellable==2 and p.reason:find('sellable output'))
P.char.profitSale='vendor';assert(#P:BuildCheapestPlan().rows>0)
''',SALE)
run('Fresh observed AH prices win; stale sources and provider exceptions are handled',r'''
P.market.observed={[10001]={value=25,time=time()-90000}}
Auctionator={API={v1={GetAuctionAgeByItemID=function()return 8 end,GetAuctionPriceByItemID=function()return 100 end}}}
assert(P:AuctionSalePrice(10001)==nil)
Auctionator.API.v1.GetAuctionAgeByItemID=function()return 2 end
local v,source,stamp=P:AuctionSalePrice(10001);assert(v==100 and source=='Auctionator estimate' and stamp==time()-2*86400)
AucAdvanced={API={GetMarketValue=function()error('offline')end}};assert(P:AuctionSalePrice(10001)==100)
P.market.observed[10001]={value=35,time=time(),source='AH sample'};assert(P:AuctionSalePrice(10001)==35)
''',SALE)
run('Profit menu, goal, cache separation and cost table show the selected method',r'''
P.mode='cost';P:Refresh();P.modeButton.scripts.OnClick();choose('Profit / minimal loss >');choose('Vendor only')
assert(P.mode=='profit' and P.planGoal.shown and not P.excludeRecipe.shown and not P.resetChoices.shown)
assert(P.planSummary.rows[1].spell==900002 and P.listHint.text:find('profit'))
local text='';for _,row in ipairs(P.currentDetailRows)do text=text..table.concat(row.cells,' ')..'\n'end
assert(text:find('SALE ESTIMATE') and text:find('Vendor only') and text:find('Est. profit') and text:find('Gross / item'))
assert(P:SmallMoney(-150)=='-1s 50c')
P.mode='cost';P:Refresh();assert(P.planSummary.rows[1].spell==900001)
''',SALE)
run('Shopping preserves profit materials and marks changes of objective or fee stale',r'''
P.char.shoppingPlans=nil;assert(P:BuildShopping(5));local p=P:ShoppingPlan()
assert(p.objective=='profit' and p.saleKey=='vendor' and p.needs[765]==10 and p.net==-500 and not P:ShoppingIsStale())
P:CreateShoppingUI();P:RefreshShopping();assert(P.shoppingWindow.route.text:find('Vendor only') and P.shoppingWindow.route.text:find('Est. profit'))
local _,lines=P.shoppingWindow.summary.text:gsub('\n','');assert(lines==2)
P.char.profitSale='best15';assert(P:ShoppingIsStale());P.char.profitSale='vendor';assert(not P:ShoppingIsStale())
P.mode='cost';assert(P:ShoppingIsStale());assert(P:BuildShopping(5));assert(P:ShoppingPlan().needs[765]==5)
''',SALE)
run('Profit scan adds unique outputs while Cheapest retains reagent-only scans',r'''
P.auctionOpen=true;C_AuctionHouse={SendSearchQuery=function()end};P.NextPriceQuery=function()end
P:StartPriceScan();local seen={};for _,id in ipairs(P.priceScan.ids)do assert(not seen[id]);seen[id]=true end
assert(seen[10001] and seen[10002] and seen[765]);P:StopPriceScan()
P.mode='cost';P:StartPriceScan();assert(#P.priceScan.ids==1 and P.priceScan.ids[1]==765)
''',SALE)
run('Unavailable recipes, enchants and cooldowns do not become profit candidates',r'''
P.Catalog.Alchemy[2].enchant=true;assert(P:BuildCheapestPlan().rows[1].spell==900001)
P.Catalog.Alchemy[1].cooldown=100;assert(#P:BuildCheapestPlan().rows==0)
P.Catalog.Alchemy[1].cooldown=0;P.char.recipes.Alchemy={};assert(#P:BuildCheapestPlan().rows==0)
''',SALE)
run('No profitable output is added beyond the skill goal and repeat segments do not farm rounding crafts',r'''
P.Catalog.Alchemy[1].grey=95;P.Catalog.Alchemy[2].difficulty='medium';P.Catalog.Alchemy[2].yellow=90;P.Catalog.Alchemy[2].grey=110
local p=P:BuildCheapestPlan();assert(p.reached==100 and #p.rows==1)
local expected=0;for skill=95,99 do expected=expected+1/P:PlanChance(p.rows[1],skill,95) end
assert(p.rows[1].crafts==math.ceil(expected-.0000001))
P.skills.Alchemy.rank=150;assert(#P:BuildCheapestPlan().rows==0)
''',SALE)
report=dict(runtime='Actual Lua 5.1 modules with mocked client APIs; no live-game actions',tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'profit-test-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
