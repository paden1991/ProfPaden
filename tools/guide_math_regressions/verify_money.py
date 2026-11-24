"""Production-profit behavior exercised under Lua 5.1, without game actions."""
from pathlib import Path
import sys,json,traceback
REPO=Path(__file__).resolve().parents[2];ROOT=REPO/'ProfPaden';REPORTS=REPO/'docs/guide-math-2026-11-24'
sys.path.insert(0,'C:/Users/pgold/AppData/Local/Temp/ProfPadenScreenRuntime')
from lupa.lua51 import LuaRuntime
FILES=[x.strip().replace('\\','/') for x in (ROOT/'ProfPaden.toc').read_text().splitlines() if x.strip().endswith('.lua') and not x.startswith(('Vendor','Companions'))]
SETUP='''
SetupReference();P.mode='money';P.tab='Recipes';P.selectedProf='Alchemy';P.skills.Alchemy={rank=100,cap=150};P.live={};P.char.trainers={};P.Recipes.Alchemy={}
P.market.prices={};P.market.observed={[765]={value=100,time=time(),source='Viewed AH'},[3371]={value=300,time=time(),source='Viewed AH'},[10001]={value=400,time=time(),source='Viewed AH'},[10002]={value=400,time=time(),source='Viewed AH'}}
P.char.vendors={[3371]={value=20,stock=-1,name='Supply seller',time=time(),npcID=123,zone='Town'}};P.char.unlimitedVendors={}
P.Catalog.Alchemy={{name='Gray potion',spell=900001,item=10001,profession='Alchemy',mats={{id=765,count=1},{id=3371,count=1}},complete=true,yellow=20,grey=50,output=1},
{name='Costly potion',spell=900002,item=10002,profession='Alchemy',mats={{id=765,count=2},{id=3371,count=1}},complete=true,yellow=120,grey=150,output=1}}
P.char.recipes.Alchemy={s900001=P.Catalog.Alchemy[1],s900002=P.Catalog.Alchemy[2]};P.char.moneySale='auction5';P.char.moneyBatches={Alchemy=10};Bag[765]=999;Bag[3371]=999
C_Item.GetItemInfo=function(id)return 'Item '..id,'item:'..id,1,1,1,'Consumable','Potion',20,'',1,10,0,1,0 end
Auctionator=nil;AucAdvanced=nil;TSM_API=nil
function choose(label)for _,r in ipairs(P.dropdown.rows)do if r.shown and r.label.text==label then r.scripts.OnClick();return end end;error(label)end
'''
results=[]
def run(name,code):
 try:
  L=LuaRuntime(unpack_returned_tuples=True);L.execute((REPO/'tools/fixtures/snapshot.lua').read_text());P=L.table()
  loader=L.eval('function(code,p)assert(loadstring(code))("ProfPaden",p)end')
  for file in FILES:loader((ROOT/file).read_text(encoding='utf-8'),P)
  L.execute(SETUP);L.execute(code);results.append(dict(name=name,passed=True))
 except Exception as e:results.append(dict(name=name,passed=False,error=str(e)));traceback.print_exc()
run('Gray recipes rank by batch profit and ignore bags and Cheapest exclusions', '''
P:RouteChoices().excluded.s900001=true;local rows=P:Rows();assert(#rows==2 and rows[1].spell==900001 and rows[1].moneyProfit==2600 and rows[1].moneyCost==1200)
Bag[765]=0;assert(P:Rows()[1].moneyProfit==2600);assert(rows[1].start==nil and not rows[1].planStep)
''')
run('Input model ignores manual overrides, recognizes bundled supplies, and does not infer stock from price hints', '''
P.market.prices[765]={value=1};P.char.vendors[765]={stock=4,value=2};assert(P:MoneyInputPrice(765)==100)
P.char.vendors[3371].stock=0;assert(P:MoneyInputPrice(3371)==20)
P.char.vendors[3371].stock=nil;assert(P:MoneyInputPrice(3371)==20)
P.market.observed[3371]=nil;assert(P:MoneyInputPrice(3371)==20);P.Items[990001]={vendorBuy=10};assert(P:MoneyInputPrice(990001)==nil)
''')
run('Unlimited merchant capture persists through later limited-stock offers', '''
GetMerchantNumItems=function()return 1 end;GetMerchantItemLink=function()return 'item:3371' end
GetMerchantItemInfo=function()return 'Vial',nil,100,5,-1,nil,false end;P:CaptureMerchant();assert(P:MoneyInputPrice(3371)==20)
GetMerchantItemInfo=function()return 'Vial',nil,200,5,1,nil,false end;P:CaptureMerchant();assert(P:MoneyInputPrice(3371)==20)
GetMerchantItemInfo=function()return 'Vial',nil,1,1,-1,nil,true end;P:CaptureMerchant();assert(P:MoneyInputPrice(3371)==20)
''')
run('Trainer fees amortize across selected batch; future or blocked offerings excluded', '''
P.char.recipes.Alchemy.s900001=nil;P.char.trainers={Alchemy={s900001={eligible=true,required=100,cost=1000,trainer='Tutor'}}}
P.char.moneyBatches.Alchemy=1;assert(#P:Rows()==1 and P:Rows()[1].spell==900002)
P.char.moneyBatches.Alchemy=20;assert(P:Rows()[1].spell==900001 and P:Rows()[1].moneyProfit==4200)
P.char.trainers.Alchemy.s900001.required=101;assert(#P:Rows()==1)
P.char.trainers.Alchemy.s900001.required=100;P.char.trainers.Alchemy.s900001.eligible=false;assert(#P:Rows()==1)
''')
run('Losses and unpriced inputs do not appear as opportunities', '''
P.market.observed[10001].value=100;P.market.observed[10002].value=100;assert(#P:Rows()==0 and P.moneySummary.loss==2)
P.market.observed[765]=nil;assert(#P:Rows()==0 and P.moneySummary.unpriced==2)
''')
run('Output eligibility, minimum yield and sale fees remain conservative', '''
C_Item.GetItemInfo=function(id)return 'Item '..id,'item:'..id,1,1,1,'Consumable','Potion',20,'',1,10,0,1,1 end
assert(#P:Rows()==0 and P.moneySummary.unsellable==2)
P.char.moneySale='vendor';assert(#P:Rows()==0)
C_Item.GetItemInfo=function(id)return 'Item '..id,'item:'..id,1,1,1,'Consumable','Potion',20,'',1,500,0,1,0 end
P.char.moneySale='best5';local rows=P:Rows();assert(rows[1].planSale.method=='Vendor' and rows[1].moneyProfit==3800)
P.Catalog.Alchemy[1].output=2;P.Catalog.Alchemy[1].outputMax=10;assert(P:Rows()[1].moneyProfit==8800)
''')
run('Menu and batch controls keep leveling targets and sale settings independent', '''
P.char.profitSale='vendor';P.char.planTargets={Alchemy=140};P:Refresh();P.modeButton.scripts.OnClick();choose('Money-making >');choose('Auction (15% cut)')
assert(P.mode=='money' and P.char.moneySale=='auction15' and P.char.profitSale=='vendor');assert(P.planGoalLabel.text=='Batch:')
P.planGoal:SetText('20');P.planGoal.scripts.OnEnterPressed(P.planGoal);assert(P:MoneyBatch()==20 and P.char.planTargets.Alchemy==140 and P.qty.text=='20')
assert(not P.excludeRecipe.shown and not P.resetChoices.shown and P.priceButton.text=='Export inputs')
assert(not P:SetMoneyBatch(0) and P:MoneyBatch()==20)
''')
run('Details show full purchase costs, ROI, vendor source and no skill-gain plan', r'''
local rows=P:MoneyDetailRows(P:Rows()[1],10);local text='';for _,r in ipairs(rows)do for _,c in ipairs(r.cells)do text=text..tostring(c)..'\n' end end
assert(text:find('Upfront budget',1,true) and text:find('Estimated profit',1,true) and text:find('Return on spend',1,true) and text:find('Unlimited vendor:',1,true))
assert(not text:find('Materials owned',1,true) and not text:find('SKILL GAINS',1,true))
''')
run('Export sends full batch AH quantities, excludes unlimited vendor inputs', '''
P.auctionOpen=true;local terms;Auctionator={API={v1={MultiSearchAdvanced=function(_,t)terms=t end}}}
assert(P:ExportMoneyInputs(P:Rows()[1],10));assert(#terms==1 and terms[1].quantity==10 and terms[1].isExact and terms[1].searchString=='Item 765')
assert(P.auctionatorShopping==nil)
''')
run('Export rejects scan, purchase dialog, missing names and combat without partial export', '''
P.auctionOpen=true;local calls=0;Auctionator={API={v1={MultiSearchAdvanced=function()calls=calls+1 end}}};local r=P:Rows()[1]
P.auctionatorScanActive=true;assert(not P:ExportMoneyInputs(r,10));P.auctionatorScanActive=nil
AuctionHouseFrame={BuyDialog={IsShown=function()return true end}};assert(not P:ExportMoneyInputs(r,10));AuctionHouseFrame=nil
InCombatLockdown=function()return true end;assert(not P:ExportMoneyInputs(r,10));InCombatLockdown=function()return false end
C_Item.GetItemInfo=function()end;assert(not P:ExportMoneyInputs(r,10));assert(calls==0)
''')
run('At skill cap money-making remains available; no profitable result explains missing data', '''
P.skills.Alchemy.rank=150;P:Refresh();assert(#P.entries==2 and P.selected.money)
P.market.observed={};P:Refresh();assert(#P.entries==0 and P.detailTitle.text=='No profitable crafts priced')
''')
report=dict(tests=len(results),passed=sum(r['passed'] for r in results),results=results)
(REPORTS/'money-test-results.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2));sys.exit(report['tests']!=report['passed'])
