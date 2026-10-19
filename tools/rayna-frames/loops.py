"""Turn a Higgsfield swim-cycle video into a creature's animation frames for the scenes.

usage: loops.py <video.mp4> <scene-dir> <loop-name> magenta|black [frames=40] [max=220]
Writes <scene-dir>/anim/<loop-name>/001.png … (one shared crop, so the creature doesn't jitter) and prints the
frames' width/height, which goes in SeaSceneLayout.aspect. The video starts and ends on the same pose, so its last
frame is dropped to make a seamless loop.

  magenta: key each frame against its own border colour (backgrounds sometimes drift during a video)
  black:   glowing creatures (jellyfish) on black: brightness becomes transparency, so they stay see-through
"""
import os, subprocess, sys, tempfile
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from key import key_auto  # noqa: E402


def glow_key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255
    alpha = np.clip((a.max(axis=2) - 0.10) / 0.55, 0, 1) ** 1.2
    rgb = np.clip((a - 0.04) / np.maximum(alpha[..., None], 1e-3), 0, 1) * 255
    return rgb, alpha


def main():
    video, out, name, mode = sys.argv[1:5]
    count = int(sys.argv[5]) if len(sys.argv) > 5 else 40
    biggest = int(sys.argv[6]) if len(sys.argv) > 6 else 220
    tmp = tempfile.mkdtemp()
    subprocess.run(["ffmpeg", "-v", "error", "-i", video, f"{tmp}/%04d.png"], check=True)
    files = sorted(f for f in os.listdir(tmp) if f.endswith(".png"))[:-1]       # last frame repeats the first
    pick = [files[int(i * len(files) / count)] for i in range(count)]
    keyed = [(glow_key if mode == "black" else key_auto)(f"{tmp}/{f}") for f in pick]
    union = np.zeros_like(keyed[0][1], dtype=bool)
    for _, a in keyed:
        union |= a > 0.06
    ys, xs = np.where(union)
    pad = 6
    box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, union.shape[1]), min(ys.max() + pad, union.shape[0]))
    d = os.path.join(out, "anim", name)
    os.makedirs(d, exist_ok=True)
    for old in os.listdir(d):
        os.remove(os.path.join(d, old))
    size = None
    for i, (rgb, a) in enumerate(keyed, 1):
        im = Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA").crop(box)
        im.thumbnail((biggest, biggest), Image.LANCZOS)
        size = im.size
        im.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG).save(f"{d}/{i:03d}.png", optimize=True)
    print(name, size, round(size[0] / size[1], 3))


if __name__ == "__main__":
    main()
