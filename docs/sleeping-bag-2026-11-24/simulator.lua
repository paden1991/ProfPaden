local P=ProfPaden
assert(P.version=="0.20.42-rc1")
SleepQA={read=P.ReadSleepAuras,position=P.char.sleepTimerPosition,enabled=P.char.sleepTimerEnabled,resting=true,stacks=1,expires=GetTime()+7200}
P.ReadSleepAuras=function()return SleepQA.resting,SleepQA.stacks,SleepQA.expires end
P.char.sleepTimerEnabled=true;P.sleepTimerState=nil;P.sleepTimerPreview=nil
if P.window then P.window:Hide() end
P:UpdateSleepTimer();P.sleepTimerState.deadline=GetTime()+42;P:RenderSleepTimer()
assert(math.abs(P.sleepTimerFrame:GetWidth()-320)<.01 and math.abs(P.sleepTimerFrame:GetHeight()-64)<.01)
assert(P.sleepTimerCategory)
return "PASS: compact timer",P.version,P.sleepTimerFrame:GetWidth(),P.sleepTimerFrame:GetHeight()
