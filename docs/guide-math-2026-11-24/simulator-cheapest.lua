SlashCmdList.PROFPADEN("")
local P=ProfPaden
assert(P.version=="0.20.41-rc1" and P.skillChanceModel==4)
QAMath={original={}}
for k,v in pairs(P) do QAMath.original[k]=v end
local function clone(t) local c={} for k,v in pairs(t) do c[k]=type(v)=="table" and clone(v) or v end return c end
P.char=clone(P.char)
P.selectedProf="Blacksmithing";P.tab="Recipes";P.mode="cost";P.live={};P.skills={Blacksmithing={rank=95,cap=150}}
local r={name="Runed Copper Belt",spell=2666,item=2857,profession="Blacksmithing",learn=45,yellow=85,grey=125,mats={{id=2840,count=10}},complete=true,difficulty="medium",skillAtCapture=95,output=1,icon=133024}
QAMath.recipe=r
P.Catalog={Blacksmithing={r}};P.Recipes={Blacksmithing={r}};P.char.recipes={Blacksmithing={s2666=r}};P.char.trainers={};P.char.vendors={};P.char.unlimitedVendors={};P.char.routeChoices={};P.char.planTargets={Blacksmithing=100}
P.market={prices={[2840]={value=50,time=time()}},observed={}};P.Count=function()return 0 end
P.selectedKey=nil;P.selected=nil;P.offset=0;P:InvalidatePlan();P:Refresh();P.window:Show()
local p=P.planSummary;assert(p.reached==100 and p.materials==7000 and p.rows[1].crafts==14)
local n=0;for _,r in ipairs(p.rows)do n=n+r.crafts*10 end;assert(n==140)
P.message="QA fixture: 14 crafts / 140 Copper Bars / 70s materials";P:Refresh()
return "PASS: cheapest",P.version,p.rows[1].crafts,n,p.materials
