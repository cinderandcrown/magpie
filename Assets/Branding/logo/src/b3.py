from fx import *
import random
from shapely.geometry import MultiLineString

def rings(g):
    ps = [g] if isinstance(g, Polygon) else [p for p in getattr(g, 'geoms', []) if isinstance(p, Polygon)]
    out = []
    for p in ps:
        out.append(list(p.exterior.coords)); out += [list(r.coords) for r in p.interiors]
    return out

def dr(rs):
    return ''.join('M' + ' L'.join(f'{x:.2f} {y:.2f}' for x, y in r) + 'Z' for r in rs if len(r) > 2)

def tube(sv, rs, color, w, lit=1.0, glow=1.0):
    dd = dr(rs)
    if lit > 0.5:
        for std, op in ((w*5.0*glow, 0.35), (w*1.8*glow, 0.6), (w*0.7, 0.9)):
            f = sv.blur(std)
            sv.add(f'<g filter="url(#{f})" opacity="{op*lit}"><path d="{dd}" fill="none" stroke="{color}" stroke-width="{w*1.6:.2f}" stroke-linejoin="round"/></g>')
        sv.add(f'<path d="{dd}" fill="none" stroke="{color}" stroke-width="{w:.2f}" stroke-linejoin="round"/>')
        sv.add(f'<path d="{dd}" fill="none" stroke="#FFFFFF" stroke-width="{w*0.38:.2f}" stroke-linejoin="round" opacity="0.95"/>')
    else:  # dead / flickering tube: dim glass
        sv.add(f'<path d="{dd}" fill="none" stroke="{color}" stroke-width="{w:.2f}" stroke-linejoin="round" opacity="0.28"/>')
        sv.add(f'<path d="{dd}" fill="none" stroke="#FFFFFF" stroke-width="{w*0.3:.2f}" stroke-linejoin="round" opacity="0.15"/>')

def clips(sv, rs, every, w, rnd):
    out = []
    for r in rs:
        ls = LineString(r); L = ls.length; t = rnd.uniform(0, every)
        while t < L:
            p = ls.interpolate(t); q = ls.interpolate(min(L, t + 0.5))
            ang = math.degrees(math.atan2(q.y - p.y, q.x - p.x))
            c = affinity.rotate(box(p.x - w*0.5, p.y - w*1.5, p.x + w*0.5, p.y + w*1.5), ang, origin=(p.x, p.y))
            out.append(c); t += every
    return U(out) if out else Polygon()

def bolt(sv, x, y, r):
    sv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r*1.25:.2f}" fill="#05060F" opacity="0.8"/>')
    sv.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{sv.lin(x-r, y-r, x+r, y+r, [(0, "#C9D3F0"), (0.5, "#5B6488"), (1, "#1A1E34")])}"/>')
    sv.add(f'<path d="M{x-r*0.6:.2f} {y+r*0.3:.2f} L{x+r*0.6:.2f} {y-r*0.3:.2f}" stroke="#14172A" stroke-width="{r*0.28:.2f}"/>')

def plate(sv, poly, scale, seed=1, bolts=None):
    pb = poly.bounds
    sv.add(f'<path d="{d(affinity.translate(poly, scale*0.02, scale*0.05))}" fill="#000" opacity="0.6" filter="url(#{sv.blur(scale*0.04)})"/>')
    # RGB edge (chromatic offset outlines)
    pbb = poly.bounds
    cyc = poly.boundary.intersection(box(-1e5, -1e5, pbb[0] + (pbb[2]-pbb[0])*0.45, 1e5))
    mgc = poly.boundary.intersection(box(pbb[0] + (pbb[2]-pbb[0])*0.55, -1e5, 1e5, 1e5))
    for geom, col, sg in ((cyc, CY, -1), (mgc, MG, 1)):
        ln = affinity.translate(geom, sg*scale*0.006, sg*scale*0.003).buffer(scale*0.0025, cap_style=2)
        sv.bloom(ln, col, scale*0.05, passes=((0.3, 0.5),))
    sv.path(poly, sv.lin(0, pb[1], 0, pb[3], [(0, '#2A3150'), (0.08, '#1A1F36'), (0.6, '#11142A'), (1, '#0A0C1C')]))
    cp = sv.clip(poly)
    nz = sv.noise(None, 0.10, seed=seed, stretch=(0.002, 0.9))
    sv.add(f'<g clip-path="url(#{cp})"><rect x="{pb[0]:.1f}" y="{pb[1]:.1f}" width="{pb[2]-pb[0]:.1f}" height="{pb[3]-pb[1]:.1f}" fill="#fff" filter="url(#{nz})"/></g>')
    inset = poly.buffer(-scale*0.014, join_style=2)
    sv.path(poly.difference(inset), sv.lin(0, pb[1], 0, pb[3], [(0, '#6C77A4'), (0.12, '#2C3352'), (1, '#0D0F20')]))
    sv.path(edges(inset, scale*0.003, scale*0.006), '#05060F', 'opacity="0.9"')
    m = scale*0.065
    if bolts is None: bolts = [(pb[0]+m, pb[1]+m), (pb[2]-m, pb[1]+m), (pb[0]+m, pb[3]-m), (pb[2]-m, pb[3]-m)]
    for x, y in bolts:
        bolt(sv, x, y, scale*0.018)
    return inset

def channel(sv, g, depth):
    ext = U([affinity.translate(g, i*depth/6*0.5, i*depth/6) for i in range(1, 7)])
    sv.path(ext.buffer(0.6), '#05060F')
    sv.path(ext, sv.lin(0, g.bounds[1], 0, g.bounds[3]+depth, [(0, '#3B4366'), (1, '#151829')]))
    sv.path(g, '#090B18')
    sv.path(g.difference(g.buffer(-1.2, join_style=2)), '#2C3352')

def word_layers(sv, g, letters, rnd, detail=1.0):
    gb = g.bounds
    tw = 3.0 if detail > 0.5 else 3.8
    # glow cast on plate from lit letters
    channel(sv, g, 5)
    for i, L in enumerate(letters):
        inner = L.buffer(-6.2, join_style=2)
        rs = rings(inner)
        lit = 1.0
        if i == 2: lit = 0.0          # N tube dead / flickering
        tube(sv, rs, MG, tw, lit=lit)
        if i == 2:
            # half-lit flicker: lower half of N still glowing
            lower = inner.intersection(box(-1e5, gb[1]+(gb[3]-gb[1])*0.55, 1e5, 1e5))
            tube(sv, rings(lower.boundary.buffer(0.01)) if False else [list(c.coords) for c in getattr(inner.boundary.intersection(box(-1e5, gb[1]+(gb[3]-gb[1])*0.58, 1e5, 1e5)), 'geoms', [])], MG, tw, lit=0.85)
        cl = clips(sv, rs, 26, 1.3, rnd)
        sv.path(cl, '#1B1F33'); sv.path(edges(cl, 0.2, 0.3), '#7C86AE')
    # spark on the N
    nb = letters[2].bounds
    sx, sy = nb[0] + (nb[2]-nb[0])*0.62, nb[1] + (nb[3]-nb[1])*0.42
    spark = U([affinity.rotate(Polygon([(sx-0.6, sy), (sx, sy-7), (sx+0.6, sy), (sx, sy+7)]), a, origin=(sx, sy)) for a in (0, 60, 120)])
    sv.bloom(spark, '#FFFFFF', 12, passes=((0.4, 0.8), (0.12, 1.0)))

def emblem_tubes(sv, cx, cy, R, rnd):
    e = emblem(cx, cy, R)
    head = e['head']
    sv.path(head, '#0A0C1A', 'opacity="0.85"')
    tube(sv, rings(head.buffer(-R*0.05, join_style=2)), CY, R*0.035)
    tube(sv, rings(e['inner_ear']), CY, R*0.022)
    tube(sv, rings(e['mask'].buffer(-R*0.03, join_style=2)), MG, R*0.035)
    for k in ('brow', 'muzzle'):
        tube(sv, rings(e[k].buffer(-R*0.015, join_style=2)), '#E9FDFF', R*0.025, glow=0.7)
    sv.bloom(e['eyes'], LIME, R*0.9, core=e['eyes'].buffer(-R*0.03, join_style=2), passes=((0.25, 0.6), (0.08, 0.9)))
    tube(sv, rings(e['nose']), MG, R*0.02)

def secondary_tube(sv, text, cx, y, cap):
    t = secondary(text, cap, 0.55, 400)
    tb = t.bounds; t = affinity.translate(t, cx - (tb[0]+tb[2])/2, y - tb[3]); t = shear(t, 12, origin=(cx, y))
    tube(sv, rings(t), CY, cap*0.09)
    return t.bounds

def glitch_wrap(content, bounds, bands, prefix):
    """repeat content clipped into horizontal bands with x offsets"""
    x0, y0, x1, y1 = bounds
    defs, out = [], []
    edges_ = [y0] + [v for a, b, dx in bands for v in (a, b)] + [y1]
    segs = []; cur = y0
    for a, b, dx in bands:
        segs.append((cur, a, 0)); segs.append((a, b, dx)); cur = b
    segs.append((cur, y1, 0))
    for i, (a, b, dx) in enumerate(segs):
        defs.append(f'<clipPath id="{prefix}gw{i}"><rect x="{x0-500:.1f}" y="{a:.2f}" width="{x1-x0+1000:.1f}" height="{b-a:.2f}"/></clipPath>')
        out.append(f'<g clip-path="url(#{prefix}gw{i})"><g transform="translate({dx:.2f},0)">{content}</g></g>')
        if dx:
            out.append(f'<rect x="{x0-20:.1f}" y="{a-0.3:.2f}" width="{x1-x0+40:.1f}" height="0.6" fill="#FFFFFF" opacity="0.7"/>')
            out.append(f'<rect x="{x0-10:.1f}" y="{a:.2f}" width="{x1-x0+20:.1f}" height="{b-a:.2f}" fill="{CY}" opacity="0.06"/>')
    return ''.join(defs), ''.join(out)

def build(kind):
    rnd = random.Random(4)
    sv = Svg('b3' + kind[0])
    g, L = bandit(cuts=False)
    gb = g.bounds; cx = (gb[0]+gb[2])/2
    if kind == 'full':
        R = 58
        ex = gb[0] - R*1.55; ey = (gb[1]+gb[3])/2 - 14
        pl = Polygon([(ex - R*1.45, gb[1]-48), (gb[2]+44, gb[1]-48), (gb[2]+64, gb[1]-28), (gb[2]+64, gb[3]+30), (ex - R*1.25, gb[3]+30), (ex - R*1.45, gb[3]+10)])
        plate(sv, pl, 520, seed=3)
        # divider
        dx_ = gb[0] - R*0.42
        sv.add(f'<rect x="{dx_-1.2:.1f}" y="{gb[1]-30:.1f}" width="2.4" height="{gb[3]-gb[1]+44:.1f}" fill="#05060F"/><rect x="{dx_+1.2:.1f}" y="{gb[1]-30:.1f}" width="0.8" height="{gb[3]-gb[1]+44:.1f}" fill="#4A5378"/>')
        emblem_tubes(sv, ex, ey, R, rnd)
        secondary_tube(sv, 'THE NEON CITY', cx + 8, gb[1] - 13, 15)
        word_layers(sv, g, L, rnd)
        pb = pl.bounds
        bands = [(gb[1] + 38, gb[1] + 46, 9), (gb[1] + 70, gb[1] + 73, -14)]
    elif kind == 'compact':
        R = 84; ey = gb[1] - 50 - R*0.9
        pl = Polygon([(gb[0]-54, ey - R*1.25), (gb[2]+14, ey - R*1.25), (gb[2]+40, ey - R*1.0), (gb[2]+40, gb[3]+58), (gb[0]-34, gb[3]+58), (gb[0]-54, gb[3]+36)])
        plate(sv, pl, 560, seed=5)
        emblem_tubes(sv, cx - 6, ey, R, rnd)
        secondary_tube(sv, 'THE NEON CITY', cx + 4, gb[1] - 14, 17)
        word_layers(sv, g, L, rnd, detail=0.4)
        pb = pl.bounds
        bands = [(gb[1] + 40, gb[1] + 46, 7)]
    content = ''.join(sv.body); sv.body = []
    gd, go = glitch_wrap(content, pb, bands, sv.p)
    sv.defs.append(gd); sv.add(go)
    m = 120
    return sv.out((pb[0]-m, pb[1]-m, pb[2]-pb[0]+2*m, pb[3]-pb[1]+2*m))

def icon():
    rnd = random.Random(9)
    sv = Svg('b3i')
    sv.add(f'<rect width="1024" height="1024" fill="{sv.rad(512, 420, 760, [(0, "#1A1F3E"), (0.6, "#0A0C1E"), (1, "#030409")])}"/>')
    # brick wall texture
    rows = []
    for j, y in enumerate(range(0, 1024, 46)):
        off = 0 if j % 2 else 60
        for x in range(-120 + off, 1100, 120):
            rows.append(f'M{x+3} {y+3}h114v40h-114Z')
    sv.add(f'<path d="{"".join(rows)}" fill="#151a33" opacity="0.6"/>')
    hexp = Polygon([(512 + 420*math.cos(math.radians(a)), 512 + 420*math.sin(math.radians(a))) for a in range(-90, 270, 60)])
    bl = [(512 + 360*math.cos(math.radians(a)), 512 + 360*math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    plate(sv, hexp, 900, seed=7, bolts=bl)
    emblem_tubes(sv, 512, 540, 270, rnd)
    content = ''.join(sv.body); sv.body = []
    gd, go = glitch_wrap(content, (0, 0, 1024, 1024), [(600, 618, 16)], 'b3i')
    sv.defs.append(gd); sv.add(go)
    sv.add(sv.scan(0, 0, 1024, 1024, 5, 0.12, '#000'))
    return sv.out((0, 0, 1024, 1024))

if __name__ == '__main__':
    o = '/workspace/logo/round2/'
    s = build('full'); open(o+'B3_neon_hardware.svg', 'w').write(s); render(s, o+'B3_neon_hardware.png', 2048)
    s = build('compact'); open(o+'B3_neon_hardware_compact.svg', 'w').write(s); render(s, o+'B3_neon_hardware_compact.png', 2048)
    s = icon(); open(o+'B3_neon_hardware_icon.svg', 'w').write(s); render(s, o+'B3_neon_hardware_icon.png', 1024)
