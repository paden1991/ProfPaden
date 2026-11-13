"""Generate the reviewed November 12 data module without replacing earlier evidence."""
import json
from build_launch_sources import ROOT,build as sources,lua
D=ROOT/'docs/november-12';OUTPUT=ROOT/'ProfPaden/Data/NovemberUpdate.lua'
def build():
 sources(D/'sources.json',OUTPUT,'2026-11-12','NovemberSourceCoverage')
 body=OUTPUT.read_text(encoding='utf8').replace('tools/build_launch_sources.py','tools/build_november_update.py')
 data=json.loads((D/'sources.json').read_text(encoding='utf8'));fix=json.loads((D/'hotfixes.json').read_text(encoding='utf8'))
 body+='\nlocal trainers='+lua(data['trainers'])+'\nlocal fixes='+lua({int(k):v for k,v in fix['recipes'].items()})+'\nlocal itemFixes='+lua({int(k):v for k,v in fix['items'].items()})+'\nlocal hotfixURL='+lua(fix['source'])+'\n'
 body+=(ROOT/'tools/fixtures/november_patch.lua').read_text(encoding='utf8')
 OUTPUT.write_text(body,encoding='utf8',newline='\n');return OUTPUT
if __name__=='__main__':print(build())
