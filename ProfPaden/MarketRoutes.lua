local _,P=...
local settings={
    {key="vendor",label="Vendor only",method="vendor",cut=0},
    {key="auction5",label="Auction (5% cut)",method="auction",cut=.05},
    {key="auction15",label="Auction (15% cut)",method="auction",cut=.15},
    {key="best5",label="Best return (5% AH cut)",method="best",cut=.05},
    {key="best15",label="Best return (15% AH cut)",method="best",cut=.15},
}
function P:IsOptimizedRoute()return self.mode=="cost" or self.mode=="profit" end
function P:ProfitSetting()
    for _,s in ipairs(settings) do if s.key==(self.shoppingPlanningSale or self.char.profitSale) then return s.key,s end end
    return settings[1].key,settings[1]
end
function P:ProfitLabel(key)
    key=key or self:ProfitSetting()
    for _,s in ipairs(settings) do if s.key==key then return s.label end end
    return settings[1].label
end
function P:ProfitOptions()
    local options={};for _,s in ipairs(settings) do options[#options+1]={label=s.label,value="profit:"..s.key} end
    return options
end
function P:NetLabel(cost)return cost<0 and "Est. profit" or "Est. loss" end
local function public(fn,...)
    if type(fn)~="function" then return end
    local ok,v=pcall(fn,...);if ok and type(v)=="number" and v>=0 and v<math.huge then return v end
end
-- Sale prices deliberately do not use Price(): that is a purchase quote and
-- may be a merchant buy price or a manual reagent-cost override.
function P:AuctionSalePrice(id)
    local observed=self.market.observed and self.market.observed[id]
    if observed and (type(observed.time)~="number" or observed.time>time() or self.market.auctionatorScanStarted and observed.time<self.market.auctionatorScanStarted) then observed=nil end
    if observed and observed.time and time()-observed.time<=86400 and type(observed.value)=="number" and observed.value>0 and observed.value<math.huge then
        return observed.value,observed.source or "Viewed auction price",observed.time
    end
    local best,source,stamp
    local function candidate(value,from,when)
        if value and value>0 and (not best or value<best) then best,source,stamp=value,from,when end
    end
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if api then
        local age=public(api.GetAuctionAgeByItemID,self.name,id)
        -- With an age API present, nil means absent or older than 21 days.
        if not api.GetAuctionAgeByItemID or age and age<=7 then
            candidate(public(api.GetAuctionPriceByItemID,self.name,id),"Auctionator estimate",age and time()-age*86400)
        end
    end
    if AucAdvanced and AucAdvanced.API and AucAdvanced.API.GetMarketValue then
        self.auctioneerCache=self.auctioneerCache or {}
        local cached=self.auctioneerCache[id]
        if not cached or time()-(cached.readTime or 0)>60 then
            cached={value=public(AucAdvanced.API.GetMarketValue,id),readTime=time()};self.auctioneerCache[id]=cached
            if cached.value then
                self.market.external=self.market.external or {}
                self.market.external[id]={value=cached.value,source="Auctioneer estimate",readTime=cached.readTime}
            end
        end
        candidate(cached.value,"Auctioneer estimate")
    end
    if TSM_API then candidate(public(TSM_API.GetCustomPriceValue,"dbmarket","i:"..id),"TSM historical estimate") end
    return best,source,stamp
end
function P:SaleEstimate(r,saleKey)
    if not r.item or r.enchant or r.acquisitionOnly then return end
    local _,setting=self:ProfitSetting()
    if saleKey then for _,s in ipairs(settings) do if s.key==saleKey then setting=s;break end end end
    local fn=C_Item and C_Item.GetItemInfo or GetItemInfo
    local v=fn and {fn(r.item)} or {}
    local vendor=v[1] and tonumber(v[11]);local bind=v[1] and v[14]
    local vendorSource="Client vendor value"
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if vendor==nil and api then vendor=public(api.GetVendorPriceByItemID,self.name,r.item);vendorSource="Auctionator vendor cache" end
    if vendor==nil and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.item) end
    -- Only confirmed tradable binding types. Unknown metadata must not turn a
    -- crafted bind-on-pickup item into an auction opportunity.
    local auction,source,stamp
    if bind==0 or bind==2 or bind==3 then auction,source,stamp=self:AuctionSalePrice(r.item) end
    local output=r.output==nil and 1 or tonumber(r.output)
    if not output or output<1 or output>=math.huge or output~=math.floor(output) then return end -- unknown/invalid yield is not a sale
    -- Minimum yield only; no proc bonus.
    local result
    if setting.method~="auction" and vendor~=nil then
        result={gross=vendor,net=vendor*output,output=output,method="Vendor",cut=0,source=vendorSource,stamp=v[1] and time() or nil}
    end
    if setting.method~="vendor" and auction then
        local net=math.floor(auction*(1-setting.cut))*output
        if not result or net>result.net then result={gross=auction,net=net,output=output,method="Auction",cut=setting.cut,source=source,stamp=stamp} end
    end
    return result
end
