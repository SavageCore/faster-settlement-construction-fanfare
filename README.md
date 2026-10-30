# Faster Settlement Construction Fanfare

Shortens the **settlement construction complete** fanfare in No Man's Sky. When a settlement building finishes upgrading, the game plays a 10 second reveal cutscene with a CONSTRUCTION COMPLETE banner and fireworks. This cuts that cutscene to 1 second. Built natively on Linux with the [AMUMSS Linux port](https://github.com/SavageCore/AMUMSS/tree/feat/linux-support).

## Usage

Install it and settlement upgrades still play the fanfare, just for 1 second instead of 10.

| Value | Vanilla | Modded |
| --- | --- | --- |
| `BuildingRevealCutsceneLength` | 10.0 | 1.0 |

It does not touch build timers, judgement timers, production rates, or anything else in the settlement globals. Pair it with a timer mod if you also want faster builds.

## Compatibility

Modifies `GLOBALS/GCSETTLEMENTGLOBALS.GLOBAL.MBIN` only. It may conflict with any other mod editing that file, including full settlement overhauls such as Accelerated Settlements and timer mods. The generated patch is minimal: one value and nothing else, so load-order conflicts with unrelated globals mods should not happen, but two mods writing the same settlement globals will conflict outright and the pak the game loads last wins.

Same-file mods do not merge: the game loads one `GCSETTLEMENTGLOBALS.EXML` and discards the other. The timer mod `gSettlement Timers Instant` sorts after this mod, so with both installed the timer file wins and the fanfare stays at 10 seconds. The fix is a one-line local merge: add `<Property name="BuildingRevealCutsceneLength" value="1.000000" />` to the timer mod's `GLOBALS/GCSETTLEMENTGLOBALS.EXML` and redeploy. Re-apply that line after every timer mod update, since updates overwrite it.

## Build (on Linux)

Requires a full AMUMSS install at `~/AMUMSS` (override with `AMUMSS_HOME=...`) with `MBINCompiler-linux` fetched (`linux/scripts/fetch_mbincompiler.sh` in the AMUMSS repo).

```sh
make release      # clean rebuild + verify + pack dist/ zip (default)
make verify       # sanity-check the built outputs
make clean        # remove build/ and dist/
make assets       # regenerate Nexus page images (needs assets/src/gallery-fanfare.jpg)
```

`make build` stages the rendered script into `$(AMUMSS_HOME)/ModScript` (existing content moved aside and restored), runs one `buildmod.sh --run-pipeline`, and collects the output.

`make verify` is the load-bearing step. It asserts that the EXML was produced by *this* run, that `BuildingRevealCutsceneLength` carries the expected value, that the patch touches nothing else, and that there are no marker tags.

## Release

`make release` creates `dist/Faster Settlement Construction Fanfare.zip`. It is a plain zip: import it into [Amethyst](https://github.com/ChrisDKN/Amethyst-Mod-Manager)/[Vortex](https://github.com/Nexus-Mods/Vortex) or upload it to Nexus. For a manual install, copy the mod folder into `GAMEDATA/MODS`.

The zip is named after the mod and carries no version, because a mod manager names the installed mod after the archive file name and shows the version in a column of its own. The version travels as the version of the Nexus release instead.

## Game updates / versioning

The mod version is `VERSION` in the `Makefile`. The game version the script targets is `GameVersion` in `src/fanfare.lua.in`.

When No Man's Sky updates:

1. Fetch the new matching compiler from the AMUMSS repo (use `MBINCOMPILER_TAG=vX` to pin): `AMUMSS_HOME=~/AMUMSS linux/scripts/fetch_mbincompiler.sh`. If the AMUMSS core itself changed, re-run the pipeline once so the linux patches re-verify (`apply_linux_patches.sh --verify`).
2. Re-derive the base in `src/patches.tsv` (see below).
3. Bump `GameVersion` in `src/fanfare.lua.in` and `VERSION` in the `Makefile`.
4. `make release`, install, test.

### Re-deriving the base

The base value is game data, not a constant this mod owns. To re-derive it:

```sh
GLOBALS=~/.steam/steam/steamapps/common/"No Man's Sky"/GAMEDATA/PCBANKS/NMSARC.globals.pak
hgpaktool -O /tmp/probe -f "*GCSETTLEMENTGLOBALS*" "$GLOBALS"
cd /tmp/probe
~/AMUMSS/MODBUILDER/MBINCompiler-linux -q -y -f -iMBIN gcsettlementglobals.mbin
grep -n "BuildingRevealCutsceneLength" gcsettlementglobals.MXML
```

Expected as of Forsaken: `BuildingRevealCutsceneLength` is `10.000000`. If the vanilla value changes, update the `BASE` column in `src/patches.tsv` to keep the docs honest.
