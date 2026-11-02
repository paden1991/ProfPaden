local _,P=...
function P:IsBuffFood(id,bag,slot)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    local values=info and {info(id)} or {};local classID,subclass=values[12],values[13]
    local meta=self.ItemMeta and self.ItemMeta[id]
    classID=classID or meta and meta.classID;subclass=subclass or meta and meta.subclassID
    if classID~=0 or subclass~=5 then return false end
    local text={}
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok,data=pcall(C_TooltipInfo.GetBagItem,bag,slot)
        if ok and data then for _,line in ipairs(data.lines or {}) do
            if type(line.leftText)=="string" then text[#text+1]=line.leftText end
            if type(line.rightText)=="string" then text[#text+1]=line.rightText end
        end end
    end
    local spell=C_Item and C_Item.GetItemSpell or GetItemSpell
    if spell and C_Spell and C_Spell.GetSpellDescription then
        local _,sid=spell(id)
        if sid then local ok,description=pcall(C_Spell.GetSpellDescription,sid);if ok and description then text[#text+1]=description end end
    end
    local s=table.concat(text," "):lower():gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    -- Use the actual buff wording, not every food/drink item or an item-ID range.
    local tokens={"well fed","well-fed","satt","bien nourri","bien alimentado","bem alimentado","сытость","포만감","进食充分","充分進食"}
    if type(WELL_FED)=="string" then tokens[#tokens+1]=WELL_FED:lower() end
    for _,token in ipairs(tokens) do if s:find(token,1,true) then return true end end
    return false
end
function P:OwnedBuffFoods()
    local result,seen={},{}
    local api=C_Container
    local slots=api and api.GetContainerNumSlots or GetContainerNumSlots
    local itemID=api and api.GetContainerItemID or GetContainerItemID
    if not slots or not itemID then return result end
    for bag=0,(NUM_BAG_SLOTS or 4) do for slot=1,slots(bag) do
        local id=itemID(bag,slot)
        if id and not seen[id] then
            seen[id]=true
            local usable=C_Item and C_Item.IsUsableItem or IsUsableItem
            if (not usable or usable(id)) and self:IsBuffFood(id,bag,slot) then
                result[#result+1]={id=id,count=self:Count(id),name=self:ItemName(id),food=true}
            end
        end
    end end
    table.sort(result,function(a,b)return a.name<b.name end)
    return result
end
