#!/usr/bin/env python3
"""Trace the raster brand logos (assets/logos/*.png) into true vector paths.

Run from the repo root (pure Pillow 10, no numpy / potrace):

    python3 -I tool/vectorize_logos.py              # brand/svg/*.svg + lib/brand/logo_paths.dart
    python3 -I tool/vectorize_logos.py --preview D  # also writes outline QA PNGs into D

Pipeline (per colour layer)
---------------------------
1. Layer field: a 0..1 coverage value per source pixel.  Titles: the asset's
   alpha, split into colour classes (white body / gold accents).  Medallions:
   each pixel is modelled as ``bg + a * (fg - bg)`` against the local disc
   colour (emerald: a radial profile, ivory: flat ivory) for a set of
   reference colours; the best class gives ``a`` (scaled by GAIN), as in
   tool/extract_logos.py.
2. The field is upscaled x4 (bicubic) and Gaussian-smoothed (JPEG staircase
   and keying noise go away; strokes keep their width because the iso level
   is the 50 % coverage line).
3. Marching squares (saddles resolved by the cell average) with linear
   interpolation gives sub-pixel closed contours; specks are dropped.
4. Corners (pen tips) are found from the turning angle over a short arc;
   between corners the dense polyline is thinned with Ramer-Douglas-Peucker
   and fitted with cubic Beziers (Schneider's least-squares algorithm with
   Newton re-parameterisation, split at the worst point, C1 at the splits).
5. Each layer's colour: flat, or a linear gradient fitted to the stroke
   interior (least-squares luminance direction, mean colour per band); the
   emerald discs get a radial gradient from their radial colour profile.

The view box of every logo equals its raster asset (same aspect ratio and
padding), so swapping a raster for the vector keeps the poster layout.  All
constants are below; the output is deterministic.
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGOS = os.path.join(ROOT, 'assets', 'logos')
SVG_DIR = os.path.join(ROOT, 'brand', 'svg')
DART_OUT = os.path.join(ROOT, 'lib', 'brand', 'logo_paths.dart')

SCALE = 4  # upscale factor before tracing
BLUR = 1.4  # Gaussian radius in upscaled px (0.35 source px)
ISO = 127.5  # 50 % coverage
MIN_AREA = 3.0  # source px^2; smaller closed contours are specks
RDP_TOL = 0.30  # upscaled px; dense contour thinning before fitting
FIT_TOL = 0.9  # upscaled px; max Bezier deviation from the thinned contour
CORNER_ARM = 5.0  # upscaled px; arc length on each side for the angle test
CORNER_DEG = 62.0  # turning angle above which a point is a corner
DECIMALS = 2

# ------------------------------------------------------------- geometry ---


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def mul(a, s):
    return (a[0] * s, a[1] * s)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def norm(a):
    d = math.hypot(a[0], a[1])
    return (a[0] / d, a[1] / d) if d > 1e-12 else (0.0, 0.0)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def polygon_area(pts):
    s = 0.0
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        s += x0 * y1 - x1 * y0
    return s / 2.0


# ------------------------------------------------------ marching squares ---

# corners: TL=8 TR=4 BR=2 BL=1; edges: T R B L
_CORNER_POS = {8: (0.0, 0.0), 4: (1.0, 0.0), 2: (1.0, 1.0), 1: (0.0, 1.0)}
_EDGE_MID = {'T': (0.5, 0.0), 'R': (1.0, 0.5), 'B': (0.5, 1.0),
             'L': (0.0, 0.5)}
_SEGS = {
    1: [('L', 'B')], 2: [('B', 'R')], 3: [('L', 'R')], 4: [('T', 'R')],
    6: [('T', 'B')], 7: [('T', 'L')], 8: [('T', 'L')], 9: [('T', 'B')],
    11: [('T', 'R')], 12: [('L', 'R')], 13: [('B', 'R')], 14: [('L', 'B')],
    # saddles: (centre inside, centre outside)
    5: ([('T', 'L'), ('B', 'R')], [('T', 'R'), ('L', 'B')]),
    10: ([('T', 'R'), ('L', 'B')], [('T', 'L'), ('B', 'R')]),
}


def _orient(case, seg, centre_in):
    """Direct a segment so inside corners lie on its positive-cross side."""
    a, b = _EDGE_MID[seg[0]], _EDGE_MID[seg[1]]
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    best = min(_CORNER_POS, key=lambda c: (dist(_CORNER_POS[c], mid), -c))
    c = _CORNER_POS[best]
    side = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    inside = bool(case & best)
    return seg if inside == (side > 0) else (seg[1], seg[0])


def _build_table():
    table = {}
    for case, segs in _SEGS.items():
        if case in (5, 10):
            table[(case, True)] = [_orient(case, s, True) for s in segs[0]]
            table[(case, False)] = [_orient(case, s, False) for s in segs[1]]
        else:
            table[(case, None)] = [_orient(case, s, None) for s in segs]
    return table


_TABLE = _build_table()


def trace_contours(img):
    """Closed iso contours of an 'L' image (pixel-centre coordinates)."""
    w, h = img.size
    W, H = w + 2, h + 2
    pad = Image.new('L', (W, H), 0)
    pad.paste(img, (1, 1))
    v = pad.tobytes()
    binary = pad.point(lambda q: 255 if q > ISO else 0)
    near = ImageChops.difference(binary.filter(ImageFilter.MaxFilter(3)),
                                 binary.filter(ImageFilter.MinFilter(3)))
    nb = near.tobytes()
    nxt = {}
    pos = {}
    idx = nb.find(b'\xff')
    while idx != -1:
        x, y = idx % W, idx // W
        if x < W - 1 and y < H - 1:
            i = y * W + x
            tl, tr, bl, br = v[i], v[i + 1], v[i + W], v[i + W + 1]
            case = ((8 if tl > ISO else 0) | (4 if tr > ISO else 0) |
                    (2 if br > ISO else 0) | (1 if bl > ISO else 0))
            if case not in (0, 15):
                if case in (5, 10):
                    key = (case, (tl + tr + bl + br) / 4.0 > ISO)
                else:
                    key = (case, None)
                for e1, e2 in _TABLE[key]:
                    ids = []
                    for e in (e1, e2):
                        if e == 'T':
                            eid = (y * W + x) * 2
                            p = (x + (ISO - tl) / (tr - tl), y)
                        elif e == 'B':
                            eid = ((y + 1) * W + x) * 2
                            p = (x + (ISO - bl) / (br - bl), y + 1)
                        elif e == 'L':
                            eid = (y * W + x) * 2 + 1
                            p = (x, y + (ISO - tl) / (bl - tl))
                        else:  # R
                            eid = (y * W + x + 1) * 2 + 1
                            p = (x + 1, y + (ISO - tr) / (br - tr))
                        pos[eid] = p
                        ids.append(eid)
                    nxt[ids[0]] = ids[1]
        idx = nb.find(b'\xff', idx + 1)
    loops = []
    while nxt:
        start, cur = nxt.popitem()
        loop = [pos[start]]
        while cur != start:
            loop.append(pos[cur])
            cur = nxt.pop(cur)
        # back to unpadded pixel-centre coordinates
        loops.append([(p[0] - 1, p[1] - 1) for p in loop])
    return loops


# ------------------------------------------------------------------ RDP ---


def rdp(pts, tol):
    """Ramer-Douglas-Peucker on an open polyline (keeps both ends)."""
    if len(pts) < 3:
        return list(pts)
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        pa, pb = pts[a], pts[b]
        d = sub(pb, pa)
        L = math.hypot(d[0], d[1])
        best, bi = -1.0, -1
        for i in range(a + 1, b):
            q = sub(pts[i], pa)
            if L < 1e-12:
                e = math.hypot(q[0], q[1])
            else:
                e = abs(d[0] * q[1] - d[1] * q[0]) / L
            if e > best:
                best, bi = e, i
        if best > tol:
            keep[bi] = True
            stack.append((a, bi))
            stack.append((bi, b))
    return [p for p, k in zip(pts, keep) if k]


# --------------------------------------------------------- corner finding --


def find_corners(pts):
    """Indices of pen-tip corners on a closed dense contour."""
    n = len(pts)
    seg = [dist(pts[i], pts[(i + 1) % n]) for i in range(n)]
    total = sum(seg)
    if total < 8 * CORNER_ARM:
        return []
    ang = [0.0] * n
    # walk arms of CORNER_ARM arc length both ways
    for i in range(n):
        j, acc = i, 0.0
        while acc < CORNER_ARM:
            j = (j - 1) % n
            acc += seg[j]
        k, acc = i, 0.0
        while acc < CORNER_ARM:
            acc += seg[k]
            k = (k + 1) % n
        u = norm(sub(pts[i], pts[j]))
        w = norm(sub(pts[k], pts[i]))
        c = max(-1.0, min(1.0, dot(u, w)))
        ang[i] = math.degrees(math.acos(c))
    corners = []
    win = 4
    for i in range(n):
        a = ang[i]
        if a < CORNER_DEG:
            continue
        if all(a >= ang[(i + d) % n] for d in range(-win, win + 1)):
            if not corners or i - corners[-1] > win:
                corners.append(i)
    return corners


# ---------------------------------------------------- Bezier (Schneider) ---


def bez_pt(b, t):
    mt = 1 - t
    return (mt ** 3 * b[0][0] + 3 * mt * mt * t * b[1][0] +
            3 * mt * t * t * b[2][0] + t ** 3 * b[3][0],
            mt ** 3 * b[0][1] + 3 * mt * mt * t * b[1][1] +
            3 * mt * t * t * b[2][1] + t ** 3 * b[3][1])


def bez_d1(b, t):
    mt = 1 - t
    return (3 * mt * mt * (b[1][0] - b[0][0]) + 6 * mt * t * (b[2][0] - b[1][0]) +
            3 * t * t * (b[3][0] - b[2][0]),
            3 * mt * mt * (b[1][1] - b[0][1]) + 6 * mt * t * (b[2][1] - b[1][1]) +
            3 * t * t * (b[3][1] - b[2][1]))


def bez_d2(b, t):
    return (6 * (1 - t) * (b[2][0] - 2 * b[1][0] + b[0][0]) +
            6 * t * (b[3][0] - 2 * b[2][0] + b[1][0]),
            6 * (1 - t) * (b[2][1] - 2 * b[1][1] + b[0][1]) +
            6 * t * (b[3][1] - 2 * b[2][1] + b[1][1]))


def chord_params(d):
    u = [0.0]
    for i in range(1, len(d)):
        u.append(u[-1] + dist(d[i], d[i - 1]))
    L = u[-1] or 1.0
    return [x / L for x in u]


def gen_bezier(d, u, t1, t2):
    p0, p3 = d[0], d[-1]
    c00 = c01 = c11 = x0 = x1 = 0.0
    for p, t in zip(d, u):
        mt = 1 - t
        b1 = 3 * mt * mt * t
        b2 = 3 * mt * t * t
        a1 = mul(t1, b1)
        a2 = mul(t2, b2)
        c00 += dot(a1, a1)
        c01 += dot(a1, a2)
        c11 += dot(a2, a2)
        b0 = mt ** 3
        b3 = t ** 3
        tmp = sub(p, add(mul(p0, b0 + b1), mul(p3, b2 + b3)))
        x0 += dot(a1, tmp)
        x1 += dot(a2, tmp)
    det = c00 * c11 - c01 * c01
    seg = dist(p0, p3)
    eps = 1e-6 * seg
    if abs(det) > 1e-12:
        al = (x0 * c11 - x1 * c01) / det
        ar = (c00 * x1 - c01 * x0) / det
    else:
        al = ar = seg / 3.0
    if al < eps or ar < eps or al > 2.5 * seg or ar > 2.5 * seg:
        al = ar = seg / 3.0
    return (p0, add(p0, mul(t1, al)), add(p3, mul(t2, ar)), p3)


def max_err(d, b, u):
    best, split = 0.0, len(d) // 2
    for i in range(1, len(d) - 1):
        e = dist(bez_pt(b, u[i]), d[i])
        if e > best:
            best, split = e, i
    return best, split


def reparam(d, b, u):
    out = []
    for p, t in zip(d, u):
        q = bez_pt(b, t)
        q1 = bez_d1(b, t)
        q2 = bez_d2(b, t)
        diff = sub(q, p)
        num = dot(diff, q1)
        den = dot(q1, q1) + dot(diff, q2)
        out.append(min(1.0, max(0.0, t - num / den)) if abs(den) > 1e-12
                   else t)
    return out


def fit_cubic(d, t1, t2, tol, depth=0):
    if len(d) == 2:
        s = dist(d[0], d[1]) / 3.0
        return [(d[0], add(d[0], mul(t1, s)), add(d[1], mul(t2, s)), d[1])]
    u = chord_params(d)
    b = gen_bezier(d, u, t1, t2)
    err, split = max_err(d, b, u)
    if err < tol:
        return [b]
    if err < tol * 4:
        for _ in range(6):
            u2 = reparam(d, b, u)
            if any(u2[i] >= u2[i + 1] for i in range(len(u2) - 1)):
                break
            u = u2
            b = gen_bezier(d, u, t1, t2)
            err, split = max_err(d, b, u)
            if err < tol:
                return [b]
    if depth > 40:
        return [b]
    split = max(1, min(len(d) - 2, split))
    tc = norm(sub(d[split - 1], d[split + 1]))
    if tc == (0.0, 0.0):
        tc = norm(sub(d[split - 1], d[split]))
    left = fit_cubic(d[:split + 1], t1, tc, tol, depth + 1)
    right = fit_cubic(d[split:], mul(tc, -1), t2, tol, depth + 1)
    return left + right


def end_tangent(pts, i, step):
    """Unit tangent from pts[i] into the run (step = +1 forward, -1 back)."""
    base = pts[i]
    for k in range(1, min(4, len(pts) - 1) + 1):
        j = i + step * k
        if 0 <= j < len(pts):
            t = norm(sub(pts[j], base))
            if dist(pts[j], base) > 1.5:
                return t
    j = i + step
    return norm(sub(pts[j], base))


def fit_loop(dense):
    """Fit a closed dense contour with cubic Beziers."""
    corners = find_corners(dense)
    n = len(dense)
    if not corners:
        # Smooth loop: open it at index 0 with a shared tangent.
        run = dense + [dense[0]]
        thin = rdp(run, RDP_TOL)
        if len(thin) < 4:
            thin = run[::max(1, len(run) // 6)] + [run[0]]
        t = norm(sub(dense[1 % n], dense[-1]))
        return fit_cubic(thin, t, mul(t, -1), FIT_TOL)
    out = []
    for ci in range(len(corners)):
        a = corners[ci]
        b = corners[(ci + 1) % len(corners)]
        run = (dense[a:b + 1] if b > a else dense[a:] + dense[:b + 1])
        thin = rdp(run, RDP_TOL)
        if len(thin) < 2:
            continue
        if len(thin) == 2:
            out.append((thin[0], add(thin[0], mul(sub(thin[1], thin[0]), 1 / 3)),
                        add(thin[0], mul(sub(thin[1], thin[0]), 2 / 3)),
                        thin[1]))
            continue
        t1 = end_tangent(run, 0, 1)
        t2 = end_tangent(run, len(run) - 1, -1)
        out.extend(fit_cubic(thin, t1, t2, FIT_TOL))
    return out


# --------------------------------------------------------------- layers ---


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else hi if v > hi else v


def load(name):
    return Image.open(os.path.join(LOGOS, name + '.png')).convert('RGBA')


def field_image(field, w, h):
    im = Image.new('L', (w, h))
    im.putdata([int(round(255 * clamp(a))) for a in field])
    return im


def trace_field(field, w, h):
    """Field (0..1 list) -> list of Bezier loops in source px units."""
    im = field_image(field, w, h)
    big = im.resize((w * SCALE, h * SCALE), Image.BICUBIC)
    big = big.filter(ImageFilter.GaussianBlur(BLUR))
    loops = trace_contours(big)
    out = []
    min_area = MIN_AREA * SCALE * SCALE
    for loop in loops:
        if len(loop) < 6 or abs(polygon_area(loop)) < min_area:
            continue
        # drop exact duplicate neighbours (iso through a corner)
        clean = [loop[0]]
        for p in loop[1:]:
            if dist(p, clean[-1]) > 1e-6:
                clean.append(p)
        if len(clean) > 2 and dist(clean[0], clean[-1]) < 1e-6:
            clean.pop()
        if len(clean) < 6:
            continue
        curves = fit_loop(clean)
        # upscaled pixel centre u -> source edge coordinate (u + 0.5) / SCALE
        conv = [tuple(((p[0] + 0.5) / SCALE, (p[1] + 0.5) / SCALE) for p in c)
                for c in curves]
        out.append(conv)
    out.sort(key=lambda lp: (round(lp[0][0][1], 3), round(lp[0][0][0], 3)))
    return out


def fmt(v):
    s = ('%.' + str(DECIMALS) + 'f') % v
    if '.' in s:
        s = s.rstrip('0').rstrip('.')
    if s in ('-0', ''):
        s = '0'
    return s


def path_data(loops):
    """Relative SVG path data from rounded absolute points (no drift)."""
    parts = []
    for lp in loops:
        q = lambda p: (round(p[0], DECIMALS), round(p[1], DECIMALS))
        start = q(lp[0][0])
        parts.append('M%s %s' % (fmt(start[0]), fmt(start[1])))
        cur = start
        for c in lp:
            p1, p2, p3 = q(c[1]), q(c[2]), q(c[3])
            parts.append('c%s %s %s %s %s %s' % (
                fmt(p1[0] - cur[0]), fmt(p1[1] - cur[1]),
                fmt(p2[0] - cur[0]), fmt(p2[1] - cur[1]),
                fmt(p3[0] - cur[0]), fmt(p3[1] - cur[1])))
            cur = p3
        parts.append('z')
    return ''.join(parts).replace(' -', '-')


def circle_loops(cx, cy, r):
    k = 0.5522847498 * r
    pts = [(cx + r, cy), (cx, cy + r), (cx - r, cy), (cx, cy - r)]
    tans = [(0, 1), (-1, 0), (0, -1), (1, 0)]
    curves = []
    for i in range(4):
        a, b = pts[i], pts[(i + 1) % 4]
        ta, tb = tans[i], tans[(i + 1) % 4]
        curves.append((a, add(a, mul(ta, k)), sub(b, mul(tb, k)), b))
    return [curves]


# ----------------------------------------------------------- colour fits ---


def lum(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def mean_colour(samples):
    n = float(len(samples))
    return tuple(int(round(sum(s[k] for s in samples) / n)) for k in range(3))


def fit_linear_gradient(samples, bands=5, min_range=14.0):
    """samples: (x, y, (r, g, b)) of stroke interior pixels.

    Returns ('flat', colour) or ('linear', (x0, y0, x1, y1), colours, stops).
    """
    n = float(len(samples))
    mx = sum(s[0] for s in samples) / n
    my = sum(s[1] for s in samples) / n
    ml = sum(lum(s[2]) for s in samples) / n
    sxx = sxy = syy = sxl = syl = 0.0
    for x, y, c in samples:
        dx, dy, dl = x - mx, y - my, lum(c) - ml
        sxx += dx * dx
        sxy += dx * dy
        syy += dy * dy
        sxl += dx * dl
        syl += dy * dl
    det = sxx * syy - sxy * sxy
    gx = (sxl * syy - syl * sxy) / det
    gy = (sxx * syl - sxy * sxl) / det
    d = norm((gx, gy))
    if d == (0.0, 0.0):
        return ('flat', mean_colour([s[2] for s in samples]))
    proj = sorted((s[0] - mx) * d[0] + (s[1] - my) * d[1] for s in samples)
    lo = proj[int(0.03 * len(proj))]
    hi = proj[int(0.97 * len(proj)) - 1]
    bins = [[] for _ in range(bands)]
    for x, y, c in samples:
        t = ((x - mx) * d[0] + (y - my) * d[1] - lo) / (hi - lo)
        bins[min(bands - 1, max(0, int(t * bands)))].append(c)
    cols = [mean_colour(b) for b in bins if b]
    stops = [(i + 0.5) / bands for i, b in enumerate(bins) if b]
    if max(lum(c) for c in cols) - min(lum(c) for c in cols) < min_range:
        return ('flat', mean_colour([s[2] for s in samples]))
    p0 = (mx + d[0] * lo, my + d[1] * lo)
    p1 = (mx + d[0] * hi, my + d[1] * hi)
    return ('linear', p0 + p1, cols, stops)


# ------------------------------------------------------------ the logos ---

WHITE = (247, 248, 249)
GOLD_ACCENT = (186, 163, 116)


def title_two_tone():
    """title_white.png: white calligraphy + gold accents (two layers)."""
    im = load('title_white')
    w, h = im.size
    px = list(im.getdata())
    body, accent = [0.0] * (w * h), [0.0] * (w * h)
    b_s, a_s = [], []
    for i, p in enumerate(px):
        a = p[3] / 255.0
        if a <= 0:
            continue
        c = p[:3]
        dw = sum((c[k] - WHITE[k]) ** 2 for k in range(3))
        dg = sum((c[k] - GOLD_ACCENT[k]) ** 2 for k in range(3))
        if dw <= dg:
            body[i] = a
            if a > 0.95:
                b_s.append(c)
        else:
            accent[i] = a
            if a > 0.95:
                a_s.append(c)
    return dict(id='titleTwoTone', file='title_two_tone', w=w, h=h, layers=[
        dict(id='body', loops=trace_field(body, w, h),
             fill=('flat', mean_colour(b_s))),
        dict(id='accent', loops=trace_field(accent, w, h),
             fill=('flat', mean_colour(a_s))),
    ])


def title_gold():
    """title_gold.png: one gold layer with its light-to-deep gradient."""
    im = load('title_gold')
    w, h = im.size
    px = list(im.getdata())
    field = [p[3] / 255.0 for p in px]
    samples = [(i % w + 0.5, i // w + 0.5, p[:3]) for i, p in enumerate(px)
               if p[3] > 242]
    return dict(id='titleGold', file='title_gold', w=w, h=h, layers=[
        dict(id='gold', loops=trace_field(field, w, h),
             fill=fit_linear_gradient(samples)),
    ])


def disc_geometry(im):
    """Centre and radius of the medallion's circular alpha mask."""
    w, h = im.size
    a = im.getchannel('A').load()
    s = sx = sy = 0.0
    for y in range(h):
        for x in range(w):
            v = a[x, y] / 255.0
            s += v
            sx += v * (x + 0.5)
            sy += v * (y + 0.5)
    return sx / s, sy / s, math.sqrt(s / math.pi)


GOLDS = [(236, 204, 132), (200, 158, 88), (160, 118, 58), (118, 84, 38)]
EMERALD_GAIN = 1.25


def radial_bg(px, w, h, cx, cy, R, is_bg, bins=10):
    """Median background colour per radius band -> list of (r/R, colour)."""
    buckets = [[] for _ in range(bins)]
    for i, p in enumerate(px):
        x, y = i % w + 0.5, i // w + 0.5
        r = math.hypot(x - cx, y - cy)
        if r < R - 1 and is_bg(p):
            buckets[min(bins - 1, int(r / R * bins))].append(p[:3])
    prof = []
    for k, b in enumerate(buckets):
        if len(b) < 20:
            continue
        med = tuple(sorted(c[j] for c in b)[len(b) // 2] for j in range(3))
        prof.append(((k + 0.5) / bins, med))
    return prof


def interp_prof(prof, t):
    if t <= prof[0][0]:
        return prof[0][1]
    for (t0, c0), (t1, c1) in zip(prof, prof[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(c0[k] + f * (c1[k] - c0[k]) for k in range(3))
    return prof[-1][1]


def best_class(p, bg, classes, gain):
    v = (p[0] - bg[0], p[1] - bg[1], p[2] - bg[2])
    best_a, best_r, best_k = 0.0, None, -1
    for k, c in enumerate(classes):
        u = (c[0] - bg[0], c[1] - bg[1], c[2] - bg[2])
        uu = float(u[0] ** 2 + u[1] ** 2 + u[2] ** 2)
        a = clamp((v[0] * u[0] + v[1] * u[1] + v[2] * u[2]) / uu)
        r = ((v[0] - a * u[0]) ** 2 + (v[1] - a * u[1]) ** 2 +
             (v[2] - a * u[2]) ** 2)
        if best_r is None or r < best_r:
            best_a, best_r, best_k = a, r, k
    return clamp(best_a * gain), best_k


def medallion_emerald(name, art_id, ring_split):
    """Emerald disc (radial gradient) + gold ring(s) + gold calligraphy.

    ring_split: radius fraction separating the ring layer (outside) from the
    calligraphy layer (inside), read off the radial gold profile.
    """
    im = load(name)
    w, h = im.size
    px = list(im.getdata())
    cx, cy, R = disc_geometry(im)
    is_green = lambda p: (p[3] > 250 and p[1] > p[0] + 8 and p[0] < 70 and
                          p[2] >= p[0])
    prof = radial_bg(px, w, h, cx, cy, R, is_green)
    ring, art = [0.0] * (w * h), [0.0] * (w * h)
    ring_s, art_s = [], []
    for i, p in enumerate(px):
        if p[3] == 0:
            continue
        x, y = i % w + 0.5, i // w + 0.5
        r = math.hypot(x - cx, y - cy)
        bg = interp_prof(prof, r / R)
        a, _ = best_class(p, bg, GOLDS, EMERALD_GAIN)
        a *= p[3] / 255.0
        if r / R >= ring_split:
            ring[i] = a
            if a > 0.97 and r < R - 2:
                ring_s.append((x, y, p[:3]))
        else:
            art[i] = a
            if a > 0.97:
                art_s.append((x, y, p[:3]))
    disc_cols = [c for _, c in prof]
    disc_stops = [t for t, _ in prof]
    # Extend the profile to the rim so the gradient reaches R.
    disc_stops = [0.0] + disc_stops + [1.0]
    disc_cols = [disc_cols[0]] + disc_cols + [disc_cols[-1]]
    disc_cols = [tuple(int(round(v)) for v in c) for c in disc_cols]
    # The disc runs under the ring, 0.5 px inside the alpha edge.
    return dict(id=art_id, file=name, w=w, h=h, layers=[
        dict(id='disc', loops=circle_loops(cx, cy, R - 0.25),
             fill=('radial', (cx, cy, R), disc_cols, disc_stops)),
        dict(id='ring', loops=trace_field(ring, w, h),
             fill=fit_linear_gradient(ring_s)),
        dict(id='art', loops=trace_field(art, w, h),
             fill=fit_linear_gradient(art_s)),
    ])


IVORY_BG = (246, 245, 238)
IV_NAVY = (18, 30, 56)
IV_GOLD = (176, 140, 84)
IV_LACE = (176, 184, 190)
IVORY_GAIN = 1.15
LACE_GAIN = 1.6
LACE_MIN = 0.10  # lace coverage below this is paper noise
LACE_KEEP_OUT = 2  # px around strong navy/gold strokes where lace is dropped


def medallion_ivory():
    """Ivory disc + pale arabesque lace + gold + navy (calligraphy & rings)."""
    name = 'medallion_ivory'
    im = load(name)
    w, h = im.size
    px = list(im.getdata())
    cx, cy, R = disc_geometry(im)
    n = w * h
    navy, gold, lace = [0.0] * n, [0.0] * n, [0.0] * n
    navy_s, gold_s, lace_s, paper = [], [], [], []
    for i, p in enumerate(px):
        if p[3] == 0:
            continue
        x, y = i % w + 0.5, i // w + 0.5
        a, k = best_class(p, IVORY_BG, [IV_NAVY, IV_GOLD, IV_LACE],
                          IVORY_GAIN)
        cov = p[3] / 255.0
        # Pale lace and faint navy look alike (navy at ~30 % coverage is
        # the lace grey), so every pixel also gets a lace coverage from its
        # projection on the lace colour; strong strokes and their rims are
        # masked out of the lace below.
        la, _ = best_class(p, IVORY_BG, [IV_LACE], LACE_GAIN)
        la = clamp((la - LACE_MIN) / (1 - LACE_MIN))
        if k == 0:
            navy[i] = a * cov
            if a > 0.97:
                navy_s.append((x, y, p[:3]))
        elif k == 1:
            gold[i] = a * cov
            if a > 0.97:
                gold_s.append((x, y, p[:3]))
        if k != 1:
            lace[i] = la * cov
            if 0.6 < la and a < 0.6:
                lace_s.append((x, y, p[:3]))
        if a < 0.05 and math.hypot(x - cx, y - cy) < R - 3:
            paper.append(p[:3])
    strong = Image.new('L', (w, h))
    strong.putdata([255 if max(navy[i], gold[i]) > 0.5 else 0
                    for i in range(n)])
    strong = strong.filter(ImageFilter.MaxFilter(2 * LACE_KEEP_OUT + 1))
    sb = strong.tobytes()
    for i in range(n):
        if sb[i]:
            lace[i] = 0.0
    return dict(id='medallionIvory', file=name, w=w, h=h, layers=[
        dict(id='disc', loops=circle_loops(cx, cy, R - 0.25),
             fill=('flat', mean_colour(paper))),
        dict(id='lace', loops=trace_field(lace, w, h),
             fill=('flat', mean_colour([c for _, _, c in lace_s]))),
        dict(id='gold', loops=trace_field(gold, w, h),
             fill=fit_linear_gradient(gold_s)),
        dict(id='navy', loops=trace_field(navy, w, h),
             fill=('flat', mean_colour([c for _, _, c in navy_s]))),
    ])


# --------------------------------------------------------------- output ---


def hexc(c):
    return '#%02x%02x%02x' % tuple(int(v) for v in c)


def write_svg(art):
    os.makedirs(SVG_DIR, exist_ok=True)
    defs, paths = [], []
    for layer in art['layers']:
        fill = layer['fill']
        gid = '%s-%s' % (art['file'], layer['id'])
        if fill[0] == 'flat':
            paint = hexc(fill[1])
        elif fill[0] == 'linear':
            x0, y0, x1, y1 = fill[1]
            stops = ''.join('<stop offset="%s" stop-color="%s"/>' % (
                fmt(s), hexc(c)) for c, s in zip(fill[2], fill[3]))
            defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse"'
                        ' x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
                        % (gid, fmt(x0), fmt(y0), fmt(x1), fmt(y1), stops))
            paint = 'url(#%s)' % gid
        else:
            cx, cy, r = fill[1]
            stops = ''.join('<stop offset="%s" stop-color="%s"/>' % (
                fmt(s), hexc(c)) for c, s in zip(fill[2], fill[3]))
            defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse"'
                        ' cx="%s" cy="%s" r="%s">%s</radialGradient>'
                        % (gid, fmt(cx), fmt(cy), fmt(r), stops))
            paint = 'url(#%s)' % gid
        paths.append('<path id="%s" fill="%s" fill-rule="evenodd" d="%s"/>'
                     % (layer['id'], paint, layer['d']))
    svg = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<!-- Generated by tool/vectorize_logos.py from assets/logos/%s.png.'
           ' Do not edit. -->\n'
           '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" '
           'width="%d" height="%d">\n<title>تقويم أهل البيت</title>\n'
           '<defs>%s</defs>\n%s\n</svg>\n') % (
        art['src'], art['w'], art['h'], art['w'], art['h'], ''.join(defs),
        '\n'.join(paths))
    with open(os.path.join(SVG_DIR, art['file'] + '.svg'), 'w',
              encoding='utf-8') as f:
        f.write(svg)


def argb(c):
    return '0xFF%02X%02X%02X' % tuple(int(v) for v in c)


def dart_fill(fill):
    if fill[0] == 'flat':
        return 'color: Color(%s)' % argb(fill[1])
    # one element per line, as `dart format` lays out long lists
    cols = ''.join('\n          Color(%s),' % argb(c) for c in fill[2]) + '\n        '
    stops = ', '.join(fmt(s) for s in fill[3])
    if len('        stops: [%s],' % stops) > 80:
        stops = ''.join('\n          %s,' % fmt(s) for s in fill[3]) + '\n        '
    if fill[0] == 'linear':
        x0, y0, x1, y1 = fill[1]
        return ('color: Color(%s),\n      gradient: LogoGradient.linear(\n'
                '        from: Offset(%s, %s),\n        to: Offset(%s, %s),\n'
                '        colors: [%s],\n        stops: [%s],\n      )') % (
            argb(fill[2][len(fill[2]) // 2]), fmt(x0), fmt(y0), fmt(x1),
            fmt(y1), cols, stops)
    cx, cy, r = fill[1]
    return ('color: Color(%s),\n      gradient: LogoGradient.radial(\n'
            '        center: Offset(%s, %s),\n        radius: %s,\n'
            '        colors: [%s],\n        stops: [%s],\n      )') % (
        argb(fill[2][len(fill[2]) // 2]), fmt(cx), fmt(cy), fmt(r), cols,
        stops)


def write_dart(arts):
    out = ['// GENERATED by tool/vectorize_logos.py from assets/logos/*.png.',
           '// Do not edit by hand: re-run `python3 -I tool/vectorize_logos.py`.',
           '//',
           '// Each logo keeps the view box (and so the aspect ratio and',
           '// padding) of the raster asset it was traced from.',
           '// ignore_for_file: lines_longer_than_80_chars',
           '',
           "import 'dart:ui' show Color, Offset;",
           '',
           "import 'logo_art.dart';",
           '']
    for art in arts:
        out.append('/// Traced from `assets/logos/%s.png` (%d x %d).'
                   % (art['src'], art['w'], art['h']))
        out.append('const %s = LogoArt(' % ('logo' + art['id'][0].upper() + art['id'][1:]))
        out.append("  id: '%s'," % art['id'])
        out.append('  width: %d,' % art['w'])
        out.append('  height: %d,' % art['h'])
        out.append('  layers: [')
        for layer in art['layers']:
            out.append('    LogoLayer(')
            out.append("      id: '%s'," % layer['id'])
            out.append('      %s,' % dart_fill(layer['fill']))
            out.append("      pathData: '%s'," % layer['d'])
            out.append('    ),')
        out.append('  ],')
        out.append(');')
        out.append('')
    with open(DART_OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out))


# --------------------------------------------------------------- preview ---


def flatten(loop, steps=10):
    pts = [loop[0][0]]
    for c in loop:
        for k in range(1, steps + 1):
            pts.append(bez_pt(c, k / steps))
    return pts


def render_mask(loops, w, h, s, ss=3):
    """Even-odd raster of loops at scale s (anti-aliased by ss supersampling)."""
    W, H = int(w * s * ss), int(h * s * ss)
    canvas = Image.new('1', (W, H), 0)
    f = s * ss
    for lp in loops:
        pts = [(p[0] * f, p[1] * f) for p in flatten(lp)]
        x0 = max(0, int(min(p[0] for p in pts)) - 1)
        y0 = max(0, int(min(p[1] for p in pts)) - 1)
        x1 = min(W, int(max(p[0] for p in pts)) + 2)
        y1 = min(H, int(max(p[1] for p in pts)) + 2)
        m = Image.new('1', (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(m).polygon([(p[0] - x0, p[1] - y0) for p in pts],
                                  fill=1)
        region = canvas.crop((x0, y0, x1, y1))
        canvas.paste(ImageChops.logical_xor(region, m), (x0, y0))
    return canvas.convert('L').resize((int(w * s), int(h * s)), Image.BOX)


def preview(arts, outdir, s=3):
    os.makedirs(outdir, exist_ok=True)
    for art in arts:
        for layer in art['layers']:
            m = render_mask(layer['loops'], art['w'], art['h'], s)
            m.save(os.path.join(outdir, '%s_%s.png' % (art['file'],
                                                       layer['id'])))


def main(argv):
    arts = [title_two_tone(), title_gold(),
            medallion_emerald('medallion_emerald', 'medallionEmerald', 0.86),
            medallion_emerald('medallion_emerald_b', 'medallionEmeraldDouble',
                              0.80),
            medallion_ivory()]
    srcs = {'titleTwoTone': 'title_white', 'titleGold': 'title_gold',
            'medallionEmerald': 'medallion_emerald',
            'medallionEmeraldDouble': 'medallion_emerald_b',
            'medallionIvory': 'medallion_ivory'}
    files = {'titleTwoTone': 'title_two_tone', 'titleGold': 'title_gold',
             'medallionEmerald': 'medallion_emerald',
             'medallionEmeraldDouble': 'medallion_emerald_double',
             'medallionIvory': 'medallion_ivory'}
    for art in arts:
        art['src'] = srcs[art['id']]
        art['file'] = files[art['id']]
        for layer in art['layers']:
            layer['d'] = path_data(layer['loops'])
            segs = sum(len(lp) for lp in layer['loops'])
            print('%-24s %-7s loops=%4d curves=%5d bytes=%7d fill=%s' % (
                art['id'], layer['id'], len(layer['loops']), segs,
                len(layer['d']), layer['fill'][0]))
        write_svg(art)
    write_dart(arts)
    if '--preview' in argv:
        preview(arts, argv[argv.index('--preview') + 1])


if __name__ == '__main__':
    main(sys.argv[1:])
