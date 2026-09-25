#!/usr/bin/env python3
"""Write the AutoBleem Store's descriptor for one platform's package of one of the three Apps (autobleem-repo
CLAUDE.md, "The AutoBleem Store's catalog"), next to the package and its picture, ready for
`repo_publish.sh store <platform> ...`:

    tools/store_item.py dist/freedoom1-psc-7.1-1.zip   -> dist/store/psc/freedoom1.item.json
                                                           + freedoom1.png + the zip

The id is the same on every platform (app/doom, app/freedoom1, app/freedoom2), so an installed App is
updated in place. Only the standard library is needed.
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

CRISPY = "Crispy Doom by Fabian Greffrath and contributors"
ITEMS = {
    "doom": {
        "title": "Doom (Shareware)",
        "author": CRISPY + "; Doom by id Software",
        "licence": "GPL-2.0-or-later (DOOM1.WAD: id Software's shareware, freely distributable unmodified)",
        "description": "The first episode of Doom (1993), nine levels, through Crispy Doom - a faithful "
                       "source port. Put your own DOOM.WAD next to it to play the full game.",
    },
    "freedoom1": {
        "title": "Freedoom: Phase 1",
        "author": CRISPY + "; Freedoom by the Freedoom project",
        "licence": "GPL-2.0-or-later (freedoom1.wad: BSD)",
        "description": "A complete free game for the Doom engine - four episodes of new levels, monsters and "
                       "music in the style of the original Doom - through Crispy Doom.",
    },
    "freedoom2": {
        "title": "Freedoom: Phase 2",
        "author": CRISPY + "; Freedoom by the Freedoom project",
        "licence": "GPL-2.0-or-later (freedoom2.wad: BSD)",
        "description": "A complete free game for the Doom engine - one 32-level campaign in the style of "
                       "Doom II - through Crispy Doom.",
    },
}


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    package = argv[1]
    m = re.match(r"^(?P<app>doom|freedoom1|freedoom2)-(?P<key>[a-z0-9]+)-(?P<version>.+)\.zip$",
                 os.path.basename(package))
    if not m:
        print("not a <doom|freedoom1|freedoom2>-<key>-<version>.zip: %s" % package)
        return 1
    app, key, version = m.group("app"), m.group("key"), m.group("version")
    out = os.path.join(os.path.dirname(package), "store", key)
    os.makedirs(out, exist_ok=True)
    shutil.copy(package, out)
    shutil.copy(os.path.join(ROOT, "resources", app, "icon.png"), os.path.join(out, app + ".png"))
    item = dict(ITEMS[app])
    item = {
        "id": "app/" + app,
        "kind": "app",
        "title": item["title"],
        "version": version,
        "author": item["author"],
        "licence": item["licence"],
        "description": item["description"],
        "image": app + ".png",
        "files": [{"name": os.path.basename(package)}],
    }
    with open(os.path.join(out, app + ".item.json"), "w", encoding="utf-8") as f:
        json.dump(item, f, indent=2)
        f.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
