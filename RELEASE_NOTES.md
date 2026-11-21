ProfPaden 0.20.36-rc1 — WoW Forever / Interface 16001.

Gather location QA found that newer drop sources could appear in text without their zones being selectable on the map. Linen Cloth in Duskwood was one example.

- Restores 402 missing material/zone choices and completes 679 existing zone views across 180 material entries.
- Builds 313 shared overlays from existing recorded source masks, preserving previous map coverage. No new spawn coordinates, drop rates, or acquisition claims are introduced.
- Preserves original source records, historical/reference labels, node coordinates, and live-observation behavior.

Validation: eight focused repair checks cover all 1,499 material entries, 48,985 source records, 8,536 selectable material/zone combinations, overlay pixel unions, and 1,169,461 exported node instances. All exported coordinates are bounded; raw sentinel records remain preserved but are excluded from exports. The 36 prior acquisition checks still pass. Baseline regression suites passed 84 checks after correcting two obsolete test assumptions about Copper's source count.

UIForever loaded the complete package with zero errors and zero missing APIs. Actual clicks tested location disclosure, paged zone selection, and the selected world map. Console checks covered cloth, ore, herbs, leather, meat and fish. The simulator shows placeholder Blizzard map tiles: native artwork and actual loot/harvest behavior remain unverified in-game.

This is a complete internal location-integrity audit plus representative fresh Wowhead spot checks, not a new online verification of every drop record. Evidence: docs/gather-location-qa-2026-11-21/.

Install ProfPaden-0.20.36-rc1-forever.zip or update through WowUp. Reload WoW after updating.
