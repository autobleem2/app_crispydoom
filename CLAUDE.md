# app_crispydoom - developer context

**Crispy Doom** 7.1 packaged as **three AutoBleem Apps** from one build, one zip per App per platform
(`dist/<app>-<key>-<version>.zip`) in the multi-platform App format (the launcher's `docs/app-format-plan.md`):

| App | folder | Store id | the game |
|---|---|---|---|
| Doom (Shareware) | `Apps/doom/` | `app/doom` | `DOOM1.WAD`, id's shareware episode (v1.9, SHA-1 5b2e249b...) |
| Freedoom: Phase 1 | `Apps/freedoom1/` | `app/freedoom1` | `freedoom1.wad`, Freedoom 0.13.0 (BSD) |
| Freedoom: Phase 2 | `Apps/freedoom2/` | `app/freedoom2` | `freedoom2.wad`, Freedoom 0.13.0 (BSD) |

Started 2026-09-25, the third third-party App port (autobleem-main `docs/decisions.md`, "Third-party App
ports" - the rules; `app_opentyrian`'s CLAUDE.md is the template). `app/doom` replaces the RetroBoot 1.2
crispy-doom build in the psc catalog. Crispy Doom only - no Heretic/Hexen/Strife (the owner's call).

## The owner's decisions for this port (2026-09-25)

- **Patches over pinned submodules**: `upstream/crispy-doom` at `crispy-doom-7.1` (2025-09-23; it needs SDL
  2.0.14, exactly the console's), `upstream/SDL_net` at `release-2.4.0`.
- **SDL2_net is bundled** (`lib/<key>/`, netgames work); SDL2 and SDL2_mixer are the launcher's or the
  system's. PNG screenshots, libsamplerate and FluidSynth are switched off so nothing else needs shipping.
- **The 2020 PSC layout**, in Crispy's gamepad mode (`use_gamepad 1`, an empty `joystick_guid` = the first
  pad - the virtual X360 pad on Linux, an XInput pad on Windows): Cross fire, Circle use, Triangle jump
  (Crispness -> "Allow jumping" is off by default, as in 2020), Square run, L1/R1 strafe, L2/R2 previous/next
  weapon (the triggers are Crispy's virtual buttons 15/16 -> `GAMEPAD_BUTTON_TRIGGERLEFT/RIGHT` = 21/22 with
  SDL >= 2.0.14 headers, which every target has), Start menu, Select automap; left stick/D-pad move and turn,
  a right stick strafes. A modern twin-stick layout was asked for first and dropped: the console's own pad
  has no sticks and could not turn.
- **A way out**: Reset (console) and the Start+Select hold (Linux) come from abpadd; on Windows, Start ->
  Quit Game - each readme says so.
- **Three Store items**: Doom (shareware) and both Freedoom phases, each its own App.

## Layout

| path | what |
|---|---|
| `upstream/crispy-doom`, `upstream/SDL_net` | the pinned upstream sources (submodules; `quickcheck`, crispy's own test submodule, is not needed) |
| `patches/crispy-doom/0001-dpad-is-the-left-stick.patch` | in gamepad mode Crispy moves only on the stick axes and uses the D-pad for the menus; the D-pad now stands in for a centred left stick. On Linux the virtual pad already does this (`movement=both`); on Windows an XInput pad's D-pad would do nothing in the game without it. |
| `resources/common/default.cfg`, `crispy-doom.cfg` | the defaults every App ships - only the keys we set; Crispy fills in the rest and writes both files back in full on a clean exit. `default.cfg` holds the vanilla keys (`use_joystick`, `joyb_fire/use/speed/strafe/jump`, `screenblocks`), `crispy-doom.cfg` the extended ones (`use_gamepad`, `joystick_*`, `joyb_strafeleft/...`, video) - a key in the wrong file is ignored. |
| `resources/<app>/` | each App's `app.ini` (`Exec=bin/{key}/crispy-doom`, `Args=-iwad <wad> -config default.cfg -extraconfig crispy-doom.cfg -savedir savegames`, `Lib=lib/{key}`, `VirtualPad=true`), `readme.txt`, `icon.png` |
| `VERSION` | the package version for all three (`7.1-1`) |
| `ci/build.sh` | `native|psc|rpi|rpi64|pcusb|win|all`: the data from our mirror (sha256-pinned), SDL2_net by hand, Crispy's CMake with every SDL path given as a cache variable (`CMAKE_FIND_PACKAGE_PREFER_CONFIG=OFF`, so its own find modules make the targets and nothing is searched), `CMAKE_SKIP_RPATH` (CMake would otherwise embed the build machine's library paths - check_psc_binary.sh caught it), `--target crispy-doom` only |
| `tools/make_icons.py` | draws each icon from its IWAD's `TITLEPIC` (PLAYPAL colours, stretched to 4:3, cropped to 256x219) - nothing of unknown origin |
| `tools/store_item.py` | a package -> `dist/store/<key>/` with `<app>.item.json` and `<app>.png`, for autobleem-repo's `repo_publish.sh store <key> dist/store/<key>/*` |
| `tools/check_psc_binary.sh`, `tools/check_needed.sh` | as in app_opentyrian (`shlwapi.dll` is a system DLL - Crispy imports it on Windows) |

## Things to know

- **The data**: `mirror/doom/doom1.wad` and `mirror/freedoom/freedoom-0.13.0.zip` on the site (the latter's
  sha256 is the one in Freedoom's signed CHECKSUM file). `build_data/` caches them.
- **Settings and saves** live in the App folder (`-config`, `-extraconfig`, `-savedir`). A Store update lays
  the package's `default.cfg`/`crispy-doom.cfg` over the user's - the settings reset, the saves in
  `savegames/` stay. The readmes say so.
- **Full game**: the Doom App plays a `DOOM.WAD` put next to it once `app.ini`'s `-iwad` names it.
- **Windows**: run on the dev PC on 2026-09-25 (Freedoom: Phase 1, only the Windows product's official SDL
  DLLs and the App's `SDL2_net.dll` on PATH): "Freedoom: Phase 1 - Crispy Doom 7.1.0" comes up.
- **Build on the server**: sync with MSYS2's rsync (excluding `/build_*`, `/dist`), then
  `docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all`.
- **Not yet run**: on a console, a Pi or the PC stick (the tester checklist).
