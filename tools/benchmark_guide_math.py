from pathlib import Path
from time import perf_counter
import ast,json
from lupa.lua51 import LuaRuntime
R=Path(__file__).resolve().parents[1];A=R/'ProfPaden'
tree=ast.parse((R/'tools/verify_guide_math.py').read_text())
setup=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SETUP' for t in n.targets))
results=[]
for recipes,goal,conversions in [(100,300,False),(30,150,True)]:
 L=LuaRuntime();L.execute(setup);P=L.globals().P
 for f in ['Planner.lua','Cheapest.lua','MarketRoutes.lua','MoneyRoutes.lua','Sourcing.lua']:
  L.execute((A/f).read_text(encoding='utf8'),'ProfPaden',P)
 L.execute('P.skills.Alchemy.rank=1;P.skills.Alchemy.cap=300')
 L.execute('''local n,conv=...;for i=1,n do local r=recipe(i,500+i);r.yellow=300;r.green=310;r.grey=320;P.market.prices[500+i]={value=i+10};if conv then local c=recipe(10000+i,1000+i);c.item=500+i;P.market.prices[1000+i]={value=i+9};c.grey=1 end end''',recipes,conversions)
 start=perf_counter();p=P.BuildCheapestPlan(P,goal);elapsed=perf_counter()-start
 assert p.reached==goal
 results.append(dict(recipes=recipes,skill_start=1,goal=goal,learned_conversions=conversions,seconds=round(elapsed,3),total=p.total))
(R/'docs/guide-math-2026-11-24/performance.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results))
