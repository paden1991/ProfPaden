local _,P=...
-- Forever 1.60.1 schemas: TradeSkillUI / TradeSkillUITypes / SkillInfo.
local function call(fn,...)
    if not fn then return nil end
    local ok,a,b=pcall(fn,...);if ok then return a,b end
end
function P:ScanModernRecipes()
    local api=C_TradeSkillUI
    if call(api.IsTradeSkillLinked) or call(api.IsTradeSkillGuild) or call(api.IsDataSourceChanging) then return end
    local info=call(api.GetBaseProfessionInfo)
    if not info then return end
    local prof=self.skillIDs[info.professionID] or self.skillIDs[info.parentProfessionID] or self:Canonical(info.professionName)
    if not prof then return end
    self.activeProf=prof
    if info.skillLevel and info.skillLevel>0 then self.skills[prof]={rank=info.skillLevel,cap=info.maxSkillLevel or 75} end
    local ids=call(api.GetAllRecipeIDs) or call(api.GetFilteredRecipeIDs)
    if not ids then
        -- Keep curated spell-ID recipes usable if a beta build omits enumeration.
        ids={};for _,r in ipairs(self.Recipes[prof] or {}) do if r.spell then ids[#ids+1]=r.spell end end
    end
    local seen={}
    self.char.catalog=self.char.catalog or {};self.char.catalog[prof]=self.char.catalog[prof] or {}
    for _,id in ipairs(ids) do
        local rinfo=call(api.GetRecipeInfo,id)
        if rinfo and not rinfo.isDummyRecipe then
            local source=call(api.GetRecipeSourceText,id)
            self.char.catalog[prof]["s"..id]={spell=id,name=rinfo.name or ("Recipe "..id),learned=rinfo.learned==true,
                icon=rinfo.icon,mats={},complete=false,sourceText=source,source=source,
                url="https://www.wowhead.com/forever/spell="..id}
            if rinfo.learned==false and self.char.recipes[prof] then self.char.recipes[prof]["s"..id]=nil end
        end
        if rinfo and rinfo.learned and not seen[id] and not rinfo.isDummyRecipe then
            seen[id]=true
            local owner=call(api.GetProfessionInfoByRecipeID,id)
            local ownerName=owner and (self.skillIDs[owner.professionID] or self.skillIDs[owner.parentProfessionID] or self:Canonical(owner.professionName))
            local sch=call(api.GetRecipeSchematic,id,false)
            if sch and (not ownerName or ownerName==prof) then
                local output=call(api.GetRecipeOutputItemData,id)
                local difficulty=rinfo.difficulty
                if not difficulty and rinfo.relativeDifficulty and Enum and Enum.TradeskillRelativeDifficulty then
                    for k,v in pairs(Enum.TradeskillRelativeDifficulty) do
                        if v==rinfo.relativeDifficulty then difficulty=({Optimal="optimal",Medium="medium",Easy="easy",Trivial="trivial"})[k] end
                    end
                end
                if rinfo.canSkillUp==false then difficulty="trivial" end
                local r={name=rinfo.name or sch.name,spell=id,item=sch.outputItemID or output and output.itemID,
                    icon=rinfo.icon or sch.icon,profession=prof,api="modern",mats={},complete=true,live=true,
                    available=call(api.GetCraftableCount,id) or 0,output=sch.quantityMin or 1,outputMax=sch.quantityMax or 1,
                    difficulty=difficulty,skillAtCapture=info.skillLevel,numSkillUps=rinfo.numSkillUps,
                    grey=rinfo.maxTrivialLevel and rinfo.maxTrivialLevel>0 and rinfo.maxTrivialLevel or nil,
                    source="Known recipe in the open Forever profession",kind="live",enchant=rinfo.isEnchantingRecipe,
                    cooldown=call(api.GetRecipeCooldown,id)}
                if rinfo.disabled or rinfo.craftable==false then r.blocked=rinfo.disabledReason or "This recipe is not currently craftable." end
                if rinfo.isSalvageRecipe or rinfo.isGatheringRecipe or rinfo.isRecraft then
                    r.blocked="Use the game's profession window for this recipe type."
                    r.planBlocked=true
                end
                for _,req in ipairs(call(api.GetRecipeRequirements,id) or {}) do
                    if req.met==false then r.blocked="Requires: "..(req.name or "a crafting requirement") end
                end
                for _,slot in ipairs(sch.reagentSlotSchematics or {}) do
                    local basic=Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
                    if slot.required or slot.reagentType==basic then
                        local reagents=slot.reagents or {};local reagent=reagents[1];local quantity=slot.quantityRequired
                        if #reagents~=1 or not reagent or not reagent.itemID or not quantity then
                            r.complete=false;r.blocked="This recipe needs reagent choices or currency. Use the game's profession window."
                        elseif quantity>0 then r.mats[#r.mats+1]={id=reagent.itemID,count=quantity} end
                    end
                end
                self.live[#self.live+1]=r
                self.char.recipes[prof]=self.char.recipes[prof] or {}
                self.char.recipes[prof]["s"..id]={name=r.name,item=r.item,spell=id,mats=r.mats,icon=r.icon,output=r.output,outputMax=r.outputMax,complete=r.complete,
                    difficulty=r.difficulty,skillAtCapture=r.skillAtCapture,numSkillUps=r.numSkillUps,grey=r.grey,enchant=r.enchant,planBlocked=r.planBlocked}
            end
        end
    end
end
function P:CaptureModernAuction(event,key)
    local api=C_AuctionHouse;if not api then return end
    local id=type(key)=="table" and key.itemID or key
    if type(id)~="number" then return end
    local best
    if event=="COMMODITY_SEARCH_RESULTS_UPDATED" or event=="COMMODITY_SEARCH_RESULTS_ADDED" then
        for i=1,(call(api.GetNumCommoditySearchResults,id) or 0) do
            local info=call(api.GetCommoditySearchResultInfo,id,i)
            if info and info.unitPrice and info.unitPrice>0 then best=math.min(best or info.unitPrice,info.unitPrice) end
        end
    elseif type(key)=="table" then
        for i=1,(call(api.GetNumItemSearchResults,key) or 0) do
            local info=call(api.GetItemSearchResultInfo,key,i)
            if info and info.buyoutAmount and info.buyoutAmount>0 and info.quantity and info.quantity>0 then
                local unit=math.ceil(info.buyoutAmount/info.quantity);best=math.min(best or unit,unit)
            end
        end
    end
    if best then self.market.observed=self.market.observed or {};self.market.observed[id]={value=best,time=time(),source="Viewed AH results (sample)"} end
end
