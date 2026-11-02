local _,P=...
function P:IsGatherGuide()
    return self.GatherGuides and self.GatherGuides[self.selectedProf] and
        (self.tab=="Recipes" and (self.mode=="guide" or self.mode=="all") or
         self.tab=="Gather" and (self:GatherView()=="guide" or self:GatherView()=="guideall"))
end
function P:GatherGuideRows()
    local prof=self.selectedProf;local bands=self.GatherGuides[prof]
    local skill=self.skills[prof];local rank=skill and skill.rank or 1
    local all=self.tab=="Recipes" and self.mode=="all" or self.tab=="Gather" and self:GatherView()=="guideall"
    local rows={};local stop=skill and self:RouteRankStop(300)
    local bandIndex=0
    for i,b in ipairs(bands) do if rank>=b.start and rank<b.stop then bandIndex=i end end
    local progress=prof..":"..tostring(skill and skill.cap)..":"..bandIndex..":"..tostring(stop and rank>=stop.required)
    if not all and progress~=self.gatherGuideProgress then self.selectedKey=nil;self.offset=0 end
    self.gatherGuideProgress=progress
    local inserted=false
    local function train(at)
        if stop and not inserted and at>=stop.required then
            stop.gatherTraining=true
            stop.note=(stop.note or "")..". Train before reaching your current cap of "..skill.cap.."; gathering at the cap cannot increase skill."
            rows[#rows+1]=stop;inserted=true
        end
    end
    if not skill then
        local target=self:NearestNPC(self.TrainerNPCs[prof],75)
        rows[#rows+1]={key="gather:learn:"..prof,name="Learn "..prof,sub="Apprentice / browse guide",
            journeyAction=true,gatherLearn=true,gatherTraining=true,actionKind="trainer",required=0,
            target=target,npcIDs=target and {target.npc.id} or {},
            note="Learn Apprentice "..prof.." before gathering for skill. Check the trainer's requirements and offering in game. Ask a city guard if no trainer location is recorded.",url=bands[1].url}
    end
    if rank>=300 and not all then
        return {{key="gather:complete:"..prof,name=prof.." guide complete",sub="Skill 300 reached",
            body="The 1-300 gathering guide is complete. Use Gather > Materials to find resources, or Show > All gathering steps to revisit zones. No further training tier is assumed."}}
    end
    for i,b in ipairs(bands) do
        local cuts={b.start}
        if stop and stop.required>b.start and stop.required<b.stop then cuts[#cuts+1]=stop.required end
        cuts[#cuts+1]=b.stop
        for j=1,#cuts-1 do
            local first,last=cuts[j],cuts[j+1]
            if all or last>rank then
                train(math.max(first,rank))
                local effective=math.max(first,math.min(rank,last-1))
                local state=not skill and "Browse" or first>rank and "Later" or "Now"
                local capNote=skill and first>=skill.cap and " / train first" or ""
                rows[#rows+1]={key="gather:guide:"..prof..":"..i..":"..first,gatherGuide=true,
                    name=first.."-"..last.." / "..b.name,sub=state.." / "..b.targets..capNote,
                    start=first,stop=last,guideSkill=effective,guideBand=b,url=b.url,
                    body=self:GatherGuideText(b,first,last,rank,skill)}
            end
        end
    end
    train(300)
    return rows
end
function P:GatherGuideText(b,first,last,rank,skill)
    local prof=self.selectedProf
    local text="|cffffd100Skill "..first.."-"..last.."|r\n\n"..b.targets.."\n\nChoose any suggested zone above. Stay while gathering gives skill, then move to the next band. These are broad recommendations; travel is optional."
    if prof=="Skinning" then
        text=text.."\n\nCarry a Skinning Knife and loot corpses fully. The map focuses on creatures appropriate for the start of this band. Check the corpse tooltip; special creatures can have different requirements. Classic reference yields are labeled in Materials."
    elseif prof=="Mining" then text=text.."\n\nCarry a Mining Pick and enable Find Minerals. Maps show the selected vein type, not ore dropped by creatures."
    elseif prof=="Herbalism" then text=text.."\n\nEnable Find Herbs. Map choices use the selected band's skill and omit locked or gray plants. Equipment bonuses are not included."
    end
    if b.note then text=text.."\n\n"..b.note end
    if skill then
        local nextRank=self:NextProfessionRank(prof,skill.cap)
        if nextRank then text=text.."\n\n|cffffd100Training: "..nextRank[3].." from skill "..nextRank[1].."; train before cap "..skill.cap..".|r" end
        if rank>=skill.cap then text=text.."\nYou are at the skill cap. Complete the training step before continuing." end
    else text=text.."\n\nBrowse mode: train this profession to follow your own progress." end
    return text.."\n\nClassic leveling recommendations with recorded Classic / Forever locations. Blue areas are historical observations, not live nodes or a validated walking path."
end
function P:GatherGuideMaps(entry)
    local maps={}
    for _,a in ipairs(entry.guideBand.maps) do
        if (a.required or 1)<=entry.guideSkill and (not a.gray or entry.guideSkill<a.gray) then maps[#maps+1]=a end
    end
    -- Prefer the current zone, then friendly starting areas, while keeping all
    -- alternatives available. Never change the shared material map records.
    local map=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local faction=UnitFactionGroup("player")
    local starters={[1429]="Alliance",[1426]="Alliance",[1438]="Alliance",[1411]="Horde",[1412]="Horde",[1420]="Horde"}
    local function score(a)return a.mapId==map and 0 or starters[a.mapId]==faction and 1 or 2 end
    table.sort(maps,function(a,b)
        if score(a)~=score(b) then return score(a)<score(b) end
        if a.zone~=b.zone then return a.zone<b.zone end
        return (a.required or 1)==(b.required or 1) and (a.target or "")<(b.target or "") or (a.required or 1)<(b.required or 1)
    end)
    return maps
end
