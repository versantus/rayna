"""Cut a Higgsfield sheet of separate objects on magenta into one transparent PNG per object.

usage: sprites.py <sheet.png> <out-dir> <name> [<name> ...]
Objects are found as blobs (nearby parts such as a fish's fins or kelp leaves merge into one), ordered
top-to-bottom then left-to-right, and saved as <out-dir>/<name>.png, trimmed, at most MAX px on a side.
"""
import os, sys
import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from key import key  # noqa: E402  (magenta key with spill removal)

MAX = int(os.environ.get("MAX", "384"))   # tall kelp is drawn big, so cut it with MAX=768

def main():
    sheet, outdir, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    os.makedirs(outdir, exist_ok=True)
    rgb, alpha = key(sheet)
    solid = (alpha > 0.1).astype(np.uint8)
    merged = cv2.dilate(solid, np.ones((25, 25), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(merged, connectivity=8)
    blobs = [i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] > 4000]
    if len(blobs) != len(names):
        sys.exit(f"found {len(blobs)} objects, expected {len(names)}")
    h = alpha.shape[0]
    row = lambda i: round((stats[i, 1] + stats[i, 3] / 2) / (h / 4))   # quarter-height rows
    blobs.sort(key=lambda i: (row(i), stats[i, 0]))
    for name, i in zip(names, blobs):
        x, y, w, hh = stats[i, :4]
        mask = (labels[y:y + hh, x:x + w] == i)
        a = alpha[y:y + hh, x:x + w] * mask
        px = np.dstack([rgb[y:y + hh, x:x + w], a * 255]).astype(np.uint8)
        im = Image.fromarray(px, "RGBA")
        im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())
        im.thumbnail((MAX, MAX), Image.LANCZOS)
        im.save(os.path.join(outdir, f"{name}.png"), optimize=True)
        print(name, im.size)

if __name__ == "__main__":
    main()
