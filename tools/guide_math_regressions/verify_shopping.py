"""Execute export-only shopping against deterministic WoW API fakes."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=['Core.lua','Data/Recipes.lua','Data/Catalog.lua','Data/FieldGuide.lua','Data/Research.lua','Data/GatherVisuals.lua','Data/Details.lua','Adapter.lua','ModernAdapter.lua','Planner.lua','Cheapest.lua','MarketRoutes.lua','MoneyRoutes.lua','Sourcing.lua','Costs.lua','Catalog.lua','CampFood.lua','Camping.lua','Minimap.lua','QuestBridge.lua','GatherMaps.lua','Tooltips.lua','Shopping.lua','ShoppingRoutes.lua','AuctionatorBridge.lua','AuctionatorScan.lua','ShoppingUI.lua','Navigation.lua','NavigationGoals.lua','Details.lua','ProfessionAccess.lua','Materials.lua','MaterialFilters.lua','UI.lua']
SETUP='''
SetupReference();P.window:Hide();P.skills.Alchemy={rank=1,cap=11};P.live={};P.Recipes.Alchemy={}
P.Catalog.Alchemy={
 {name='First recipe',spell=1,item=1001,learn=1,yellow=6,grey=6,mats={{id=101,count=1}},complete=true},
 {name='Second recipe',spell=2,item=1002,learn=6,yellow=20,grey=30,mats={{id=101,count=1},{id=102,count=2}},complete=true}}
P.char.recipes.Alchemy={s1=P.Catalog.Alchemy[1]}
P.char.trainers={Alchemy={s2={eligible=true,cost=2,required=6,trainer='Test trainer',zone='Stormwind'}}}
P.market.prices={[101]={value=10,time=time()},[102]={value=1,time=time()}}
Bag={[101]=3};P.auctionOpen=true;P:CreateShoppingUI()
now=0;timers={};searches={};purchases=0;money=100000;dialogs={};ready=true
function GetTime()return now end
function GetMoney()return money end
function hooksecurefunc(obj,name,cb)
 local original=obj[name];obj[name]=function(...)local result={original(...)};cb(...);return unpack(result)end
end
C_Timer.After=function(delay,fn)timers[#timers+1]={at=now+delay,fn=fn}end
function Advance(amount)
 local finish=now+amount
 while true do local index,minimum=nil,math.huge
  for i,t in ipairs(timers)do if t.at<minimum then index,minimum=i,t.at end end
  if not index or minimum>finish then break end
  local t=table.remove(timers,index);now=t.at;t.fn()
 end
 now=finish
end
commodityResults={{unitPrice=5,quantity=2,numOwnerItems=0},{unitPrice=10,quantity=10,numOwnerItems=0}}
itemResults={{itemKey={itemID=101},auctionID=700,quantity=4,buyoutAmount=40}}
C_AuctionHouse={
 SendSearchQuery=function(k)searches[#searches+1]=k.itemID end,
 SendBrowseQuery=function()end,SendSellSearchQuery=function()end,
 IsThrottledMessageSystemReady=function()return ready end,
 GetNumCommoditySearchResults=function()return #commodityResults end,
 GetCommoditySearchResultInfo=function(id,i)return commodityResults[i]end,
 GetNumItemSearchResults=function()return #itemResults end,
 GetItemSearchResultInfo=function(k,i)return itemResults[i]end,
 ConfirmCommoditiesPurchase=function()purchases=purchases+1 end,
 PlaceBid=function()purchases=purchases+1 end}
AuctionHouseFrame={BuyDialog=CreateFrame('Frame')}
AuctionHouseFrame.BuyDialog:Hide()
function AuctionHouseFrame:StartCommoditiesPurchase(id,qty,unit,total)
 self.BuyDialog:Show();dialogs[#dialogs+1]={kind='commodity',id=id,qty=qty,total=total}
end
function AuctionHouseFrame:StartItemBuyout(id,total)dialogs[#dialogs+1]={kind='item',id=id,total=total}end
function Event(e,a,b)P.shoppingEvents.scripts.OnEvent(P.shoppingEvents,e,a,b)end
function CheckCommodity()
 P.shoppingSelected=101;P:SearchShoppingItem(101);Event('COMMODITY_SEARCH_RESULTS_ADDED',101)
end
assert(P:BuildShopping(10))
exports={}
Auctionator={API={v1={MultiSearchAdvanced=function(caller,terms)exports[#exports+1]={caller=caller,terms=terms}end}}}
C_Item.GetItemInfo=function(id)return 'Material '..id end
'''
results=[]
def run(name,code):
 try:
  L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
  loader=L.eval('function(code,ns)local f,e=loadstring(code);assert(f,e);f("ProfPaden",ns)end')
  for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
  L.execute(SETUP);L.execute(code);results.append(dict(name=name,passed=True))
 except Exception as e:traceback.print_exc();results.append(dict(name=name,passed=False,error=str(e)))
run('X skill levels aggregate all route steps, subtract bags once and retain trainer fees','''
local p=P:ShoppingPlan();assert(p.start==1 and p.target==11 and p.reached==11 and #p.steps==2)
assert(p.needs[101]==10 and p.needs[102]==10 and p.training==2)
local r=P:ShoppingRow(101);assert(r.missing==7 and r.cost==70 and r.owned==3)
assert(P.char.planTargets==nil and purchases==0)
''')
run('Invalid level counts are rejected and valid goals clamp to trained cap','''
local saved=P:ShoppingPlan()
for _,n in ipairs({0,-1,1.5,301,'bad'})do assert(not P:BuildShopping(n));assert(P:ShoppingPlan()==saved)end
assert(P:BuildShopping(100) and P:ShoppingPlan().target==11)
''')
run('Incomplete routes are labeled partial and missing prices never become free','''
P.market.prices[102]=nil;P.Items[102]=nil;P:BuildShopping(10)
local p=P:ShoppingPlan();assert(p.reached==6 and p.reason and not p.needs[102])
P:RefreshShopping();assert(P.shoppingWindow.summary.text:find('PARTIAL',1,true))
P.market.prices[101]=nil;P.Items[101]=nil;P:RefreshShopping()
assert(P.shoppingWindow.summary.text:find('unpriced',1,true))
''')
run('Commodity sample sums price tiers and item export never opens a buy dialog','''
CheckCommodity();local o=P.shoppingOffer;assert(o.quantity==7 and o.total==60)
P:SendShoppingItem()
assert(#dialogs==0 and #exports==1 and #exports[1].terms==1 and exports[1].terms[1].quantity==7 and purchases==0)
assert(P:ShoppingRow(101).pending==0)
''')
run('Confirmed commodity receipt credits mail once and delivery replaces that credit','''
CheckCommodity();P:SendShoppingItem();C_AuctionHouse.ConfirmCommoditiesPurchase(101,7)
assert(purchases==1 and P:ShoppingRow(101).missing==0 and P.char.shoppingUncertain)
Event('COMMODITY_PURCHASED',999,7);assert(P.char.shoppingUncertain)
AuctionHouseFrame.BuyDialog:Hide();Event('COMMODITY_PURCHASED',101,7)
assert(not P.char.shoppingUncertain and P:ShoppingRow(101).pending==7)
Event('COMMODITY_PURCHASED',101,7);assert(P:ShoppingRow(101).pending==7)
Bag[101]=10;Event('BAG_UPDATE_DELAYED');assert(P:ShoppingRow(101).pending==0 and P:ShoppingRow(101).missing==0)
''')
run('Cancellation buys nothing; explicit failure removes reserved credit','''
CheckCommodity();P:SendShoppingItem();AuctionHouseFrame.BuyDialog:Hide()
assert(purchases==0 and P:ShoppingRow(101).pending==0)
CheckCommodity();P:SendShoppingItem();C_AuctionHouse.ConfirmCommoditiesPurchase(101,7)
AuctionHouseFrame.BuyDialog:Hide();Event('COMMODITY_PURCHASE_FAILED')
assert(P:ShoppingRow(101).missing==7 and not P.char.shoppingUncertain)
''')
run('Reload/disconnect uncertainty prevents duplicate buys until explicit reconciliation','''
CheckCommodity();P:SendShoppingItem();C_AuctionHouse.ConfirmCommoditiesPurchase(101,7)
P.shoppingTransaction=nil;AuctionHouseFrame.BuyDialog:Hide();local n=#searches
P:SearchShoppingItem(102);assert(#searches==n and P.char.shoppingUncertain)
P:ReconcileShoppingCredit(101);assert(P:ShoppingRow(101).pending==7)
P:ReconcileShoppingCredit(101);assert(P:ShoppingRow(101).pending==0 and not P.char.shoppingUncertain)
''')
run('Partial commodity stock and whole item stacks disclose shortages/surplus','''
commodityResults={{unitPrice=5,quantity=2,numOwnerItems=0}};CheckCommodity()
assert(P.shoppingOffer.quantity==2 and P.shoppingOffer.total==10)
P:RefreshShopping();assert(P.shoppingWindow.body.text:find('5 still needed',1,true))
itemResults={{itemKey={itemID=101},auctionID=702,quantity=10,buyoutAmount=50}}
P:SearchShoppingItem(101);Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101});P:RefreshShopping()
assert(P.shoppingOffer.quantity==10 and P.shoppingWindow.body.text:find('3 extra',1,true))
''')
run('Item buyout uses matching auction ID and only successful receipt credits stock','''
P.shoppingSelected=101;P:SearchShoppingItem(101);Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101})
P:SendShoppingItem();assert(#dialogs==0 and #exports==1 and purchases==0)
Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101})
C_AuctionHouse.PlaceBid(700,40);assert(P:ShoppingRow(101).pending==4)
Event('AUCTION_HOUSE_PURCHASE_COMPLETED',701);assert(P.char.shoppingUncertain)
Event('AUCTION_HOUSE_PURCHASE_COMPLETED',700);assert(not P.char.shoppingUncertain and P:ShoppingRow(101).missing==3)
''')
run('Changing a sample cannot trigger a purchase; own and bid-only listings are excluded','''
P.shoppingSelected=101;P:SearchShoppingItem(101);Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101})
itemResults[1].buyoutAmount=100;P:SendShoppingItem();assert(#dialogs==0 and purchases==0 and exports[1].terms[1].quantity==7)
itemResults[1].containsOwnerItem=true
itemResults[2]={itemKey={itemID=101},auctionID=701,quantity=2,minBid=1}
P:SearchShoppingItem(101);Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101})
assert(P.shoppingOffer.quantity==0 and purchases==0)
''')
run('Export uses current bag shortfall and blocks stale skills or combat without buying','''
CheckCommodity();now=31;Bag[101]=4;P:SendShoppingItem()
assert(#dialogs==0 and #exports==1 and exports[1].terms[1].quantity==6 and purchases==0)
P.skills.Alchemy.rank=2;assert(not P:SendShoppingItem() and #exports==1)
P.skills.Alchemy.rank=1;function InCombatLockdown()return true end
assert(not P:SendShoppingItem() and #exports==1 and purchases==0)
''')
run('AH closure, throttle, timeout, unrelated searches and profession changes invalidate review','''
ready=false;P:SearchShoppingItem(101);assert(#searches==0)
ready=true;P:SearchShoppingItem(101);Advance(31);assert(not P.shoppingQuery)
CheckCommodity();C_AuctionHouse.SendBrowseQuery({});assert(not P.shoppingOffer)
CheckCommodity();Event('AUCTION_HOUSE_CLOSED');assert(not P.shoppingOffer)
CheckCommodity();P.selectedProf='Cooking';P:RefreshShopping();assert(not P.shoppingOffer)
''')
run('Shopping pauses scanner; starting a cost scan invalidates shopping sample','''
P:StartPriceScan();assert(P.priceScan)
CheckCommodity();assert(not P.priceScan and P.shoppingOffer)
P:StartPriceScan();assert(not P.shoppingOffer)
''')
run('Active native confirmation prevents changing transactions or clearing credit','''
CheckCommodity();AuctionHouseFrame.BuyDialog:Show();local n=#searches
P:SearchShoppingItem(102);P:ReconcileShoppingCredit(101)
assert(#searches==n and not P.shoppingClearID and not P.shoppingTransaction)
''')
run('Saved shopping list is stable through price changes; rebuilding keeps mail credit','''
local saved=P:ShoppingPlan();P.market.prices[101].value=1000;P:InvalidatePlan();P:RefreshShopping()
assert(P:ShoppingPlan()==saved and P:ShoppingRow(101).cost==7000)
P:ShoppingTransit(101).count=2;P:BuildShopping(10);assert(P:ShoppingRow(101).missing==5)
''')
run('Auctionator advanced search receives exact localized names and net missing quantities','''
local calls={};Auctionator={API={v1={MultiSearchAdvanced=function(caller,terms)calls[#calls+1]={caller=caller,terms=terms}end,
 RegisterForDBUpdate=function(caller,fn)dbCallback=fn end}}}
C_Item.GetItemInfo=function(id)return id==101 and 'Copper Ore' or 'Silverleaf' end
P:ShoppingTransit(101).count=2;assert(P:ShopWithAuctionator())
assert(#calls==1 and calls[1].caller=='ProfPaden' and #calls[1].terms==2)
local quantities={};for _,t in ipairs(calls[1].terms)do assert(t.isExact);quantities[t.searchString]=t.quantity end
assert(quantities['Copper Ore']==5 and quantities.Silverleaf==10 and purchases==0)
P.planCache={};dbCallback();assert(not P.planCache and not P.shoppingWindow.shown)
''')
run('Auctionator export refuses uncached names, stale skills and API failure without losing list','''
C_Item.GetItemInfo=function()return nil end
local count=0;Auctionator={API={v1={MultiSearchAdvanced=function()count=count+1;error('mock failure')end}}}
assert(not P:ShopWithAuctionator() and count==0)
C_Item.GetItemInfo=function(id)return 'Material '..id end
local plan=P:ShoppingPlan();assert(not P:ShopWithAuctionator() and count==1 and not P.auctionatorShopping and P:ShoppingPlan()==plan)
P.skills.Alchemy.rank=2;assert(not P:ShopWithAuctionator() and count==1)
''')
run('Auctionator commodity and item buyouts credit receipts without reopening PP over Auctionator','''
Auctionator={API={v1={MultiSearchAdvanced=function()end}}};C_Item.GetItemInfo=function(id)return 'Material '..id end
assert(P:ShopWithAuctionator());C_AuctionHouse.ConfirmCommoditiesPurchase(101,3)
assert(P.shoppingTransaction.external and P:ShoppingRow(101).pending==3)
Event('COMMODITY_PURCHASED',101,3);Advance(1);assert(not P.shoppingWindow.shown and P:ShoppingRow(101).missing==4)
Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101});C_AuctionHouse.PlaceBid(700,40)
Event('AUCTION_HOUSE_PURCHASE_COMPLETED',700);assert(P:ShoppingRow(101).missing==0)
''')
run('Auctionator purchases outside the exported materials and bids are not credited','''
Auctionator={API={v1={MultiSearchAdvanced=function()end}}};C_Item.GetItemInfo=function(id)return 'Material '..id end
assert(P:ShopWithAuctionator());C_AuctionHouse.ConfirmCommoditiesPurchase(999,3)
assert(not P.shoppingTransaction and not P.char.shoppingUncertain)
Event('ITEM_SEARCH_RESULTS_ADDED',{itemID=101});C_AuctionHouse.PlaceBid(700,20)
assert(not P.shoppingTransaction and P:ShoppingRow(101).pending==0)
''')
run('Auctionator export preserves an active native confirmation and requires tracking','''
local calls=0;Auctionator={API={v1={MultiSearchAdvanced=function()calls=calls+1 end}}}
C_Item.GetItemInfo=function(id)return 'Material '..id end
CheckCommodity();AuctionHouseFrame.BuyDialog:Show();local tx=P.shoppingTransaction
assert(not P:ShopWithAuctionator() and calls==0 and P.shoppingTransaction==tx)
AuctionHouseFrame.BuyDialog:Hide();P.shoppingHooks=nil;hooksecurefunc=nil
assert(not P:ShopWithAuctionator() and calls==0)
''')
run('Missing Auctionator preserves the list and never falls back to Blizzard buy methods','''
Auctionator=nil;CheckCommodity();local plan=P:ShoppingPlan()
assert(not P:SendShoppingItem() and P:ShoppingPlan()==plan and purchases==0 and #dialogs==0)
P:RefreshShopping();assert(not P.shoppingWindow.buy.enabled)
''')
run('Export without checking prices sends only the selected material and never credits a purchase','''
P.shoppingSelected=102;assert(P:SendShoppingItem())
assert(#exports==1 and #exports[1].terms==1 and exports[1].terms[1].searchString=='Material 102')
assert(exports[1].terms[1].quantity==10 and #dialogs==0 and purchases==0)
assert(not P.char.shoppingUncertain and P:ShoppingRow(102).pending==0)
''')
report=dict(runtime='Actual Lua 5.1 modules; export-only Auctionator flow, read-only AH quotes and simulated receipts; no live purchases',tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'shopping-test-results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));sys.exit(report['passed']!=report['tests'])
