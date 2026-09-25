# app_crispydoom

[Crispy Doom](https://github.com/fabiangreffrath/crispy-doom) packaged as three
[AutoBleem](https://github.com/autobleem2/autobleem) Apps for the PlayStation Classic, the Raspberry Pi, the
AutoBleem PC stick and Windows:

- **Doom (Shareware)** - id Software's first episode, `DOOM1.WAD`;
- **Freedoom: Phase 1** and **Freedoom: Phase 2** - [Freedoom](https://freedoom.github.io), a complete free
  game for the Doom engine.

Install them from the AutoBleem Store. The upstream sources are pinned submodules; this repository holds only
the build (`ci/build.sh`, run in the [autobleem-build](https://github.com/autobleem2/autobleem-build) image),
one patch (the D-pad moves in gamepad mode), the default settings and each App's files.

```
git clone --recurse-submodules https://github.com/autobleem2/app_crispydoom
ci/build.sh all    # inside ghcr.io/autobleem2/autobleem-build
```

Controls (PlayStation Classic pad): D-pad move and turn, Cross fire, Circle use, Square run, Triangle jump,
L1/R1 strafe, L2/R2 weapons, Start menu, Select automap. Press Reset on the console or hold Start + Select to
leave.

Licence: the build, patch and tools GPL-3.0-or-later, Crispy Doom GPL-2.0-or-later, SDL_net zlib; DOOM1.WAD
is id Software's shareware, Freedoom is BSD (see `LICENSE`).
