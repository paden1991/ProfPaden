# November 12 profession update

Target: WoW Forever, existing Interface 16001 contract, public provider build 1.60.1.70888. This data-only change adds no Blizzard API calls. The user authorized source updates, hotfix corrections, installation and GitHub publication; the earlier new-ID threshold no longer blocks this release.

## Coverage

- 3,745 added item-source relationships across 317 existing items: 2,807 creature loot, 852 vendors, 86 quest rewards.
- 712 observed trainer relationships across 274 recipes.
- Fifteen recipe correction records and thirteen item correction records from official hotfixes.
- 417 source candidates held: 232 shared objects, 185 unresolved entity names.

The full source review considers the latest snapshot against installed 0.20.33-rc1, including unpublished November 7 findings. The audit's 796 changed provider recipe rows are not 796 new recipes. Counts of observed NPCs or vendor visits are not drop rates, stock or guaranteed availability. Missing names, classic fallback-only relationships and shared objects are not promoted. Prior sources remain; changing a sampled trainer list does not prove removal. Creature loot is not relabelled Skinning. Existing coordinates are reused only for the same source entity.

## Hotfixes

[Blizzard's hotfix log](https://news.blizzard.com/en-us/article/24315281/wow-forever-hotfixes-november-11-2026) supplies recipe costs, skill changes, names and item facts. [hotfixes.json](hotfixes.json) is the reviewed machine-readable ledger. It takes precedence over stale provider fields. Bag quantities update catalog, leveling and derived material summaries; actual live recipe reagents still override static defaults. Tanning Rack's former 140/140/142/145 thresholds each move down 15. Coarse Grinding Stone retains yellow 50 and uses gray 90 with green 70 following the catalog's midpoint convention, not a newly observed green threshold.

Price corrections are informational sell values and guide notes; vendor purchase offers and user market observations are not overwritten. New names and descriptive hotfix notes use the addon's existing English fallback convention. No controls or configuration options were added. Existing mouse, keyboard and gamepad navigation remain unchanged; physical controller testing was not performed.

## Evidence and reproduction

- [Reviewed sources](sources.json), [accepted and held records](review.json), [snapshot hashes and URLs](provider-manifest.json), [provider recipe diffs](recipe-review.json).
- Run `python tools/build_november_update.py`, then `python tools/verify_november_update.py` with `lupa.lua51` installed.
- [Nine focused checks](tests.json) and [ten broad functional checks](functional-tests.json) cover 2,574 catalog and 1,499 material detail entries.
- [Visual and functional reference](preview.html) contains actual detail-row output; simulator results are recorded separately.

No settings, macros, user observations, spawn positions or unrelated addon files are reset. Real crafting, trainer services and gameplay are not verified by offline tests or the simulator.

Thirty-four provider training-price changes are retained in [held-training-fees.json](held-training-fees.json), not applied: several differ by exactly the common reputation discount, and the provider does not establish a consistent undiscounted basis. Observed source counts also remain audit metadata, not availability guarantees.

Simulator review found and fixed a second stale Tanning Rack requirement on the Happy Camper source record (140 to 125). Regression validation rejects the conflicting old requirement in actual acquisition rows.

UIForever loaded 0.20.34-rc1 with zero errors and zero missing APIs. Its older 1.60.1.70450 item tooltip still supplies a separate Leatherworking 140 requirement; runtime inspection confirmed the addon static source is 125. Client tooltip precedence is preserved. See [simulator observations](simulator.json), [bag screenshot](simulator-bag.png) and [Tanning Rack screenshot](simulator-rack.png). This remaining simulator-only discrepancy needs confirmation on the current real client.
