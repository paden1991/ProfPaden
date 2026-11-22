# PadenCrates 0.2.1-rc1

Standalone WoW Forever addon (interface 16001). Install this PadenCrates folder directly in `_forever_/Interface/AddOns/`, then restart the client if it was already running. Enable Auctionator and scan the auction house for prices.

- Hover a Waylaid Crate: see the cheapest complete material bundle, its estimated total cost, carried quantity and scan age. Hold Shift to compare all its bundles.
- Hover a Craftsman's Writ: see the required finished item and total estimated purchase cost. Client quest data updates the required quantity when available; otherwise the recorded requirement is explicitly labelled.
- Right-click a carried crate to fill ONE crate with the cheapest bundle. Equal-cost choices prefer available materials. No expensive substitute is chosen if the cheapest material is missing. No purchases, crafting or quest turn-ins are automated.
- `/pcrates` opens native Settings. `/pcrates status` reports provider/auto-fill status. Preferences are account-wide.
- `/pcrates shop` opens the supplies preview; the **Supplies** tab at the auction house opens the same window. Select crates, writs or both, then **Shop missing items** to open a combined Auctionator shopping list with exact missing quantities. Review current prices and confirm each purchase in Auctionator. The addon does not spend gold unattended.

Shopping counts all copies of selected crates and writs in carried bags, chooses the same cheapest crate bundle as the tooltip, combines shared requirements, and subtracts bag inventory once. Writs use their recorded quantities while quest objectives are unavailable; loaded quest quantities override them. The writ itself is excluded from material requirements. Unexpected additional material objectives still require manual review. Missing or stale crate prices block selecting a cheapest bundle; refresh your Auctionator scan. Unknown prices for a fixed writ item are labelled and can be checked in the auction house. Names must be cached in the client locale before the entire list is sent.

Bank/alt inventory and uncollected auction mail are not counted. Collect purchases before planning another batch. Refresh never silently re-exports a list; an identical already-sent list cannot be resent during the current UI session, preserving Auctionator's buying progress. An updated bag plan may be sent after review. The estimates are not a spending cap; Auctionator shows the current purchase price and available stock for confirmation.

Auto-fill requires all bundle prices to be known and at most three days old, enough unlocked materials in carried bags, and an ordinary unmodified right-click outside combat and service windows. If those conditions are not met, normal manual crate use remains available. Left-click and modifier clicks retain normal bag behavior. Supports bag buttons exposing the standard GetBagID/GetID interface, including Blizzard and Baganator-style buttons; other bag replacements need a compatibility check.

Prices are Auctionator's last scanned unit prices multiplied by the required quantity. They are estimates, not a live offer or guarantee of auction stock. Carried materials retain market value. Writ pricing covers buying the requested finished items, not an optimal crafting recipe tree.

Thirty crate and 150 writ records are included. Catalog facts are adapted from the MIT-licensed Warlune/forever-waylaid-addon, commit 92c6316feb6298f270b40966c73472d2c21e6ba8. See Catalog-LICENSE.txt. Its catalog snapshot identifies build 1.60.1.70009; all thirty crate bundle lists were cross-checked against an independent build 1.60.1.70959 reference. This is not verification of every requirement on the live server.

This release candidate has automated Lua and simulator checks. Actual in-game secure filling, split-stack consumption, Baganator interaction and controller input still need testing. For split stacks, the addon targets one unlocked stack of the selected material and relies on the server to aggregate the required carried quantity; it never merges stacks or loops item uses. If the client leaves a targeting cursor or rejects the fill, choose the material manually and report the error.

English addon text ships as the fallback for every locale. Cached item names use the client locale. Native Settings and passive tooltip behavior are retained; controller auto-fill has not been certified.
