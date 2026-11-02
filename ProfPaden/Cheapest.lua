local _,P=...
local function copy(r)local out={};for k,v in pairs(r) do out[k]=v end;return out end
local function identity(r)return r.spell and "s"..r.spell or r.item and "i"..r.item or r.name end
function P:InvalidatePlan() self.planCache=nil;self.sourcingPool=nil;self.journeyGuideCache=nil end
function P:RecipeIdentity(r)return identity(r) end
function P:MigrateFavoritePins()
    self.char.favorites=self.char.favorites or {}
    for prof,choices in pairs(self.char.routeChoices or {}) do
        if choices.pinned then
            self.char.favorites[prof]=self.char.favorites[prof] or {}
            self.char.favorites[prof][choices.pinned]=true
            choices.pinned=nil;choices.pinnedName=nil;choices.revision=(choices.revision or 0)+1
            self:InvalidatePlan()
        end
    end
end
function P:IsFavorite(r)
    local favorites=self.char.favorites and self.char.favorites[self.selectedProf]
    return favorites and favorites[identity(r)]==true or false
end
function P:ToggleFavorite(r)
    if not r then return end
    self.char.favorites=self.char.favorites or {}
    local prof=self.selectedProf;self.char.favorites[prof]=self.char.favorites[prof] or {}
    local favorites=self.char.favorites[prof];local key=identity(r)
    if not key then return end
    favorites[key]=not favorites[key] and true or nil
    self.message=favorites[key] and "Saved to Catalog > Show > Favorites." or "Removed from Favorites."
    if self.window then self:Refresh() end
end
function P:RouteChoices()
    self.char.routeChoices=self.char.routeChoices or {}
    self.char.routeChoices[self.selectedProf]=self.char.routeChoices[self.selectedProf] or {excluded={},revision=0}
    return self.char.routeChoices[self.selectedProf]
end
function P:SetRouteChoice(action,r)
    if action=="pin" then return self:ToggleFavorite(r) end
    local choices=self:RouteChoices();local key=r and identity(r)
    if action=="reset" then choices.excluded={}
    elseif action=="exclude" and key then
        choices.excluded[key]=not choices.excluded[key] and r.name or nil
    else return end
    choices.revision=choices.revision+1;self:InvalidatePlan()
    if self.tab=="Recipes" and self.mode=="cost" then self.offset=0;self.selectedKey=nil end
    self.message="Cheapest choices updated. Rebuild any saved shopping list to use them."
    if self.window then self:Refresh() end
    if self.shoppingWindow then self:RefreshShopping() end
end

-- Only remember services actually exposed by the trainer. Never buy training,
-- change trainer filters, or infer that an unlearned world drop is obtainable.
function P:CaptureTrainer()
    if not GetNumTrainerServices or not GetTrainerServiceInfo then return end
    local npcID=self.RememberNPC and self:RememberNPC()
    self.char.trainers=self.char.trainers or {}
    local bySpell,byName={},{}
    for prof,recipes in pairs(self.Catalog) do
        for _,r in ipairs(recipes) do if r.spell then
            bySpell[r.spell]={prof=prof,recipe=r}
            local name=(C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(r.spell)) or r.name
            if name then
                if byName[name]~=nil then byName[name]=false else byName[name]={prof=prof,recipe=r} end
            end
        end end
    end
    for prof,recipes in pairs(self.char.recipes) do
        for _,r in pairs(recipes) do if r.spell then
            bySpell[r.spell]=bySpell[r.spell] or {prof=prof,recipe=r}
            if byName[r.name]==nil then byName[r.name]={prof=prof,recipe=r} end
        end end
    end
    for i=1,GetNumTrainerServices() do
        local name,serviceType,_,reqLevel=GetTrainerServiceInfo(i)
        local link=GetTrainerServiceItemLink and GetTrainerServiceItemLink(i)
        local spell=self:SpellID(link)
        local match=spell and bySpell[spell] or byName[name]
        if match and (serviceType=="available" or serviceType=="unavailable" or serviceType=="used") then
            local prof,r=match.prof,match.recipe
            local skillName,rank,hasSkill
            if GetTrainerServiceSkillReq then skillName,rank,hasSkill=GetTrainerServiceSkillReq(i) end
            local required=tonumber(rank) or r.learn or 1
            local skillMatches=not skillName or skillName=="" or self:Canonical(skillName)==prof
            local abilitiesMet=true
            if GetTrainerServiceNumAbilityReq then
                for j=1,GetTrainerServiceNumAbilityReq(i) do
                    local _,met=GetTrainerServiceAbilityReq(i,j)
                    if not met then abilitiesMet=false end
                end
            end
            local current=(self.skills[prof] or {}).rank or 0
            local levelMet=not reqLevel or reqLevel<=UnitLevel("player")
            -- An unavailable service is usable later only when skill is its
            -- sole identified blocker; specializations/level gates stay out.
            local eligible=serviceType=="available" or serviceType=="used" or
                (serviceType=="unavailable" and skillMatches and hasSkill==false and required>current and levelMet and abilitiesMet)
            local cost=GetTrainerServiceCost and GetTrainerServiceCost(i)
            self.char.trainers[prof]=self.char.trainers[prof] or {}
            self.char.trainers[prof][identity(r)]={spell=r.spell,name=r.name,required=required,cost=cost,
                eligible=eligible,known=serviceType=="used",trainer=UnitName and UnitName("npc") or "Visited trainer",
                zone=GetRealZoneText and GetRealZoneText() or "",time=time(),serviceType=serviceType,npcID=npcID}
            if npcID then
                self.char.trainerOffers=self.char.trainerOffers or {}
                self.char.trainerOffers[prof]=self.char.trainerOffers[prof] or {}
                self.char.trainerOffers[prof][identity(r)]=self.char.trainerOffers[prof][identity(r)] or {}
                self.char.trainerOffers[prof][identity(r)][npcID]=self.char.trainers[prof][identity(r)]
            end
        end
    end
    self:InvalidatePlan()
end

function P:PlanChance(r,skill,start)
    if r.grey and skill>=r.grey then return 0 end
    if r.yellow and r.grey or r.skillAtCapture==skill and r.difficulty then return self:Chance(r,skill) end
    -- A current color is not evidence of future difficulty thresholds.
    if skill==start and r.live then return self:Chance(r,skill) end
end

function P:BuildCheapestPlan(goalOverride,objective,options)
    options=options or {}
    objective=objective or (self.mode=="profit" and "profit" or "cost")
    local profit=objective=="profit"
    local prof=self.selectedProf;local skill=self.skills[prof]
    local choices=self:RouteChoices()
    local first=skill and skill.rank or 0
    local cap=skill and skill.cap or first
    local goal=goalOverride or self.char.planTargets and self.char.planTargets[prof] or cap
    goal=math.max(first,math.min(cap,math.floor(tonumber(goal) or cap)))
    local plan={start=first,target=goal,reached=first,rows={},materials=0,training=0,shopping=0,total=0,
        considered=0,known=0,trainer=0,unpriced=0,uncertain=0,objective=objective,proceeds=0,net=0,unsellable=0,saleKey=self:ProfitSetting()}
    if not skill then plan.reason="Open this profession to record your skill and learned recipes.";return plan end
    local pool={}
    local function add(r)
        if r.acquisitionOnly then return end
        local key=identity(r);if not key then return end
        if not pool[key] then pool[key]=copy(r) else
            for k,v in pairs(r) do if pool[key][k]==nil then pool[key][k]=v end end
        end
    end
    for _,r in ipairs(self.Catalog[prof] or {}) do add(r) end
    for _,r in ipairs(self.Recipes[prof] or {}) do add(r) end
    for _,r in pairs(self.char.recipes[prof] or {}) do add(r) end
    for _,r in ipairs(self.live) do if r.profession==prof then add(r) end end
    local candidates={}
    for key,r in pairs(pool) do
        local live=self:Resolve(r);local saved=self.char.recipes[prof] and self.char.recipes[prof][key]
        if not saved then for _,s in pairs(self.char.recipes[prof] or {}) do if self.SameRecipe(r,s) then saved=s;break end end end
        local trainer=self.char.trainers and self.char.trainers[prof] and self.char.trainers[prof][key]
        local known=live~=nil or saved~=nil or trainer and trainer.known
        if not choices.excluded[key] and (known or trainer and trainer.eligible) and (not options.bands or options.bands[key]) and (options.kind~="live" or live) then
            plan.considered=plan.considered+1
            local actual=live or saved
            if actual then
                for _,field in ipairs({"name","mats","complete","difficulty","output","outputMax","available","api","index","cooldown","item","spell","enchant","icon","skillAtCapture","numSkillUps","blocked","planBlocked","grey"}) do
                    if actual[field]~=nil then r[field]=actual[field] end
                end
            end
            r.profession=prof;r.live=live~=nil;r.cached=not live and saved~=nil
            if live then r.skillAtCapture=first end
            r.planKnown=known and true or false
            r.planFee=known and 0 or trainer.cost
            r.planLearn=known and first or (trainer.required or r.learn or 1)
            r.planAccess=known and "Already learned" or ("Train at "..(trainer.trainer or "visited trainer").." • "..(trainer.zone or "").." • Skill "..r.planLearn)
            r.mats=r.mats or {}
            local economy=self:Economy(r)
            local sale=profit and self:SaleEstimate(r)
            r.planSale=sale
            if profit and not sale then plan.unsellable=plan.unsellable+1
            elseif economy.cost==nil and options.kind~="guide" or r.planFee==nil then plan.unpriced=plan.unpriced+1
            -- A missing forge/tool or today's bag shortage blocks the craft click,
            -- not a future shopping/leveling plan for an already learned recipe.
            elseif #r.mats==0 or r.complete==false or r.planBlocked or (r.cooldown and r.cooldown>0) then plan.uncertain=plan.uncertain+1
            elseif r.planLearn<goal and (self:PlanChance(r,math.max(first,r.planLearn),first) or 0)>0 then
                r.planUnit=economy.cost or 0;r.planID=key;candidates[#candidates+1]=r
                if known then plan.known=plan.known+1 else plan.trainer=plan.trainer+1 end
            else plan.uncertain=plan.uncertain+1 end
        end
    end
    table.sort(candidates,function(a,b)return a.planID<b.planID end)
    -- Shortest path over contiguous crafting segments. Each segment pays its
    -- training fee once, so a cheap recipe must repay its acquisition cost.
    -- Repeated training segments are conservatively charged again; no claim of
    -- global optimality across arbitrary learned-set/component inventory states.
    local best={[first]=0};local previous={};local inventories={[first]={}}
    for from=first,goal-1 do if best[from] then
        for _,r in ipairs(candidates) do if from>=r.planLearn and (not profit or not previous[from] or previous[from].recipe.planID~=r.planID) then
            local expected=0
            for to=from+1,goal do
                local band
                if options.bands then
                    for _,b in ipairs(options.bands[r.planID]) do if from>=b.start and to<=b.stop then band=b;break end end
                    if not band then break end
                end
                local chance=self:PlanChance(r,to-1,first)
                if not chance or chance<=0 then break end
                expected=expected+1/(chance*math.max(1,r.numSkillUps or 1))
                local crafts=math.max(1,math.ceil(expected-0.0000001))
                r.sourceCosts=r.sourceCosts or {}
                if not r.sourceCosts[crafts] then r.sourceCosts[crafts]=self:SourceRecipe(r,crafts).knownCost end
                local value=best[from]+r.sourceCosts[crafts]-crafts*(r.planSale and r.planSale.net or 0)+r.planFee
                local needs
                if options.kind=="guide" then value=best[from]+band.order*(to-from)+crafts*.0001
                elseif options.kind=="bags" then
                    needs={};for id,count in pairs(inventories[from]) do needs[id]=count end
                    for _,m in ipairs(r.mats) do needs[m.id]=(needs[m.id] or 0)+m.count*crafts end
                    local before=self:SourceNeeds(inventories[from],{bags=true,mail=true}).knownCost
                    local after=self:SourceNeeds(needs,{bags=true,mail=true}).knownCost
                    value=best[from]+after-before+r.planFee
                end
                if not best[to] or value<best[to]-0.000001 then
                    best[to]=value;if needs then inventories[to]=needs end;previous[to]={from=from,recipe=r,crafts=crafts,expected=expected}
                end
            end
        end end
    end end
    local reached=goal;while reached>first and not best[reached] do reached=reached-1 end
    plan.reached=reached
    local at=reached
    while previous[at] do
        local step=previous[at];local r=copy(step.recipe)
        r.start=step.from;r.stop=at;r.crafts=step.crafts;r.planExpected=step.expected
        r.planCost=self:SourceRecipe(r,r.crafts).knownCost;r.planTraining=r.planFee
        r.planProceeds=r.crafts*(r.planSale and r.planSale.net or 0);r.planNet=r.planCost+r.planTraining-r.planProceeds
        r.key="plan:"..r.planID..":"..r.start
        table.insert(plan.rows,1,r);at=step.from
    end
    local needs={}
    for i,r in ipairs(plan.rows) do
        r.planStep=i
        plan.proceeds=plan.proceeds+r.planProceeds
        plan.materials=plan.materials+r.planCost;plan.training=plan.training+r.planTraining
        for _,m in ipairs(r.mats) do needs[m.id]=(needs[m.id] or 0)+m.count*r.crafts end
    end
    plan.sourcePlan=self:SourceNeeds(needs)
    plan.missingPlan=self:SourceNeeds(needs,{bags=true})
    plan.materials=plan.sourcePlan.knownCost;plan.shopping=plan.missingPlan.knownCost
    plan.total=plan.materials+plan.training;plan.owned=plan.materials-plan.shopping;plan.remaining=plan.shopping+plan.training
    plan.net=plan.total-plan.proceeds
    if reached<goal then plan.reason="No priced, accessible recipe with usable skill-up data at skill "..reached..". Check recipe exclusions, open your profession, visit a trainer with all service filters shown, and scan missing prices."..(profit and " Profit also needs a sellable output and a price for the selected sale method; open the profession to cache item information." or "") end
    if reached<goal and options.kind=="guide" then plan.reason="No accessible main guide step covers skill "..reached..". Learn the recipe or try Cheapest / All steps."
    elseif reached<goal and options.kind=="all" then plan.reason="No priced, accessible guide step or alternative covers skill "..reached..". Scan prices, learn recipes or try Cheapest."
    elseif reached<goal and options.kind=="live" then plan.reason="Open the profession, clear its filters and expand categories. Live alternatives need priced recipes with skill-up data covering skill "..reached.."." end
    return plan
end

function P:CheapestRows()
    local skill=self.skills[self.selectedProf] or {}
    local key=self.mode..":"..self:ProfitSetting()..":"..self.selectedProf..":"..(skill.rank or 0)..":"..(skill.cap or 0)..":"..tostring(self.char.planTargets and self.char.planTargets[self.selectedProf])
    if not self.planCache or self.planCache.key~=key or time()-(self.planCache.time or 0)>60 then
        self.planCache={key=key,time=time(),plan=self:BuildCheapestPlan()}
    end
    self.planSummary=self.planCache.plan
    for _,r in ipairs(self.planSummary.rows) do r.ready=self:Available(r);r.economy=self:Economy(r) end
    return self.planSummary.rows
end

function P:PlanSummaryText()
    local p=self.planSummary;if not p then return "" end
    return (self.mode=="guide" and "GUIDED ROUTE" or p.objective=="profit" and "PROFIT / MINIMAL LOSS" or "CHEAPEST ROUTE").." • "..p.start.." to "..p.target.."\n"..
        "Planned to "..p.reached.." • "..#p.rows.." step(s)\n"..
        "Total material value: "..self:Money(p.materials).."\n"..
        "Materials you own: "..self:Money(p.materials-p.shopping).."\n"..
        "Still to buy: "..self:Money(p.shopping).." • Training fees: "..self:Money(p.training).."\n"..
        "Estimated remaining cost: "..self:Money(p.shopping+p.training).."\n"..
        (p.objective=="profit" and ("Sale: "..self:ProfitLabel(p.saleKey).."\nEstimated proceeds: "..self:Money(p.proceeds).."\n"..self:NetLabel(p.net)..": "..self:Money(math.abs(p.net)).."\n"..p.unsellable.." recipes without usable sale data\n") or "")..
        p.known.." learned / "..p.trainer.." trainer recipes • "..p.unpriced.." unpriced\n\n"..
        (p.preferenceNotice and p.preferenceNotice.."\n" or "")..(p.reason and p.reason or "Select a step for materials and training.")
end
