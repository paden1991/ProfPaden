local _,P=...
-- Standard restockable crafting supplies; base prices in copper per item.
-- Existing guide vial prices retained. Added supplies cross-checked against
-- https://www.wow-professions.com/forever/npc/reagent-bot (2026-10-16).
-- Weak/Strong/Elemental Flux: 1s / 20s / 15g; Coal: 5s.
P.purchaseModel=1
P.VendorSupplies={}
for _,id in ipairs({3371,3372,8925,2320,2321,4291,14341,2324,2325,2604,2605,6260,2678,2692,3713,4289,10284,159}) do
    local item=P.Items[id]
    if item and item.vendorBuy then P.VendorSupplies[id]={value=item.vendorBuy,stock=-1,name="Profession supplier",source="Bundled profession guide"} end
end
local added={
    [2880]={"Weak Flux",100},[3466]={"Strong Flux",2000},[18567]={"Elemental Flux",150000},[3857]={"Coal",500},
    [8343]={"Heavy Silken Thread",2000},[4340]={"Gray Dye",350},[6261]={"Orange Dye",1000},
    [10290]={"Pink Dye",2500},[4342]={"Purple Dye",2500},[4341]={"Yellow Dye",500},
    [4399]={"Wooden Stock",200},[4400]={"Heavy Stock",2000},[11291]={"Star Wood",4500},[4470]={"Simple Wood",38},[10647]={"Engineer's Ink",2000},[10648]={"Blank Parchment",500},
    [272941]={"Thick Logs",200000},[4536]={"Shiny Red Apple",5}
}
for id,row in pairs(added) do
    P.VendorSupplies[id]={value=row[2],stock=-1,name="Profession supplier",source="WoW-Professions Forever Reagent Bot",url="https://www.wow-professions.com/forever/npc/reagent-bot"}
    P.Items[id]=P.Items[id] or {name=row[1]};P.Items[id].vendorBuy=row[2]
end

-- https://www.wowhead.com/forever/item=18256/imbued-vial (5 for 3g).
P.VendorSupplies[18256]={value=6000,stock=-1,name="Alchemy supplier",source="Wowhead Forever Imbued Vial",url="https://www.wowhead.com/forever/item=18256/imbued-vial"}
P.Items[18256]=P.Items[18256] or {name="Imbued Vial"};P.Items[18256].vendorBuy=6000
