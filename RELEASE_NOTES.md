# ProfPaden 0.20.42-rc1 — compact sleeping-bag countdown

- Add a 320 x 64 sleeping-bag HUD: actual stack markers, estimated next-stack/full-stack times, interruption and completion states.
- Starts from Forever's Resting aura; does not trigger from campfires, inns, or placing a bag. Handles refreshing an existing three-stack buff.
- Fades after completion/interruption. Click-through normally; `/ppsleep preview` unlocks dragging for 15 seconds. Preferences, preview, and position reset are available under Settings > AddOns > ProfPaden - Sleeping Bag.
- Preserve all 0.20.41 crafting math fixes. Bundled for the GitHub/WowUp release.

See [implementation and QA](docs/sleeping-bag-2026-11-24/README.md). Live sleeping-bag timing still requires in-game acceptance; simulator tests use controlled aura events.

# ProfPaden 0.20.41-rc1 — crafting guide math

Local candidate, November 24, 2026. No public release made by this audit.

- Compare cheaper AH quotes with vendor supplies and reject invalid/stale quotes.
- Include learned intermediate materials, live-only recipes, and money-making outputs in price scans; refresh guide and shopping estimates after Auctionator updates.
- Correct multi-point skill jumps and remaining craft counts. Charge training once when returning to a recipe.
- Price combined route quantities so limited merchant stock cannot be counted repeatedly. Unpriced batches cannot become free Cheapest routes; Guided shows incomplete totals as subtotals.
- Keep margins based on full materials, training, minimum output, and the selected 5%/15% AH cut. Reject invalid yields and preserve bag/mail credit.
- Invalidate saved shopping calculations using the updated model, retaining user settings and mail tracking.

Quotes and skill probabilities are estimates. Available provider summaries are not a guarantee of current auction depth or successful sales; expired/cancelled-auction deposits are not modeled. The route search remains bounded rather than an exhaustive inventory/learned-recipe-state optimizer.

See [math audit and verification](docs/guide-math-2026-11-24/README.md).

## Previous release notes

# ProfPaden 0.20.40-rc1

- Refreshed all 12 profession catalogs and 4,401 referenced item IDs against 141 provider datasets. All 2,492 shared recipes retain matching reagent quantities.
- Added 1,303 item-source relationships across 200 items: 977 qualified acquisition reports and 326 observed vendor listings. Reports do not imply a guaranteed drop, exact method, current stock or price.
- Added 514 observed trainer relationships across 329 recipes.
- Added the Draught of Water Walking recipe book and its Alchemy 180 requirement, with published fishing samples in Tanaris and Mount Hyjal. Added teaching-book links for the two level-300 off-hand enchants.
- Corrected Gray Leather Boots, Mender's Mail Shoulders and Skycaller's Mail Shoulders names. Cleared the stale Gray Leather Boots training-threshold discrepancy using current Forever evidence.
- Preserved existing recipe yields, materials, map coordinates, vendor conditions, saved settings and PadenCrates 0.2.1-rc1.

Install the asset ending in `-forever.zip` through WowUp's Forever flavor. This is a release candidate; live-client acceptance remains separate from offline and simulator QA.

[Audit, decisions, checks and visual references](docs/catalog-refresh-2026-11-23/README.md)
