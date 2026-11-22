local _,P=...
local S=P.Shopping
local checks=0
local function check(v,message) checks=checks+1; assert(v,message) end
GetTime=function() return 0 end
C_QuestLog={GetQuestObjectives=function() return nil end,RequestLoadQuestByID=function() end}
for id,e in pairs(P.Catalog) do
    if e.kind=='writ' then
        local material=e.options[1]
        local cold=S.Build({[id]=2},{[material.itemID]=1},P.Adapter.Entry,function() return nil end,
            {buyCrates=false,buyWrits=true})
        check(#cold.blocked==0 and #cold.rows==1 and cold.units==material.quantity*2-1,
            'cold quest cache produces accurate recorded shortage for writ '..id)
    end
end
-- Loaded quests require the writ and the finished item. Neither the self-item nor
-- its fulfilled count should be bought, nor should bag stock be deducted twice.
C_QuestLog.GetQuestObjectives=function() return {
    {type='item',text="Craftsman's Writ: Advanced Target Dummy: 1/1",numRequired=1},
    {type='item',text='Advanced Target Dummy: 1/3',numRequired=3,numFulfilled=1}} end
local live=S.Build({[264081]=2},{[4392]=1},P.Adapter.Entry,function() return 100,0 end,
    {buyCrates=false,buyWrits=true})
check(#live.blocked==0 and live.units==5 and live.rows[1].itemID==4392,'real adapter includes only missing finished items')
local entries={
 [1]={itemID=1,kind='crate',name='Crate A',options={{itemID=10,name='Herb',quantity=10},{itemID=20,name='Ore',quantity=20}}},
 [2]={itemID=2,kind='crate',name='Crate B',options={{itemID=10,name='Herb',quantity=5}}},
 [3]={itemID=3,kind='writ',name='Writ A',requirementSource='liveQuantity',options={{itemID=10,name='Herb',quantity=7}}},
}
local prices={[10]=100,[20]=75}
local age=0
local function entry(id) return entries[id] end
local function price(id) return prices[id],age end
local options={buyCrates=true,buyWrits=true}
local plan=S.Build({[1]=3,[2]=2,[3]=2},{[10]=15},entry,price,options)
check(plan.crates==5 and plan.writs==2,'all stacked owned orders counted')
check(#plan.rows==1 and plan.rows[1].needed==54,'aggregate shared material across crates and writs')
check(plan.rows[1].missing==39 and plan.estimate==3900,'subtract owned inventory once')
check(plan.units==39 and #plan.blocked==0,'complete actionable plan')
plan=S.Build({[1]=3,[3]=2},{[10]=15},entry,price,{buyCrates=false,buyWrits=true})
check(plan.crates==0 and plan.writs==2 and plan.units==0,'writ-only selection and sufficient inventory')
plan=S.Build({[1]=3,[3]=2},{},entry,price,{buyCrates=true,buyWrits=false})
check(plan.writs==0 and plan.units==30,'crate-only selection')
plan=S.Build({[1]=3,[3]=2},{},entry,price,{buyCrates=false,buyWrits=false})
check(plan.crates+plan.writs==0 and #plan.rows==0,'both selectors disabled')
prices[20]=nil
plan=S.Build({[1]=1},{},entry,price,options)
check(plan.blocked[1].reason=='prices' and #plan.rows==0,'missing alternative prevents guessed cheapest')
prices[20]=75; age=4
plan=S.Build({[1]=1},{},entry,price,options)
check(plan.blocked[1].reason=='stale','old crate prices block choosing a bundle')
age=0; entries[3].requirementSource='catalog'
plan=S.Build({[3]=1},{},entry,price,options)
check(#plan.blocked==0 and plan.units==7,'uncached writ uses recorded requirement for shopping')
entries[3].requirementSource='mismatch'; entries[3].options=nil
plan=S.Build({[3]=1},{},entry,price,options)
check(plan.blocked[1].reason=='requirements','changed objective reported distinctly')
entries[3].requirementSource='liveQuantity'; entries[3].options={{itemID=10,name='Herb',quantity=7}}
prices[10]=nil
plan=S.Build({[3]=2},{},entry,price,options)
check(plan.units==14 and plan.unknown==1 and #plan.blocked==0,'fixed writ requirement can be searched without an old price')
prices[10]=100

-- Live adapter and atomic Auctionator export, with a fresh rebuild on each click.
P.db=options
local bags={[0]={[1]={itemID=248682,stackCount=2},[2]={itemID=248682,stackCount=3},
    [3]={itemID=2449,stackCount=7,isLocked=true},[4]={itemID=99999,stackCount=8}}}
Enum={BagIndex={ReagentBag=5}}
C_Container={GetContainerNumSlots=function(b) return b==0 and 4 or 0 end,
    GetContainerItemInfo=function(b,s) return bags[b] and bags[b][s] end}
local owned,stock=S.Snapshot()
check(owned[248682]==5 and stock[2449]==7 and not owned[99999],'scan merges repeated crate stacks and excludes unrelated items')
local itemPrices={[2447]=100,[765]=100,[2449]=150,[785]=400,[2450]=500}
local names={[2449]='Localized Earthroot'}
local exports,exported,loads=0,nil,0
Auctionator={API={v1={
 GetAuctionPriceByItemID=function(_,id) return itemPrices[id] end,
 GetAuctionAgeByItemID=function() return 0 end,
 MultiSearchAdvanced=function(caller,terms) check(caller=='PadenCrates','stable Auctionator caller ID'); exports=exports+1; exported=terms end,
}}}
C_Item={GetItemNameByID=function(id) return names[id] end,RequestLoadItemDataByID=function() loads=loads+1 end}
local combat,ahOpen=false,false
InCombatLockdown=function() return combat end
AuctionHouseFrame={IsShown=function() return ahOpen end}
local ok,key=S.Send()
check(not ok and key=='SHOP_OPEN_AH' and exports==0,'AH must be open')
ahOpen=true; combat=true
ok,key=S.Send()
check(not ok and key=='SHOP_COMBAT','combat blocks launching purchases')
combat=false
ok,key=S.Send()
check(ok and exports==1 and #exported==1,'single batch export')
check(exported[1].searchString=='Localized Earthroot' and exported[1].isExact and exported[1].quantity==43,'exact localized item and quantity after stock deduction')
ok,key=S.Send()
check(not ok and key=='SHOP_ALREADY_SENT' and exports==1,'repeat click cannot reset an unchanged Auctionator quantity list')
bags[0][2].stackCount=2 -- user removed one crate while panel was open
ok,key=S.Send()
check(ok and exported[1].quantity==33,'send rebuilds from current bags rather than preview')
S.sentSignature=nil; names[2449]=nil
ok,key=S.Send()
check(not ok and key=='SHOP_NAMES' and loads==1 and exports==2,'uncached localized name aborts entire export')
names[2449]='Bad;name'
ok,key=S.Send()
check(not ok and key=='SHOP_NAME_FORMAT' and exports==2,'reject advanced-search metacharacters')
names[2449]='Localized Earthroot'
AuctionHouseFrame.BuyDialog={IsShown=function() return true end}
ok,key=S.Send()
check(not ok and key=='SHOP_FINISH_PURCHASE','do not interrupt current purchase confirmation')
AuctionHouseFrame.BuyDialog=nil
AuctionatorBuyCommodityFrame={FinalConfirmationDialog={IsVisible=function() return true end}}
ok,key=S.Send()
check(not ok and key=='SHOP_FINISH_PURCHASE','preserve Auctionator commodity confirmation')
AuctionatorBuyCommodityFrame=nil
AuctionatorBuyItemFrame={BuyDialog={IsVisible=function() return true end}}
ok,key=S.Send()
check(not ok and key=='SHOP_FINISH_PURCHASE','preserve Auctionator item confirmation')
AuctionatorBuyItemFrame=nil
Auctionator.API.v1.MultiSearchAdvanced=function() error('not ready') end
ok,key=S.Send()
check(not ok and key=='SHOP_FAILED' and not S.sentSignature,'provider error allows retry without marking purchases')
Auctionator=nil
ok,key=S.Send()
check(not ok and key=='SHOP_PROVIDER','missing provider reported')
return checks
