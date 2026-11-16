from fx import *
import random

def mkbands(y0, y1, n, rnd, amp, keep=0.45):
    ys = sorted([y0] + [rnd.uniform(y0, y1) for _ in range(n-1)] + [y1])
    out = []
    for a, b in zip(ys, ys[1:]):
        if b - a < 0.8: continue
        dx = 0 if rnd.random() < keep else rnd.choice([-1, 1]) * rnd.uniform(amp*0.25, amp)
        out.append((a, b, dx))
    return out

def cut(g, bands):
    pieces = []
    for a, b, dx in bands:
        pieces.append(affinity.translate(g.intersection(box(-1e5, a, 1e5, b)), dx, 0))
    return U(pieces)

def tape(sv, x0, y0, x1, y1, h, text='SIGNAL LOST', seed=1, opacity=1.0):
    ang = math.degrees(math.atan2(y1-y0, x1-x0)); L = math.hypot(x1-x0, y1-y0)
    rnd = random.Random(seed)
    # jagged torn ends
    top = [(0, 0), (L, 0)]
    right = [(L, 0)] + [(L - rnd.uniform(0, h*0.5), h*k/6) for k in range(1, 6)] + [(L, h)]
    left = [(0, h)] + [(rnd.uniform(0, h*0.5), h*(6-k)/6) for k in range(1, 6)] + [(0, 0)]
    poly = Polygon(top + right[1:] + [(0, h)][:0] + left)
    chev = []
    x = -h
    while x < L + h:
        chev.append(Polygon([(x, 0), (x + h*0.45, 0), (x + h*0.45 + h*0.55, h), (x + h*0.55, h)]))
        x += h*1.25
    f = font('Orbitron-VariableFont_wght.ttf', 900)
    seg = U(word(f, text, h*0.46, gap=h*0.12))
    sb = seg.bounds; sw = sb[2]-sb[0]
    labels = []; plates = []
    k = 0; x = h*1.4
    while x + sw < L - h*1.2:
        lbl = affinity.translate(seg, x - sb[0], h*0.73)
        labels.append(lbl); plates.append(box(x - h*0.35, h*0.12, x + sw + h*0.35, h*0.88))
        x += sw + h*4.5
    plates = U(plates) if plates else Polygon()
    chev = U(chev).intersection(poly).difference(plates.buffer(h*0.06))
    lab = U(labels) if labels else Polygon()
    T = lambda g: affinity.translate(affinity.rotate(g, ang, origin=(0, 0), use_radians=False), x0, y0)
    poly, chev, plates, lab = T(poly), T(chev), T(plates.intersection(poly)), T(lab)
    sv.path(affinity.translate(poly, h*0.12, h*0.25), '#000000', f'opacity="{0.55*opacity}"')
    sv.path(poly, LIME, f'opacity="{opacity}"')
    sv.path(chev, '#0B0B12', f'opacity="{opacity}"')
    sv.path(lab, '#0B0B12', f'opacity="{opacity}"')
    sv.path(edges(poly, 0, h*0.08), '#F2FFB8', f'opacity="{0.7*opacity}"')
    return poly

def word_layers(sv, g, seed=5, amp=16, detail=1.0):
    rnd = random.Random(seed)
    b = g.bounds; hgt = b[3]-b[1]
    k = amp / 16.0
    spec = [(0.00, 0.16, 0), (0.16, 0.30, 11), (0.30, 0.47, 0), (0.47, 0.50, -26), (0.50, 0.70, 0), (0.70, 0.735, 30),
            (0.735, 0.88, -6), (0.88, 1.0, 0)]
    if detail <= 0.5: spec = [(0.0, 0.2, 0), (0.2, 0.28, 9), (0.28, 0.6, 0), (0.6, 0.66, -12), (0.66, 1.0, 0)]
    y0, y1 = b[1]-2, b[3]+2
    bands = [(y0 + (y1-y0)*a, y0 + (y1-y0)*c, dx*k) for a, c, dx in spec]
    gs = cut(g, bands)
    sb = gs.bounds
    # datamosh smear streaks from displaced bands
    for a, c, dx in bands:
        if dx == 0 or c - a < 2.5: continue
        pc = gs.intersection(box(-1e5, a, 1e5, c))
        if pc.is_empty: continue
        pb = pc.bounds
        sgn = 1 if dx > 0 else -1
        x0 = pb[2] if sgn > 0 else pb[0]
        ln = rnd.uniform(40, 120) * (1 if detail > 0.5 else 0.4)
        col = rnd.choice([MG, CY, '#FFFFFF'])
        gr = sv.lin(x0, 0, x0 + sgn*ln, 0, [(0, col, 0.85), (1, col, 0)])
        sv.add(f'<rect x="{min(x0, x0+sgn*ln):.1f}" y="{a:.2f}" width="{ln:.1f}" height="{c-a:.2f}" fill="{gr}"/>')
    # pixel blocks (data-mosh)
    if detail > 0.5:
        for _ in range(60):
            q = rnd.choice([2.5, 3.5, 5])
            x = round(rnd.uniform(sb[0]-40, sb[2]+60)/q)*q; y = round(rnd.uniform(sb[1]-8, sb[3]+8)/q)*q
            if gs.contains(Point(x, y)) and rnd.random() < 0.7: continue
            col = rnd.choice([MG, CY, CY, '#FFFFFF', NV, LIME])
            sv.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{q*rnd.choice([1, 2, 3, 6]):.1f}" height="{q:.1f}" fill="{col}" opacity="{rnd.uniform(0.5, 0.95):.2f}"/>')
    # bloom
    sv.bloom(gs.buffer(1), MG, 100, passes=((0.40, 0.4), (0.12, 0.5)), solid=False)
    # heavy RGB split (ghost bands only cyan/magenta)
    sv.path(affinity.translate(gs, -4.0, -0.6), CY, 'opacity="0.95"')
    sv.path(affinity.translate(gs, 4.0, 0.8), MG, 'opacity="0.95"')
    # signal-lost bands: punch holes in face so only RGB ghosts show
    ghost = U([box(-1e5, a, 1e5, c) for a, c, dx in bands if abs(dx) > amp*1.4])
    face = gs.difference(ghost) if detail > 0.5 else gs
    sv.path(face.buffer(1.4, join_style=2), NV)
    sv.path(face, sv.lin(0, sb[1], 0, sb[3], [(0, '#FFFFFF'), (0.45, '#FFE6FA'), (0.7, '#FF8BEA'), (1, MG)]))
    sv.path(edges(g, 1.0, 1.8).intersection(face), '#FFFFFF', 'opacity="0.0"')
    cp = sv.clip(face)
    sv.add(f'<g clip-path="url(#{cp})">' + sv.scan(sb[0]-30, sb[1]-3, sb[2]-sb[0]+60, sb[3]-sb[1]+6, 2.0 if detail > 0.5 else 3.6, 0.28, '#2A0630') + '</g>')
    nz = sv.noise(1.1, 0.16, seed=9)
    sv.add(f'<g clip-path="url(#{cp})"><rect x="{sb[0]-30:.1f}" y="{sb[1]-5:.1f}" width="{sb[2]-sb[0]+60:.1f}" height="{sb[3]-sb[1]+10:.1f}" fill="#fff" filter="url(#{nz})"/></g>')
    # bright tear lines
    for a, c, dx in bands:
        if abs(dx) > amp*0.5:
            sv.add(f'<rect x="{sb[0]-rnd.uniform(10, 50):.1f}" y="{a-0.3:.2f}" width="{sb[2]-sb[0]+rnd.uniform(40, 110):.1f}" height="0.6" fill="#FFFFFF" opacity="0.8"/>')
    return gs

def emblem_layers(sv, cx, cy, R, seed=3, amp=0.22, detail=1.0):
    rnd = random.Random(seed)
    e = emblem(cx, cy, R)
    bands = mkbands(cy - R*1.05, cy + R*0.95, 9 if detail > 0.5 else 6, rnd, R*amp, keep=0.5)
    E = {k: cut(v, bands) for k, v in e.items()}
    head = E['head']
    sv.bloom(solid(head).buffer(R*0.04), MG, R*1.2, passes=((0.35, 0.30), (0.1, 0.5)), solid=False)
    sv.path(affinity.translate(head, -R*0.05, 0), CY, 'opacity="0.95"')
    sv.path(affinity.translate(head, R*0.05, R*0.01), MG, 'opacity="0.95"')
    sv.path(head.buffer(R*0.015, join_style=2), NV)
    sv.path(head, sv.lin(cx, cy-R, cx, cy+R, [(0, '#3B3F6E'), (0.5, '#1E2048'), (1, '#0C0D24')]))
    sv.path(E['inner_ear'], MG)
    for k in ('brow', 'muzzle'):
        sv.path(E[k], sv.lin(cx, cy-R*0.6, cx, cy+R*0.8, [(0, '#FFFFFF'), (1, '#FFC1F2')]))
    sv.path(E['mask'].buffer(R*0.02, join_style=2), '#000000')
    sv.path(E['mask'], sv.lin(cx, cy-R*0.4, cx, cy+R*0.25, [(0, '#16102E'), (1, '#050510')]))
    sv.path(edges(E['mask'], 0, R*0.035), MG)
    sv.bloom(E['eyes'], LIME, R*0.9, core=E['eyes'].buffer(-R*0.03, join_style=2), passes=((0.25, 0.6), (0.08, 0.9)))
    sv.path(E['nose'], NV)
    hb = head.bounds
    cp = sv.clip(head)
    sv.add(f'<g clip-path="url(#{cp})">' + sv.scan(hb[0], hb[1], hb[2]-hb[0], hb[3]-hb[1], R*0.035, 0.25, '#000') + '</g>')
    for a, c, dx in bands:
        if abs(dx) > R*amp*0.5:
            sv.add(f'<rect x="{hb[0]-R*0.3:.1f}" y="{a-R*0.004:.2f}" width="{hb[2]-hb[0]+R*0.6:.1f}" height="{R*0.008:.2f}" fill="#FFFFFF" opacity="0.8"/>')
    return solid(head).buffer(R*0.1).bounds

def label(sv, text, cx, y, cap):
    t = secondary(text, cap, 0.5, 800)
    tb = t.bounds; t = affinity.translate(t, cx - (tb[0]+tb[2])/2, y - tb[3]); t = shear(t, 12, origin=(cx, y)); tb = t.bounds
    plate = shear(box(tb[0]-cap*1.0, tb[1]-cap*0.45, tb[2]+cap*1.6, tb[3]+cap*0.45), 12, origin=(cx, y))
    sv.path(plate, '#0A0E27', 'opacity="0.9"')
    sv.path(plate.difference(plate.buffer(-cap*0.08, join_style=2)), MG, 'opacity="0.8"')
    cur = shear(box(tb[2]+cap*0.5, tb[1], tb[2]+cap*1.1, tb[3]), 12, origin=(cx, y))
    sv.path(affinity.translate(t, -cap*0.12, 0), CY, 'opacity="0.9"')
    sv.path(affinity.translate(t, cap*0.12, 0), MG, 'opacity="0.9"')
    sv.path(t, '#FFFFFF')
    sv.bloom(cur, LIME, cap*1.5, passes=((0.3, 0.6),))
    return plate.bounds

def full():
    sv = Svg('b2f')
    g, L = bandit()
    gb = g.bounds
    R = 62
    ex = gb[0] - R*1.5; ey = (gb[1]+gb[3])/2 - 12
    tape(sv, ex - R*0.6, gb[3] + 40, gb[2] + 70, gb[3] - 18, 20, 'SIGNAL LOST', seed=2)
    eb = emblem_layers(sv, ex, ey, R)
    tb = label(sv, 'THE NEON CITY', (gb[0]+gb[2])/2 + 20, gb[1] - 14, 13)
    word_layers(sv, g)
    allb = (min(eb[0], gb[0]) - 70, min(eb[1], tb[1]) - 30, gb[2] + 160, max(eb[3], gb[3]) + 75)
    return sv.out((allb[0], allb[1], allb[2]-allb[0], allb[3]-allb[1]), pad=70)

def compact():
    sv = Svg('b2c')
    g, L = bandit()
    gb = g.bounds; cx = (gb[0]+gb[2])/2
    R = 92; ey = gb[1] - 46 - R*0.9
    tape(sv, gb[0] - 40, gb[3] + 10, gb[2] + 50, gb[3] - 50, 24, 'SIGNAL LOST', seed=4)
    eb = emblem_layers(sv, cx - 6, ey, R, detail=0.4)
    tb = label(sv, 'THE NEON CITY', cx + 4, gb[1] - 14, 15)
    word_layers(sv, g, amp=10, detail=0.4)
    allb = (gb[0] - 70, eb[1] - 30, gb[2] + 80, gb[3] + 60)
    return sv.out((allb[0], allb[1], allb[2]-allb[0], allb[3]-allb[1]), pad=70)

def icon():
    sv = Svg('b2i')
    sv.add(f'<rect width="1024" height="1024" fill="{sv.rad(512, 480, 760, [(0, "#24103F"), (0.5, "#0E0A26"), (1, "#040410")])}"/>')
    rnd = random.Random(12)
    for _ in range(120):
        q = rnd.choice([8, 12, 16, 24]); x = rnd.randrange(0, 1024, 8); y = rnd.randrange(0, 1024, 8)
        sv.add(f'<rect x="{x}" y="{y}" width="{q*rnd.choice([1, 2, 4, 8])}" height="{q}" fill="{rnd.choice([MG, CY, NV, "#FFFFFF"])}" opacity="{rnd.uniform(0.05, 0.3):.2f}"/>')
    tape(sv, -60, 930, 1100, 700, 70, 'SIGNAL LOST', seed=7, opacity=0.95)
    emblem_layers(sv, 512, 500, 300, seed=8, amp=0.16)
    sv.add(sv.scan(0, 0, 1024, 1024, 5, 0.18, '#000'))
    nz = sv.noise(0.8, 0.1, seed=2)
    sv.add(f'<rect width="1024" height="1024" fill="#fff" filter="url(#{nz})"/>')
    return sv.out((0, 0, 1024, 1024))

if __name__ == '__main__':
    o = '/workspace/logo/round2/'
    s = full(); open(o+'B2_broken_signal.svg', 'w').write(s); render(s, o+'B2_broken_signal.png', 2048)
    s = compact(); open(o+'B2_broken_signal_compact.svg', 'w').write(s); render(s, o+'B2_broken_signal_compact.png', 2048)
    s = icon(); open(o+'B2_broken_signal_icon.svg', 'w').write(s); render(s, o+'B2_broken_signal_icon.png', 1024)
