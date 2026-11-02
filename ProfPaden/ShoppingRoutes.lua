local _,P=...
P.ShoppingModes={guide="Guided",cost="Cheapest",profit="Profit / minimal loss",bags="In my bags first",live="Live alternatives",all="All steps"}
P.ShoppingModeHelp={
 guide="Follows the main guide steps you can learn or already know. Prices are optional.",
 cost="Lowest estimated full material value plus training fees.",
 profit="Material value and training minus estimated vendor or auction proceeds.",
 bags="Uses available bag and tracked-mail supplies to reduce additional spending.",
 live="Plans only recipes exposed by your currently open profession window.",
 all="Chooses one affordable path through guide steps and alternatives; never buys every alternative."
}
function P:ShoppingConfig(create)
    self.char.shoppingOptions=self.char.shoppingOptions or {}
    local cfg=self.char.shoppingOptions[self.selectedProf]
    if not cfg and create then
        local skill=self.skills[self.selectedProf] or {rank=0,cap=0};local old=self:ShoppingPlan()
        cfg={mode=old and (old.routeMode or old.objective) or self.mode or "cost",saleKey=old and old.saleKey or self:ProfitSetting(),target=old and old.target or math.min(skill.cap,skill.rank+10),goal="fixed"}
        if not self.ShoppingModes[cfg.mode] then cfg.mode="cost" end
        self.char.shoppingOptions[self.selectedProf]=cfg
    end
    if cfg then
        if not self.ShoppingModes[cfg.mode] then cfg.mode="cost" end
        local validSale=false;for _,option in ipairs(self:ProfitOptions()) do if option.value=="profit:"..tostring(cfg.saleKey) then validSale=true end end
        if not validSale then cfg.saleKey="vendor" end
        local skill=self.skills[self.selectedProf] or {rank=0,cap=0}
        cfg.target=math.max(0,math.floor(tonumber(cfg.target) or math.min(skill.cap,skill.rank+10)))
        if cfg.goal~="cap" then cfg.goal="fixed" end
    end
    return cfg
end
function P:ShoppingMode()
    local cfg=self:ShoppingConfig()
    return cfg and cfg.mode or (self.mode=="profit" and "profit" or "cost")
end
function P:ShoppingSaleKey()
    local cfg=self:ShoppingConfig();return cfg and cfg.saleKey or self:ProfitSetting()
end
function P:ShoppingModeOptions()
    local list={}
    for _,mode in ipairs({"guide","cost","profit","bags","live","all"}) do
        list[#list+1]=mode=="profit" and {label=self.ShoppingModes[mode],children=self:ProfitOptions()} or {label=self.ShoppingModes[mode],value=mode}
    end
    return list
end
function P:SetShoppingMode(value)
    local cfg=self:ShoppingConfig(true)
    if value:find("^profit:") then cfg.mode="profit";cfg.saleKey=value:sub(8)
    elseif self.ShoppingModes[value] then cfg.mode=value else return end
    self:CancelShoppingSearch();self.shoppingMessage=nil;self.shoppingDirty=true
    self:EnsureShoppingPlan(true);self:RefreshShopping()
end
function P:SetShoppingGoal(value,relative)
    local skill=self.skills[self.selectedProf]
    if not skill then self:ShoppingNotice("Open this profession to read its skill first.");return false end
    local cfg=self:ShoppingConfig(true)
    local target=value=="cap" and skill.cap or tonumber(value)
    if not target or target~=math.floor(target) or target<1 then self:ShoppingNotice("Enter a whole target skill above your current skill.");return false end
    if relative then target=skill.rank+target end
    if target<skill.rank then self:ShoppingNotice("The target cannot be below your current skill.");return false end
    cfg.goal=value=="cap" and "cap" or "fixed";cfg.target=math.min(skill.cap,target)
    self.shoppingMessage=target>skill.cap and "Goal limited to your trained cap. Train the next rank for a higher target." or nil
    local built=self:EnsureShoppingPlan(true);self:RefreshShopping();return built
end
function P:BuildShoppingRoute(target)
    local mode=self:ShoppingMode();local opts={kind=mode}
    if mode=="guide" or mode=="all" then
        opts.bands={}
        for index,r in ipairs(self.Recipes[self.selectedProf] or {}) do
            if mode=="all" or r.kind=="guide" then
                local key=self:RecipeIdentity(r);opts.bands[key]=opts.bands[key] or {}
                opts.bands[key][#opts.bands[key]+1]={start=r.start or 1,stop=r.stop or 301,order=index}
            end
        end
    end
    if mode=="bags" then opts.inventory={};for _,r in ipairs(self.Catalog[self.selectedProf] or {}) do for _,m in ipairs(r.mats or {}) do if m.id then opts.inventory[m.id]=self:Count(m.id)+self:ShoppingTransit(m.id).count end end end end
    local old=self.shoppingPlanningSale;self.shoppingPlanningSale=self:ShoppingSaleKey()
    local ok,plan=pcall(self.BuildCheapestPlan,self,target,mode=="profit" and "profit" or "cost",opts)
    self.shoppingPlanningSale=old
    if not ok then error(plan) end
    plan.routeMode=mode;return plan
end
function P:EnsureShoppingPlan(force)
    local receipt=self.char.shoppingUncertain
    if receipt then self:ShoppingTransit(receipt.item) end
    local cfg=self:ShoppingConfig(force)
    if not cfg then return false end
    if self.shoppingRebuilding then
        if force then self:ShoppingNotice("The route is still updating. Try again shortly.") end
        return false
    end
    if cfg.cancelled and not force then return false end
    -- Automatic refresh waits for purchase results. Explicit planning is read-only
    -- and may restart a canceled list without discarding an outstanding receipt.
    if not force then
        if self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent then return false end
        if AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() then return false end
        if StaticPopup_Visible and StaticPopup_Visible("BUYOUT_AUCTION") then return false end
    end
    local skill=self.skills[self.selectedProf]
    if not skill then
        if force then self:ShoppingNotice("Open this profession to read its skill and recipes, then choose Start new list.") end
        return false
    end
    local target=cfg.goal=="cap" and skill.cap or math.min(cfg.target or skill.rank,skill.cap)
    local plan=self:ShoppingPlan()
    if not force and plan and not self.shoppingDirty and not self:ShoppingIsStale() then return true end
    self.shoppingRebuilding=true
    if target<=skill.rank then
        self.char.shoppingPlans=self.char.shoppingPlans or {}
        self.char.shoppingPlans[self.selectedProf]={profession=self.selectedProf,start=skill.rank,cap=skill.cap,target=target,reached=skill.rank,needs={},steps={},training=0,completeGoal=true,purchaseModel=self.purchaseModel,
            routeMode=cfg.mode,objective=cfg.mode=="profit" and "profit" or "cost",saleKey=cfg.saleKey,chanceModel=self.skillChanceModel,choiceRevision=self:RouteChoices().revision,created=time(),requested=0,dataRevision=self.shoppingDataRevision or 0}
        cfg.cancelled=nil
        self:CancelShoppingSearch()
        self.shoppingMessage=skill.rank>=skill.cap and "At your trained cap. Train the next profession rank to plan more levels." or "Goal reached. Choose a higher target to plan more levels."
    else
        local ok,built=pcall(self.BuildShopping,self,target-skill.rank,force)
        if not ok or not built then
            self.shoppingRebuilding=nil;self.shoppingDirty=true
            if not ok then self:ShoppingNotice("Could not build the route. Your previous list is kept; try again after opening the profession.") end
            return false
        end
    end
    self.shoppingDirty=nil;self.shoppingRebuilding=nil
    if self.char.shoppingUncertain then
        self:ShoppingNotice((self.shoppingMessage or "List updated.").." An earlier purchase is still tracked; use Resolve purchase before exporting again.")
    end
    return true
end
function P:ShoppingChanged(event)
    if not self.char then return end
    if event=="SKILL_LINES_CHANGED" or event:find("TRAINER",1,true) or event=="NEW_RECIPE_LEARNED" or event:find("TRADE_SKILL",1,true) or event:find("CRAFT",1,true) then self.shoppingDirty=true;self.shoppingDataRevision=(self.shoppingDataRevision or 0)+1 end
    if not self:ShoppingConfig() then return end
    if self.shoppingRefreshPending then return end
    self.shoppingRefreshPending=true
    C_Timer.After(.3,function()
        P.shoppingRefreshPending=nil
        if P.shoppingWindow and P.shoppingWindow:IsShown() then P:EnsureShoppingPlan();P:RefreshShopping() end
    end)
end
function P:ShoppingActionState(rows)
    local plan=self:ShoppingPlan();local skill=self.skills[self.selectedProf]
    if self.ShoppingCancelled and self:ShoppingCancelled() then
        return "Shopping canceled",false,"Choose Start new list or a new target to begin again. Purchased items and mail credits are kept."
    end
    if self:IsAuctionatorScanning() then return "Full scan running",false,"Wait for Auctionator to finish before exporting a shopping search." end
    if not skill then return "Open profession",false,"Open the profession to read your skill and recipes." end
    if self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent then return "Check purchase / mail",false,"Resolve the outstanding purchase before exporting again." end
    if plan and plan.completeGoal then return skill.rank>=skill.cap and "Train next rank" or "Goal reached",false,"Choose another goal when you are ready." end
    if self:ShoppingIsStale() then return "Updating list...",false,"Finish any open auction confirmation, then refresh the route." end
    if not plan or #plan.steps==0 then return "No route yet",false,plan and plan.reason or "Choose a route and goal to start." end
    local count,vendors=0,0;for _,r in ipairs(rows) do if r.missing>0 then if r.method=="vendor" then vendors=vendors+1 else count=count+1 end end end
    if count==0 and vendors>0 then return "Visit supply vendor",false,"Only vendor supplies remain. Select a material for supplier directions." end
    if count==0 then return "Materials covered",false,"Collect credited mail, then open the profession to craft." end
    if not self:AuctionatorShoppingAvailable() then return "Enable Auctionator",false,"Auctionator is required for exporting; your shopping list is saved." end
    if not self.auctionOpen then return "Visit auction house",false,"Open an auction house to export "..count.." missing materials to Auctionator." end
    if InCombatLockdown() then return "Leave combat",false,"Export becomes available after combat." end
    return "Export missing ("..count..")",true,"Review the exact quantities and buy in Auctionator."
end
