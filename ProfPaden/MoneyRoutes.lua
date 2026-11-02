local _,P=...
-- Money-making is a current-skill production comparison, not a leveling path.
function P:MoneyOptions()
    local rows=self:ProfitOptions()
    for _,r in ipairs(rows) do r.value=r.value:gsub('^profit:','money:') end
    return rows
end
function P:MoneyBatch()
    return math.max(1,math.min(9999,math.floor(tonumber(self.char.moneyBatches and self.char.moneyBatches[self.selectedProf]) or 1)))
end
function P:SetMoneyBatch(value)
    value=tonumber(value)
    if not value or value<1 or value>9999 or value~=math.floor(value) then self.message='Enter a whole batch size from 1 to 9999.';return false end
    self.char.moneyBatches=self.char.moneyBatches or {};self.char.moneyBatches[self.selectedProf]=value
    self.selectedKey=nil;self.offset=0;return true
end
function P:MoneyInputPrice(id)
    local vendor,observed=self:VendorSupply(id)
    if vendor then
        return vendor.value,'Unlimited vendor: '..(observed and vendor.name or 'Profession supplier'),vendor.time,'vendor',vendor
    end
    local value,source,stamp=self:AuctionSalePrice(id)
    return value,source or 'AH price needed',stamp,'auction'
end
function P:MoneyCost(r,n)
    local plan=self:SourceRecipe(r,n,{policy='money'})
    local ah,vendor=0,0
    for id,count in pairs(plan.needs) do
        local price,_,_,method=self:MoneyInputPrice(id)
        if price then if method=='vendor' then vendor=vendor+price*count else ah=ah+price*count end end
    end
    return plan.cost,plan.unknown,ah,vendor,plan
end
function P:MoneyRows()
    local prof=self.selectedProf;local skill=self.skills[prof];local n=self:MoneyBatch()
    local report={unpriced=0,unsellable=0,loss=0,batch=n};self.moneySummary=report
    if not skill then return {} end
    local pool={};local function add(r)
        if r.acquisitionOnly then return end
        local key=self:RecipeIdentity(r);if not key then return end
        pool[key]=pool[key] or {};for k,v in pairs(r) do if pool[key][k]==nil then pool[key][k]=v end end
    end
    for _,r in ipairs(self.Catalog[prof] or {}) do add(r) end
    for _,r in ipairs(self.Recipes[prof] or {}) do add(r) end
    for _,r in pairs(self.char.recipes[prof] or {}) do add(r) end
    for _,r in ipairs(self.live) do if r.profession==prof then add(r) end end
    local rows={}
    for key,r in pairs(pool) do
        local live=self:Resolve(r);local saved=self.char.recipes[prof] and self.char.recipes[prof][key]
        if not saved then for _,s in pairs(self.char.recipes[prof] or {}) do if self.SameRecipe(r,s) then saved=s;break end end end
        local trainer=self.char.trainers and self.char.trainers[prof] and self.char.trainers[prof][key]
        local known=live or saved or trainer and trainer.known
        local trainable=trainer and trainer.eligible and (trainer.required or r.learn or 1)<=skill.rank
        if known or trainable then
            local actual=live or saved
            if actual then for _,f in ipairs({'name','mats','complete','output','outputMax','item','spell','enchant','icon','available','api','index','cooldown','blocked','planBlocked'}) do if actual[f]~=nil then r[f]=actual[f] end end end
            local fee=known and 0 or trainer.cost
            if fee~=nil and r.mats and #r.mats>0 and r.complete~=false and not r.planBlocked and not (r.cooldown and r.cooldown>0) then
                local cost=self:MoneyCost(r,n);local sale=self:SaleEstimate(r,self.char.moneySale or 'best5')
                if not cost then report.unpriced=report.unpriced+1
                elseif not sale then report.unsellable=report.unsellable+1
                elseif sale.net*n-cost-fee>0 then
                    r.money=true;r.moneyProfit=sale.net*n-cost-fee;r.moneyCost=cost;r.moneySaleKey=self.char.moneySale or 'best5'
                    r.planSale=sale;r.planTraining=fee;r.planKnown=known and true or false;r.live=live~=nil;r.cached=saved~=nil and not live
                    r.moneyTrainer=not known and trainer or nil;r.profession=prof;r.key='money:'..key;r.crafts=n;r.start=nil;r.stop=nil;r.planStep=nil
                    r.ready=self:Available(r);rows[#rows+1]=r
                else report.loss=report.loss+1 end
            end
        end
    end
    table.sort(rows,function(a,b)if a.moneyProfit~=b.moneyProfit then return a.moneyProfit>b.moneyProfit end;if a.moneyCost~=b.moneyCost then return a.moneyCost<b.moneyCost end;return a.key<b.key end)
    return rows
end
function P:MoneyDetailRows(r,n)
    local rows={};local function add(a,b)rows[#rows+1]={cells={a,tostring(b or '-')},widths={108,242}}end
    local function heading(text)rows[#rows+1]={cells={text},widths={350},heading=true}end
    local function note(text)rows[#rows+1]={cells={text},widths={350},muted=true}end
    local cost,missing,ah,vendor,sourcing=self:MoneyCost(r,n);local fee=r.planTraining or 0
    local sale=self:SaleEstimate(r,r.moneySaleKey);local proceeds=sale and sale.net*n
    local net=cost and proceeds and proceeds-cost-fee
    heading('MONEY-MAKING / '..n..' CRAFT(S)')
    add('Recipe',r.planKnown and 'Learned' or 'Train before crafting')
    add('Buy all inputs',self:SmallMoney(cost));add('AH / vendor',self:SmallMoney(ah)..' / '..self:SmallMoney(vendor))
    add('Training once',self:SmallMoney(fee));add('Upfront budget',self:SmallMoney(cost and cost+fee))
    if sale then
        add('Sell via',sale.method..' / '..math.floor(sale.cut*100+.5)..'% AH cut')
        add('Output to sell',sale.output*n..' / minimum yield');add('Proceeds',self:SmallMoney(proceeds)..' after cut')
        add(net and net>0 and 'Estimated profit' or 'Estimated loss',self:SmallMoney(net and math.abs(net)))
        if cost and cost+fee>0 and net then add('Return on spend',string.format('%.1f%%',100*net/(cost+fee))) end
        if cost then add('Break-even / item',self:SmallMoney(math.ceil((cost+fee)/(sale.output*n*(1-sale.cut))))) end
        note(sale.source..' / '..self:PriceDate(sale.stamp,sale.source,r.item))
    else add('Sale price','Refresh item data and scan prices') end
    note('All inputs are purchased; bag supplies are not deducted. Gray recipes qualify. Ranking uses the batch size above the recipe list.')
    heading('PURCHASE INPUTS')
    rows[#rows+1]={cells={'Material','Buy','Each','Total'},widths={150,42,74,84},heading=true}
    local inputs={};for id,count in pairs(sourcing.needs) do inputs[#inputs+1]={id=id,count=count} end;table.sort(inputs,function(a,b)return a.id<b.id end)
    for _,m in ipairs(inputs) do
        local price,source,stamp,method,v=self:MoneyInputPrice(m.id);local amount=m.count
        rows[#rows+1]={cells={'|Hitem:'..m.id..'|h['..self:ItemName(m.id)..']|h',amount,self:SmallMoney(price),self:SmallMoney(price and price*amount)},widths={150,42,74,84}}
        note(source..' / '..self:PriceDate(stamp,source,m.id))
        if v and v.npcID then add('Buy from',self:NPCLink(v.npcID)..(v.zone and ' / '..v.zone or '')) end
    end
    for _,row in ipairs(self:SourcingDetailRows(sourcing)) do rows[#rows+1]=row end
    if missing>0 then add('Unpriced inputs',missing) end
    if r.moneyTrainer then add('Trainer',r.moneyTrainer.npcID and self:NPCLink(r.moneyTrainer.npcID) or r.moneyTrainer.trainer);add('Location',r.moneyTrainer.zone) end
    if r.blocked then add('Craft requires',r.blocked) end
    note('AH proceeds assume the entire batch sells at the quoted price. Demand, market depth, lost deposits and relisting costs are not modeled. Smaller batches limit unsold stock.')
    note('Export inputs sends all AH quantities to Auctionator; unlimited vendor supplies stay in this table. It never buys or posts items.')
    return rows
end
function P:ExportMoneyInputs(r,n)
    local function notice(s)self.message=s;self:Print(s);if self.window then self:RefreshDetail();self.status:SetText(s) end end
    if not r or not r.money or not n or n<1 or n>9999 or n~=math.floor(n) then notice('Choose a money-making recipe and a whole craft quantity.');return false end
    if not self.auctionOpen or not self:AuctionatorShoppingAvailable() then notice('Open the auction house with Auctionator enabled to export inputs.');return false end
    if InCombatLockdown() or self:IsAuctionatorScanning() or self.char.shoppingUncertain or self.shoppingTransaction and self.shoppingTransaction.sent or
        AuctionHouseFrame and AuctionHouseFrame.BuyDialog and AuctionHouseFrame.BuyDialog:IsShown() or StaticPopup_Visible and StaticPopup_Visible('BUYOUT_AUCTION') then notice('Finish the current scan, purchase or combat before exporting.');return false end
    local needs=self:SourceRecipe(r,n,{policy='money'}).needs
    local terms,items={},{};local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    for id,count in pairs(needs) do
        local _,_,_,method=self:MoneyInputPrice(id)
        if method=='auction' then
            local name=info and info(id)
            if not name or name:find('[;^]') or name:match('^".*"$') then
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
                notice('Item name is unavailable for Auctionator export. Retry after item data loads; nothing was exported.');return false
            end
            terms[#terms+1]={searchString=name,isExact=true,quantity=count}
            items[id]=true
        end
    end
    if #terms==0 then notice('All inputs come from unlimited-stock vendors. See the purchase table.');return false end
    self:CancelShoppingSearch();if self.priceScan then self:StopPriceScan('Money-making export started.') end
    self.auctionatorShopping=nil -- this independent production batch is not a leveling-list receipt scope
    local ok=pcall(Auctionator.API.v1.MultiSearchAdvanced,self.name,terms)
    if not ok then notice('Auctionator could not open the input search. No purchase was requested.');return false end
    self.char.auctionatorExport={profession=self.selectedProf,items=items,listName=AUCTIONATOR_L_TEMPORARY_LOWER_CASE and (self.name.." ("..AUCTIONATOR_L_TEMPORARY_LOWER_CASE..")")}
    notice('Exported all AH inputs for '..n..' crafts. Bags are not deducted; buy unlimited vendor supplies separately.')
    if self.window then self.window:Hide() end;return true
end
