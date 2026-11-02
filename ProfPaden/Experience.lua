local _,P=...
local function now()return GetTime and GetTime() or time() end
local function bucket(rank,color)return (math.floor(rank/5)*5)..":"..(color or "unknown") end
function P:ObservedSkills(r,rank)
    local prof=r.profession or self.selectedProf
    local data=self.char.skillHistory and self.char.skillHistory[prof]
    data=data and data[r.spell]
    return data and data[bucket(rank,r.difficulty)]
end
function P:ObservedChance(r,rank,base)
    if not base or base<=0 or base>=1 then return base end
    -- Calibrate against the observed/current band, then preserve the underlying
    -- declining forecast. Sparse samples never change the planning model.
    local anchor=r.skillAtCapture or (self.skills[r.profession or self.selectedProf] or {}).rank or rank
    local s=self:ObservedSkills(r,anchor)
    if not s or s.attempts<20 then return base end
    local expected=s.expected or 0
    if expected<=0 then return base end
    local factor=math.min(1,(s.gains+10)/(expected+10))
    return base*factor
end
function P:FinishSkillObservation()
    local pending=self.skillPending;self.skillPending=nil
    if not pending or not pending.success then return end
    self:ReadSkills();local skill=self.skills[pending.profession]
    if not skill or skill.cap~=pending.cap or pending.rank>=pending.cap then return end
    local gained=skill.rank-pending.rank
    if gained<0 or gained>pending.maxGain then return end
    self.char.skillHistory=self.char.skillHistory or {}
    local history=self.char.skillHistory
    history[pending.profession]=history[pending.profession] or {}
    local recipes=history[pending.profession];recipes[pending.spell]=recipes[pending.spell] or {}
    local bands=recipes[pending.spell];local key=bucket(pending.rank,pending.color)
    local s=bands[key] or {attempts=0,gains=0,points=0,expected=0,start=math.floor(pending.rank/5)*5,finish=math.floor(pending.rank/5)*5+4,color=pending.color}
    bands[key]=s;s.attempts=s.attempts+1;s.gains=s.gains+(gained>0 and 1 or 0);s.points=s.points+gained
    s.expected=s.expected+(pending.base or 0);s.updated=time()
    self:InvalidatePlan()
    if self.window and self.window:IsShown() then self:Refresh() end
end
function P:ObserveCraftEvent(event,unit,a,b,c)
    if unit~="player" then return end
    local guid,spell=a,b
    if event=="UNIT_SPELLCAST_SENT" then guid,spell=b,c end
    if not guid or not spell then return end
    if event=="UNIT_SPELLCAST_SENT" or event=="UNIT_SPELLCAST_START" then
        if self.skillPending and self.skillPending.guid==guid then return end
        self:FinishSkillObservation()
        local recipe,profession
        for _,r in ipairs(self.live) do if r.spell==spell then recipe=r;profession=r.profession;break end end
        if not recipe then return end -- Only our own actively exposed profession recipes.
        self:ReadSkills();local skill=self.skills[profession]
        if not skill or skill.rank>=skill.cap or recipe.difficulty=="trivial" then return end
        local r={};for k,v in pairs(recipe) do r[k]=v end
        r.skillAtCapture=skill.rank
        local base=self:BaseChance(r,skill.rank)
        self.skillPending={guid=guid,spell=spell,profession=profession,rank=skill.rank,cap=skill.cap,
            color=recipe.difficulty,maxGain=math.max(1,recipe.numSkillUps or 1),base=base,started=now()}
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local pending=self.skillPending
        if not pending or pending.guid~=guid or pending.spell~=spell or pending.success then return end
        pending.success=true
        C_Timer.After(1,function()if P.skillPending==pending then P:FinishSkillObservation() end end)
    elseif self.skillPending and self.skillPending.guid==guid and not self.skillPending.success then self.skillPending=nil end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED_QUIET"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,...)if P.char then P:ObserveCraftEvent(event,...) end end)
P.experienceEvents=events
