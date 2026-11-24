"""Behavioral regressions for client fixes, including a deterministic AH clock."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=['Core.lua','Data/Recipes.lua','Data/Catalog.lua','Data/FieldGuide.lua','Data/Research.lua','Data/GatherVisuals.lua','Data/Details.lua','Adapter.lua','ModernAdapter.lua','Planner.lua','Cheapest.lua','MarketRoutes.lua','MoneyRoutes.lua','Sourcing.lua','Costs.lua','Catalog.lua','CampFood.lua','Camping.lua','Minimap.lua','QuestBridge.lua','GatherMaps.lua','Tooltips.lua','Shopping.lua','ShoppingRoutes.lua','AuctionatorBridge.lua','AuctionatorScan.lua','ShoppingUI.lua','Navigation.lua','NavigationGoals.lua','Details.lua','ProfessionAccess.lua','Materials.lua','MaterialFilters.lua','UI.lua']
results=[]
def run(name,code,setup=''):
 try:
  L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
  loader=L.eval('function(code,ns)local f,e=loadstring(code);assert(f,e);f("ProfPaden",ns)end')
  for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
  L.execute('SetupReference();P.window:Hide()');L.execute(setup);L.execute(code)
  results.append(dict(name=name,passed=True))
 except Exception as e:results.append(dict(name=name,passed=False,error=str(e)));traceback.print_exc()

run('Yellow and green fallback probabilities reduced by 20 percent; orange and grey unchanged','''
for color,expected in pairs({optimal=1,medium=.4,easy=.16,trivial=0})do
 local r={difficulty=color,skillAtCapture=95}
 assert(math.abs(P:Chance(r,95)-expected)<.000001)
 assert(P:PlanChance(r,95,95)==P:Chance(r,95))
 assert(P:PlanChance(r,96,95)==nil,'No invented future curve')
end
''')
run('Threshold-only probabilities are discounted once and cannot rise with skill','''
local r={yellow=75,grey=115};assert(P:PlanChance(r,74,74)==1)
local previous=1
for skill=75,115 do
 local p=P:PlanChance(r,skill,75)
 assert(p<=previous and p>=0);previous=p
 assert(math.abs(p-math.max(0,(115-skill)/40)*.8)<.000001)
end
assert(P:PlanChance(r,116,75)==0)
''')
run('Live and cached yellow observations anchor a declining future curve instead of a jump','''
local r={yellow=85,grey=125,difficulty='medium',skillAtCapture=95,live=true}
local previous=.4
for skill=95,125 do
 local p=P:PlanChance(r,skill,95);assert(p<=previous+.0000001);previous=p
 assert(math.abs(p-P:Chance(r,skill))<.000001)
end
local live=P:PlanChance(r,99,95);r.live=nil;r.cached=true
assert(math.abs(live-P:PlanChance(r,99,95))<.000001)
assert(math.abs(live-.4*26/30)<.000001)
''')
run('A known green recipe stays conservative as its grey threshold approaches','''
local r={yellow=75,grey=115,difficulty='easy',skillAtCapture=95}
assert(P:PlanChance(r,95,95)==.16)
assert(math.abs(P:PlanChance(r,105,95)-.08)<.000001)
assert(P:PlanChance(r,115,95)==0)
''')

PLAN='''
P.selectedProf='Blacksmithing';P.skills.Blacksmithing={rank=95,cap=150}
P.char.planTargets={Blacksmithing=100};P.char.trainers={};P.Recipes.Blacksmithing={};P.live={}
local r={name='Runed Copper Belt',spell=2666,item=2857,learn=45,yellow=85,grey=125,mats={{id=2840,count=10}},complete=true,difficulty='medium',skillAtCapture=95}
P.Catalog.Blacksmithing={r};P.char.recipes.Blacksmithing={s2666=r};P.market.prices[2840]={value=50,time=time()};Bag[2840]=0
'''
run('Revised crafts, route budget and shopping quantities agree for skill 95 to 100','''
local plan=P:BuildCheapestPlan();assert(plan.reached==100 and #plan.rows==1)
assert(plan.rows[1].crafts==14 and plan.materials==7000 and plan.shopping==7000)
assert(P:BuildShopping(5));assert(P:ShoppingPlan().needs[2840]==140)
assert(P:ShoppingRow(2840).cost==7000 and not P:ShoppingIsStale())
''',PLAN)
run('Cheapest can switch to an orange alternative after accounting for missed skill-ups','''
local r={name='Orange alternative',spell=9999,item=9998,learn=95,yellow=110,grey=130,mats={{id=2840,count=20}},complete=true}
table.insert(P.Catalog.Blacksmithing,r);P.char.recipes.Blacksmithing.s9999=r
local plan=P:BuildCheapestPlan();assert(plan.rows[1].spell==9999 and plan.materials==5000)
''',PLAN)
run('Old shopping plans require rebuild without losing mail credit or saved quantities','''
assert(P:BuildShopping(5));local old=P:ShoppingPlan();old.chanceModel=nil;old.needs[2840]=80
P:ShoppingTransit(2840).count=20
assert(P:ShoppingIsStale() and P:ShoppingPlan()==old and old.needs[2840]==80)
assert(P:BuildShopping(5) and not P:ShoppingIsStale())
assert(P:ShoppingRow(2840).pending==20 and P:ShoppingRow(2840).missing==120)
''',PLAN)
run('Detail panel labels the reduced forecast and explains additional attempts','''
local p=P:BuildCheapestPlan();P.planSummary=p;local text=''
for _,row in ipairs(P:DetailRows(p.rows[1],14))do text=text..table.concat(row.cells,' ')end
assert(text:find('40% to 35% conservative estimate',1,true))
assert(text:find('20% planning reduction',1,true) and text:find('Skill gains remain random',1,true))
''',PLAN)
report=dict(runtime='Actual Lua 5.1 modules; deterministic probability, route and shopping fixtures',tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'chances-test-results.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
