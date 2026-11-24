# Compact sleeping-bag countdown

ProfPaden 0.20.42-rc1, Forever Interface 16001. November 24, 2026.

Approved design: one 320 x 64 HUD bar, brass trim, sleeping-bag icon, three stack markers, next-stack countdown and a smaller full-stack estimate. The HUD is click-through except during its 15-second move preview. There is no new main window or automatic popup.

## Behavior

- Starts from the player **Resting** aura (1331671), not the item placement, campfire, inns, generic rested-XP flag, or the similarly named Legacy talent.
- Reads **Well-Rested** (429959) applications for the three stack markers. Countdown starts at an estimated 60 seconds per stack and resynchronizes when the actual count changes. It never manufactures a stack because time passed; at zero it waits for confirmation.
- Existing three stacks: show a refresh countdown and wait for an observed buff expiration extension before reporting completion.
- Losing the resting aura stops the timer. The interrupted state fades after four seconds. Reentry starts a fresh estimated minute, preserving only actual stacks.
- Completion is green for three seconds, then fades over one second. It does not repeatedly reopen while resting at three stacks.
- Combat hides the HUD and clears timing; no aura query runs in combat. Unreadable/restricted aura data is omitted. Returning from combat, logging in, or reloading while already resting starts a new estimate because the exact partial-minute phase is unknown.
- No timer phase or guessed buff progress is saved across sessions. Only per-character enable/disable and HUD position are saved in the existing ProfPaden character data.

## Controls

Settings > AddOns > **ProfPaden - Sleeping Bag**: enabled checkbox, **Preview / move**, **Reset position**.

- `/ppsleep preview`: show a 15-second preview; drag it to move.
- `/ppsleep on` / `/ppsleep off`: enable or disable immediately.
- `/ppsleep reset`: reset only this HUD's position and preview it.

The normal display does not capture mouse or controller focus. Configuration uses native checkbox/button templates and the player's existing cursor controls; no bindings are overwritten. Hardware controller navigation is not certified. Strings are centralized with complete English fallback; other locales use English for this new module, and aura detection is language-independent.

## Source evidence

- [Blizzard November 17 hotfix](https://worldofwarcraft.blizzard.com/en-us/news/24315281/wow-forever-hotfixes-november-17-2026): adds a Resting aura indicating sleeping-bag proximity.
- [Resting data](https://www.wowhead.com/forever/spell=1331671/resting) and [Well-Rested data](https://www.wowhead.com/forever/spell=429959/well-rested): IDs are separate from the Legacy talent 1225478.
- [Sleeping-bag item](https://www.wowhead.com/forever/item=211527/cozy-sleeping-bag): a minimum minute of resting, up to three stacks. Countdown is an estimate until actual aura changes confirm it.
- Bundled Forever API ledger, 1.60.1.70938, `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`: `C_UnitAuras.GetPlayerAuraBySpellID` has `RequiresNonSecretAura` and `SecretWhenUnitAuraRestricted`; `UNIT_AURA` can be restricted. The module checks access before comparing/indexing values or formatting counts. `pcall` only contains API errors and is not used to bypass secret restrictions.
- Settings canvas registration signatures were checked against the plugin's source-pinned Forever Settings reference. Client presence and simulator operation are separate evidence.

## Verification

`python tools/verify_sleep_timer.py`: **15/15** deterministic Lua 5.1 cases, covering actual aura-driven stacks, waiting at zero, interruptions, buff refresh, combat, secret/unavailable data, malformed preferences/counts, preview, dragging/reset, saved false, event filtering, reload estimates, and single/late Settings registration. [Results](tests.json).

The previous crafting math suite also passes **16/16** with this module present in the package. Release packaging guard suite: **9/9**. The 0.20.41 guide fixes and PadenCrates companion are retained.

UIForever uses older client 1.60.1.70450. Controlled aura fixtures exercise the production timer code because this simulator predates the November 17 aura addition. Screenshots show the implemented UI, not live sleeping-bag timing. Live in-game acceptance remains outstanding.

Final candidate verification: the reimported 0.20.42-rc1 package loaded with **0 errors and 0 missing APIs**. Native Settings clicks verified preview, real mouse dragging, reset to the default position, and disabling the HUD. Preview renders above Settings so it can be moved immediately. Simulator preferences and aura readers were restored after testing.

- [Active countdown](timer-active.jpg), [three-stack completion](timer-complete.jpg), [native settings](timer-settings.jpg), and [final move preview](timer-move-preview.jpg) show the implemented UI at 1280 x 720.
- **84 Lua files** compile; timer, crafting math, and skill-chance integration checks pass **39/39**, plus **9/9** packaging guards.
- All **5,358 installed ProfPaden files** match the reviewed manifest. [Installation evidence](installation.json) and [static verification](static.json).
- The release contains **5,370 runtime files** across ProfPaden and the unchanged PadenCrates companion. GitHub Actions builds the WowUp `-forever.zip`; publication verification separately downloads and checks the public asset against every reviewed manifest entry.
