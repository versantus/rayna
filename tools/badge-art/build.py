"""Re-render the over-achiever badge imagesets.

Needs Python packages skia-python and pillow, plus the Nunito variable font
(see FONT in draw.py, or set RAYNA_FONT).

The band3 still used as the composite background lives at
Sources/RaynaCore/Resources/RaynaFrames/stills/band3.png.

Writes tools/badge-art/out/<name>.imageset and a contact sheet next to it.
Copy the imagesets into both app catalogs when the render should ship:

  iOS/Rayna/Assets.xcassets
  iOS/RaynaMac/Assets.xcassets

This script does not overwrite those catalogs.
"""
import json
import shutil
from pathlib import Path

from new import *
from trim import TRIM, keep_main
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BG = ROOT / "Sources/RaynaCore/Resources/RaynaFrames/stills/band3.png"
out = HERE / "out"

shutil.rmtree(out, ignore_errors=True)
out.mkdir(parents=True)


def imageset(name, fn, bg):
    d = out / f"{name}.imageset"
    d.mkdir()
    png = d / f"{name}.png"
    render(fn, bg=str(bg) if bg else None, out=str(png))
    im = Image.open(png).convert("RGBA")
    im.save(png, optimize=True)
    if name in TRIM:
        keep_main(png)
    (d / "Contents.json").write_text(json.dumps(
        {"images": [{"filename": f"{name}.png", "idiom": "universal"}],
         "info": {"author": "xcode", "version": 1}},
        separators=(",", ":"),
    ))


for k, title, when, f in NEW:
    imageset(f"badge-{k}", f, BG)
    imageset(f"badge-{k}-overlay", f, None)

fb = ImageFont.truetype(FONT, 22)
fb.set_variation_by_axes([800])
fs = ImageFont.truetype(FONT, 16)
fs.set_variation_by_axes([600])
fh = ImageFont.truetype(FONT, 30)
fh.set_variation_by_axes([900])
cell, pad, cols = 280, 20, 4
items = [(k, t, w, out / f"badge-{k}.imageset" / f"badge-{k}.png") for k, t, w, _ in NEW]
rows = [items[:4], items[4:]]
H = pad + 50 + len(rows) * (cell + 70) + pad
W = pad * 2 + cols * cell + (cols - 1) * pad
sheet = Image.new("RGBA", (W, H), (246, 248, 251, 255))
dr = ImageDraw.Draw(sheet)
y = pad
dr.text((pad, y + 8), "Over-achiever badges", font=fh, fill=(20, 40, 70))
y += 50
for row in rows:
    for i, (k, t, w, p) in enumerate(row):
        x = pad + i * (cell + pad)
        dr.rounded_rectangle([x, y, x + cell, y + cell + 60], radius=18, fill=(232, 238, 245))
        im = Image.open(p).convert("RGBA").resize((cell - 20, cell - 20), Image.LANCZOS)
        sheet.alpha_composite(im, (x + 10, y + 5))
        dr.text((x + cell / 2, y + cell - 2), t, font=fb, fill=(20, 40, 70), anchor="mt")
        dr.text((x + cell / 2, y + cell + 26), f"{k} · {w}", font=fs, fill=(90, 105, 125), anchor="mt")
    y += cell + 70
sheet.convert("RGB").save(out / "contact-sheet.png")
print(f"wrote {out}")
