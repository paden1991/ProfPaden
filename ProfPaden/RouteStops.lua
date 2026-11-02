local _,P=...
local function copy(t)local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function keys(t)local out={};for k in pairs(t or {}) do out[#out+1]=k end;table.sort(out);return out end

function P:RouteBatchLimit(r)
    if r and r.journeyPrepare then
        local rank=(self.skills[r.profession] or {}).rank or 0
        local boundary
        for _,n in pairs({r.yellow,r.green,r.grey}) do if n>rank and (not boundary or n<boundary) then boundary=n end end
        local goal=r.profession==self.selectedProf and self.planSummary and self.planSummary.target
        if goal and goal>rank and (self:Chance(r,rank) or 0)>0 and (not boundary or goal<boundary) then boundary=goal end
        return boundary and math.max(1,math.ceil((boundary-rank)/(r.numSkillUps or 1))) or 9999
    end
    if not r or not r.routeBand or not r.stop then return 9999 end
    local rank=(self.skills[r.profession or self.selectedProf] or {}).rank or r.start
    return math.max(0,math.ceil((r.stop-math.max(rank,r.start))/(r.numSkillUps or 1)))
end

function P:SkillBand(r,skill)
    if r.grey and skill>=r.grey then return "Gray" end
    if r.green and skill>=r.green then return "Green" end
    if r.yellow and skill>=r.yellow then return "Yellow" end
    if r.yellow then return "Orange" end
    return ({optimal="Orange",medium="Yellow",easy="Green",trivial="Gray"})[r.difficulty] or "Unknown"
end

-- Split an already costed segment without rounding a new batch at every
-- boundary. Its training charge, total crafts and material demand are conserved.
function P:SplitRouteBands(rows)
    local out={};local rank=(self.skills[self.selectedProf] or {}).rank or 1
    local nextRank=self:NextProfessionRank(self.selectedProf,(self.skills[self.selectedProf] or {}).cap)
    for _,r in ipairs(rows) do
        if not r.start or not r.stop or not r.crafts or r.money then out[#out+1]=r
        else
            local first=math.max(rank,r.start);local cuts={first};local seen={[first]=true}
            for _,n in pairs({r.yellow,r.green,r.grey,nextRank and nextRank[1]}) do
                if n>first and n<r.stop and not seen[n] then cuts[#cuts+1]=n;seen[n]=true end
            end
            cuts[#cuts+1]=r.stop;table.sort(cuts)
            local weights,total={},0
            for i=1,#cuts-1 do
                local w=0
                for skill=cuts[i],cuts[i+1]-1 do
                    local chance=self:PlanChance(r,skill,first)
                    w=w+(chance and chance>0 and 1/(chance*math.max(1,r.numSkillUps or 1)) or 1)
                end
                weights[i]=w;total=total+w
            end
            local count=r.crafts
            if not r.planStep then count=math.max(self:StepCrafts(r) or count,math.ceil(total-.0000001)) end
            local cumulative,assigned=0,0
            for i=1,#cuts-1 do
                cumulative=cumulative+weights[i]
                local upto=i==#cuts-1 and count or math.min(count,math.ceil(cumulative-.0000001))
                local n=upto-assigned;assigned=upto
                if n>0 then
                    local s=copy(r);s.start=cuts[i];s.stop=cuts[i+1];s.crafts=n
                    s.key=r.key..":band:"..s.start;s.routeBand=self:SkillBand(r,s.start)
                    s.routeBoundary=self:SkillBand(r,s.stop);s.routeParent=r.key
                    s.planCost=(r.planCost or 0)*n/count;s.planTraining=i==1 and (r.planTraining or 0) or 0
                    s.planProceeds=(r.planProceeds or 0)*n/count;s.planNet=s.planCost+s.planTraining-s.planProceeds
                    out[#out+1]=s
                end
            end
        end
    end
    return out
end

function P:RouteVendor(id,count)
    local _,_,_,method=self:Price(id,count)
    if method~="vendor" then return end
    local offers=copy(self.char.vendorOffers and self.char.vendorOffers[id])
    local last=self.char.vendors and self.char.vendors[id]
    if last and last.npcID then offers[last.npcID]=last end
    local ids,seen={},{}
    local function add(npc)
        local offer=offers[npc]
        if not seen[npc] and (not offer or offer.stock==-1 or (offer.stock or 0)>=count) then ids[#ids+1]=npc;seen[npc]=true end
    end
    for _,npc in ipairs((self.ReagentVendors or {})[id] or {}) do add(npc) end
    for npc in pairs(offers) do add(npc) end
    table.sort(ids)
    local target=self:NearestNPC(ids)
    return target,ids,target and offers[target.npc.id]
end

function P:RouteTrainer(r)
    local prof=r.profession or self.selectedProf;local key=self:RecipeIdentity(r)
    local ids,seen={},{}
    local function add(t)
        if t and t.npcID and t.eligible and not seen[t.npcID] then ids[#ids+1]=t.npcID;seen[t.npcID]=true end
    end
    for _,offer in pairs(self.char.trainerOffers and self.char.trainerOffers[prof] and self.char.trainerOffers[prof][key] or {}) do add(offer) end
    add(self.char.trainers and self.char.trainers[prof] and self.char.trainers[prof][key])
    table.sort(ids)
    return self:NearestNPC(ids),ids
end

function P:RouteRankStop(at)
    local skill=self.skills[self.selectedProf];local nextRank=skill and self:NextProfessionRank(self.selectedProf,skill.cap)
    if not nextRank or at<nextRank[1] then return end
    local label,target,kind=self:TrainingStop({stop=at})
    if not label then return end
    local special=({Cooking=true,["First Aid"]=true,Fishing=true})[self.selectedProf]
    local required=special and skill.cap==225 and 225 or nextRank[1]
    return {journeyAction=true,key="rank:"..self.selectedProf..":"..skill.cap,name=kind=="Book vendor" and "Buy the next profession book" or special and skill.cap==225 and "Unlock Artisan: profession quest" or "Train "..nextRank[3],
        actionKind=kind=="Book vendor" and "vendor" or special and skill.cap==225 and "quest" or "trainer",required=required,
        minLevel=nextRank[4],target=target,npcIDs=target and {target.npc.id} or {},sub="Skill "..required.." / next cap "..nextRank[2],note=label,rankStop=true,nextCap=nextRank[2],navPurchaseItem=kind=="Book vendor" and ({Cooking=16072,["First Aid"]=16084,Fishing=16083})[self.selectedProf] or nil}
end

-- The entire range shares Shopping's sourcing engine. Buy/prep each allocated
-- input once, just before its first consumer; do not charge bag stock twice.
function P:RouteEntries(rows)
    if self.mode~="guide" and self.mode~="cost" and self.mode~="profit" then return rows end
    if self.mode=="guide" and not self.skills[self.selectedProf] then self.planSummary=nil end
    if self.mode=="guide" and self.skills[self.selectedProf] then
        if not self.journeyGuideCache or self.journeyGuideCache.profession~=self.selectedProf then
            local options={kind="guide",bands={}}
            for i,r in ipairs(self.Recipes[self.selectedProf] or {}) do if r.kind=="guide" then
                local key=self:RecipeIdentity(r);options.bands[key]=options.bands[key] or {}
                table.insert(options.bands[key],{start=r.start or 1,stop=r.stop or 301,order=i})
            end end
            self.journeyGuideCache={profession=self.selectedProf,plan=self:BuildCheapestPlan(nil,"cost",options)}
        end
        self.planSummary=self.journeyGuideCache.plan;rows=self.planSummary.rows
    end
    local crafts=self:SplitRouteBands(rows);local needs={}
    for _,r in ipairs(crafts) do for _,m in ipairs(r.mats or {}) do
        if m.id then needs[m.id]=(needs[m.id] or 0)+m.count*(r.crafts or 1) end
    end end
    local supply=self:SourceNeeds(needs,{bags=true,mail=true});self.routeSupply=supply
    self.routeNeeds=needs
    local prep={};for i,s in ipairs(supply.steps) do prep[s.item]=prep[s.item] or {};prep[s.item][#prep[s.item]+1]={step=s,index=i} end
    local out,done,learned={}, {}, {};local rank=(self.skills[self.selectedProf] or {}).rank or 1
    local rankAdded=false
    local function rankStop(at)
        if rankAdded then return end
        local stop=self:RouteRankStop(at)
        if stop then out[#out+1]=stop;rankAdded=true end
    end
    local function input(id,required)
        if done[id] then return end;done[id]=true
        local mail=math.min(self:ShoppingTransit(id).count,math.max(0,(supply.used[id] or 0)-self:Count(id)))
        if mail>0 then
            out[#out+1]={journeyAction=true,key="mail:"..id,name="Collect mail: "..self:ItemName(id),actionKind="mail",item=id,mailCount=mail,required=required,
                icon=(self.Items[id] or {}).icon,sub=mail.." already purchased / collect before crafting",note="These tracked purchases are credited to this route. Collect them from a mailbox; no second purchase is needed."}
        end
        local count=supply.buy[id] or 0
        if count>0 then
            local target,ids,offer=self:RouteVendor(id,count);local _,_,_,method=self:Price(id,count)
            local vendor=method=="vendor"
            out[#out+1]={journeyAction=true,key="supply:"..id,name=(vendor and "Vendor supplies: " or "Auction supplies: ")..self:ItemName(id),
                actionKind=vendor and "vendor" or "shopping",item=id,count=count,target=target,npcIDs=ids or {},offer=offer,required=required,
                icon=(self.Items[id] or {}).icon,sub=count.." needed for remaining route"..(target and " / "..target.npc.name or ""),
                note=vendor and "Buy the listed quantity. Stock and discounts are checked when you visit." or "Open Shopping and export this route to Auctionator. Collect purchased items from mail before crafting."}
        end
        for _,entry in ipairs(prep[id] or {}) do
            local s=entry.step
            for _,m in ipairs(s.mats) do input(m.id,required) end
            local r=copy(s);r.key="prepare:"..tostring(s.spell or s.item)..":"..entry.index;r.journeyPrepare=true;r.complete=true;r.required=required
            r.icon=(self.Items[s.item] or {}).icon
            for _,recipe in ipairs(self:SourcingRecipes()[s.item] or {}) do if recipe.spell==s.spell and recipe.profession==s.profession then
                for _,field in ipairs({"yellow","green","grey","difficulty","skillAtCapture","numSkillUps"}) do r[field]=recipe[field] end;break
            end end
            r.name="Prepare: "..s.name;r.prepName=s.name;r.output=s.output/s.crafts;r.ready=self:Available(r)
            r.sub=s.crafts.." crafts / "..s.profession.." / makes "..s.output;r.routeSub=r.sub
            out[#out+1]=r
        end
    end
    for _,r in ipairs(crafts) do
        local required=r.start or rank;rankStop(required)
        local known=r.live or r.cached or r.planKnown or self:Resolve(r)
        if not known then
            for _,cached in pairs(self.char.recipes[self.selectedProf] or {}) do if self.SameRecipe(r,cached) then known=true;break end end
        end
        local key=self:RecipeIdentity(r)
        if not known and not learned[key] then
            local target,ids=self:RouteTrainer(r);learned[key]=true
            out[#out+1]={journeyAction=true,key="learn:"..key,name="Learn: "..r.name,actionKind="trainer",target=target,npcIDs=ids,
                navSpell=r.spell,navRecipeKey=key,required=math.max(required,r.planLearn or r.learn or 1),fee=r.planTraining,sub="Before crafting / skill "..(r.planLearn or r.learn or required),
                note=target and "Recorded trainer offering. Learn this recipe before continuing." or "Acquire and learn this recipe first. Select it below for recipe sources; no exact trainer has been recorded."}
        end
        for _,m in ipairs(r.mats or {}) do if m.id then input(m.id,required) end end
        if r.routeBand then r.routeSub=r.start.."-"..r.stop.." / "..r.crafts.." crafts / "..r.routeBand..(r.routeBoundary~=r.routeBand and " > "..r.routeBoundary or "") end
        out[#out+1]=r
    end
    rankStop(crafts[#crafts] and crafts[#crafts].stop or rank)
    for _,r in ipairs(out) do if r.journeyAction then
        if r.target then r.url="https://www.wowhead.com/forever/npc="..r.target.npc.id
        elseif r.item then r.url="https://www.wowhead.com/forever/item="..r.item end
    end end
    return out
end

function P:OpenRouteShopping()
    local cfg=self:ShoppingConfig(true)
    cfg.mode=self.mode;cfg.saleKey=self:ProfitSetting();cfg.goal="fixed"
    cfg.target=self.planSummary and self.planSummary.target or (self.skills[self.selectedProf] or {}).cap or 0
    self:EnsureShoppingPlan(true)
    if not self.shoppingWindow then self:CreateShoppingUI() end
    self.shoppingWindow:Show();self:RefreshShopping()
end

function P:RouteStopReady(r)
    if r and r.gatherLearn then return true end -- Directions do not assert eligibility to purchase training.
    local skill=self.skills[self.selectedProf]
    return r and r.journeyAction and skill and skill.rank>=(r.required or 1) and (not r.minLevel or UnitLevel("player")>=r.minLevel)
end
function P:RouteDetailRows(r)
    local rows={}
    local function add(a,b)rows[#rows+1]={cells={a,b},widths={112,238}} end
    add("When",(self:RouteStopReady(r) and "Ready now" or "Later").." / skill "..(r.required or 1)..(r.minLevel and " / level "..r.minLevel or ""))
    if r.mailCount then add("Collect",r.mailCount.." x |Hitem:"..r.item.."|h["..self:ItemName(r.item).."]|h")
    elseif r.item then
        local price,source,stamp=self:Price(r.item)
        if r.offer then price,source,stamp=r.offer.value,"Merchant: "..r.offer.name,r.offer.time end
        add("Buy",r.count.." x |Hitem:"..r.item.."|h["..self:ItemName(r.item).."]|h")
        add("Each / total",self:SmallMoney(price).." / "..self:SmallMoney(price and price*r.count))
        add("Price updated",self:PriceDate(stamp,source,r.item))
    end
    if r.fee then add("Training fee",self:SmallMoney(r.fee)) end
    if r.target then
        add(r.target.comparable and "Nearest known NPC" or "Known NPC",self:NPCSourceText(r.target.npc.id))
        add("Directions",not self:IsNavigationEnabled() and "Tracking off - enable Tracking above for directions." or self:RouteStopReady(r) and "Arrow appears automatically; right-click it to dismiss." or "Arrow starts when this step is available.")
    elseif r.actionKind=="vendor" or r.actionKind=="trainer" then add("Location","No usable supplier location recorded for this step.") end
    rows[#rows+1]={cells={r.note or ""},widths={350},muted=true}
    return rows
end

function P:UpdateRouteNavigation()
    if not (self:IsGatherGuide() or self.tab=="Recipes" and (self.mode=="guide" or self.mode=="cost" or self.mode=="profit")) or not self:IsNavigationEnabled() then
        if self.navRouteKey then self:ClearNavigation() end;return
    end
    local r=self.selected
    if not r or not r.journeyAction or not r.target or not self:RouteStopReady(r) then
        if self.navRouteKey then self:ClearNavigation() end;return
    end
    local key=self.selectedProf..":"..r.key
    if self.dismissedRouteKey==key then return end
    if self.completedNavigation and self.completedNavigation.key==key and self:NavigationGoalComplete(self.completedNavigation.goal) then return end
    local target=self:NearestNPC(r.npcIDs) or r.target
    if self.navRouteKey~=key or not self.navTarget or self.navTarget.npc.id~=target.npc.id then
        if self:TrackNPC(target.npc.id,nil,self:NPCNavigationGoal(r,target.npc.id)) then self.navRouteKey=key end
    end
end
