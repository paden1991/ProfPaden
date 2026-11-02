local _, P = ...
-- Original route directions; skill bands adapted from Classic WoW Forever (CC BY 4.0).
-- These are route areas, not a database of guaranteed node spawns.
P.Gathering = {
    Mining={
        {1,65,"Copper circuits","Alliance: Elwynn Forest or Dun Morogh. Horde: Durotar or Mulgore.","Follow the foothills around the zone. Check cave mouths; avoid deep mines until you can fight the occupants. Carry a Mining Pick and enable Find Minerals.","Copper Vein 1"},
        {65,125,"Tin and silver","Alliance: Redridge Mountains or Ashenvale. Horde: The Barrens or Hillsbrad Foothills.","Trace rocky edges and ridges, returning along the opposite side of the valley. Silver is a bonus rather than a dependable leveling route.","Tin 65; Silver 75"},
        {125,175,"Iron ridgelines","Arathi Highlands, Desolace or Thousand Needles.","Circle the zone boundary and work inward along cliffs. Smelt your ore between circuits and compare useful bars in the recipe window.","Iron 125; Gold 155"},
        {175,245,"Mithril country","The Hinterlands or Tanaris.","Follow mountain walls and the edges of rocky basins. Check whether nearby enemies are appropriate for your character before entering caves.","Mithril 175; Truesilver 230"},
        {245,275,"Small thorium","Un'Goro Crater, Blasted Lands or Felwood.","Loop the crater wall or the zone's mountain edges. Gather small veins until rich veins become available.","Small Thorium 245"},
        {275,300,"Rich thorium","Winterspring, Eastern Plaguelands, Burning Steppes or Un'Goro Crater.","Use broad perimeter circuits. Move zones when competition is high; icons show currently detected nodes, not reserved spawns.","Rich Thorium 275"},
    },
    Herbalism={
        {1,70,"Meadows and woodland","Alliance: Elwynn Forest or Teldrassil. Horde: Durotar, Mulgore or Tirisfal Glades.","Loop open grass for Peacebloom, trees for Silverleaf, and rocks for Earthroot. Enable Find Herbs.","Peacebloom / Silverleaf 1; Earthroot 15"},
        {70,115,"Briarthorn circuit","The Barrens, Silverpine Forest, Loch Modan or Darkshore.","Follow woodland margins and return through fields. Pick Mageroyal and Briarthorn; add Bruiseweed when your skill allows.","Mageroyal 50; Briarthorn 70; Bruiseweed 100"},
        {115,170,"River and hillside","Hillsbrad Foothills, Wetlands or Stonetalon Mountains.","Work riverbanks for Liferoot and ridges for Wild Steelbloom, gathering Kingsblood and Bruiseweed between them.","Wild Steelbloom 115; Kingsblood 125; Liferoot 150"},
        {170,205,"Goldthorn uplands","Arathi Highlands or Stranglethorn Vale.","Follow hills and ruins for Goldthorn, then sweep the wooded edges for Khadgar's Whisker.","Goldthorn 170; Khadgar's Whisker 185"},
        {205,230,"Dryland herbs","Tanaris or Searing Gorge.","Sweep open ground for Firebloom and ruins for Purple Lotus. Keep a clear escape route in hostile camps.","Firebloom 205; Purple Lotus 210"},
        {230,270,"Hinterlands loop","The Hinterlands.","Circle grassy clearings for Sungrass and ruins for Purple Lotus. Ghost Mushroom requires cave trips; use outdoor alternatives if unsafe.","Sungrass 230; Ghost Mushroom 245; Golden Sansam 260"},
        {270,300,"Felwood circuit","Felwood; alternate high-level herb circuits in the Plaguelands.","Travel along both sides of the main road, turning into safe clearings. Late herbs require progressively higher skill.","Dreamfoil 270; Mountain Silversage 280; Plaguebloom 285"},
    },
    Skinning={
        {1,75,"Starter beasts","Your starting zone, then Elwynn Forest / Dun Morogh or Durotar / Mulgore.","Carry a Skinning Knife. Loot beasts completely, then skin them. Work on beasts you can kill comfortably; leather grade varies by creature.","Ruined scraps and Light Leather"},
        {75,150,"Light to medium","Westfall, Loch Modan, The Barrens, then Hillsbrad or Wetlands.","Follow quest objectives involving beasts. Clear and skin one small group at a time instead of leaving corpses behind.","Light and Medium Leather"},
        {150,225,"Heavy to thick","Stranglethorn Vale, Arathi Highlands, then Feralas or Tanaris.","Hunt beasts around your own level. At skill 100+, a typical beast's skinning requirement is five times its level; check the corpse tooltip.","Heavy and Thick Leather"},
        {225,300,"Rugged hides","Un'Goro Crater, Winterspring or high-level beasts in the Plaguelands.","Choose a compact beast circuit with manageable respawns. Keep hides and specialty scales for recipe and quest requirements.","Thick and Rugged Leather"},
    },
    Fishing={
        {1,75,"A quiet beginning","Starting-zone inland water for Smallfish; coasts for Mackerel. Undead can try Durotar for useful cooking fish.","Equip your pole. Cast, wait for the splash, then interact. Cook the catch between sessions.","Brilliant Smallfish / Slitherskin Mackerel"},
        {75,150,"Capital waters","A safe fishing spot in your capital.","Train Journeyman from 50. Buy Expert Fishing - The Bass and You from Old Man Heming in Booty Bay at 125 (Classic level requirement 20). Add a lure when fish escape.","Longjaw Mud Snapper / Bristle Whisker Catfish"},
        {150,225,"Coastal provisions","Alliance: Dustwallow Marsh, north of Theramore. Horde: Savage Coast, Stranglethorn Vale.","Inland Dustwallow yields catfish and trout; coastal water adds alchemy fish. Zone catch requirements are not verified in Forever. Safer water can still provide skill-ups.","Mithril Head Trout / Rockscale Cod / alchemy fish"},
        {225,300,"Artisan angler","Steamwheedle Port, Tanaris; alternatives in Feralas or Winterspring around 275.","Complete Nat Pagle's Artisan quest first. Use lures and retain seasonal fish. Raw Winter Squid and Summer Bass depend on season. Higher-zone catches are planning references beyond the current beta cap.","Spotted Yellowtail / seasonal fish"},
    },
}
P.MaterialHints={
    cloth="Humanoid drops: Linen in starting zones; Wool in Westfall/Barrens/Hillsbrad; Silk in Scarlet Monastery or Stranglethorn; Mageweave in Tanaris; Runecloth from high-level humanoids. Match enemies to your level.",
    leather="Skin beasts: Light in starting zones; Medium in Hillsbrad/Wetlands; Heavy in Stranglethorn; Thick in Tanaris/Feralas; Rugged in Un'Goro/Winterspring.",
    herb="Gather herbs with Herbalism. Open the Herbalism field routes for skill bands and alternative zones.",
    ore="Mine ore along mountain edges; smelt bars at a forge. Open the Mining field routes for the appropriate tier.",
    fish="Fish in suitable waters; open Fishing field routes. Catch tables and required skill can change during beta.",
    vendor="Trade suppliers sell this reagent. The displayed list price is an estimate before reputation discounts.",
}
P.QuestGuide={}
local function q(prof,id,title,skill,level,faction,where,text,nextID)
    P.QuestGuide[#P.QuestGuide+1]={profession=prof,id=id,title=title,skill=skill,level=level,faction=faction,where=where,text=text,nextID=nextID}
end
q("Cooking",96629,"Camping 101: Cooking",1,4,nil,"Your starting-area cook","Learn Cooking and your first campfire. This ID is one regional variant; other starting areas have separate quests.")
q("Cooking",nil,"Expert Cookbook",125,20,nil,"Shandrina, Ashenvale (Alliance) / Wulan, Desolace (Horde)","Buy and read the Expert Cookbook to raise the cap to 225. Check the book tooltip for current beta requirements.")
q("Cooking",6612,"I Know A Guy...",225,35,"Alliance","Daryl Riknussun, Ironforge","Optional breadcrumb to Dirge Quikcleave in Gadgetzan. Artisan content is beyond the level-30 beta.",6610)
q("Cooking",6611,"To Gadgetzan You Go!",225,35,"Horde","Zamja, Orgrimmar","Optional breadcrumb to Dirge Quikcleave in Gadgetzan.",6610)
q("Cooking",6610,"Clamlette Surprise",225,35,nil,"Dirge Quikcleave, Gadgetzan, Tanaris","Bring 12 Giant Egg, 10 Zesty Clam Meat and 20 Alterac Swiss. Rewards Artisan Cooking. Plan this after the beta level cap increases.")
q("Cooking",nil,"Restocking the Larders / Crab Season",25,1,nil,"Zephras Isle","Recipe quests for Skywall Souffle and Pincer Bites. Check your local quest log for the exact starter and prerequisites.")
q("Fishing",96050,"Camping 101: Fishing",20,1,nil,"Paxton Ganter, Iceflow Lake, Dun Morogh (regional example)","Learn the Fish Bowl in Bait and Tackle. Other starting areas have their own variants.")
q("Fishing",nil,"Expert Fishing - The Bass and You",125,20,nil,"Old Man Heming, Booty Bay","Purchase the Expert book and read it before reaching 150. The book can be traded.")
q("Fishing",6608,"You Too Good.",225,35,"Horde","Lumak, Orgrimmar","Classic optional breadcrumb to Nat Pagle; verify availability in Forever.",6607)
q("Fishing",6609,"I Got Nothin' Left!",225,35,"Alliance","Grimnur Stonebrand, Ironforge","Classic optional breadcrumb to Nat Pagle; verify availability in Forever.",6607)
q("Fishing",6607,"Nat Pagle, Angler Extreme",225,35,nil,"Nat Pagle, island southwest of Theramore, Dustwallow Marsh","Catch Feralas Ahi (Verdantis River), Sar'theris Striker (Sar'theris Strand, Desolace), Savage Coast Blue Sailfin (Stranglethorn), and Misty Reed Mahi Mahi (Swamp of Sorrows). Return for Artisan. 225 skill requirement remains a Classic reference.")
q("Fishing",1141,"The Family and the Fishing Pole",1,10,"Alliance","Gubber Blump, Auberdine, Darkshore","Optional fishing-pole reward; follow the quest's catch objective.")
q("Fishing",7815,"Snapjaws, Mon!",1,44,"Horde","Katoom the Angler, Revantusk Village, Hinterlands","Optional pole upgrade; combat quest, not an early-level fishing route.")
q("First Aid",96047,"Camping 101: First Aid",20,1,nil,"Your starting-area First Aid trainer","Learn a First Aid Kit. The linked quest is one regional variant.")
q("First Aid",nil,"Expert First Aid and manuals",125,1,nil,"Deneb Walker, Stromgarde (Alliance) / Balai Lok'Wein, Brackenwall (Horde)","Buy Under Wraps, Heavy Silk Bandage and Mageweave Bandage manuals. Read each at its required skill.")
q("First Aid",6625,"Alliance Trauma",225,35,"Alliance","Nissa Firestone, Ironforge (54.8, 58.6)","Optional breadcrumb to Doctor Gustaf VanHowzen in Theramore.",6624)
q("First Aid",6623,"Horde Trauma",225,35,"Horde","Arnok, Orgrimmar (34.0, 84.4)","Optional breadcrumb to Doctor Gregory Victor in Hammerfall.",6622)
q("First Aid",6624,"Triage",225,35,"Alliance","Doctor Gustaf VanHowzen, Theramore (67.6, 48.8)","Use the supplied bandages to save 15 patients before 6 die. Treat the most critically injured first. Rewards Artisan First Aid.")
q("First Aid",6622,"Triage",225,35,"Horde","Doctor Gregory Victor, Hammerfall (73.4, 36.8)","Use the supplied bandages to save 15 patients before 6 die. Treat the most critically injured first. Rewards Artisan First Aid.")
q("Blacksmithing",nil,"Armorsmith or Weaponsmith",200,40,nil,"Grumnus Steelshaper / Ironus Coldsteel, Ironforge; Okothos Ironrager / Borgosh Corebender, Orgrimmar","Classic specialization branches. Armorsmith follows the Mithril Order and Ornate Mithril recipes; Weaponsmith has its own delivery quest. The Forever client retains the schools; confirm live requirements before committing.")
q("Blacksmithing",nil,"Mithril Order breadcrumbs",200,40,nil,"Capital smiths -> Galvan the Ancient, Stranglethorn -> Trenton Lighthammer, Gadgetzan","Follow the live quest chain to obtain Ornate Mithril recipes for Armorsmithing. QuestieDB, if enabled, supplies individual quests and prerequisite IDs below.")
q("Engineering",nil,"Gnome Engineering",200,30,nil,"Engineering trainer -> Tinkmaster Overspark, Ironforge (A) / Oglethorpe Obnoticus, Booty Bay (H)","Classic branch: sign the pledge and complete Show Your Work. Check the live delivery list before crafting; Forever may change requirements.")
q("Engineering",nil,"Goblin Engineering",200,30,nil,"Engineering trainer -> Nixx Sprocketspring, Gadgetzan","Classic alternate branch: sign the pledge and complete Show Your Work. Choose a school deliberately; the base leveling route needs neither.")
q("Leatherworking",nil,"Tribal Leatherworking",225,40,nil,"Wild Leather quests in Feralas -> Caryssia Moonhunter (A) / Se'Jib, Stranglethorn (H)","Classic branch: finish the Wild Leather training chain, then the Tribal delivery. Keep Wildvine and quest gear until the chain is complete.")
q("Leatherworking",nil,"Elemental Leatherworking",225,40,nil,"Sarah Tanner, Searing Gorge (A) / Brumn Winterhoof, Arathi (H)","Classic alternate specialization. Bring the elemental materials requested by the live quest.")
q("Leatherworking",nil,"Dragonscale Leatherworking",225,40,nil,"Peter Galen, Azshara (A) / Thorkaf Dragoneye, Badlands (H)","Classic alternate specialization. Confirm the required scales and crafted pieces in the live quest.")
q("Enchanting",nil,"Artisan training expedition",200,35,nil,"Annora, Uldaman (Classic trainer reference)","Plan a dungeon group for the Artisan trainer. Keep your runed rods; the route notes say when each is needed. Confirm trainer access in the current Forever build.")
q("Tailoring",nil,"A finish beyond Runecloth Boots",235,35,nil,"Darnall, Moonglade -> drop-pattern sources","Buy Runecloth Boots for the vendor route to 272. Alternate finishes use Brightcloth Cloak, Runecloth Headband, Wizardweave Turban, and Runed Stygian Belt. The last pattern comes from Decoded True Believer Clippings; it is not a guaranteed trainer recipe.")
for _,name in ipairs({"Alchemy","Blacksmithing","Enchanting","Engineering","Leatherworking","Tailoring","Herbalism","Mining","Skinning"}) do
    q(name,nil,"Camping 101: "..name,20,1,nil,"Your profession trainer / starting-area quest hub","Follow the local Camping 101 breadcrumb for the profession's first camp object. Higher-tier blueprints require separate acquisition; many beta sources remain unknown.")
end
for _,name in ipairs({"Alchemy","Blacksmithing","Engineering","Leatherworking","Tailoring","Enchanting"}) do
    q(name,nil,"Merchant's Favor and trade camps",1,10,nil,"Alliance: Three Corners, Redridge. Horde: outside the Crossroads, Barrens.","Fill Waylaid Crates and turn them in at your faction's trade camp. Buy profession patterns with Merchant's Favor. Craftsman's Writs cover five crafting trades; Enchanting has no writs. Writ recipes in the guide are marked; check the actual order's quantity.")
end
function P:QuestStatus(q)
    if q.id and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(q.id) then return "Completed" end
    if q.id and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(q.id) then return "In quest log" end
    local rank=(self.skills[q.profession] or {}).rank or 0
    if UnitLevel("player")<(q.level or 1) or rank<(q.skill or 0) then return "Later" end
    return "Check starter"
end
