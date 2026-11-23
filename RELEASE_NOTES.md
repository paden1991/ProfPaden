ProfPaden 0.20.39-rc1 - WoW Forever / Interface 16001.

Audits all 627 Gather materials and adds 1,200 acquisition relationships across 75 materials (278 profession entries). Twelve previously empty materials gain sources.

- Adds five missing dungeon-boss reagents: Golem Heart, Undeath Engine, Bottled Screams, Lich's Index Finger and Maker's Spark.
- Adds seven published herb-yield links for Rosecap, Unusual Herb Seeds and Scarce Herb Seeds, plus a checked Frilled Lichen vendor listing.
- Adds 1,187 repeated community acquisition reports across cloth, leather/hides, gems, stones, fish, cooking and specialty materials. These are visibly labeled Report: normal loot versus skinning/other methods and observation build/date are not supplied. Counts are not drop rates.
- Corrects the Scarce Herb Seeds note: the November 19 hotfix removed Seed Hybridizer use. Preserves Greenhouse planting.
- Preserves recipes, existing sources, map coordinates, overlays, routes, settings and controls. Ambiguous vendor stock and low-confidence reports remain held.

Includes unchanged PadenCrates 0.2.1-rc1. Install ProfPaden-0.20.39-rc1-forever.zip through WowUp or extract both addon folders into Interface/AddOns. Do not install GitHub's automatic source archive.

Validation: all 75 updated material views exercise the actual Lua 5.1 UI path; full Gather integrity covers 53,967 source records and 1,169,461 node exports. PadenCrates passes 970 assertions, and all nine packaging guards pass. See docs/material-sources-2026-11-22 for the catalog ledger, provenance, held candidates, functional checks and simulator evidence. This is not live-game drop certification.

Simulator: production ZIP initialization, representative material views, Details controls and scrolling passed. Source pagination passes through its registered handler, but a simulator mouse click on the existing hyperlink did not advance; actual-client clicking remains to be checked. No UI code changed.
