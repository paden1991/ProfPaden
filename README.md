# ProfPaden

WoW Forever, Interface 16001. Version 0.20.37-rc1 (release candidate).

## Installation

Select Forever in WowUp, choose **Install from URL**, and enter `https://github.com/paden1991/ProfPaden`. The installable release asset ends in `-forever.zip` and contains the ProfPaden and PadenCrates addon folders. Do not use GitHub's automatic source-code archive as an installable package.

## Crate and writ companion

The ProfPaden release now includes **PadenCrates 0.2.1-rc1**. It appears separately in WoW's AddOns list and preserves the existing PadenCratesDB settings. If it is already installed, extract/update over that same PadenCrates folder; do not install a second renamed copy.

Enable Auctionator and scan for prices. The **Supplies** tab beside Auctionator's tabs (or `/pcrates shop`) plans the missing items for carried crates and writs, combines shared requirements, deducts bag inventory once, and sends exact quantities to Auctionator for review. Confirm purchases there. Uncached writs use recorded requirements until quest data loads; the writ itself is excluded from materials. Crafting and quest turn-ins remain manual.

[Companion instructions](PadenCrates/README.md) · [Checks and screenshots](docs/padencrates/README.md)

## Current package

ProfPaden retains profession leveling, material/source information, shopping and navigation. BetterFishing and NodeSight are no longer embedded; install NodeSight separately if wanted. It owns its settings and keybindings. Maps use textures already installed in WoW beneath ProfPaden's existing overlays.

GatherMate coordinates are not bundled. For extra mining/herbalism coverage, install and enable the **Forever versions of [GatherMate2](https://www.wowace.com/projects/gathermate2) and [GatherMate2_Data](https://www.wowace.com/projects/gathermate2_data)**, then reload the UI. ProfPaden automatically loads the installed data addon outside combat and imports matching records into session memory. No manual GatherMate import is required. GatherMate2 alone supplies your collected records. Both are declared in OptionalDeps; WoW and WowUp do not automatically install dependencies from this declaration. Missing, disabled or incompatible dependencies leave the built-in atlas available. ProfPaden never changes GatherMate settings, saved databases or import options.

Routes includes the existing compiled 43-map elevation data and numeric terrain hints. Raw research ZIPs, original heightmap images/F32 exports, copied map backgrounds and other addon bundles are excluded. These conversions do not change the underlying source rights; see [attribution](THIRD_PARTY.md).

## Validation

`python tools/build_release.py` verifies every runtime file against the reviewed SHA-256 manifest, packages the main addon and reviewed companions, and checks the TOC and ZIP. Use a matching `v<version>` tag to publish via GitHub Actions; manual dispatch accepts an existing reviewed tag.

Lua regressions cover gathering, guides, source data, tracking, walking and terrain. The Forever simulator loads the package without the removed companions. Its native map texture assets show checkerboards in both ProfPaden and Blizzard's map; real-client map artwork and optional NodeSight coexistence still require live acceptance. This is not a live-game certification.

## Latest verification

Version 0.20.36-rc1 adds eight reviewed Wowhead acquisition and hotfix updates after comparing all 933 recipes in the November 19 overview. The [November 21 review](docs/wowhead-2026-11-21/review.json) records accepted facts, conflicts and test results. Version 0.20.34-rc1 supplied the earlier November source and profession corrections. The [update report](docs/november-12/README.md) includes provenance, held candidates, tests and visual references. Earlier release evidence remains in docs/morning-data and docs/launch-data; in-game acceptance is separate.

Gather location QA (2026-11-21): repaired 402 missing material/zone choices and 679 incomplete zone views across 180 entries, using existing recorded masks. Full integrity checks cover 1,499 entries and 48,985 source records. See `docs/gather-location-qa-2026-11-21/` for the audit, tests and simulator screenshots. Native map artwork and live drops still require actual-client confirmation.
