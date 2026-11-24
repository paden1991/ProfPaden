"""Regressions for the October 16 in-game screenshots."""
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

MODERN='''
P.selectedProf='Blacksmithing';P.skills.Blacksmithing={rank=95,cap=150};P.openKind='trade'
P.char.planTargets={Blacksmithing=100};P.char.trainers={};P.Recipes.Blacksmithing={}
local r={name='Fixture craft',spell=900001,item=900002,learn=1,yellow=75,grey=115,mats={{id=2840,count=10}},complete=true}
P.Catalog.Blacksmithing={r};P.char.recipes.Blacksmithing={s900001=r};P.market.prices[2840]={value=50,time=time()};Bag[2840]=100
Enum={TradeskillRelativeDifficulty={Optimal=0,Medium=1,Easy=2,Trivial=3},CraftingReagentType={Basic=1}}
info={name=r.name,learned=true,relativeDifficulty=1,canSkillUp=true,maxTrivialLevel=115,numSkillUps=1,craftable=false}
C_TradeSkillUI={
 GetBaseProfessionInfo=function()return {professionID=164,skillLevel=95,maxSkillLevel=150}end,
 GetAllRecipeIDs=function()return {900001}end,
 GetRecipeInfo=function()return info end,
 GetRecipeSchematic=function()return {outputItemID=900002,quantityMin=1,quantityMax=1,reagentSlotSchematics={{required=true,reagentType=1,reagents={{itemID=2840}},quantityRequired=10}}}end,
 GetCraftableCount=function()return 0 end,
 GetRecipeRequirements=function()return {{met=false,name='Anvil'}}end,
 CraftRecipe=function()error('Craft should not be sent without station')end}
'''
run('Opening a profession without its station preserves the learned cheapest route', '''
local before=P:BuildCheapestPlan();assert(before.reached==100 and before.known==1)
P:ScanRecipes();assert(#P.live==1 and P.live[1].blocked:find('Anvil'))
local after=P:BuildCheapestPlan();assert(after.reached==100 and after.known==1 and #after.rows>0)
local ok,reason=P:Craft(after.rows[1],1);assert(not ok and reason:find('Anvil'))
P.planSummary=after;local text='';for _,r in ipairs(P:DetailRows(after.rows[1],1))do text=text..table.concat(r.cells,' ')end
assert(text:find('Craft requires',1,true) and text:find('Anvil',1,true))
''',MODERN)
run('Empty bags and craftable=false affect craft readiness, not leveling or shopping', '''
C_TradeSkillUI.GetRecipeRequirements=function()return {}end;Bag[2840]=0
P:ScanRecipes();local plan=P:BuildCheapestPlan();assert(plan.reached==100 and plan.shopping>0)
assert(P:Available(P.live[1])==0);assert(not P:Craft(plan.rows[1],1))
local ok=P:BuildShopping(5);assert(ok);assert(P:ShoppingPlan() and P:ShoppingPlan().needs[2840]>0)
''',MODERN)
run('Profession loading events retain cached learned-route data and disable stale craft actions', '''
P:ScanRecipes();C_TradeSkillUI.IsDataSourceChanging=function()return true end;P:ScanRecipes()
assert(#P.live==0 and P.char.recipes.Blacksmithing.s900001)
local plan=P:BuildCheapestPlan();assert(plan.reached==100 and plan.rows[1].cached)
assert(not P:Craft(plan.rows[1],1))
''',MODERN)
run('Unsupported salvage recipes remain excluded from both live and cached plans', '''
info.isSalvageRecipe=true;P:ScanRecipes();assert(P.live[1].planBlocked)
assert(P:BuildCheapestPlan().reached==95)
P.openKind=nil;P:ScanRecipes();assert(P:BuildCheapestPlan().reached==95)
''',MODERN)
run('Skill ranges and probabilities use Classic-font-safe text', '''
P:ScanRecipes();local p=P:BuildCheapestPlan();P.planSummary=p
local rows=P:DetailRows(p.rows[1],8);local text=''
for _,row in ipairs(rows)do text=text..table.concat(row.cells,' ')end
assert(text:find('95 to 100',1,true) and text:find('% to ',1,true))
assert(not text:find('→',1,true));assert(P:SmallMoney(nil)=='-')
assert(P:BriefSource('Learn at ≈45')=='Learn at ~45')
''',MODERN)
run('Gilnid and dungeon vendors retain their dungeon and explicitly labeled entrance waypoint', '''
local n=P.NPCSources[1763];assert(n.name=='Gilnid' and #n.points==0 and n.locations[1]=='The Deadmines')
local text=P:NPCSourceText(1763,true)
assert(text:find('The Deadmines',1,true) and text:find('Entrance: Westfall',1,true))
assert(text:find('profpaden:npc:1763:drop',1,true))
local target=P:NearestNPC({1763},nil,true);assert(target.point.entrance=='The Deadmines' and target.point.map==1436)
assert(P:NPCSourceText(12944):find('Blackrock Depths',1,true))
''')
run('Forever NPCs absent from Questie retain Wowhead names and source zones', '''
assert(P:NPCSourceText(264797):find('Aisarra Nightmeadow',1,true))
assert(P:NPCSourceText(264797):find('Mount Hyjal',1,true))
assert(P:NPCSourceText(250657,true):find('Ruins of Lordaeron',1,true))
''')
run('Drop links allow hostile targets while vendor directions retain faction checks', '''
local pin
C_Map={GetBestMapForUnit=function()return 1 end,SetUserWaypoint=function(p)pin=p end}
UiMapPoint={CreateFromCoordinates=function(map,x,y)return {map=map,x=x,y=y}end}
P.NPCSources[999]={name='Enemy drop',faction='H',points={{map=1,x=.2,y=.3,zone='Test'}}}
assert(not P:TrackNPC(999));P.detailChild.scripts.OnHyperlinkClick(nil,'profpaden:npc:999:drop')
assert(pin and pin.x==.2 and P.navTarget.npc.name=='Enemy drop')
''')
run('Observed trainer and opposing vendor detail text retain recorded locations', '''
P.NPCSources[999]={name='Trainer',faction='A',points={{map=1,x=.2,y=.3,zone='Test Zone'}}}
P.char.trainers={Alchemy={s999={npcID=999,cost=100}}}
local text='';for _,r in ipairs(P:DetailRows({spell=999,name='Recipe',mats={}},1))do text=text..table.concat(r.cells,' ')end
assert(text:find('Test Zone 20.0, 30.0',1,true))
P.NPCSources[999].faction='H';assert(P:NPCSourceText(999):find('Test Zone',1,true))
assert(not P:NPCSourceText(999):find('|H',1,true))
''')
audit=json.loads((REPORTS/'npc-location-audit.json').read_text())
missing=[x for x in audit if not x['coordinates'] and not x['locations']]
results.append(dict(name='All recipe-source NPC references audited; unresolved locations explicitly listed',passed=all(x['name'] for x in audit) and {x['id'] for x in missing}<={1800,1801,417,5224,5225},referenced=len(audit),unlocated=missing))
report=dict(runtime='Actual Lua 5.1 modules; mocked profession and navigation APIs',tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'client-fixes-test-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
