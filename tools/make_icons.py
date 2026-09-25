#!/usr/bin/env python3
"""Draw each App's icon.png (256x219, what the launcher's Apps set shows) from its own IWAD's title picture:

    tools/make_icons.py build_data     -> resources/doom/icon.png, resources/freedoom1/icon.png, ...

The TITLEPIC lump (a Doom picture: columns of posts, in the WAD's PLAYPAL colours) is the art the game
itself opens with - id's for the shareware Doom, Freedoom's own (BSD) for the two Freedoom games - so
the icons carry nothing the packages do not already. Needs Pillow; run after ci/build.sh has fetched the
data (build_data/doom1.wad, build_data/freedoom1.wad, build_data/freedoom2.wad).
"""
import os
import struct
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
W, H = 256, 219

APPS = {"doom": "doom1.wad", "freedoom1": "freedoom1.wad", "freedoom2": "freedoom2.wad"}


def lumps(path):
    with open(path, "rb") as f:
        data = f.read()
    _, count, offset = struct.unpack_from("<4sii", data, 0)
    out = {}
    for i in range(count):
        pos, size, name = struct.unpack_from("<ii8s", data, offset + 16 * i)
        name = name.rstrip(b"\0").decode("ascii", "replace").upper()
        out.setdefault(name, data[pos:pos + size])  # the first of a name, as the engine finds it
    return out


def picture(lump, palette):
    width, height, _, _ = struct.unpack_from("<hhhh", lump, 0)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    pixels = image.load()
    for x in range(width):
        (column,) = struct.unpack_from("<i", lump, 8 + 4 * x)
        while lump[column] != 0xFF:
            top, length = lump[column], lump[column + 1]
            for y in range(length):
                index = lump[column + 3 + y]
                if top + y < height:
                    pixels[x, top + y] = palette[index] + (255,)
            column += length + 4
    return image


def main(argv):
    data_dir = argv[1] if len(argv) > 1 else os.path.join(ROOT, "build_data")
    for app, wad in APPS.items():
        found = lumps(os.path.join(data_dir, wad))
        raw = found["PLAYPAL"][:768]
        palette = [tuple(raw[i:i + 3]) for i in range(0, 768, 3)]
        title = picture(found["TITLEPIC"], palette)
        # the picture is 320x200 on a 4:3 screen: stretch it to its displayed shape, then cover the icon
        title = title.resize((320, 240), Image.LANCZOS)
        scale = max(W / title.width, H / title.height)
        title = title.resize((round(title.width * scale), round(title.height * scale)), Image.LANCZOS)
        left, top = (title.width - W) // 2, (title.height - H) // 2
        icon = title.crop((left, top, left + W, top + H))
        out = os.path.join(ROOT, "resources", app, "icon.png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        icon.save(out)
        print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
