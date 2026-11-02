local _,P=...
local function contains(ids,id)for _,v in ipairs(ids or {}) do if v==id then return true end end end
local function vendorItem(self,item,npc)
    for _,s in ipairs((self.ItemMeta[item] or {}).sources or {}) do if s.kind=="Vendor" and s.npc==npc then return true end end
    local offers=self.char.vendorOffers and self.char.vendorOffers[item]
    local last=self.char.vendors and self.char.vendors[item]
    if offers and offers[npc] or last and last.npcID==npc then return true end
    return contains((self.ReagentVendors or {})[item],npc)
end
function P:NPCNavigationGoal(r,npc,prof)
    if not r then return end
    prof=prof or r.profession or self.selectedProf
    local skill=self.skills[prof]
    local goal
    if r.journeyAction then
        if r.navPurchaseItem then goal={kind="item",item=r.navPurchaseItem,target=1}
        elseif r.rankStop and r.nextCap then goal={kind="rank",profession=prof,cap=r.nextCap}
        elseif r.actionKind=="vendor" and r.item and r.count then goal={kind="item",item=r.item,target=self:Count(r.item)+r.count}
        elseif r.actionKind=="trainer" and r.navSpell then goal={kind="recipe",profession=prof,spell=r.navSpell,key=r.navRecipeKey} end
        if goal then goal.routeKey=prof..":"..r.key end
        return goal
    end
    if r.gatherItem and r.item and vendorItem(self,r.item,npc) then return {kind="item",item=r.item,target=self:Count(r.item)+1} end
    if r.acquisitionOnly and r.item and vendorItem(self,r.item,npc) then return {kind="item",item=r.item,target=1} end
    for _,ref in ipairs(r.acquisitionItems or {}) do
        if ref.id and vendorItem(self,ref.id,npc) then return {kind="item",item=ref.id,target=1} end
    end
    local key=self:RecipeIdentity(r)
    local trainer=self.char.trainers and self.char.trainers[prof] and self.char.trainers[prof][key]
    if r.spell and (trainer and trainer.npcID==npc or contains(self.TrainerNPCs[prof],npc)) then
        local known=self.char.recipes[prof] and self.char.recipes[prof][key] or trainer and trainer.known or r.live or r.cached or r.known or r.planKnown
        if not known then return {kind="recipe",profession=prof,spell=r.spell,key=key} end
        if skill and skill.cap<300 then return {kind="rank",profession=prof,cap=skill.cap+75} end
    end
end
function P:ShoppingNavigationGoal(npc)
    local row=self.shoppingSelected and self:ShoppingRow(self.shoppingSelected)
    if not row or row.method~="vendor" or row.missing<=0 then return end
    local _,ids=self:RouteVendor(row.item,row.missing)
    if contains(ids,npc) then return {kind="item",item=row.item,target=self:Count(row.item)+row.missing} end
end
function P:NavigationGoalComplete(goal,event,spell)
    if not goal then return false end
    if goal.confirmed then return true end
    if goal.kind=="item" then return self:Count(goal.item)>=goal.target end
    local skill=self.skills[goal.profession]
    if goal.kind=="rank" then return skill and skill.cap>=goal.cap or false end
    if goal.kind=="recipe" then
        if event=="NEW_RECIPE_LEARNED" and tonumber(spell)==goal.spell then return true end
        local known=self.char.recipes[goal.profession] or {}
        if goal.key and known[goal.key] then return true end
        for _,r in pairs(known) do if r.spell==goal.spell then return true end end
        local services=self.char.trainers and self.char.trainers[goal.profession] or {}
        for _,r in pairs(services) do if r.known and (r.spell==goal.spell or goal.key and services[goal.key]==r) then return true end end
        for _,r in ipairs(self.live or {}) do if r.spell==goal.spell and (r.profession or self.selectedProf)==goal.profession then return true end end
    end
    return false
end
function P:CheckNavigationCompletion(event,spell)
    local goal=self.navGoal
    if not self.navTarget or not self:NavigationGoalComplete(goal,event,spell) then return false end
    -- Suppress immediate reattachment from the old selected row before the
    -- debounced route refresh has removed it. New incomplete goals still work.
    if goal.kind~="item" then goal.confirmed=true end
    if goal.routeKey then self.completedNavigation={key=goal.routeKey,goal=goal} end
    if self.navRouteKey then self.navigationRouteCompleted=true end
    self:ClearNavigation()
    return true
end
