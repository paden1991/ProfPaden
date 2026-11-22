local _, P = ...
local E = P.Engine
local tests = 0
local function check(ok, message) tests = tests + 1; assert(ok, message) end
local entry = P.Catalog[248682]
local prices = { [2447]=10, [765]=9, [2449]=15, [785]=30, [2450]=40 }
local ages = {}
local stock = {}
local function price(id) return prices[id], ages[id] or 0 end
local function inventory(id, qty) local n = stock[id] or 0; return n, n >= qty and { bag=0, slot=id, count=n } or nil end
local function compare() return E.Compare(entry, price, inventory, 3) end
local r = compare()
check(r.best.itemID == 2449 and r.best.cost == 150, "compare bundle cost, not unit cost")
check(not r.fill, "cannot fill without inventory")
stock[2447] = 20
check(not compare().fill, "do not substitute expensive owned ingredients")
stock[2449] = 10
check(compare().fill.itemID == 2449, "cheapest complete carried bundle")
prices[765] = nil
check(compare().missing == 1 and not compare().fill, "unknown alternative blocks auto fill")
prices[765] = 9; ages[765] = 4
check(compare().stale == 1 and not compare().fill, "stale alternative blocks auto fill")
ages[765] = 0; prices[765] = 0
check(compare().missing == 1, "zero is not a price")
prices[765] = 0/0
check(compare().missing == 1, "NaN is not a price")
prices[765] = math.huge
check(compare().missing == 1, "infinity is not a price")
prices[765] = 7.5
check(compare().best.itemID == 2449, "equal-cost tie prefers materials ready in bags")
stock[2449]=0
check(compare().best.itemID == 765, "deterministic ID tie break when neither available")
stock[2449]=10
prices[765] = 9
ages[765]=0/0
check(not compare().fill, "invalid age cannot permit auto-fill")
ages[765]=0
r = E.Compare(entry, function(id) return prices[id] end, inventory, 3)
check(not r.fill and r.stale == 5, "unknown scan age requires manual choice")
local items = { [1]={itemID=2449, stackCount=6}, [2]={itemID=2449, stackCount=4}, [3]={itemID=2449, stackCount=10,isLocked=true}, [4]={itemID=2449, stackCount=13} }
local n, s = E.Inventory(2449,10,{0},function() return 4 end,function(_,slot) return items[slot] end)
check(n == 33 and s.slot == 4, "count split stacks but select unlocked sufficient stack")
items[4] = nil
n,s = E.Inventory(2449,10,{0},function() return 4 end,function(_,slot) return items[slot] end)
check(n == 20 and s.slot == 1, "split unlocked stacks select largest stack for server aggregation")
items[2].isLocked=true
n,s = E.Inventory(2449,10,{0},function() return 4 end,function(_,slot) return items[slot] end)
check(not s, "locked inventory cannot satisfy required quantity")
local context={enabled=true,autoFill=true}
local crate={itemID=248682,bag=0,slot=1}
r=compare()
check(E.FillPlan(entry,r,crate,context).targetID == 2449, "plan contains exact chosen target")
for _, flag in ipairs({'combat','modifier','cursor','targeting','service'}) do
    context[flag]=true
    check(not E.FillPlan(entry,r,crate,context), flag.." blocks fill")
    context[flag]=nil
end
context.autoFill=false
check(not E.FillPlan(entry,r,crate,context), "auto fill preference respected")
context.autoFill=true; crate.isLocked=true
check(not E.FillPlan(entry,r,crate,context), "locked crate blocked")
crate.isLocked=false; crate.itemID=999
check(not E.FillPlan(entry,r,crate,context), "moved/replaced crate blocked")
local c,w=0,0
for id,e in pairs(P.Catalog) do
    check(id==e.itemID and #e.options>0, "catalog record structure")
    if e.kind=='crate' then c=c+1 else w=w+1; check(e.questID>0 and #e.options==1, "writ has fixed quest requirement") end
    local all=E.Compare(e,function() return 100,0 end,function(_,qty) return qty,{bag=0,slot=1,count=qty} end,3)
    check(all.best and all.complete, "every catalog entry priced")
    if e.kind=='writ' then check(not all.fill,"writ never autoused") end
end
check(c==30 and w==150, "catalog coverage")
return tests
