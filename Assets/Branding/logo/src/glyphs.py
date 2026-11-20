"""Custom angular BANDIT letterforms (original, built from polygons). y down, cap top y=-H, baseline y=0."""
import sys; sys.path.insert(0, '/workspace/logo/src')
from lib import *
from shapely.geometry import Polygon, box
from shapely.ops import unary_union

H = 100.0   # cap height
S = 23.0    # stem weight
C = 14.0    # standard chamfer

def P(*pts): return Polygon(pts)
def Y(y): return y - H  # convert 0..100 top-down to coords

def B(w=74):
    s = S
    outer = P((0, Y(0)), (w-C, Y(0)), (w, Y(C)), (w, Y(42)), (w-7, Y(48)), (w+4, Y(56)), (w+4, Y(100-C)), (w+4-C, Y(100)), (-10, Y(100)), (0, Y(84)))
    c1 = P((s, Y(s-4)), (w-s-4, Y(s-4)), (w-s, Y(s)), (w-s, Y(39)), (s, Y(39)))
    c2 = P((s, Y(57)), (w-s+4, Y(57)), (w-s+4, Y(100-s-2)), (w-s, Y(100-s+2)), (s, Y(100-s+2)))
    g = outer.difference(c1).difference(c2)
    return g, w+4

def A(w=86):
    s = S
    outer = P((0, Y(100)), (w*0.36, Y(0)), (w*0.64+4, Y(0)), (w, Y(100)), (w-s-2, Y(100)), (w-s-8, Y(76)), (s+8, Y(76)), (s+2, Y(100)))
    cnt = P((w*0.5-6, Y(s+2)), (w*0.5+6, Y(s+2)), (w-s-14, Y(56)), (s+14, Y(56)))
    return outer.difference(cnt), w

def N(w=76):
    s = S
    l = P((0, Y(C)), (C, Y(0)), (s, Y(0)), (s, Y(100)), (0, Y(100)))
    r = P((w-s, Y(0)), (w, Y(0)), (w, Y(100-C)), (w-C, Y(100)), (w-s, Y(100)))
    dg = P((0, Y(0)), (s+6, Y(0)), (w, Y(100)), (w-s-6, Y(100)))
    g = unary_union([l, r, dg]).intersection(box(0, Y(0), w, Y(100)))
    return g, w

def D(w=76):
    s = S
    outer = P((0, Y(0)), (w-24, Y(0)), (w, Y(24)), (w, Y(100-C)), (w-C, Y(100)), (0, Y(100)))
    cnt = P((s, Y(s)), (w-s-12, Y(s)), (w-s, Y(s+12)), (w-s, Y(100-s)), (s, Y(100-s)))
    return outer.difference(cnt), w

def I(w=None):
    s = S
    g = P((0, Y(8)), (s, Y(0)), (s, Y(100)), (0, Y(100)))
    return g, s

def T(w=78, blade=30):
    s = S
    bar = P((0, Y(0)), (w+blade, Y(0)), (w, Y(s)), (0, Y(s)))
    x0 = w*0.5 - s*0.5
    stem = P((x0, Y(s-1)), (x0+s, Y(s-1)), (x0+s, Y(100-10)), (x0+s-10, Y(100)), (x0, Y(100)))
    return unary_union([bar, stem]), w

def bandit(gap=9, slant=12, cuts=True):
    parts = [B(), A(), N(), D(), I(), T()]
    adj = [0, -9, -2, 0, 0, 0]   # kerning: A tucks under B's spur
    x = 0; out = []
    for (g, w), a in zip(parts, adj):
        x += a
        out.append(affinity.translate(g, x, 0)); x += w + gap
    if cuts:
        # signature cuts: one diagonal slash through B-A, a horizontal speed slit across N-D-I
        # B: angular bite out of the upper bowl's right shoulder
        out[0] = out[0].difference(P((60, Y(-2)), (80, Y(-2)), (80, Y(22))))
        slit = box(-50, Y(64), 2000, Y(67.5))
        for i in (2, 3, 4):
            out[i] = out[i].difference(slit)
        # notch top of D, chip out of N's terminal
        out[3] = out[3].difference(P((out[3].bounds[0]+S, Y(-1)), (out[3].bounds[0]+S+14, Y(-1)), (out[3].bounds[0]+S+6, Y(6))))
    letters = out
    g = unary_union(letters)
    g = shear(g, slant, origin=(0, 0))
    letters = [shear(l, slant, origin=(0, 0)) for l in letters]
    return g, letters

def emblem(cx=0, cy=0, R=100):
    """Geometric raccoon-bandit head: ears + faceted head + mask band with sharp eye slits + nose."""
    def pt(x, y): return (cx + x*R, cy + y*R)
    def mir(pts): return pts + [(-x, y) for x, y in reversed(pts)]
    right = [(0.30, -0.66), (0.74, -0.98), (0.72, -0.48), (0.98, -0.10), (1.16, 0.20), (0.84, 0.26), (0.98, 0.44), (0.50, 0.60), (0.0, 0.90)]
    hp = mir([(x, y) for x, y in right])
    # mir builds right side then mirrored left; ensure ring order
    head = Polygon([pt(x, y) for x, y in right] + [pt(-x, y) for x, y in reversed(right)][1:]).buffer(0)
    inner_ear = unary_union([Polygon([pt(sg*0.40, -0.66), pt(sg*0.68, -0.86), pt(sg*0.66, -0.56)]) for sg in (-1, 1)])
    mask = Polygon([pt(-1.20, -0.26), pt(-0.55, -0.40), pt(-0.12, -0.20), pt(0.0, -0.26), pt(0.12, -0.20), pt(0.55, -0.40), pt(1.20, -0.26),
                    pt(0.86, 0.04), pt(0.62, 0.20), pt(0.22, 0.14), pt(0.0, 0.24), pt(-0.22, 0.14), pt(-0.62, 0.20), pt(-0.86, 0.04)])
    eyes = unary_union([Polygon([pt(sg*0.64, -0.16), pt(sg*0.20, -0.07), pt(sg*0.30, 0.06), pt(sg*0.58, 0.02)]) for sg in (-1, 1)])
    brow = unary_union([Polygon([pt(sg*0.08, -0.32), pt(sg*0.56, -0.50), pt(sg*0.68, -0.40), pt(sg*0.16, -0.22)]) for sg in (-1, 1)]
                       + [Polygon([pt(-0.07, -0.58), pt(0.07, -0.58), pt(0.0, -0.34)])])
    nose = Polygon([pt(-0.14, 0.40), pt(0.14, 0.40), pt(0.0, 0.56)])
    muzzle = Polygon([pt(-0.42, 0.26), pt(0.0, 0.30), pt(0.42, 0.26), pt(0.24, 0.60), pt(0.0, 0.74), pt(-0.24, 0.60)])
    return dict(head=head, inner_ear=inner_ear, mask=mask, eyes=eyes, brow=brow, nose=nose, muzzle=muzzle)
