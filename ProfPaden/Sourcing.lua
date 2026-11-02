local _,P=...
local function copy(t)local r={};for k,v in pairs(t or {}) do r[k]=v end;return r end
local function keys(t)local r={};for k in pairs(t) do r[#r+1]=k end;table.sort(r);return r end
local function blank(stock)return {knownCost=0,unknown=0,needs={},buy={},used={},steps={},remaining=copy(stock)} end
local function merge(a,b)
    a.knownCost=a.knownCost+b.knownCost;a.unknown=a.unknown+b.unknown;a.remaining=b.remaining
    for _,field in ipairs({'needs','buy','used'}) do for id,n in pairs(b[field]) do a[field][id]=(a[field][id] or 0)+n end end
    for _,step in ipairs(b.steps) do a.steps[#a.steps+1]=step end
end
function P:SourcingRecipes()
    if self.sourcingPool then return self.sourcingPool end
    local pool={};local seen={}
    local function add(base,prof)
        if not self.skills[prof] then return end
        local key=self:RecipeIdentity(base);if not key or seen[prof..':'..key] then return end
        local r=copy(base)
        for _,c in ipairs(self.Catalog[prof] or {}) do if self.SameRecipe(base,c) then for k,v in pairs(c) do if r[k]==nil then r[k]=v end end;break end end
        if r.planBlocked or r.cooldown and r.cooldown>0 then seen[prof..':'..key]=true;return end
        if not r.item or r.enchant or r.acquisitionOnly or r.complete==false or not r.mats or #r.mats==0 then return end
        for _,m in ipairs(r.mats) do if not m.id or not m.count or m.count<=0 then return end end
        seen[prof..':'..key]=true;r.profession=prof;r.sourceKey=key
        pool[r.item]=pool[r.item] or {};pool[r.item][#pool[r.item]+1]=r
    end
    -- Live data wins. Only learned conversions qualify; an unlearned recipe
    -- cannot silently become an ingredient supplier in another profession.
    for _,r in ipairs(self.live or {}) do add(r,r.profession or self.selectedProf) end
    for prof,recipes in pairs(self.char.recipes or {}) do for _,r in pairs(recipes) do add(r,prof) end end
    for prof,services in pairs(self.char.trainers or {}) do for _,t in pairs(services) do if t.known then
        for _,r in ipairs(self.Catalog[prof] or {}) do if r.spell==t.spell then add(r,prof);break end end
    end end end
    for _,recipes in pairs(pool) do table.sort(recipes,function(a,b)return a.sourceKey<b.sourceKey end) end
    self.sourcingPool=pool;return pool
end
function P:SourceNeeds(needs,options)
    options=options or {};local pool=self:SourcingRecipes()
    local function quote(id,count)if options.policy=='money' then return self:MoneyInputPrice(id) end;return self:Price(id,count) end
    local function available(stock,id)
        if stock[id]==nil then stock[id]=options.inventory and options.inventory[id] or (options.bags and self:Count(id) or 0)
            if options.mail then stock[id]=stock[id]+self:ShoppingTransit(id).count end
        end
        return stock[id]
    end
    local solve
    solve=function(id,count,stock,path,depth)
        stock=copy(stock);local owned=math.min(count,available(stock,id));stock[id]=stock[id]-owned
        local buy=count-owned;local price,_,_,method=quote(id,buy)
        local best=blank(stock);best.needs[id]=count;best.buy[id]=buy;best.used[id]=owned
        best.knownCost=price and price*buy or 0;best.unknown=buy>0 and price==nil and 1 or 0
        if buy>0 and not path[id] and depth<8 and not (options.policy=='money' and method=='vendor') then
            local nextPath=copy(path);nextPath[id]=true
            for _,r in ipairs(pool[id] or {}) do
                local crafts=math.ceil(buy/math.max(1,tonumber(r.output) or 1));local raw={}
                for _,m in ipairs(r.mats) do raw[m.id]=(raw[m.id] or 0)+m.count*crafts end
                local made=blank(stock)
                if owned>0 then made.needs[id]=owned;made.used[id]=owned;made.buy[id]=0 end
                for _,input in ipairs(keys(raw)) do merge(made,solve(input,raw[input],made.remaining,nextPath,depth+1)) end
                if made.unknown==0 and (best.unknown>0 or made.knownCost<best.knownCost-.000001) then
                    made.steps[#made.steps+1]={item=id,name=r.name,spell=r.spell,profession=r.profession,crafts=crafts,output=crafts*math.max(1,tonumber(r.output) or 1),needed=buy,cost=made.knownCost,direct=price and price*buy,mats=r.mats}
                    best=made
                end
            end
        end
        return best
    end
    local result=blank(options.inventory)
    for _,id in ipairs(keys(needs)) do if needs[id]>0 then merge(result,solve(id,needs[id],result.remaining,options.blocked or {},0)) end end
    result.cost=result.unknown==0 and result.knownCost or nil
    return result
end
function P:RecipeNeeds(r,n)
    local needs={};local invalid=false
    for _,m in ipairs(r.mats or {}) do if m.id and m.count and m.count>0 then needs[m.id]=(needs[m.id] or 0)+m.count*n else invalid=true end end
    return needs,invalid
end
function P:SourceRecipe(r,n,options)
    options=copy(options);options.blocked=copy(options.blocked)
    if r.item then options.blocked[r.item]=true end
    local needs,invalid=self:RecipeNeeds(r,n);local result=self:SourceNeeds(needs,options)
    if invalid or r.complete==false then result.unknown=result.unknown+1;result.cost=nil end
    return result
end
function P:SourcingDetailRows(plan)
    local rows={};if not plan or #plan.steps==0 then return rows end
    rows[#rows+1]={cells={'MAKE INTERMEDIATE MATERIALS FIRST'},widths={350},heading=true}
    for _,s in ipairs(plan.steps) do
        rows[#rows+1]={cells={s.profession,s.crafts..' x '..s.name..' / makes '..s.output},widths={108,242}}
        rows[#rows+1]={cells={'Make / buy direct',self:SmallMoney(s.cost)..' / '..self:SmallMoney(s.direct)},widths={108,242}}
    end
    rows[#rows+1]={cells={'Follow preparation steps in order. Counts use minimum yields and round up; surplus is not credited. Preparation skill-ups are not assumed.'},widths={350},muted=true}
    return rows
end
