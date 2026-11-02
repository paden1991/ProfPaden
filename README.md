# ProfPaden

Profession leveling, recipes, materials, economics and gathering guides.

**WoW Forever · Interface 16001 · 0.20.28-rc1**

Release candidate / beta. Live-game acceptance is still required.


## WowUp release status

An installable public WowUp release is on hold while redistribution permission for the local-only dependencies is resolved. Full functionality is being preserved; no incomplete or reduced-functionality ZIP is published. The public release builder refuses to package unresolved external files.

## Installation

This is a source repository with **48 local-only dependency files omitted**. A download of this repository alone is not the complete local addon bundle. Use a matching, lawfully obtained complete `ProfPaden` folder as the dependency input:

```sh
python tools/build_local.py --local-addon "path/to/ProfPaden"
```

The script copies only manifest-listed dependency bytes, checks their SHA-256 hashes, and combines them with this source in a ZIP under `dist/`. It does not download files, modify the input, or change addon functionality. The resulting local bundle is not automatically cleared for public redistribution.

Open the addon with `/pp`.

## Verification

```sh
python tools/build_local.py --verify-only
```

This checks the published runtime bytes against the reviewed source manifest. For repositories with external files, add `--local-addon` to verify the complete build. It is a source-integrity check, not live-game certification.

## Related addons

- [ProfPadenRoutes](https://github.com/paden1991/ProfPadenRoutes)
- [ProfPadenClams](https://github.com/paden1991/ProfPadenClams)
- [CounterCast](https://github.com/paden1991/CounterCast)
- [CounterCastProbe](https://github.com/paden1991/CounterCastProbe)
- [RAID](https://github.com/paden1991/RAID)

## Ownership and provenance

Public visibility does not assign a new open-source license. Existing third-party notices and applicable data licenses remain in force. Do not assume that excluded dependencies may be redistributed. No account SavedVariables, personal settings, raw research archives, credentials, or prior packaged releases are included.

## Current interface

The current design uses charcoal panels, bronze framing, larger native text and a Leveling tab. Sources are grouped into compact summaries with native Details buttons; original rates and location records remain available.

The complete local bundle passed 69 regression suites before the source-summary refinement; seven affected suites and six new source checks then passed. Simulator mouse expand/collapse checks completed without Lua errors. These results apply to the complete local build.

See [source attribution](docs/SOURCES.md). Historical references to research captures describe the local development archive; those captures are not published here.
