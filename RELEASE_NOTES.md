ProfPaden 0.20.32-rc1 — WoW Forever / Interface 16001.

Adds published acquisitions for newer profession materials and recipe items, including camping blueprints and Enchant Boots - Speed. The enchant now identifies Alynsia, 180 Merchant's Favor, and Honored with the Azeroth Commerce Authority.

Coverage: 966 newer items checked (54 materials and 912 recipe items), using complete public ForeverDB source/vendor snapshots supplemented by detailed Wowhead tables. 389 items have published relationships; 577 have no additional relationship in these snapshots. Existing sources remain intact. The current external recipe catalog contains the 2,491 recipes already covered plus the excluded deprecated Crystal Infused Bandage; no usable new crafting recipe was found.

Adds 503 distinct item acquisition relationships. Recipe ranks, color thresholds, reagents, outputs, recorded coordinates, and live observation precedence are preserved. No coordinates or guaranteed drop rates were invented. Forever-labelled observations may predate launch; absent tables do not prove unobtainability. Classic-only fallback rows from the new provider were not imported.

Validation: seven data checks and ten offline functional checks pass, including all 2,574 catalog and 1,499 material detail entries. UIForever build 1.60.1.70450/interface 16001 loads the candidate; enchant and blueprint requirements and leather details were inspected without Lua errors or listed missing APIs. Native map textures retain the simulator's known checkerboard limitation. These are offline/simulator results, not live-game acceptance.

Install the attached ProfPaden-0.20.32-rc1-forever.zip, or update through WowUp using https://github.com/paden1991/ProfPaden . Routes, Clam Keeper, GatherMate2 and GatherMate2_Data remain separate. Reload WoW after updating.
