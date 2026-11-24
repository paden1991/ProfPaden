"""Offline Lua 5.1 integration regressions for route execution and color changes."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=[x.strip().replace('\\','/') for x in (ROOT/'ProfPaden.toc').read_text().splitlines() if x.strip().endswith('.lua') and not x.startswith(('Vendor','Companions'))]
SETUP='''
SetupReference();P.selectedProf='Blacksmithing';P.skills={Blacksmithing={rank=94,cap=150},Mining={rank=100,cap=150}}
P.live={};P.char.recipes={};P.char.trainers={};P.char.vendorOffers={};P.char.trainerOffers={};P.Catalog={};P.Recipes={};P.char.vendors={};P.char.unlimitedVendors={};P.market.prices={};P.market.observed={};P.char.shoppingTransit={}
Auctionator=nil;AucAdvanced=nil;TSM_API=nil
for _,id in ipairs({2840,2770,2320,10001})do Bag[id]=0 end
function quote(id,p)P.market.prices[id]={value=p,time=time()} end
quote(2840,100);quote(2770,20);quote(10001,500)
root={name='Practice mail',spell=900001,item=10001,profession='Blacksmithing',mats={{id=2840,count=2},{id=2320,count=1}},complete=true,yellow=95,green=100,grey=110,start=94,stop=104,crafts=40,kind='guide',key='root'}
bar={name='Smelt Copper',spell=900002,item=2840,profession='Mining',mats={{id=2770,count=1}},complete=true,output=1}
P.char.recipes.Blacksmithing={s900001=root};P.char.recipes.Mining={s900002=bar}
P.Catalog.Blacksmithing={root};P.Catalog.Mining={bar};P.Recipes.Blacksmithing={root}
P.char.vendors[2320]={value=10,name='Far Supplier',npcID=90001,stock=-1,bundle=1,time=time()}
P.NPCSources[90001]={id=90001,name='Far Supplier',faction='A',cap=225,points={{map=1,x=.8,y=.8,zone='Test Zone'}}}
P.NPCSources[90002]={id=90002,name='Near Supplier',faction='A',cap=225,points={{map=1,x=.51,y=.5,zone='Test Zone'}}}
P.NPCSources[90003]={id=90003,name='Hostile Supplier',faction='H',cap=225,points={{map=1,x=.501,y=.5,zone='Test Zone'}}}
P.ReagentVendors={[2320]={90001,90002,90003}}
C_Map={GetBestMapForUnit=function()return 1 end,GetPlayerMapPosition=function()return {x=.5,y=.5} end,GetMapWorldSize=function()return 1000,1000 end}
P:InvalidatePlan();P.mode='cost';P.tab='Recipes';P.char.planTargets={Blacksmithing=104};P.ReadSkills=function()end
function route()local plan=P:BuildCheapestPlan(104);P.planSummary=plan;return P:RouteEntries(plan.rows),plan end
function action(entries,kind)for _,r in ipairs(entries)do if r.actionKind==kind then return r end end end
'''
results=[]
def runtime():
 L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
 loader=L.eval('function(code,p)assert(loadstring(code))("ProfPaden",p)end')
 for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
 L.execute(SETUP);return L,P
def run(name,code):
 try:
  L,P=runtime();L.execute(code);results.append(dict(name=name,passed=True))
 except Exception as e:results.append(dict(name=name,passed=False,error=str(e)));traceback.print_exc()

run('Known yellow and green boundaries reduce the forecast and gray stops skill planning','''
assert(P:Chance(root,94)==1 and math.abs(P:Chance(root,95)-.4)<.000001)
assert(math.abs(P:Chance(root,100)-.16)<.000001 and math.abs(P:Chance(root,105)-.08)<.000001)
assert(P:Chance(root,110)==0)
local prev=1;for rank=94,110 do local p=P:Chance(root,rank);assert(p<=prev);prev=p end
''')
run('Color splits conserve planned attempts, training, proceeds and shopping quantities','''
local entries,plan=route();local n,fee,proceeds=0,0,0;local bands={}
for _,r in ipairs(entries)do if r.routeBand then n=n+r.crafts;fee=fee+r.planTraining;proceeds=proceeds+r.planProceeds;bands[r.routeBand]=true end end
local original=0;for _,r in ipairs(plan.rows)do original=original+r.crafts end
assert(n==original and fee==plan.training and proceeds==plan.proceeds)
assert(bands.Orange and bands.Yellow and bands.Green)
assert(P.routeNeeds[2840]==n*2 and P.routeNeeds[2320]==n)
P.char.shoppingOptions={Blacksmithing={mode='cost',target=104,goal='fixed',saleKey='vendor'}}
P:EnsureShoppingPlan(true);P:ShoppingRows();local shopping=P:ShoppingPlan()
assert(shopping.needs[2840]==P.routeNeeds[2840] and shopping.needs[2320]==P.routeNeeds[2320])
''')
run('Cheapest changes recipe when the yellow boundary makes an alternative cheaper','''
local alt={name='Orange alternative',spell=900003,item=10002,profession='Blacksmithing',mats={{id=2770,count=4}},complete=true,yellow=120,green=130,grey=140}
P.Catalog.Blacksmithing[2]=alt;P.char.recipes.Blacksmithing.s900003=alt;P:InvalidatePlan()
local plan=P:BuildCheapestPlan(99);assert(plan.rows[1].spell==root.spell and plan.rows[1].stop==95)
assert(plan.rows[#plan.rows].spell==alt.spell)
''')
run('Nearest usable vendor excludes hostile, sold-out and insufficient recorded stock','''
local target=P:RouteVendor(2320,10);assert(target.npc.id==90002)
P.char.vendorOffers[2320]={[90002]={stock=0}};target=P:RouteVendor(2320,10);assert(target.npc.id==90001)
P.char.vendorOffers[2320][90002]={stock=2,bundle=2};assert(P:RouteVendor(2320,10).npc.id==90001)
P.char.vendorOffers[2320][90002]={stock=-1};assert(P:RouteVendor(2320,10).npc.id==90002)
''')
run('Manual valuation does not change a known vendor supply into an auction purchase','''
P.char.vendors[2320]=nil;quote(2320,1);local entries=route()
for _,r in ipairs(entries)do if r.item==2320 then assert(r.actionKind=='vendor' and r.target) end end
''')
run('Purchases precede preparations, which precede crafts, without duplicate input orders','''
local entries=route();local ore,prep,craft;local count=0
for i,r in ipairs(entries)do
 if r.journeyAction and r.item==2770 then ore=i;count=count+1 end
 if r.journeyPrepare and r.item==2840 then prep=prep or i end
 if r.routeBand then craft=craft or i end
end
assert(ore<prep and prep<craft and count==1)
local needed=P.routeNeeds;Bag[2840]=needed[2840];Bag[2320]=needed[2320];local nextEntries=route()
for _,r in ipairs(nextEntries)do assert(not r.journeyPrepare and not r.journeyAction) end
''')
run('Exact recorded recipe trainers are chosen over generic nearby trainers','''
P.char.recipes.Blacksmithing={}
P.char.trainers.Blacksmithing={s900001={eligible=true,cost=100,required=94,npcID=90001,trainer='Far Supplier'}}
local entries=route();assert(action(entries,'trainer').target.npc.id==90001)
P.char.trainerOffers.Blacksmithing={s900001={[90002]={eligible=true,npcID=90002}}};entries=route()
assert(action(entries,'trainer').target.npc.id==90002)
P.char.recipes.Blacksmithing.s900001=root;entries=route();assert(not action(entries,'trainer'))
''')
run('Future training stops wait for required skill and rank stops use level gates','''
local stop={journeyAction=true,required=100,target={npc=P.NPCSources[90002]},npcIDs={90002},key='later'}
P.selected=stop;P:UpdateRouteNavigation();assert(not P.navTarget)
P.skills.Blacksmithing.rank=100;P:UpdateRouteNavigation();assert(P.navTarget.npc.id==90002)
P.skills.Blacksmithing.cap=225;local rankStop=P:RouteRankStop(200);assert(rankStop.minLevel==35 and not P:RouteStopReady(rankStop))
''')
run('Arrow dismiss persists for the same stop; toggle and new selections behave correctly','''
local entries=route();local stop=action(entries,'vendor');P.selected=stop
P:UpdateRouteNavigation();assert(P.navTarget.npc.id==90002 and P.navRouteKey)
P.navigationArrow.scripts.OnClick();assert(not P.navTarget);P:UpdateRouteNavigation();assert(not P.navTarget)
P.dismissedRouteKey=nil;P:UpdateRouteNavigation();assert(P.navTarget)
P.char.autoRouteArrows=false;P:UpdateRouteNavigation();assert(not P.navTarget)
assert(not P:TrackNPC(90001));P:UpdateRouteNavigation();assert(not P.navTarget,'Tracking Off also blocks manual links')
P:SetNavigationEnabled(true);P:TrackNPC(90001);assert(P.navTarget.npc.id==90001,'Explicit links work after enabling tracking')
''')
run('Owned waypoint cleanup leaves a different user waypoint intact','''
local cleared=0;C_Map.ClearUserWaypoint=function()cleared=cleared+1 end
C_Map.GetUserWaypoint=function()return {uiMapID=1,position={GetXY=function()return .1,.1 end}} end
P.navTarget={mapPin=true,point={map=1,x=.5,y=.5}};P:ClearNavigation();assert(cleared==0)
C_Map.GetUserWaypoint=function()return {uiMapID=1,position={GetXY=function()return .5,.5 end}} end
P.navTarget={mapPin=true,point={map=1,x=.5,y=.5}};P:ClearNavigation();assert(cleared==1)
''')
run('Cross-profession preparation resolves its own live recipe without changing the parent route','''
P.live={bar};local entries=route();local step
for _,r in ipairs(entries)do if r.journeyPrepare then step=r;break end end
assert(step and P:Resolve(step)==bar and P.selectedProf=='Blacksmithing')
P.selected=step;P:RefreshProfessionButton();assert(P.selectedProf=='Blacksmithing')
''')
run('Craft clicks cannot queue beyond the next color boundary','''
local entries=route();local step
for _,r in ipairs(entries)do if r.routeBand=='Orange' then step=r;break end end
assert(P:RouteBatchLimit(step)==1)
assert(step.crafts==1,'A guaranteed orange point needs exactly one planned craft')
local ok,message=P:Craft(step,2);assert(not ok and message:find('boundary'))
P.selected=step;P:SetQuantity();assert(tonumber(P.qty:GetText())==1)
''')
run('Full UI shows action details and updates selected quantities on skill changes','''
P:Refresh();local stop=action(P.entries,'vendor');P.selectedKey=stop.key;P:Refresh()
assert(P.routeAction:IsShown() and not P.craft:IsShown() and P.navTarget)
assert(P.currentDetailRows[1].cells[2]:find('Ready now'))
P.skills.Blacksmithing.rank=100;P:InvalidatePlan();P.selectedKey=nil;P:Refresh()
for _,r in ipairs(P.entries)do if r.routeBand then assert(r.start>=100 and r.routeBand~='Orange') end end
''')
run('Guided uses the same bounded route and quantities as Guided Shopping','''
P.mode='guide';P:InvalidatePlan();P:Refresh();assert(P.planSummary.target==104)
P:OpenRouteShopping();assert(P:ShoppingMode()=='guide' and P:ShoppingPlan().target==104)
for id,count in pairs(P.routeNeeds)do assert(P:ShoppingPlan().needs[id]==count) end
''')
run('Money-making gray crafts and catalog remain independent of leveling stops','''
P.mode='money';local rows={{money=true,grey=1,crafts=10,key='profit'}}
assert(P:RouteEntries(rows)==rows)
P.mode='live';assert(P:RouteEntries(rows)==rows)
P.tab='Catalog';P:Refresh();for _,r in ipairs(P.entries)do assert(not r.journeyAction) end
''')
run('Preparation batches respect their own profession color boundary and parent goal','''
bar.yellow=101;bar.green=110;bar.grey=120;P:InvalidatePlan();local entries=route();local prep
for _,r in ipairs(entries)do if r.journeyPrepare then prep=r;break end end
assert(prep and P:RouteBatchLimit(prep)==1)
prep.profession='Blacksmithing';prep.yellow=120;P.skills.Blacksmithing.rank=100
assert(P:RouteBatchLimit(prep)==4,'Parent goal at 104 also bounds preparation')
''')
run('Rank training appears at the 125 boundary and cannot navigate early','''
P.skills.Blacksmithing.rank=124;root.start=124;root.stop=128;root.yellow=150;root.green=170;root.grey=190
P.TrainerNPCs.Blacksmithing={90001,90002};P:InvalidatePlan()
local plan=P:BuildCheapestPlan(128);local entries=P:RouteEntries(plan.rows);local craftBefore,stopAt,craftAfter
for i,r in ipairs(entries)do
 if r.rankStop then stopAt=i;assert(r.required==125 and not P:RouteStopReady(r)) end
 if r.routeBand and r.stop==125 then craftBefore=i end
 if r.routeBand and r.start==125 then craftAfter=i end
end
assert(craftBefore<stopAt and stopAt<craftAfter)
''')
run('Bag completion clears an owned arrow while the guide is hidden','''
P:Refresh();P.selected=action(P.entries,'vendor');P.selectedKey=P.selected.key;P:UpdateRouteNavigation();assert(P.navTarget)
for id,count in pairs(P.routeNeeds)do Bag[id]=count end
P.window:Hide();P.ScanRecipes=function()end;P.RefreshCamp=function()end;P.ShoppingChanged=function()end
C_Timer.After=function(_,fn)fn()end
P.events.scripts.OnEvent(nil,'BAG_UPDATE_DELAYED');assert(not P.navTarget and not P.selected.journeyAction)
''')
run('Merchant observations retain separate supplier offers','''
local npc=90001;P.RememberNPC=function()return npc end
GetMerchantNumItems=function()return 1 end;GetMerchantItemLink=function()return 'item:2320' end
GetMerchantItemInfo=function()return 'Coarse Thread',nil,10,1,-1,nil,false end
P:CaptureMerchant();npc=90002;P:CaptureMerchant()
assert(P.char.vendorOffers[2320][90001] and P.char.vendorOffers[2320][90002])
''')
run('Secondary profession rank stops use books and quests instead of inventing trainers','''
P.selectedProf='Cooking';P.skills.Cooking={rank=125,cap=150};local stop=P:RouteRankStop(125)
assert(stop.actionKind=='vendor' and stop.name=='Buy the next profession book')
P.skills.Cooking={rank=225,cap=225};stop=P:RouteRankStop(225)
assert(stop.actionKind=='quest' and stop.target and stop.target.npc.id==8125 and stop.required==225)
''')
run('Tracked mail is collected rather than ordered again in route stops','''
local entries=route();local ore=P.routeSupply.buy[2770]
P.char.shoppingTransit[2770]={count=3,bags=0};entries=route()
assert(P.routeSupply.buy[2770]==ore-3)
local mail=action(entries,'mail');assert(mail and mail.mailCount==3)
local rows=P:RouteDetailRows(mail);assert(rows[2].cells[1]=='Collect')
''')
report=dict(tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'route-stops-test-results.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
