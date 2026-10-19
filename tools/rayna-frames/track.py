"""Track where Rayna's badge slots are in every frame, so badges can move with her.

usage: track.py <RaynaFrames dir> <out dir>
Writes <out dir>/<clip>.json and stills.json:
  {"head": [[x, y, degrees, opacity], ...], "chest": [...], "fin": [...]}
x and y are unit coordinates in the frame square, degrees are clockwise, one row per frame.

Head and chest follow the patch of her body under the slot (ECC, rigid: shift + turn) against the
resting pose, idle-happy/001. Fin sits on her right wing, FIN_ALONG of the way from her chest to the
wing tip, and turns with that line, so it rides the flap. In swim-in / swim-off, once a patch no longer
matches (she's turned side-on or left), the badges fade out and stay out.
"""
import json, math, os, sys
import cv2
import numpy as np

REST = {"head": (0.50, 0.07), "chest": (0.50, 0.44)}
FIN_ALONG = 0.65
# Template patches (unit rects x0, y0, x1, y1) in the resting pose.
PATCH = {"head": (0.34, 0.03, 0.66, 0.16), "chest": (0.38, 0.30, 0.62, 0.56)}
# The head follows the outline of the top of her disc (alpha), which doesn't change with her expression;
# the chest follows the body texture.
USE_ALPHA = {"head"}
CLIPS = {"idle-happy": "loop", "idle-thirsty": "loop", "wiggle": "loop",
         "swim-in": "backward", "swim-off": "forward", "pout-swim-off": "forward"}
MIN_CC = 0.80
FADE = 3          # frames to fade in/out
N = 256

def load(path):
    im = cv2.imread(path, cv2.IMREAD_UNCHANGED)
    if im.shape[0] != N:
        im = cv2.resize(im, (N, N), interpolation=cv2.INTER_AREA)
    a = im[..., 3].astype(np.float32) / 255
    g = cv2.cvtColor(im[..., :3], cv2.COLOR_BGR2GRAY).astype(np.float32) * a + 128 * (1 - a)
    return g, a * 255

def rect_mask(r):
    m = np.zeros((N, N), np.uint8)
    x0, y0, x1, y1 = (int(v * N) for v in r)
    m[y0:y1, x0:x1] = 255
    return m

def ecc(tpl, tmask, img, warp):
    w = warp.copy()
    try:
        cc, w = cv2.findTransformECC(tpl, img, w, cv2.MOTION_EUCLIDEAN,
                                     (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 200, 1e-5), tmask, 5)
        return cc, w
    except cv2.error:
        return 0.0, warp

def apply(w, p):
    x, y = p[0] * N, p[1] * N
    return ((w[0, 0] * x + w[0, 1] * y + w[0, 2]) / N, (w[1, 0] * x + w[1, 1] * y + w[1, 2]) / N)

def wing_tip(a):
    on = a > 0.5
    cols = np.where(on.any(0))[0]
    if not len(cols):
        return None
    xr = cols.max()
    return (xr / N, np.where(on[:, xr])[0].mean() / N)

def fin_from(chest, tip, rest_deg):
    fx = chest[0] + FIN_ALONG * (tip[0] - chest[0])
    fy = chest[1] + FIN_ALONG * (tip[1] - chest[1])
    deg = math.degrees(math.atan2(tip[1] - chest[1], tip[0] - chest[0])) - rest_deg
    return fx, fy, deg

def track_frames(frames, rest, order):
    """frames: list of (gray, alpha). Returns {slot: [[x, y, deg, ok], ...]} in frame order."""
    rg, ra = rest
    ra01 = ra / 255
    tips_rest = wing_tip(ra01)
    rest_deg = math.degrees(math.atan2(tips_rest[1] - REST["chest"][1], tips_rest[0] - REST["chest"][0]))
    idx = list(range(len(frames)))
    if order == "backward":
        idx.reverse()
    out = {s: [None] * len(frames) for s in ("head", "chest", "fin")}
    warps = {s: np.eye(2, 3, dtype=np.float32) for s in PATCH}
    lost = False
    for i in idx:
        g, a255 = frames[i]
        a = a255 / 255
        rows = {}
        for s in PATCH:
            tpl, img = (ra, a255) if s in USE_ALPHA else (rg, g)
            cc, w = ecc(tpl, rect_mask(PATCH[s]), img, warps[s]) if not lost else (0.0, warps[s])
            x, y = apply(w, REST[s])
            deg = math.degrees(math.atan2(w[1, 0], w[0, 0]))
            probe = (x, y + (0.05 if s == "head" else 0))        # head badge sits just above the disc
            on = 0 <= probe[0] < 1 and 0 <= probe[1] < 1 and a[int(probe[1] * N), int(probe[0] * N)] > 0.5
            ok = cc >= MIN_CC and on and abs(deg) < 40
            if ok:
                warps[s] = w
            rows[s] = [x, y, deg, ok]
        tip = wing_tip(a)
        ok = rows["head"][3] and rows["chest"][3] and tip is not None
        if order != "loop" and not ok:
            lost = True
        if tip is not None:
            fx, fy, fdeg = fin_from(rows["chest"][:2], tip, rest_deg)
            ok = ok and a[min(N - 1, int(fy * N)), min(N - 1, int(fx * N))] > 0.5
        else:
            fx, fy, fdeg = rows["chest"][0], rows["chest"][1], 0
        rows["fin"] = [fx, fy, fdeg, ok]
        if lost:
            for s in rows:
                rows[s][3] = False
        for s in rows:
            out[s][i] = rows[s]
    return out

def fade(rows, loop):
    """ok flags -> opacity with a short ramp; hold the last good pose while faded."""
    ok = [r[3] for r in rows]
    n = len(rows)
    op = []
    for i in range(n):
        near = [ok[(i + d) % n] if loop else ok[min(max(i + d, 0), n - 1)] for d in range(-FADE, FADE + 1)]
        op.append(round(sum(near) / len(near), 3) if ok[i] else 0.0)
    last = None
    res = []
    for r, o in zip(rows, op):
        if r[3]:
            last = r
        base = last or next((q for q in rows if q[3]), r)
        res.append([round(float(base[0]), 4), round(float(base[1]), 4), round(float(base[2]), 2), o])
    # frames before the first good one (swim-in start) take the first good pose
    return res

def main():
    root, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    rest = load(os.path.join(root, "idle-happy", "001.png"))
    for clip, order in CLIPS.items():
        d = os.path.join(root, clip)
        files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        frames = [load(os.path.join(d, f)) for f in files]
        t = track_frames(frames, rest, order)
        res = {s: fade(t[s], order == "loop") for s in t}
        json.dump(res, open(os.path.join(outdir, f"{clip}.json"), "w"), separators=(",", ":"))
        print(clip, {s: f"{sum(1 for r in res[s] if r[3] > 0)}/{len(res[s])} visible" for s in res})
    stills = sorted(f for f in os.listdir(os.path.join(root, "stills")) if f.endswith(".png"))
    frames = [load(os.path.join(root, "stills", f)) for f in stills]
    t = {}
    for f, fr in zip(stills, frames):
        one = track_frames([fr], rest, "loop")
        t[f[:-4]] = {s: fade(one[s], True)[0] for s in one}
    json.dump(t, open(os.path.join(outdir, "stills.json"), "w"), separators=(",", ":"))
    print("stills", {k: {s: v[s][3] for s in v} for k, v in t.items()})

if __name__ == "__main__":
    main()
