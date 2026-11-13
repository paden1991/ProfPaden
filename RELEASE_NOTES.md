ProfPaden 0.20.34-rc1 — WoW Forever / Interface 16001.

Materials and recipes now include 3,745 additional observed acquisition relationships across 317 items (2,807 creature loot, 852 vendors and 86 quest rewards), plus 712 observed trainer relationships for 274 recipes. Prior sources and live trainer availability remain available.

Applies the November 6–11 profession hotfixes: Tanning Rack requires 125 skill; Coarse Grinding Stone gives skill-ups through the revised 90 gray threshold; Arcane Salvager needs Runed Golden Rod; and the five wool, silk and mageweave bags use their corrected bolt quantities and capacities. For example, three Green Woolen Bags now require 15 bolts rather than 12. Updated guide rows also explain campfire placement, vendor sell values, Spirit enchant fixes and ammunition binding/raid availability. The Holy Power recipe item uses its corrected name.

Validation: 19 offline Lua 5.1 checks passed, including rendering all 2,574 catalog and 1,499 material details, material totals, repeat-load safety, deterministic generation and unchanged coordinate data. See docs/november-12 for simulator evidence and the audit ledger. UIForever loads with zero errors or missing APIs. Its older build still supplies a stale Tanning Rack 140 tooltip alongside corrected static 125; current client tooltips remain authoritative. Live-game acceptance remains for the user after reload.

417 ambiguous relationships remain held (232 shared-object records and 185 unnamed entities). No new recipes, inferred drop rates, vendor stock or map coordinates are invented. Earlier alternative sources are retained because an observation sample is not an exhaustive roster. Coarse Grinding Stone's green threshold follows ProfPaden's existing midpoint convention; the official hotfix specifies the gray endpoint.

Install ProfPaden-0.20.34-rc1-forever.zip or update through WowUp using https://github.com/paden1991/ProfPaden . Reload WoW after updating. Settings, macros and unrelated addons are preserved.
