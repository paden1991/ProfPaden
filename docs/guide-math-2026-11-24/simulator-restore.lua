local P=ProfPaden
if QAMath.scale then P.window:SetScale(QAMath.scale);P.window:ClearAllPoints();P.window:SetPoint(unpack(QAMath.point)) end
for k in pairs(P) do if QAMath.original[k]==nil then P[k]=nil end end
for k,v in pairs(QAMath.original) do P[k]=v end
QAMath=nil;P:InvalidatePlan();P:Refresh();P.window:Show()
return "QA fixtures removed; original character and prices restored",P.version
