# Full regression review — 2026-11-02

ProfPaden 0.20.31-rc1 — WoW Forever / Interface 16001.

Full regression review found and fixed three issues:
- Browsing an unlearned profession no longer retains another profession's leveling summary or target.
- GatherMate import uses silent optional locale lookups, avoiding missing-translation errors from its real AceLocale library.
- Camp kit opens above the main guide while retaining secure actions and combat restrictions.

Validation: 1,273 checks across 68 Lua/data regression suites passed, covering leveling, catalogs, sources, shopping, vendor/Auctionator logic, camping, controller input, tracking, route recovery, terrain and Clam Keeper. Actual locally installed GatherMate libraries imported 23,460 records across 40 maps in the full runtime; every retained coordinate/type matched its provider. This is source fidelity, not live-spawn proof.

GatherMate2 and GatherMate2_Data remain separate optional Forever dependencies. Neither their data nor their code is bundled. Routes and Clam Keeper remain separate addons. Some sparse terrain starts have no safe route without the extra provider data and return an explicit message. Generated-data replay left all runtime bytes unchanged.

Simulator checks use build 1.60.1.70450 and do not certify live gameplay. Native map textures remain checkerboards in both ProfPaden and Blizzard's map in this simulator. Actual crafting/auction actions, live GatherMate load timing and terrain traversal require game-client acceptance.

Install or update through WowUp using https://github.com/paden1991/ProfPaden . The attached -forever.zip includes Forever release metadata. Routes 0.20.18-rc1 and Clam Keeper 0.1.1-beta do not need a new version for these fixes.

See [check counts by suite](qa-summary.json).

Final packaged-build simulator check: switching from learned Tailoring (205) to unlearned Alchemy cleared the plan summary, hid the goal, and retained 62 guide entries. Camp kit was visible at DIALOG strata above the HIGH main window. The corrected test sequence produced no Lua errors. One initial console-only test attempted to access the lazily created window before opening it; this harness error was corrected and cleared before the final run.
