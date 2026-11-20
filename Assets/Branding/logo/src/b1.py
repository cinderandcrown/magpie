from fx import *
import random

def word_layers(sv, g, letters, detail=1.0, ox=0, oy=0):
    """B1 holo-glass wordmark. g already positioned."""
    b = g.bounds
    hgt = b[3]-b[1]
    # glitch slices (restrained)
    bands = [(b[1]+hgt*0.30, b[1]+hgt*0.36, 7), (b[1]+hgt*0.71, b[1]+hgt*0.75, -5)] if detail > 0.5 else [(b[1]+hgt*0.30, b[1]+hgt*0.35, 5)]
    gs, pieces = slices(g, bands)
    sb = gs.bounds
    # ambient bloom
    sv.bloom(solid(gs).buffer(2), CY, 100, passes=((0.40, 0.22), (0.14, 0.30)), solid=False)
    # slab depth
    ext = U([affinity.translate(gs, i*0.55, i*0.9) for i in range(1, 10)])
    body = U([ext, gs])
    sv.path(body.buffer(3.2, join_style=2, mitre_limit=3), CY, 'opacity="0.95"')
    sv.path(body.buffer(1.8, join_style=2, mitre_limit=3), NV)
    sv.path(ext, sv.lin(0, sb[1], 0, sb[3]+8, [(0, '#123A6B'), (0.5, '#0C1A44'), (1, '#1B0B3A')]))
    sv.path(edges(ext, -0.8, -0.8).difference(gs), MG, 'opacity="0.55"')
    # chromatic aberration fringes
    sv.path(affinity.translate(gs, -1.5, 0), CY, 'opacity="0.9"')
    sv.path(affinity.translate(gs, 1.5, 0), MG, 'opacity="0.9"')
    # glass face
    sv.path(gs, sv.lin(0, sb[1], 0, sb[3], [(0, '#F4FFFF'), (0.38, '#A8F9FF'), (0.52, '#3FD9F2'), (0.56, '#1AA6D6'), (0.8, '#7C6BFF'), (1, '#FF6FE8')]))
    sv.path(gs, sv.lin(sb[0], sb[1], sb[2], sb[3], [(0, CY, 0.0), (0.45, '#FFFFFF', 0.0), (0.7, MG, 0.35), (1, MG, 0.55)]))
    # holo sheen band
    t = math.tan(math.radians(12))
    for x0, w, op in [(sb[0]+hgt*1.1, hgt*0.35, 0.28), (sb[0]+hgt*1.6, hgt*0.08, 0.35), (sb[0]+hgt*3.7, hgt*0.22, 0.2)]:
        band = Polygon([(x0, sb[1]-5), (x0+w, sb[1]-5), (x0+w-hgt*0.9, sb[3]+5), (x0-hgt*0.9, sb[3]+5)])
        sv.path(band.intersection(gs), '#FFFFFF', f'opacity="{op}"')
    # scanlines + noise, clipped to face
    cp = sv.clip(gs)
    sv.add(f'<g clip-path="url(#{cp})">' + sv.scan(sb[0]-5, sb[1]-2, sb[2]-sb[0]+10, sb[3]-sb[1]+4, 2.4 if detail > 0.5 else 4.0, 0.22) + '</g>')
    nz = sv.noise(0.9, 0.10)
    sv.add(f'<g clip-path="url(#{cp})"><rect x="{sb[0]-5:.1f}" y="{sb[1]-5:.1f}" width="{sb[2]-sb[0]+10:.1f}" height="{sb[3]-sb[1]+10:.1f}" fill="#fff" filter="url(#{nz})"/></g>')
    # bevel: lit top-left edges, shaded bottom-right
    sv.path(edges(gs, 1.4, 2.2), '#FFFFFF', 'opacity="0.95"')
    sv.path(edges(gs, -1.2, -1.8), NV, 'opacity="0.45"')
    inner = gs.buffer(-4.2, join_style=2)
    sv.add(f'<path d="{d(inner)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.12" stroke-width="0.5"/>')
    # slice tear lines and RGB on displaced pieces
    for (y0, y1, dx), pc in zip(bands, pieces):
        sv.add(f'<rect x="{sb[0]-30:.1f}" y="{y0-0.35:.2f}" width="{sb[2]-sb[0]+70:.1f}" height="0.7" fill="#FFFFFF" opacity="0.75"/>')
        sv.add(f'<rect x="{sb[0]+hgt*0.5:.1f}" y="{y1-0.25:.2f}" width="{(sb[2]-sb[0])*0.6:.1f}" height="0.5" fill="{CY}" opacity="0.8"/>')
        sv.path(affinity.translate(pc, -dx*0.5, 0).difference(gs), CY, 'opacity="0.55"')
    return gs

def emblem_layers(sv, cx, cy, R, detail=1.0):
    e = emblem(cx, cy, R)
    head = e['head']
    sv.bloom(head.buffer(R*0.05), CY, R*1.3, passes=((0.35, 0.30), (0.12, 0.5)), solid=False)
    sv.path(head.buffer(R*0.055, join_style=2), CY)
    sv.path(head.buffer(R*0.025, join_style=2), NV)
    sv.path(head, sv.lin(cx, cy-R, cx, cy+R, [(0, '#4A5C92'), (0.45, '#2A3766'), (1, '#121A40')]))
    # facets
    vs = list(head.exterior.coords)
    fac = U([LineString([(cx, cy+R*0.1), v]).buffer(R*0.006) for v in vs[::2]]).intersection(head)
    sv.path(fac, CY, 'opacity="0.16"')
    sv.path(edges(head, R*0.02, R*0.03), '#9FF8FF', 'opacity="0.7"')
    sv.path(e['inner_ear'], sv.lin(cx, cy-R, cx, cy-R*0.5, [(0, MG), (1, '#7A1E9E')]))
    for k in ('brow', 'muzzle'):
        sv.path(e[k], sv.lin(cx, cy-R*0.6, cx, cy+R*0.8, [(0, '#FFFFFF'), (0.6, '#BDF7FF'), (1, '#7FE8FF')]))
        sv.path(edges(e[k], -R*0.015, -R*0.025), '#3BA9D9', 'opacity="0.6"')
    mask = e['mask']
    sv.path(mask.buffer(R*0.04, join_style=2), MG, 'opacity="0.35"')
    sv.path(mask.buffer(R*0.02, join_style=2), NV)
    sv.path(mask, sv.lin(cx, cy-R*0.4, cx, cy+R*0.25, [(0, '#1A1440'), (0.5, '#0A0A22'), (1, '#05050F')]))
    sv.path(edges(mask, R*0.012, R*0.035), MG)
    sv.path(edges(mask, -R*0.01, -R*0.02), '#6A1D8A', 'opacity="0.8"')
    sv.path(e['eyes'].buffer(R*0.03, join_style=2), NV)
    sv.bloom(e['eyes'], CY, R*0.9, core=e['eyes'].buffer(-R*0.035, join_style=2), passes=((0.25, 0.6), (0.09, 0.9), (0.03, 1.0)))
    sv.path(e['nose'], NV)
    return head.buffer(R*0.06).bounds

def neon_secondary(sv, text, cx, y, cap, width=None):
    t = secondary(text, cap, 0.62, 600)
    tb = t.bounds
    t = affinity.translate(t, cx - (tb[0]+tb[2])/2, y - tb[3])
    t = shear(t, 12, origin=(cx, y))
    tb = t.bounds
    sv.bloom(t, CY, cap*2.2, core=None, passes=((0.35, 0.5), (0.1, 0.8)), solid=False)
    sv.path(t, '#EFFFFF')
    # flanking rails with ticks
    for sg in (-1, 1):
        x0 = (tb[0] - cap*0.8) if sg < 0 else (tb[2] + cap*0.8)
        L = cap*4.2 if width is None else width
        x1 = x0 + sg*L
        yy = (tb[1]+tb[3])/2
        rail = box(min(x0, x1), yy-cap*0.05, max(x0, x1), yy+cap*0.05)
        tick = Polygon([(x0, yy-cap*0.32), (x0 + sg*cap*0.35, yy), (x0, yy+cap*0.32)])
        sv.path(rail, sv.lin(x0, 0, x1, 0, [(0, CY), (1, CY, 0)]))
        sv.path(tick, MG)
    return tb

def full():
    sv = Svg('b1f')
    g, L = bandit()
    gb = g.bounds
    R = 64
    ex = gb[0] - R*1.55; ey = (gb[1]+gb[3])/2 - 14
    eb = emblem_layers(sv, ex, ey, R)
    tb = neon_secondary(sv, 'THE NEON CITY', (gb[0]+gb[2])/2 + 6, gb[1] - 12, 15)
    gs = word_layers(sv, g, L)
    allb = (min(eb[0], gb[0]) - 40, min(eb[1], tb[1]) - 40, max(gb[2], tb[2]) + 70, max(eb[3], gb[3]) + 40)
    return sv.out((allb[0], allb[1], allb[2]-allb[0], allb[3]-allb[1]), pad=70)

def compact():
    sv = Svg('b1c')
    g, L = bandit(cuts=True)
    gb = g.bounds; cx = (gb[0]+gb[2])/2
    R = 92
    ey = gb[1] - 52 - R*0.9
    eb = emblem_layers(sv, cx - 8, ey, R)
    tb = neon_secondary(sv, 'THE NEON CITY', cx + 4, gb[1] - 14, 17, width=50)
    word_layers(sv, g, L, detail=0.4)
    allb = (min(gb[0], tb[0]-80) - 40, eb[1] - 40, max(gb[2], tb[2]+80) + 50, gb[3] + 40)
    return sv.out((allb[0], allb[1], allb[2]-allb[0], allb[3]-allb[1]), pad=70)

def icon():
    sv = Svg('b1i')
    S_ = 1024
    sv.add(f'<rect width="{S_}" height="{S_}" fill="{sv.rad(512, 470, 720, [(0, "#1B2560"), (0.55, "#0D1236"), (1, "#05071A")])}"/>')
    # neon grid floor + horizon
    lines = []
    for i in range(-12, 13):
        lines.append(f'<line x1="{512+i*16}" y1="760" x2="{512+i*150}" y2="1100" stroke="{MG}" stroke-width="3"/>')
    for j in range(1, 8):
        y = 760 + (j/7)**2*300; lines.append(f'<line x1="0" y1="{y:.1f}" x2="1024" y2="{y:.1f}" stroke="{MG}" stroke-width="{2+j*0.6:.1f}"/>')
    sv.add(f'<g opacity="0.45">{"".join(lines)}</g>')
    sv.add(f'<rect x="0" y="757" width="1024" height="5" fill="{MG}" opacity="0.9"/>')
    f = sv.blur(26); sv.add(f'<g filter="url(#{f})"><rect x="0" y="745" width="1024" height="28" fill="{MG}" opacity="0.7"/></g>')
    # hex ring
    ring = Polygon([(512 + 410*math.cos(math.radians(a)), 500 + 410*math.sin(math.radians(a))) for a in range(-90, 270, 60)])
    rr = ring.difference(ring.buffer(-9, join_style=2))
    rr2 = ring.buffer(-26, join_style=2); rr2 = rr2.difference(rr2.buffer(-3, join_style=2))
    sv.add(f'<path d="{d(ring)}" fill="{sv.rad(512, 420, 420, [(0, "#1E2C6A", 0.9), (1, "#0A0E27", 0.9)])}"/>')
    sv.bloom(rr, CY, 60, passes=((0.4, 0.4), (0.12, 0.7)), solid=True)
    sv.path(rr2, MG, 'opacity="0.7"')
    emblem_layers(sv, 512, 540, 255)
    sv.add(sv.scan(0, 0, 1024, 1024, 6, 0.10, '#000'))
    return sv.out((0, 0, 1024, 1024))

if __name__ == '__main__':
    import os; os.makedirs('/workspace/logo/round2', exist_ok=True)
    o = '/workspace/logo/round2/'
    s = full(); open(o+'B1_holo_glass.svg', 'w').write(s); render(s, o+'B1_holo_glass.png', 2048)
    s = compact(); open(o+'B1_holo_glass_compact.svg', 'w').write(s); render(s, o+'B1_holo_glass_compact.png', 2048)
    s = icon(); open(o+'B1_holo_glass_icon.svg', 'w').write(s); render(s, o+'B1_holo_glass_icon.png', 1024)
