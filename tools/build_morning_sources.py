"""Generate the November 6 additive source update from its reviewed ledger."""
import json
from build_launch_sources import ROOT,build as build_sources,lua

DATA=ROOT/'docs/morning-data/sources.json'
OUTPUT=ROOT/'ProfPaden/Data/MorningSources.lua'

def build():
    build_sources(DATA,OUTPUT,'2026-11-06','MorningSourceCoverage')
    body=OUTPUT.read_text(encoding='utf8').replace('tools/build_launch_sources.py','tools/build_morning_sources.py')
    body+='\nlocal trainers='+lua(json.loads(DATA.read_text(encoding='utf8'))['trainers'])+'\n'
    body+='''-- Observed recipe services, not inferred trainer caps or guaranteed availability.
for _,record in ipairs(trainers) do
    for _,recipe in ipairs(P.Catalog[record.profession] or {}) do
        if recipe.spell==record.spell then
            local line='Trainer: '..record.name
            if record.zone~='' then line=line..' — '..record.zone end
            line=line..' (ForeverDB observed)'
            local text=recipe.source or ''
            if not text:find(line,1,true) then recipe.source=text..(text~='' and '\\n' or '')..line end
            recipe.sourceKinds=recipe.sourceKinds or {};recipe.sourceKinds.trainer=true
            if not recipe.sourceKind or recipe.sourceKind=='unknown' then recipe.sourceKind='trainer' end
            recipe.acquisitionChecked='2026-11-06'
            recipe.observedTrainerSources=recipe.observedTrainerSources or {}
            local exists=false
            for _,old in ipairs(recipe.observedTrainerSources) do if old.npc==record.npc then exists=true end end
            if not exists then recipe.observedTrainerSources[#recipe.observedTrainerSources+1]=clone(record) end
        end
    end
end
'''
    OUTPUT.write_text(body,encoding='utf8',newline='\n')
    return OUTPUT

if __name__=='__main__':print(build())
