local _, P = ...
function P:ReadSkills()
    self.skills={}
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        for id,key in pairs(self.skillIDs) do
            local info=C_SkillInfo.GetSkillLineInfoByID(id)
            if info and info.rank and info.rank>0 then self.skills[key]={rank=info.rank,cap=info.maxRank or 75} end
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i=1,GetNumSkillLines() do
            local name,header,_,rank,_,_,cap=GetSkillLineInfo(i)
            local key=not header and self:Canonical(name)
            if key then self.skills[key]={rank=rank or 0,cap=cap or 75} end
        end
    elseif GetProfessions and GetProfessionInfo then
        local list={GetProfessions()}
        for i=1,6 do if list[i] then
            local name,_,rank,cap=GetProfessionInfo(list[i]);local key=self:Canonical(name)
            if key then self.skills[key]={rank=rank or 0,cap=cap or 75} end
        end end
    end
end
local function linked(a,b)
    if a.spell and b.spell then return a.spell==b.spell end
    if a.item and b.item then return a.item==b.item end
    return a.name==b.name
end
P.SameRecipe=linked
function P:ScanRecipes()
    if self.InvalidatePlan then self:InvalidatePlan() end
    self.live={}
    if not self.char or not self.openKind then return end
    local kind=self.openKind
    if kind=="trade" and C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and C_TradeSkillUI.GetRecipeInfo then return self:ScanModernRecipes() end
    if kind=="trade" and not GetTradeSkillInfo then return end
    if kind=="craft" and not GetCraftInfo then return end
    if kind=="trade" and ((IsTradeSkillLinked and IsTradeSkillLinked()) or (IsTradeSkillGuild and IsTradeSkillGuild())) then return end
    local name,rank,cap
    if kind=="trade" then name,rank,cap=GetTradeSkillLine()
    else name,rank,cap=GetCraftDisplaySkillLine() end
    local prof=self:Canonical(name)
    if not prof then return end
    self.activeProf=prof
    if rank then self.skills[prof]={rank=rank,cap=cap or 75} end
    local count=kind=="trade" and GetNumTradeSkills() or GetNumCrafts()
    for index=1,count do
        local recipe,difficulty,available
        if kind=="trade" then recipe,difficulty,available=GetTradeSkillInfo(index)
        else local sub;recipe,sub,difficulty,available=GetCraftInfo(index) end
        if recipe and difficulty~="header" then
            local link=kind=="trade" and GetTradeSkillItemLink(index) or (GetCraftItemLink and GetCraftItemLink(index))
            local r={name=recipe,index=index,api=kind,profession=prof,difficulty=difficulty,available=available or 0,
                item=self:ItemID(link),spell=self:SpellID(link),mats={},live=true,output=1,source="Known recipe in the open profession window",kind="live"}
            if kind=="trade" and GetTradeSkillRecipeLink then r.spell=self:SpellID(GetTradeSkillRecipeLink(index)) or r.spell end
            if kind=="trade" then
                r.icon=GetTradeSkillIcon(index)
                local lo,hi=GetTradeSkillNumMade(index);r.output=lo or 1;r.outputMax=hi or r.output
                r.cooldown=GetTradeSkillCooldown and GetTradeSkillCooldown(index)
            else r.icon=GetCraftIcon and GetCraftIcon(index) end
            local n=kind=="trade" and GetTradeSkillNumReagents(index) or GetCraftNumReagents(index)
            r.complete=true
            for j=1,n do
                local nm,texture,needed,owned,ml
                if kind=="trade" then nm,texture,needed,owned=GetTradeSkillReagentInfo(index,j);ml=GetTradeSkillReagentItemLink(index,j)
                else nm,texture,needed,owned=GetCraftReagentInfo(index,j);ml=GetCraftReagentItemLink(index,j) end
                local id=self:ItemID(ml)
                if not id or not needed then r.complete=false end
                table.insert(r.mats,{id=id,count=needed or 0,name=nm,owned=owned,icon=texture})
            end
            table.insert(self.live,r)
            -- Cache identity and reagent data only. Never reuse an index for crafting.
            local saved={name=r.name,item=r.item,spell=r.spell,mats=r.mats,icon=r.icon,output=r.output,outputMax=r.outputMax,complete=r.complete,difficulty=r.difficulty,skillAtCapture=rank}
            local key=r.spell and ("s"..r.spell) or r.item and ("i"..r.item) or r.name
            self.char.recipes[prof]=self.char.recipes[prof] or {};self.char.recipes[prof][key]=saved
        end
    end
end
function P:Resolve(recipe)
    for _,r in ipairs(self.live) do if r.profession==(recipe.journeyPrepare and recipe.profession or self.selectedProf) and linked(recipe,r) then return r end end
end
function P:Craft(recipe,amount)
    if InCombatLockdown() then return false,"Leave combat before crafting." end
    if not amount or amount~=math.floor(amount) or amount<1 or amount>9999 then return false,"Enter a whole number of crafts from 1 to 9999." end
    if self.RouteBatchLimit and amount>self:RouteBatchLimit(recipe) then return false,"Use a smaller batch to reassess at the next route/color boundary." end
    self:ScanRecipes()
    local r=self:Resolve(recipe)
    if not r then return false,"Open this profession, clear its filters, and expand the recipe categories first." end
    if not r.complete then return false,"Reagent data is still loading; try again." end
    if r.cooldown and r.cooldown>0 then return false,"This recipe is on cooldown." end
    if r.blocked then return false,r.blocked end
    if (r.api=="craft" or r.enchant) and amount~=1 then return false,"Enchanting needs a target. Use one enchant per click." end
    local available=self:Available(r)
    if amount>available then return false,"Not enough materials in your bags for that batch." end
    if r.api=="modern" then
        if r.enchant then C_TradeSkillUI.CraftEnchant(r.spell,1)
        else C_TradeSkillUI.CraftRecipe(r.spell,amount) end
    elseif r.api=="trade" then
        SelectTradeSkill(r.index);DoTradeSkill(r.index,amount)
    else
        DoCraft(r.index)
    end
    return true,"Requested "..amount.." craft(s). The game checks tools, stations and targets."
end
function P:CaptureAuctionPage()
    if not GetNumAuctionItems or not GetAuctionItemInfo or not GetAuctionItemLink then return end
    local n=GetNumAuctionItems("list");local page={}
    for i=1,n do
        local info={GetAuctionItemInfo("list",i)};local qty,buyout=info[3],info[10]
        local id=self:ItemID(GetAuctionItemLink("list",i))
        if id and qty and qty>0 and buyout and buyout>0 then
            local unit=math.ceil(buyout/qty);page[id]=math.min(page[id] or unit,unit)
        end
    end
    self.market.observed=self.market.observed or {}
    for id,value in pairs(page) do self.market.observed[id]={value=value,time=time(),source="Viewed AH page (sample)"} end
end
