# Sources and data provenance

Snapshot collected 15 October 2026. Facts are normalized into Lua; source pages and API definitions are retained under `docs/research` for development.

## Profession guides

[Classic WoW Forever crafting overview](https://classicwowforever.com/professions/crafting/) and its profession pages are the main route/data source. Attribution: **Classic WoW Forever**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Adaptations include conversion to per-craft reagent counts, an offline catalogue, condensed route/acquisition notes, UI categorization and cost estimation. No endorsement is implied.

- [Alchemy](https://classicwowforever.com/professions/alchemy/leveling/) / [181-recipe catalogue](https://classicwowforever.com/professions/alchemy/recipes/)
- [Blacksmithing](https://classicwowforever.com/professions/blacksmithing/leveling/) / [441-recipe catalogue](https://classicwowforever.com/professions/blacksmithing/recipes/)
- [Enchanting](https://classicwowforever.com/professions/enchanting/leveling/) / [215-recipe catalogue](https://classicwowforever.com/professions/enchanting/recipes/)
- [Engineering](https://classicwowforever.com/professions/engineering/leveling/) / [246-recipe catalogue](https://classicwowforever.com/professions/engineering/recipes/)
- [Leatherworking](https://classicwowforever.com/professions/leatherworking/leveling/) / [512-recipe catalogue](https://classicwowforever.com/professions/leatherworking/recipes/)
- [Tailoring](https://classicwowforever.com/professions/tailoring/leveling/) / [414-recipe catalogue](https://classicwowforever.com/professions/tailoring/recipes/)
- [Cooking](https://classicwowforever.com/professions/cooking/), [First Aid](https://classicwowforever.com/professions/bandages/), [Fishing](https://classicwowforever.com/professions/fishing/), [Camping](https://classicwowforever.com/professions/camping/), [Mining](https://classicwowforever.com/professions/mining/leveling/), [Herbalism](https://classicwowforever.com/professions/herbalism/leveling/), [Skinning](https://classicwowforever.com/professions/skinning/).

The six catalogues were fetched across every page and checked against their advertised totals by unique spell ID. The main source identifies beta build 1.60.1.70291; secondary pages can use earlier builds. Cooking/First Aid tables and camp records supplement the complete six-catalogue dataset. The addon also reads recipes from the player's client.

## Wowhead and client evidence

[Wowhead Forever First Aid overview](https://www.wowhead.com/forever/guide/professions/first-aid/overview) was checked for Forever changes. Recipe and quest detail panes link to their Wowhead Forever item/spell/quest records. The supplied guide's acquisition notes identify vendors, drops and quest sources where available; many new beta recipes have no confirmed source. A record in client data is not proof that the recipe is obtainable in the current beta.

Classic rank, specialization, gathering-zone and artisan quest notes are identified as Classic planning references. They must not be interpreted as confirmed Forever beta availability. Optional QuestieDB records come from the user's installed database and carry their own eligibility caveats.

Modern API signatures were checked against the [Forever branch of Blizzard UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated), particularly TradeSkillUI, TradeSkillUITypes, SkillInfo and AuctionHouse. The runtime uses capability checks and a legacy profession adapter as fallback.

## Supplied addons

BetterFishing 63 by Yuyuli, NodeSight 1.3.3 by Krelock, and Camping Kit 1.4 by Doug Mansell were supplied in this workspace. See [third-party notices](../THIRD_PARTY.md) and the [companion manifest](companion-manifest.json). Camping Kit's factual object/spell IDs informed the radial menu. ProfPaden implements its own menu with game textures; it does not load Camping Kit or copy its artwork.

Camp proximity follows the player aura [Campfire Nearby, spell 1283391](https://www.wowhead.com/forever/spell=1283391/campfire-nearby), verified against Wowhead and the supplied Camping Kit aura reader. It does not infer distance from coordinates.

## Expanded offline audit — 16 October 2026

The update captures the twelve Wowhead Forever profession spell lists, partitioned by profession rather than the capped combined search; nine recipe-item categories; profession quest categories; the [Camping 101 name search](https://www.wowhead.com/forever/quests?filter=na=Camping+101); and [crafting writs](https://www.wowhead.com/forever/quests/eastern-kingdoms/crafting). Examples: [Cooking spells](https://www.wowhead.com/forever/spells/secondary-skills/cooking), [First Aid spells](https://www.wowhead.com/forever/spells/secondary-skills/first-aid), [Cooking recipe items](https://www.wowhead.com/forever/items/recipes/cooking), and [Engineering quests](https://www.wowhead.com/forever/quests/professions/engineering). Individual records are linked in the addon. Only structured factual records/objectives are imported; user comments are not used as authoritative acquisition evidence.

[Mining routes](https://classicwowforever.com/professions/mining/leveling/) and [Herbalism routes](https://classicwowforever.com/professions/herbalism/leveling/) supply the 41 circuits and zone-map images. Map art belongs to Blizzard; source route coordinates are adapted under Classic WoW Forever's CC BY 4.0 attribution. Images were converted to 512×512 RGB TGA for the addon and displayed at the zone-map aspect ratio. Gold path overlays are drawn separately. They are Classic reference routes, not verified Forever node positions. Fishing/Skinning maps are area references without invented path data.

The installed QuestieDB metadata supplies additional Classic NPC coordinates and prerequisite/breadcrumb IDs. Those factual fields are marked as Classic references, not current beta verification. No QuestieDB source code is copied. The public list data takes precedence for modern quest names/levels/factions and published starter/turn-in locations. Guide-vs-Wowhead training conflicts remain visible; live client requirements always govern crafting.

See [coverage audit](COVERAGE.md) and [machine-readable exceptions](coverage.json) for exact counts, unlinked recipe items, failed detail requests and unresolved acquisition sources. These establish completeness against the retrieved inventories, not every item or quest that may exist in the changing beta.


## 16 October compact data update

The supplied [Commerce Authority guide](https://www.wowhead.com/forever/guide/azeroth-commerce-authority-reputation-professions) was retrieved on 16 October. Its factual NPC/item relationships, skill requirements, Merchant's Favor costs and coordinates are imported. Numeric /way zones are translated through the supplied QuestieDB Forever map mapping. Recipe item rarity and new/updated flags use the saved Wowhead structured inventories; live item data fills additional type/quality fields. Quest type/rarity facets refer to reward items. NPC roles, faction restrictions, positions and rank titles use supplied QuestieDB Forever factual records; no QuestieDB code is bundled.

The user-facing table presents source facts without repeated beta uncertainty prose. A dash represents an absent value. Skill-up probabilities and extra attempts stay explicitly estimated. [Import counts](detail-data-results.json) and [implementation notes](DETAILS.md) describe scope.

## 0.4.1 location audit

The source importer preserves dungeon/zone-only records, uses the supplied Classic dungeon entrance table, and retains Wowhead NPC names/zones absent from QuestieDB. See [878-NPC audit](npc-location-audit.json) and [exceptions and provenance](CLIENT_FIXES.md). No exact coordinate is generated from a zone-only record.


## Reagent supplier import (0.9.0)

`Data/Suppliers.lua` imports factual vendor relationships and NPC spawn locations from the installed QuestieDB Forever database. The importer is `tools/build_suppliers.py`; counts and missing coordinates are in [supplier-coverage.json](supplier-coverage.json). It checks 461 reagent IDs, finds vendor relationships for 85, and imports 501 supplier NPCs. No stock quantity, unlimited availability or exact gold price is inferred from a vendor relationship. Existing curated NPC coordinates take precedence. Visited merchant and trainer records supply live prices, eligibility and exact recipe offerings.
