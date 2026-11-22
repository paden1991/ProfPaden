local _, P = ...
local n=0
local function check(ok,msg) n=n+1; assert(ok,msg) end
Auctionator=nil
check(P.Adapter.Price(2447)==nil,"missing Auctionator")
Auctionator={API={v1={GetAuctionPriceByItemID=function(caller,id) check(caller=='PadenCrates' and id==2447,'public API arguments'); return 17 end,
    GetAuctionAgeByItemID=function() return 0 end}}}
local price,age=P.Adapter.Price(2447)
check(price==17 and age==0,"zero-day scan age preserved")
Auctionator.API.v1.GetAuctionPriceByItemID=function() error('database unavailable') end
check(P.Adapter.Price(2447)==nil,"provider failure not treated as free")
local requests,clock,objectives=0,0,nil
GetTime=function() return clock end
C_QuestLog={GetQuestObjectives=function() return objectives end, RequestLoadQuestByID=function() requests=requests+1 end}
local entry=P.Adapter.Entry(264081)
check(entry.requirementSource=='catalog' and requests==1,'uncached quest fallback labelled')
P.Adapter.Entry(264081)
check(requests==1,'throttle hover requests')
clock=31; P.Adapter.Entry(264081)
check(requests==2,'allow retry after failed load')
objectives={{type='item',numRequired=7}}
entry=P.Adapter.Entry(264081)
check(entry.options[1].quantity==7 and entry.requirementSource=='liveQuantity','live quantity takes precedence')
check(P.Catalog[264081].options[1].quantity==1,'do not mutate source catalog')
objectives={{type='item',text="Craftsman's Writ: Advanced Target Dummy: 1/1",numRequired=1},
    {type='item',text='Advanced Target Dummy: 0/3',numRequired=3}}
entry=P.Adapter.Entry(264081)
check(entry.requirementSource=='liveQuantity' and entry.options[1].quantity==3,'exclude required writ itself from two item objectives')
objectives[1].text='|cffffffff|Hitem:264081::::::::|h[Localized writ]|h|r: 1/1'
entry=P.Adapter.Entry(264081)
check(entry.options[1].quantity==3,'hyperlinked writ recognized by ID')
C_Item={GetItemNameByID=function() return 'Commande artisanale' end}
objectives[1].text='Commande artisanale: 1/1'
entry=P.Adapter.Entry(264081)
check(entry.options[1].quantity==3,'localized writ self requirement excluded')
objectives[1].text='Unrelated material: 0/2'
entry=P.Adapter.Entry(264081)
check(entry.options==nil,'unrecognized extra material still blocks')
C_Item=nil
objectives={{type='item',numRequired=7},{type='item',numRequired=3}}
entry=P.Adapter.Entry(264081)
check(entry.requirementSource=='mismatch' and entry.options==nil,'multiple requirements suppress misleading cost')
return n
