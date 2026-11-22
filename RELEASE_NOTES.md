ProfPaden 0.20.37-rc1 — WoW Forever / Interface 16001.

Includes PadenCrates 0.2.1-rc1 as a companion in the same WowUp-compatible ZIP. Both ProfPaden/ and PadenCrates/ install into Interface/AddOns. Existing PadenCrates settings are retained.

- Adds Auctionator price estimates for Waylaid Crates and Craftsman's Writs, with secure right-click crate filling when eligible.
- Adds a Supplies tab styled to match Auctionator. Preview shortages for carried crates/writs and send exact quantities to Auctionator; purchases require confirmation there.
- Fixes writ shopping when quest data has not loaded, and excludes the writ itself from required materials.
- Keeps ProfPaden's current profession and gathering behavior/data unchanged.

Enable Auctionator and scan for prices, then /reload and open Supplies at the auction house (or /pcrates shop). If PadenCrates is already installed, update its existing folder, not a renamed second copy.

Validation: 970 Lua 5.1 assertions; simulator checks of the Supplies tab, cold-cache writ quantities and actual Auctionator 351 list handoff. Clean production reload reported zero Lua errors/missing APIs. All package runtime files are checked against SHA-256 manifests. Actual-client purchases, secure item consumption and controller navigation still require live acceptance.

Install ProfPaden-0.20.37-rc1-forever.zip. This release contains both addon folders; GitHub's automatic source-code archive is not the installable package. See docs/padencrates for visual and functional evidence. Catalog attribution is included in PadenCrates/Catalog-LICENSE.txt.
