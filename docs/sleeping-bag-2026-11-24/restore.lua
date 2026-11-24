local P=ProfPaden
P.ReadSleepAuras=SleepQA.read;P.char.sleepTimerPosition=SleepQA.position;P.char.sleepTimerEnabled=SleepQA.enabled
P.sleepTimerState=nil;P.sleepTimerPreview=nil;P:PlaceSleepTimer();P:UpdateSleepTimer();SleepQA=nil
return "Original aura reader and preferences restored",P.version
