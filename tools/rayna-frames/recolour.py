"""Recolour Rayna's turquoise body, leaving her eyes, blush, smile and cream rim alone.

usage: recolour.py <in.png> <out.png> <skin>
A gradient map: each skin has a shadow, mid and highlight colour, and the body's own light and dark is mapped onto
them, so her glowing caustic pattern stays clean. Works on any frame or still, so a skin keeps the same animation
and the same badge positions.
"""
import sys
import numpy as np
from PIL import Image

# shadow, mid, highlight (RGB)
SKINS = {
    "coral":    ((128, 34, 62), (244, 116, 124), (255, 232, 216)),
    "sunshine": ((156, 92, 14), (250, 192, 62), (255, 247, 206)),
    "lilac":    ((72, 42, 142), (168, 124, 232), (242, 228, 255)),
    "mint":     ((18, 104, 84), (92, 212, 164), (228, 255, 242)),
    "ocean":    ((10, 52, 134), (42, 132, 232), (212, 240, 255)),
    "midnight": ((14, 20, 62), (52, 72, 152), (192, 212, 255)),
}

def recolour(im, skin):
    lo, mid, hi = (np.array(c, np.float32) / 255 for c in SKINS[skin])
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255
    rgb, alpha = a[..., :3], a[..., 3]
    hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("HSV")).astype(np.float32) / 255
    h, s = hsv[..., 0] * 360, hsv[..., 1]
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    # Body: teal/cyan, including its pale cyan highlights. Eyes (amber), blush (pink), smile (dark) and the cream rim
    # fall outside this hue band or below this saturation, so they are left as drawn.
    body = np.clip(1 - np.abs(h - 185) / 35, 0, 1) * np.clip((s - 0.06) / 0.12, 0, 1) * np.clip((lum - 0.08) / 0.12, 0, 1)
    t = np.clip((lum - 0.12) / 0.8, 0, 1)[..., None]
    mapped = np.where(t < 0.5, lo + (mid - lo) * (t / 0.5), mid + (hi - mid) * ((t - 0.5) / 0.5))
    out = rgb + (mapped - rgb) * body[..., None]
    return Image.fromarray((np.dstack([np.clip(out, 0, 1), alpha]) * 255).astype(np.uint8), "RGBA")

if __name__ == "__main__":
    recolour(Image.open(sys.argv[1]), sys.argv[3]).save(sys.argv[2])
