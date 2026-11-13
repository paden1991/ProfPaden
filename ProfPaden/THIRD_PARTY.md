# ProfPaden runtime sources and attribution

This package contains ProfPaden code and compiled data, not the original research archives or copies of other addons.

- BetterFishing and NodeSight are not included or loaded by ProfPaden. NodeSight can be installed separately and retains its own settings and keybindings.
- World of Warcraft map textures are requested from the installed game by file ID. Copied map-background images, OpenMap's artwork, and raw heightmap PNG/F32 exports are not included. Blizzard retains its rights in game content.
- ProfPadenRoutes includes compiled terrain-height grids from local client build 1.60.1.70450, plus coarse terrain hints derived from map imagery. These are terrain samples and heuristics, not a collision mesh or a guarantee of traversability. Unknown terrain remains unknown. Converting source material to Lua does not change its underlying rights.
- No GatherMate coordinates, lookup tables, runtime code, libraries or artwork are bundled. The optional integration reads mining/herbalism records from a user's installed Forever-compatible GatherMate2 and GatherMate2_Data at runtime. Imported records stay in session memory; ProfPaden does not write them to its SavedVariables or modify GatherMate's database. The providers retain their rights and attribution. GatherMate2 / GatherMate2_Data contributors include kagaro, Xinhuan, nevcairiel, Spinx and Marrtin. Project: https://www.wowace.com/projects/gathermate2_data
- Profession guides and attributed reference circuits are adapted from Classic WoW Forever under CC BY 4.0: https://classicwowforever.com/professions/crafting/ and https://creativecommons.org/licenses/by/4.0/ . Adaptations include structured records, summaries and separately drawn overlays. This attribution does not extend that license to Blizzard artwork. No endorsement is implied.
- Additional factual source relationships retain their provider labels and links, including Wowhead, QuestieDB and ClassicDB. Recorded locations are not assertions of current live spawns.
- Camping Kit 1.4 by Doug Mansell supplied factual item/spell references. Its MIT notice is retained in ProfPaden/Vendor/CampingKit-LICENSE.txt. No Camping Kit runtime or artwork is bundled.
- ProfPadenRoutes' optional OpenMap integration uses its public API; OpenMap is installed separately. The OpenMap MIT notice in the source repository applies only to its covered material, not this entire package or Blizzard assets.

The November 5, 2026 acquisition pass includes factual item, vendor, quest, crafting and drop relationships from ForeverDB (https://foreverdb.net/) and Wowhead Forever (https://www.wowhead.com/forever). Provider labels and item links are retained. Only explicitly Forever-labelled new ForeverDB relationships were imported; observed positions were not converted to spawn coordinates. Game facts retain their underlying rights. No provider code, prose guides, or artwork is included by this pass.

Public availability does not assign a blanket open-source license to this package or erase any source attribution.

The November 6, 2026 coverage pass adds explicitly Forever-labelled creature loot, vendor, quest and recipe-trainer observations from ForeverDB (https://foreverdb.net/). The reviewed ledger and exclusions are in docs/morning-data in the source repository. Observation counts are not drop rates; observed positions are not new spawn points. Numeric profession changes and unresolved/shared source identities were not imported.

The November 12, 2026 update adds reviewed ForeverDB source and trainer observations and official Blizzard profession hotfixes from November 6–11. See docs/november-12 for provenance, held candidates and validation. Observation counts do not establish drop rates, stock, prices or precise spawn coordinates.
