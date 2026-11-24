local P=ProfPaden;local r=QAMath.recipe
r.mats={{id=2840,count=2}};r.output=2;r.outputMax=5;r.learn=95;r.yellow=110;r.green=120;r.grey=130;r.difficulty="optimal"
P.char.recipes={Blacksmithing={}};P.char.trainers={Blacksmithing={s2666={eligible=true,required=95,cost=500,trainer="QA trainer",zone="Test fixture"}}};P.char.planTargets.Blacksmithing=97
P.market.prices[2840]={value=100,time=time()};P.market.observed[2857]={value=300,time=time(),source="QA auction quote"};P.char.profitSale="auction5";P.mode="profit"
P.selectedKey=nil;P.selected=nil;P.offset=0;P:InvalidatePlan();P:Refresh()
local p=P.planSummary;assert(p.reached==97 and p.materials==400 and p.training==500 and p.proceeds==1140 and p.net==-240)
P.message="QA fixture: 4s materials + 5s training / 11s40c sales / 2s40c profit";P:Refresh()
return "PASS: profit",p.materials,p.training,p.proceeds,p.net
