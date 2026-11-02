local _,P=...
local skills={[171]="Alchemy",[164]="Blacksmithing",[333]="Enchanting",[202]="Engineering",[182]="Herbalism",[165]="Leatherworking",[186]="Mining",[393]="Skinning",[197]="Tailoring",[185]="Cooking",[129]="First Aid",[356]="Fishing"}
-- Read-only optional bridge to the user's installed QuestieDB. Work in small chunks.
function P:IndexQuests()
    if self.questIndexStarted then return end
    local db=LibQuestieDB
    if not db or not db.Quest or not db.Quest.GetAllIds then return end
    self.questIndexStarted=true;self.extraQuests={};self.questIndexStatus="Indexing QuestieDB..."
    local Q=db.Quest;local ok,ids=pcall(Q.GetAllIds)
    if not ok then self.questIndexStatus="QuestieDB unavailable";return end
    local at,seen=1,{}
    for _,q in ipairs(self.QuestGuide) do if q.id then seen[q.profession..":"..q.id]=true end end
    local function add(id,prof)
        local key=prof..":"..id
        if seen[key] then return end;seen[key]=true
        local name=Q.name(id);if not name then return end
        local skill=Q.requiredSkill(id);local starters=Q.startedBy(id);local where={}
        if starters and starters[1] and db.Npc then
            for _,npc in ipairs(starters[1]) do
                local n=db.Npc.name(npc) or ("NPC "..npc);local coords=db.Npc.spawns and db.Npc.spawns(npc)
                if coords then for area,spots in pairs(coords) do
                    if spots[1] then n=n..string.format(" (area %d: %.1f, %.1f)",area,spots[1][1],spots[1][2]);break end
                end end
                where[#where+1]=n
            end
        end
        local notes=table.concat(Q.objectivesText(id) or {}," ")
        local pre=Q.preQuestSingle(id) or {};local group=Q.preQuestGroup(id) or {};local crumbs=Q.breadcrumbs(id) or {}
        local function names(label,list)
            if #list>0 then local t={};for _,qid in ipairs(list) do t[#t+1]=(Q.name(qid) or "Quest").." ["..qid.."]" end;notes=notes.."\n"..label..table.concat(t,", ") end
        end
        names("Prerequisite (one of): ",pre);names("Prerequisites (all): ",group);names("Breadcrumbs: ",crumbs)
        local nextID=Q.breadcrumbForQuestId(id)
        self.extraQuests[#self.extraQuests+1]={profession=prof,id=id,title=name,skill=skill and skill[2] or 0,level=Q.requiredLevel(id) or 1,
            where=#where>0 and table.concat(where," / ") or "See linked quest record",text=notes.."\nQuestieDB data: race, class, reputation and prerequisite restrictions may apply.",nextID=nextID,imported=true}
        for _,v in ipairs({pre,group,crumbs}) do for _,qid in ipairs(v) do add(qid,prof) end end
    end
    local function batch()
        local success,err=pcall(function()
            for _=1,100 do
                local id=ids[at];if not id then break end;at=at+1
                local req=Q.requiredSkill(id);local prof=req and skills[req[1]]
                if not prof then
                    local name=Q.name(id) or ""
                    for _,p in ipairs(P.professions) do if name:find(p[1],1,true) then prof=p[1];break end end
                end
                if prof then add(id,prof) end
            end
        end)
        if not success then P.questIndexStatus="QuestieDB indexing stopped: incompatible data";return end
        if ids[at] then C_Timer.After(.05,batch) else
            P.questIndexStatus=#P.extraQuests.." additional QuestieDB quests"
            table.sort(P.extraQuests,function(a,b) if a.skill~=b.skill then return a.skill<b.skill end;return a.id<b.id end)
            if P.window and P.window:IsShown() then P:Refresh() end
        end
    end
    batch()
end
