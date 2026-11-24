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

BASE="\nSetupReference();P.window:Hide();P.skills.Alchemy={rank=1,cap=11};P.live={};P.Recipes.Alchemy={}\nP.Catalog.Alchemy={\n {name='First recipe',spell=1,item=1001,learn=1,yellow=6,grey=6,mats={{id=101,count=1}},complete=true},\n {name='Second recipe',spell=2,item=1002,learn=6,yellow=20,grey=30,mats={{id=101,count=1},{id=102,count=2}},complete=true}}\nP.char.recipes.Alchemy={s1=P.Catalog.Alchemy[1]}\nP.char.trainers={Alchemy={s2={eligible=true,cost=2,required=6,trainer='Test trainer',zone='Stormwind'}}}\nP.market.prices={[101]={value=10,time=time()},[102]={value=1,time=time()}}\nBag={[101]=3};P.auctionOpen=true;P:CreateShoppingUI()\nnow=0;timers={};searches={};purchases=0;money=100000;dialogs={};ready=true\nfunction GetTime()return now end\nfunction GetMoney()return money end\nfunction hooksecurefunc(obj,name,cb)\n local original=obj[name];obj[name]=function(...)local result={original(...)};cb(...);return unpack(result)end\nend\nC_Timer.After=function(delay,fn)timers[#timers+1]={at=now+delay,fn=fn}end\nfunction Advance(amount)\n local finish=now+amount\n while true do local index,minimum=nil,math.huge\n  for i,t in ipairs(timers)do if t.at<minimum then index,minimum=i,t.at end end\n  if not index or minimum>finish then break end\n  local t=table.remove(timers,index);now=t.at;t.fn()\n end\n now=finish\nend\ncommodityResults={{unitPrice=5,quantity=2,numOwnerItems=0},{unitPrice=10,quantity=10,numOwnerItems=0}}\nitemResults={{itemKey={itemID=101},auctionID=700,quantity=4,buyoutAmount=40}}\nC_AuctionHouse={\n SendSearchQuery=function(k)searches[#searches+1]=k.itemID end,\n SendBrowseQuery=function()end,SendSellSearchQuery=function()end,\n IsThrottledMessageSystemReady=function()return ready end,\n GetNumCommoditySearchResults=function()return #commodityResults end,\n GetCommoditySearchResultInfo=function(id,i)return commodityResults[i]end,\n GetNumItemSearchResults=function()return #itemResults end,\n GetItemSearchResultInfo=function(k,i)return itemResults[i]end,\n ConfirmCommoditiesPurchase=function()purchases=purchases+1 end,\n PlaceBid=function()purchases=purchases+1 end}\nAuctionHouseFrame={BuyDialog=CreateFrame('Frame')}\nAuctionHouseFrame.BuyDialog:Hide()\nfunction AuctionHouseFrame:StartCommoditiesPurchase(id,qty,unit,total)\n self.BuyDialog:Show();dialogs[#dialogs+1]={kind='commodity',id=id,qty=qty,total=total}\nend\nfunction AuctionHouseFrame:StartItemBuyout(id,total)dialogs[#dialogs+1]={kind='item',id=id,total=total}end\nfunction Event(e,a,b)P.shoppingEvents.scripts.OnEvent(P.shoppingEvents,e,a,b)end\nfunction CheckCommodity()\n P.shoppingSelected=101;P:SearchShoppingItem(101);Event('COMMODITY_SEARCH_RESULTS_ADDED',101)\nend\nassert(P:BuildShopping(10))\nexports={}\nAuctionator={API={v1={MultiSearchAdvanced=function(caller,terms)exports[#exports+1]={caller=caller,terms=terms}end}}}\nC_Item.GetItemInfo=function(id)return 'Material '..id end\n"

UX=BASE+"""
P.mode='cost';P.ReadSkills=function()end
local cfg=P:ShoppingConfig(true);cfg.target=11;P:EnsureShoppingPlan(true);P.shoppingWindow:Show();P:RefreshShopping()
function choose(label)for _,row in ipairs(P.dropdown.rows)do if row.shown and row.label.text==label then row.scripts.OnClick();return end end;error('Missing '..label)end
function guideSetup()
 P.Recipes.Alchemy={};for i,r in ipairs(P.Catalog.Alchemy)do local g={};for k,v in pairs(r)do g[k]=v end;g.kind='guide';g.start=i==1 and 1 or 6;g.stop=i==1 and 6 or 11;P.Recipes.Alchemy[#P.Recipes.Alchemy+1]=g end
end
function alternative()
 local a={name='Alternative',spell=3,item=1003,learn=1,yellow=30,grey=40,start=1,stop=11,kind='alternative',mats={{id=102,count=1}},complete=true}
 P.Catalog.Alchemy[#P.Catalog.Alchemy+1]=a;P.char.recipes.Alchemy.s3=a;return a
end
"""
run('Shopping has all six route choices and keeps them independent of Guide',r"""
P.shoppingWindow.mode.scripts.OnClick();assert(P.dropdown.menu.height==268)
choose('Guided');assert(P:ShoppingMode()=='guide' and P.mode=='cost')
P.mode='profit';assert(P:ShoppingMode()=='guide')
P.shoppingWindow.mode.scripts.OnClick();choose('Cheapest');assert(P:ShoppingMode()=='cost' and P.mode=='profit')
""",UX)
run('Fixed target automatically shrinks with skill and does not become a moving +10',r"""
P.skills.Alchemy.rank=4;P:ShoppingChanged('SKILL_LINES_CHANGED');Advance(.5)
local p=P:ShoppingPlan();assert(p.start==4 and p.target==11 and p.needs[101]==7 and not P:ShoppingIsStale())
assert(P.shoppingWindow.skill.text=='Current skill 4 / 11' and P.shoppingWindow.levels.text=='11')
""",UX)
run('Goal completion clears obsolete shopping requirements and retains mail credits',r"""
P:ShoppingTransit(101).count=2;P.skills.Alchemy.rank=11;P:ShoppingChanged('SKILL_LINES_CHANGED');Advance(.5)
assert(P:ShoppingPlan().completeGoal and not next(P:ShoppingPlan().needs) and P:ShoppingTransit(101).count==2)
assert(P.shoppingWindow.auctionator.text=='Train next rank' and not P.shoppingWindow.auctionator.enabled)
""",UX)
run('Target and gain presets validate, clamp, and cap mode follows training',r"""
assert(P:SetShoppingGoal(5,true));assert(P:ShoppingPlan().target==6)
assert(not P:SetShoppingGoal('bad'));assert(P:ShoppingPlan().target==6)
assert(P:SetShoppingGoal(25,true));assert(P:ShoppingPlan().target==11)
P:SetShoppingGoal('cap');P.skills.Alchemy.cap=20;P:ShoppingChanged('SKILL_LINES_CHANGED');Advance(.5)
assert(P:ShoppingPlan().target==20 and P.shoppingWindow.levels.text=='20')
P:SetShoppingGoal(10);P.skills.Alchemy.cap=30;P:ShoppingChanged('SKILL_LINES_CHANGED');Advance(.5);assert(P:ShoppingPlan().target==10)
""",UX)
run('Profession dropdown preserves distinct mode and goal per profession',r"""
P.skills.Cooking={rank=30,cap=75};P:SetShoppingGoal(6);P.shoppingWindow.prof.scripts.OnClick();choose('Cooking  30/75')
assert(P.selectedProf=='Cooking' and P:ShoppingConfig().target==40)
P:SetShoppingMode('bags');P:SetShoppingGoal(50);P.shoppingWindow.prof.scripts.OnClick();choose('Alchemy  1/11')
assert(P:ShoppingConfig().target==6 and P:ShoppingMode()=='cost')
P.shoppingWindow.prof.scripts.OnClick();choose('Cooking  30/75');assert(P:ShoppingConfig().target==50 and P:ShoppingMode()=='bags')
""",UX)
run('Guided follows primary skill bands without requiring reagent prices',r"""
guideSetup();P.market.prices={};P.Items[101]=nil;P.Items[102]=nil;P:SetShoppingMode('guide')
local p=P:ShoppingPlan();assert(p.reached==11 and #p.steps==2 and p.steps[1].spell==1 and p.needs[101]==10)
assert(P.shoppingWindow.summary.text:find('unpriced') and P.shoppingWindow.summary.text:find('Known budget'))
""",UX)
run('All steps selects one guide/alternative path, never sums all alternatives',r"""
guideSetup();local a=alternative();P.Recipes.Alchemy[#P.Recipes.Alchemy+1]=a;P:SetShoppingMode('all')
local p=P:ShoppingPlan();assert(p.reached==11 and #p.steps==1 and p.steps[1].spell==3 and p.needs[102]==10 and not p.needs[101])
""",UX)
run('Live alternatives use the open profession, explaining forecast gaps and close',r"""
P.live={P.Catalog.Alchemy[1]};P.live[1].profession='Alchemy';P.live[1].available=20
P:SetShoppingMode('live');assert(P:ShoppingPlan().reached==6 and P:ShoppingPlan().reason:find('Open the profession'))
P.live={};P:ShoppingChanged('TRADE_SKILL_CLOSE');Advance(.5);assert(#P:ShoppingPlan().steps==0)
""",UX)
run('Bag-first ranking counts owned inventory once and differs from Cheapest',r"""
alternative();Bag[101]=10;Bag[102]=0;P:SetShoppingMode('cost');assert(P:ShoppingPlan().needs[102]==10 and not P:ShoppingPlan().needs[101])
P:SetShoppingMode('bags');local p=P:ShoppingPlan();assert(p.needs[101]==5 and p.needs[102]==5)
assert(P:ShoppingRow(102).missing==5)
""",UX)
run('Mail delivery updates missing table without replacing the selected route',r"""
local plan=P:ShoppingPlan();P:ShoppingTransit(101).count=4;P:RefreshShopping();assert(P:ShoppingRow(101).missing==3)
Bag[101]=7;Event('BAG_UPDATE_DELAYED');Advance(.5)
assert(P:ShoppingPlan()==plan and P:ShoppingRow(101).pending==0 and P:ShoppingRow(101).missing==3)
P.shoppingWindow.filter.scripts.OnClick();choose('All materials');assert(P.shoppingShow=='all')
""",UX)
run('Missing-only view omits covered materials while Show all retains them',r"""
Bag[101]=20;P:RefreshShopping();assert(P.shoppingWindow.rows[1].entry.item==102 and not P.shoppingWindow.rows[2].shown)
P.shoppingWindow.filter.scripts.OnClick();choose('All materials');assert(P.shoppingWindow.rows[2].shown)
Bag[102]=30;P.shoppingShow='missing';P:RefreshShopping();assert(P.shoppingWindow.auctionator.text=='Materials covered' and not P.shoppingWindow.auctionator.enabled)
""",UX)
run('Auctionator export rebuilds current skills then sends only current missing quantities',r"""
P.skills.Alchemy.rank=4;assert(P:ShopWithAuctionator());assert(P:ShoppingPlan().target==11 and P:ShoppingPlan().start==4)
local found;for _,t in ipairs(exports[1].terms)do if t.searchString=='Material 101' then found=t.quantity end end
assert(found==4 and purchases==0 and not P.shoppingWindow.shown)
""",UX)
run('Automatic updates defer while a purchase or native confirmation is unresolved',r"""
local plan=P:ShoppingPlan();P.skills.Alchemy.rank=4;P:ShoppingTransit(101).count=1;P.char.shoppingUncertain={item=101,quantity=1};P:ShoppingChanged('SKILL_LINES_CHANGED');Advance(.5)
assert(P:ShoppingPlan()==plan and not P:ShopWithAuctionator())
P.char.shoppingUncertain=nil;AuctionHouseFrame.BuyDialog:Show();P:EnsureShoppingPlan();assert(P:ShoppingPlan()==plan)
AuctionHouseFrame.BuyDialog:Hide();P:EnsureShoppingPlan();assert(P:ShoppingPlan().start==4)
""",UX)
run('Popup works when main Guide is hidden; missing Auctionator or AH gives actionable states',r"""
P.window:Hide();P.shoppingWindow.mode.scripts.OnClick();assert(P.dropdown.parent==UIParent and P.dropdown.shown);choose('Cheapest')
P.auctionOpen=false;P:RefreshShopping();assert(P.shoppingWindow.auctionator.text=='Visit auction house')
Auctionator=nil;P:RefreshShopping();assert(P.shoppingWindow.auctionator.text=='Enable Auctionator')
P.shoppingWindow.scripts.OnHide();assert(not P.dropdown.shown)
""",UX)
run('Profit sale assumptions and scan outputs stay independent of the Guide',r"""
C_Item.GetItemInfo=function(id)return 'Material '..id,'item:'..id,1,1,1,'Consumable','Potion',20,'',1,10,0,1,2 end
P.char.profitSale='auction15';P:SetShoppingMode('profit:vendor')
assert(P:ShoppingPlan().saleKey=='vendor' and P.char.profitSale=='auction15' and P.mode=='cost')
P.NextPriceQuery=function()end;P.shoppingScanMode=P:ShoppingMode();P:StartPriceScan();P.shoppingScanMode=nil;assert(P.priceScan.profit)
local output=false;for _,id in ipairs(P.priceScan.ids)do if id==1001 then output=true end end;assert(output)
""",UX)
run('New trainer or learned-recipe events rebuild only the fixed goal and preserve credits',r"""
P:ShoppingTransit(101).count=2;local old=P:ShoppingPlan();alternative();P:ShoppingChanged('NEW_RECIPE_LEARNED');Advance(.5)
assert(P:ShoppingPlan()~=old and P:ShoppingPlan().target==11 and P:ShoppingTransit(101).count==2 and P:ShoppingPlan().steps[1].spell==3)
""",UX)
run('Opening an existing saved shopping plan adopts it without inheriting later Guide changes',r"""
P.shoppingWindow:Hide();P.char.shoppingOptions=nil;P.mode='guide';P:ToggleShopping()
assert(P:ShoppingConfig().mode=='cost' and P:ShoppingConfig().target==11 and P.shoppingWindow.shown)
P.mode='profit';P:RefreshShopping();assert(P:ShoppingMode()=='cost' and not P:ShoppingIsStale())
""",UX)

SCAN=UX+"""
replicates=0;browses=0;useReplicate=true;scanQuotes={[101]=7,[102]=1};listeners={}
Auctionator={State={},SavedState={},FullScan={},IncrementalScan={},Config={Options={REPLICATE_SCAN='replicate'},Get=function()return useReplicate end},
 Utilities={Message=function()end},Debug={Message=function()end},Database={GetItemCount=function()return 0 end},AH={SendBrowseQuery=function()browses=browses+1 end},
 API={v1={MultiSearchAdvanced=function()end,GetAuctionPriceByItemID=function(_,id)return scanQuotes[id]end,RegisterForDBUpdate=function(_,cb)dbCallback=cb end}},EventBus={}}
function Auctionator.EventBus:Register(listener,names)listeners[#listeners+1]={listener=listener,names=names}end
function Auctionator.EventBus:RegisterSource()return self end
function Auctionator.EventBus:Fire(_,event,value)for _,reg in ipairs(listeners)do for _,name in ipairs(reg.names)do if name==event then reg.listener:ReceiveEvent(event,value)end end end end
local root='C:/Program Files (x86)/World of Warcraft/_classic_beta_/Interface/AddOns/Auctionator/Source_ModernAH/'
assert(loadfile(root..'FullScan/Events.lua'))();assert(loadfile(root..'IncrementalScan/Events.lua'))()
assert(loadfile(root..'FullScan/Mixins/Frame.lua'))();assert(loadfile(root..'IncrementalScan/Mixins/Frame.lua'))()
full=setmetatable({state={},RegisterForEvents=function()end},{__index=AuctionatorFullScanFrameMixin})
inc=setmetatable({state={},doingFullScan=false,FireProgressEvent=function()end},{__index=AuctionatorIncrementalScanFrameMixin})
Auctionator.State.FullScanFrameRef=full;Auctionator.State.IncrementalScanFrameRef=inc
AUCTIONATOR_L_STARTING_FULL_SCAN_REPLICATE='Starting';AUCTIONATOR_L_STARTING_FULL_SCAN_SUMMARY='Starting';AUCTIONATOR_L_NEXT_SCAN_MESSAGE='Next scan in %d:%02d'
C_AuctionHouse.ReplicateItems=function()replicates=replicates+1 end
P.auctionatorScanListener=nil;P.auctionatorDBHook=nil
function scanEvent(kind,value)Auctionator.EventBus:Fire(full,Auctionator.FullScan.Events[kind],value)end
"""
run('Shopping button invokes installed Auctionator replicate scan and observes progress',r"""
P.shoppingWindow.scan.scripts.OnClick();assert(replicates==1 and P:IsAuctionatorScanning() and P.priceScan==nil)
scanEvent('ScanProgress',.5);assert(P.shoppingWindow.scan.text=='Scan 50%' and P.shoppingWindow.auctionator.text=='Full scan running')
assert(not P:StartAuctionatorScan() and replicates==1 and not P:ShopWithAuctionator())
local old=#searches;P:SearchShoppingItem(101);assert(#searches==old)
""",SCAN)
run('Full scan respects configured summary method and never changes Auctionator settings',r"""
useReplicate=false;assert(P:StartAuctionatorScan());assert(browses==1 and replicates==0 and inc.doingFullScan and not useReplicate)
""",SCAN)
run('Full-scan completion uses refreshed database prices and automatically rebuilds the fixed goal',r"""
P.market.prices[101]=nil;P.market.observed={[101]={value=1,time=time()-100,source='Old AH sample'}}
assert(P:Price(101)==1);local old=P:ShoppingPlan();P:StartAuctionatorScan();full.inProgress=false;scanEvent('ScanComplete',{})
assert(not P:IsAuctionatorScanning() and P:Price(101)==7 and P:ShoppingPlan()~=old and P:ShoppingPlan().target==11)
assert(P.shoppingWindow.status.text:find('full scan complete') and P.shoppingWindow.auctionator.enabled)
P.market.prices[101]={value=3};assert(P:Price(101)==3)
""",SCAN)
run('Auctionator cooldown and active confirmation block scans without bypassing them',r"""
full.state.TimeOfLastReplicateScan=time();assert(not P:StartAuctionatorScan() and replicates==0 and P.shoppingMessage:find('Next scan'))
full.state.TimeOfLastReplicateScan=nil;AuctionHouseFrame.BuyDialog:Show();assert(not P:StartAuctionatorScan() and replicates==0)
AuctionHouseFrame.BuyDialog:Hide();P.char.shoppingUncertain={item=101,quantity=1};assert(not P:StartAuctionatorScan() and replicates==0)
""",SCAN)
run('Unsupported, absent or closed-house scan conditions retain lists and give actionable messages',r"""
local plan=P:ShoppingPlan();P.auctionOpen=false;assert(not P:StartAuctionatorScan() and P.priceStatus:find('Open the auction house'))
P.auctionOpen=true;Auctionator.State={};assert(not P:StartAuctionatorScan() and P.shoppingMessage:find('Full Scan button'))
Auctionator=nil;assert(not P:StartAuctionatorScan() and P.priceStatus:find('Enable Auctionator') and P:ShoppingPlan()==plan)
""",SCAN)
run('Failed full scan keeps previous quotes and never reports successful completion',r"""
local plan=P:ShoppingPlan();P:StartAuctionatorScan();full.inProgress=false;scanEvent('ScanFailed')
assert(not P:IsAuctionatorScanning() and P:ShoppingPlan()==plan and P.market.auctionatorScanStarted==nil and P.priceStatus:find('did not complete'))
assert(purchases==0)
""",SCAN)
report=dict(runtime='Actual Lua 5.1 modules with mocked client APIs; no live-game purchases',tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'shopping-ux-test-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
