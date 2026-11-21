ProfPaden 0.20.35-rc1 — WoW Forever / Interface 16001.

Checked the November 19 Wowhead profession overview against ProfPaden: all 933 listed recipe spells already existed. This release adds verified acquisition and hotfix facts for eight recipes; it does not claim new recipes.

- Five starter recipes now correctly say they are learned automatically: Elixir of Minor Force, Minor Arcane Elixir, Copper Rod, Dust to Motes, and Novice's Practice Wand.
- Orcish War Leggings now links Plans: Orcish War Leggings to The Old Ways quest and Sumi's replacement service after quest completion. The recipe-item requirement confirms Blacksmithing 205; the stale 230 disagreement is removed. The quest guide includes the plans reward.
- Bronze Mace notes its bind-on-equip status and transmog eligibility.
- Seed Hybridizer notes its re-enablement, possible seed-combination failure, and exclusion of Scarce Herb Seeds.

Validation: 36 focused Lua 5.1 checks plus 9 existing data/rendering checks passed, covering all 2,574 catalog entries and 1,499 material details. Ingredient quantities, output counts, skill thresholds, map coordinates, and live-observation precedence are preserved. UIForever loaded the full release ZIP and displayed the Orcish War Leggings requirements and Seed Hybridizer warning with zero final errors or missing APIs. Current real-game acceptance remains untested.

Four blank/unresolved recipe-item links and a conflicting Spinefin Halibut trainer claim were held for further evidence. The overview downloaded successfully; direct detail collection stopped at an HTTP 403. This is a targeted guide/hotfix audit, not a full Wowhead database refresh. See docs/wowhead-2026-11-21/review.json and tests.json.

Sources: https://www.wowhead.com/forever/guide/professions/overview and Blizzard's November hotfix notes mirrored by Wowhead (links in the review ledger and data module).

Install ProfPaden-0.20.35-rc1-forever.zip or update through WowUp using https://github.com/paden1991/ProfPaden . Reload WoW after updating.
