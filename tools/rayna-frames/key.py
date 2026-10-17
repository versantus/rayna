"""Key magenta out of Higgsfield frames and fit them to the existing Rayna framing and colour.
usage: key.py <target-frame.png> <out-dir> <size> <first-input> [more inputs...]
Scale, offset and colour transfer come from the first input, so the whole clip shares one transform.
Set FIT_FROM=<image> to take them from that image instead (e.g. the reference an edit was made from,
when the new pose raises the wings and would throw off the top-of-head match).
Set KEY=auto when the background is flat in each frame but changes colour during the clip."""
import sys, os
import numpy as np
from PIL import Image

def key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g                       # magenta-ness: bg ~255, teal body < 0, cream rim ~0
    alpha = 1 - np.clip((m - 35) / (120 - 35), 0, 1)
    spill = np.clip(m, 0, None)                    # pull red/blue back toward green where magenta bled in
    rgb = np.dstack([np.clip(r - spill, 0, 255), g, np.clip(b - spill * 0.5, 0, 255)])
    return rgb, alpha

def key_auto(path):
    """For clips whose flat background drifts in colour: take each frame's background from its border
    (Rayna only ever covers a small part of it), key by distance from that colour, and un-mix the edges."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    border = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
    bg = np.median(border, 0)
    d = np.linalg.norm(a - bg, axis=2)
    alpha = np.clip((d - 45) / (110 - 45), 0, 1)
    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.clip((a - (1 - alpha[..., None]) * bg) / safe, 0, 255)
    return rgb, alpha

if os.environ.get("KEY") == "auto":
    key = key_auto

def bbox(alpha, thr=0.15):
    ys, xs = np.where(alpha > thr)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1

def stats(rgb, alpha):
    w = alpha > 0.9
    px = rgb[w]
    return px.mean(0), px.std(0)

def main():
    target, outdir, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
    inputs = sys.argv[4:]
    MIX = float(os.environ.get("MIX", "0.6"))   # how far to pull colour toward the target (1 = full transfer)
    os.makedirs(outdir, exist_ok=True)
    t = np.asarray(Image.open(target).convert("RGBA")).astype(np.float32)
    t_rgb, t_a = t[..., :3], t[..., 3] / 255
    tb = [v * size / t.shape[1] for v in bbox(t_a)]
    t_mean, t_std = stats(t_rgb, t_a)

    rgb0, a0 = key(inputs[0])
    fit_rgb, fit_a = key(os.environ["FIT_FROM"]) if os.environ.get("FIT_FROM") else (rgb0, a0)
    fb = bbox(fit_a)
    s = (tb[2] - tb[0]) / (fb[2] - fb[0])                   # match wing span
    dx = (tb[0] + tb[2]) / 2 - (fb[0] + fb[2]) / 2 * s      # match centre line
    dy = tb[1] - fb[1] * s                                  # match top of head
    f_mean, f_std = stats(fit_rgb, fit_a)
    gain = t_std / f_std
    print("scale", round(s, 4), "offset", round(dx, 1), round(dy, 1), "gain", gain.round(3))

    for i, p in enumerate(inputs, 1):
        rgb, al = (rgb0, a0) if i == 1 else key(p)
        rgb = np.clip(rgb + MIX * ((rgb - f_mean) * gain + t_mean - rgb), 0, 255)
        im = Image.fromarray(np.dstack([rgb, al * 255]).astype(np.uint8), "RGBA")
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(im, (round(dx), round(dy)), im)
        canvas.save(os.path.join(outdir, f"{i:03d}.png"), optimize=True)

if __name__ == "__main__":
    main()
