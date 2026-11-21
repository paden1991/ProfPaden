-- Reviewed Wowhead Forever guide and Blizzard hotfix facts, checked 2026-11-21.
-- Data-only update: live trainer, vendor and tooltip observations retain precedence.
local _,P=...
local checked="2026-11-21"
local guide="https://www.wowhead.com/forever/guide/professions/overview"
local hotfix="https://www.wowhead.com/forever/fr/blue-tracker/news/us/wow-forever-hotfixes-november-20-2026-world-of-warcraft-blizzard-news-24315281"
local plansURL="https://www.wowhead.com/forever/de/item=7994/plans-orcish-war-leggings"
local automatic={[1245250]=true,[1245246]=true,[1245287]=true,[1245320]=true,[1245321]=true}
local function appendUnique(rows,value,key)
    for _,old in ipairs(rows) do if (key and old[key]==value[key]) or (not key and old==value) then return end end
    rows[#rows+1]=value
end
for _,collection in ipairs({P.Catalog or {},P.Recipes or {}}) do
    for _,rows in pairs(collection) do for _,r in ipairs(rows) do
        if automatic[r.spell] then
            r.source="Learned automatically when learning the profession."
            r.sourceKind="automatic";r.sourceKinds=r.sourceKinds or {};r.sourceKinds.automatic=true
            r.sourceVerified=true;r.acquisitionChecked=checked
            r.referenceURLs=r.referenceURLs or {};appendUnique(r.referenceURLs,guide)
        elseif r.spell==9957 then
            r.source="Quest: The Old Ways (Orgrimmar). Receive Plans: Orcish War Leggings; Sumi offers a replacement after the quest is completed."
            r.sourceKind="quest";r.sourceKinds=r.sourceKinds or {};r.sourceKinds.quest=true;r.sourceKinds.vendor=true
            r.sourceVerified=true;r.acquisitionChecked=checked
            r.acquisitionItems=r.acquisitionItems or {};appendUnique(r.acquisitionItems,{id=7994,name="Plans: Orcish War Leggings"},"id")
            r.hotfixNote="The quest awards a recipe item. Replacement plans from Sumi require completion of The Old Ways."
            r.hotfixURL=hotfix;r.hotfixChecked=checked
            -- The current recipe-item requirement agrees with the existing 205 route.
            r.wowheadLearn=205;r.sourceDiscrepancy=nil;r.skillFactsURL=plansURL;r.skillFactsChecked=checked
            r.referenceURLs=r.referenceURLs or {};appendUnique(r.referenceURLs,plansURL);appendUnique(r.referenceURLs,hotfix)
        elseif r.spell==2740 then
            r.hotfixNote="Bronze Mace now binds when equipped and can be added to the transmog collection."
            r.hotfixURL=hotfix;r.hotfixChecked=checked
        elseif r.spell==1263070 then
            r.hotfixNote="Seed Hybridizer is enabled again. Combining seeds can fail, and Scarce Herb Seeds cannot be used."
            r.hotfixURL=hotfix;r.hotfixChecked=checked
        end
    end end
end
P.ItemMeta=P.ItemMeta or {}
local plans=P.ItemMeta[7994] or {name="Plans: Orcish War Leggings",classID=9,subclassID=4,sources={}}
P.ItemMeta[7994]=plans
plans.requiredSkill=205;plans.bindOnPickup=true;plans.sources=plans.sources or {}
local function source(value)
    for _,old in ipairs(plans.sources) do
        if old.kind==value.kind and (old.npc or old.id)==(value.npc or value.id) then return end
    end
    plans.sources[#plans.sources+1]=value
end
source({kind="Quest",id=2756,name="The Old Ways",zone="Orgrimmar",source="Wowhead / Blizzard hotfix",url=hotfix})
source({kind="Vendor",npc=3356,name="Sumi",requiredQuest=2756,condition="Replacement after completing The Old Ways",source="Wowhead / Blizzard hotfix",url=hotfix})
plans.sourceChecked=checked
local quest=P.QuestMeta and P.QuestMeta[2756]
if quest then quest.rewards=quest.rewards or {};appendUnique(quest.rewards,7994) end
for _,q in ipairs(P.QuestGuide or {}) do
    if q.id==2756 then
        local reward="Reward: Plans: Orcish War Leggings. Sumi offers replacement plans after this quest is completed."
        if not (q.text or ""):find(reward,1,true) then q.text=(q.text or "").."\n\n"..reward end
    end
end
if P.ItemMeta[2848] then P.ItemMeta[2848].bindOnEquip=true;P.ItemMeta[2848].sourceChecked=checked end
P.WowheadNovember21={checked=checked,guide=guide,guideRecipesCompared=933,addedRecipes=0,updatedRecipes=8}
