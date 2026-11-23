"""Generate the additive November 23 catalog update from reviewed facts."""
from pathlib import Path
import json
from build_launch_sources import lua
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'ProfPaden/Data/CatalogNovember23.lua'
def build():
    data=json.loads((ROOT/'docs/catalog-refresh-2026-11-23/reviewed.json').read_text(encoding='utf8'))
    for key in ['items','recipes','books']:data[key]={int(k):v for k,v in data[key].items()}
    body='-- Generated from reviewed November 23 evidence; live observations retain precedence.\nlocal _,P=...\nlocal reviewed='+lua(data)+'\n'
    body+=(ROOT/'tools/fixtures/catalog_november23.lua').read_text(encoding='utf8')
    OUTPUT.write_text(body,encoding='utf8',newline='\n');return OUTPUT
if __name__=='__main__':print(build())
