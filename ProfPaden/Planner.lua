local _, P = ...
function P:VendorSupply(id)
    local offer=self.char.unlimitedVendors and self.char.unlimitedVendors[id]
    local last=self.char.vendors and self.char.vendors[id]
    if last and last.stock==-1 then offer=last end
    if offer and offer.stock==-1 and type(offer.value)=="number" and offer.value>0 then return offer,true end
    return self.VendorSupplies and self.VendorSupplies[id],false
end
function P:Price(id,quantity)
    if not id then return nil,"Unknown item" end
    local supply,observed=self:VendorSupply(id)
    local manual=self.market.prices[id]
    if manual then return manual.value,"Manual",manual.time,supply and "vendor" or "auction",supply end
    if supply then return supply.value,observed and ("Merchant: "..(supply.name or "Merchant")) or "Vendor list estimate",supply.time,"vendor",supply end
    local best,source,stamp,method,offer
    local vendor=self.char.vendors and self.char.vendors[id]
    if vendor and vendor.stock and (vendor.stock==-1 or vendor.stock>=math.max(1,quantity or 1)) then best,source,stamp,method,offer=vendor.value,"Merchant: "..vendor.name,vendor.time,"vendor",vendor end
    local function candidate(value,from,when)
        if type(value)=="number" and value>0 and (not best or value<best) then best,source,stamp,method,offer=value,from,when,"auction",nil end
    end
    local obs=self.market.observed and self.market.observed[id]
    if obs and self.market.auctionatorScanStarted and obs.time<self.market.auctionatorScanStarted then obs=nil end
    if obs and time()-obs.time<=86400 then candidate(obs.value,obs.source,obs.time) end
    local fresh=obs and time()-obs.time<=86400
    if not fresh and TSM_API and TSM_API.GetCustomPriceValue then
        local ok,v=pcall(TSM_API.GetCustomPriceValue,"dbmarket","i:"..id)
        if ok then candidate(v,"TSM historical estimate") end
    end
    if not fresh and Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
        local ok,v=pcall(Auctionator.API.v1.GetAuctionPriceByItemID,self.name,id)
        if ok then candidate(v,"Auctionator estimate") end
    end
    if not fresh and AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue then
        self.auctioneerCache=self.auctioneerCache or {}
        local cached=self.auctioneerCache[id]
        if not cached or time()-cached.readTime>60 then
            local ok,value=pcall(AucAdvanced.API.GetMarketValue,id)
            cached={value=ok and type(value)=="number" and value>0 and value or nil,readTime=time()}
            self.auctioneerCache[id]=cached
            if cached.value then
                self.market.external=self.market.external or {}
                self.market.external[id]={value=cached.value,source="Auctioneer estimate",readTime=cached.readTime}
            end
        end
        candidate(cached.value,"Auctioneer estimate")
    end
    if best then return best,source,stamp,method,offer end
    local item=self.Items[id]
    if item and item.vendorBuy then return item.vendorBuy,"Vendor list estimate",nil,"vendor" end
    return nil,"Unknown",nil,"auction"
end
function P:Available(recipe)
    if recipe.complete==false or recipe.blocked then return 0 end
    if #recipe.mats==0 then return recipe.live and math.min(9999,recipe.available or 0) or 0 end
    local n=9999
    for _,m in ipairs(recipe.mats) do
        if not m.id or m.count<=0 then return 0 end
        n=math.min(n,math.floor(self:Count(m.id)/m.count))
    end
    if recipe.live then n=math.min(n,recipe.available or n) end
    return n
end
function P:Economy(recipe,quantity)
    quantity=quantity or 1
    local full=self:SourceRecipe(recipe,quantity)
    local remaining=self:SourceRecipe(recipe,quantity,{bags=true})
    return {cost=full.cost,knownCost=full.knownCost,missing=remaining.cost,knownMissing=remaining.knownCost,
        owned=full.cost and remaining.cost and math.max(0,full.cost-remaining.cost),knownOwned=math.max(0,full.knownCost-remaining.knownCost),
        unknown=full.unknown,missingUnknown=remaining.unknown,sourcePlan=full,missingPlan=remaining}
end
function P:StepCrafts(r)
    local rank=(self.skills[self.selectedProf] or {}).rank or 1
    if not r.crafts or not r.start or not r.stop then return nil end
    return math.max(0,math.ceil(r.crafts*math.max(0,r.stop-math.max(rank,r.start))/math.max(1,r.stop-r.start)))
end
function P:BaseChance(r,skill)
    if r.grey and skill>=r.grey then return 0 end
    -- Planning assumptions, not measured server rates. Discount the previous
    -- non-orange curve by 20%; use the same policy for live color estimates.
    local color=({optimal=1,medium=.4,easy=.16,trivial=0})[r.difficulty]
    local captured=r.skillAtCapture
    if not captured and r.live then captured=(self.skills[r.profession or self.selectedProf] or {}).rank end
    if color==0 and (not captured or skill>=captured) then return 0 end
    if color==1 and skill==captured then return 1 end
    if r.yellow and r.grey then
        local curve=skill<r.yellow and 1 or r.grey>r.yellow and math.max(0,(r.grey-skill)/(r.grey-r.yellow))*.8 or 0
        -- Known color boundaries constrain the forecast even before the live
        -- recipe turns yellow/green. Green starts at at most 16%, then falls
        -- toward zero; yellow declines from at most 40% toward that boundary.
        if r.green and r.green>r.yellow and r.grey>r.green and skill>=r.yellow then
            local band=skill<r.green and (.16+.24*(r.green-skill)/(r.green-r.yellow)) or .16*math.max(0,(r.grey-skill)/(r.grey-r.green))
            curve=math.min(curve,band)
        end
        if color and color<1 and captured and skill>=captured and r.grey>captured then
            -- Anchor future estimates to the observed color. Previously a
            -- yellow recipe could jump from 50% now to 70% next skill point.
            curve=math.min(curve,color*(r.grey-skill)/(r.grey-captured))
        end
        return curve
    end
    return color
end
function P:Chance(r,skill)
    local base=self:BaseChance(r,skill)
    return self.ObservedChance and self:ObservedChance(r,skill,base) or base
end
function P:Rows()
    if self.mode=="money" then return self:MoneyRows() end
    if self:IsOptimizedRoute() then return self:CheapestRows() end
    local prof=self.selectedProf;local rank=(self.skills[prof] or {}).rank or 1
    local list={};local seen={}
    local function add(base)
        local r={};for k,v in pairs(base) do r[k]=v end
        local live=self:Resolve(r)
        if live then
            for _,k in ipairs({"mats","complete","difficulty","skillAtCapture","grey","output","outputMax","available","api","index","cooldown","item","spell","enchant","blocked"}) do if live[k]~=nil then r[k]=live[k] end end
            r.live=true
        else
            for _,cached in pairs(self.char.recipes[prof] or {}) do if self.SameRecipe(r,cached) then
                r.mats=cached.mats;r.output=cached.output;r.outputMax=cached.outputMax;r.cached=true;r.complete=cached.complete;break
            end end
        end
        r.ready=self:Available(r);r.economy=self:Economy(r);r.chance=self:Chance(r,rank)
        local preparation=r.economy.missingPlan
        r.preparationReady=preparation and #preparation.steps>0 and preparation.unknown==0
        if r.preparationReady then for _,count in pairs(preparation.buy) do if count>0 then r.preparationReady=false;break end end end
        local key=r.spell and "s"..r.spell or r.item and "i"..r.item or r.name
        r.key=key..":"..(r.start or 0)
        local relevant=(r.start or 1)<=rank and (r.stop or 301)>rank
        r.current=relevant
        if self.mode=="all" or (self.mode=="guide" and (r.stop or 301)>rank and r.kind~="live") or
           (self.mode=="bags" and (r.ready>0 or r.preparationReady) and r.live and r.chance and r.chance>0) or
           (self.mode=="cost" and r.live and r.chance and r.chance>0) or self.mode=="live" and r.live then
            table.insert(list,r);seen[key]=true
        end
    end
    for _,r in ipairs(self.Recipes[prof] or {}) do add(r) end
    if self.mode~="guide" then
        for _,r in ipairs(self.live) do
            local key=r.spell and "s"..r.spell or r.item and "i"..r.item or r.name
            if r.profession==prof and not seen[key] then add(r) end
        end
    end
    table.sort(list,function(a,b)
        if self.mode=="cost" then
            local ac=a.economy.cost and a.chance and a.chance>0 and a.economy.cost/a.chance or math.huge
            local bc=b.economy.cost and b.chance and b.chance>0 and b.economy.cost/b.chance or math.huge
            if ac~=bc then return ac<bc end
        elseif self.mode=="bags" and a.ready~=b.ready then return a.ready>b.ready end
        if (a.start or rank)~=(b.start or rank) then return (a.start or rank)<(b.start or rank) end
        if a.kind~=b.kind then return a.kind=="guide" end
        return a.name<b.name
    end)
    return list
end
