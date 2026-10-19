"""Keep only the main drawing in a badge overlay (drops loose confetti), so the badge fills its slot.

usage: trim.py <overlay.png> [more...]   (edits in place; build.py calls keep_main for the overlays in TRIM)
"""
import sys

import cv2
import numpy as np
from PIL import Image

# Overlays whose loose bits make the badge tiny on Rayna. The composite imagesets keep them.
TRIM = {"badge-personalBest-overlay"}


def keep_main(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im)[..., 3]
    n, labels, stats, _ = cv2.connectedComponentsWithStats((a > 16).astype(np.uint8), connectivity=8)
    if n <= 2:
        return
    main = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    x, y, w, h = stats[main, :4]
    # keep everything inside the main drawing's box (sparkles on the cup), drop what's outside it
    keep = np.zeros_like(a, dtype=bool)
    keep[y:y + h, x:x + w] = True
    px = np.asarray(im).copy()
    px[..., 3] = np.where(keep, px[..., 3], 0)
    Image.fromarray(px, "RGBA").save(path, optimize=True)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        keep_main(p)
