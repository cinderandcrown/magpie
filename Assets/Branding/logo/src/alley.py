from fx import *
import random, io
from PIL import Image, ImageFilter
import numpy as np
W, H = 1179, 2556
VX, VY = 590, 1330
FL, FR, FT, FB = 455, 725, 1080, 1470   # far-end rectangle (back of alley)
NL_TOP, NL_BOT = -300, 2050          # near-edge wall top/bottom y

def lerp(a, b, t): return a + (b - a) * t
def wallpt(side, u, v):
    """u: 0 near .. 1 far ; v: 0 top .. 1 bottom. returns point on wall"""
    xn = 0 if side < 0 else W; xf = FL if side < 0 else FR
    # perspective-ish: depth parameter non-linear
    t = 1 - 1 / (1 + 3.2 * u); t /= (1 - 1 / 4.2)
    x = lerp(xn, xf, t)
    yt = lerp(NL_TOP, FT, t); yb = lerp(NL_BOT, FB, t)
    return x, lerp(yt, yb, v)

def quad(side, u0, u1, v0, v1):
    return Polygon([wallpt(side, u0, v0), wallpt(side, u1, v0), wallpt(side, u1, v1), wallpt(side, u0, v1)])

def backdrop(seed=21):
    rnd = random.Random(seed)
    sv = Svg('al')
    sv.add(f'<rect width="{W}" height="{H}" fill="#03040B"/>')
    # sky slit + far haze
    sv.add(f'<rect width="{W}" height="{H}" fill="{sv.lin(0, 0, 0, H, [(0, "#0A0D24"), (0.42, "#120A2A"), (0.55, "#1E0B33"), (0.6, "#07081A"), (1, "#020309")])}"/>')
    haze = sv.rad(VX, 1290, 520, [(0, '#FF2BD6', 0.55), (0.35, '#7A1CA0', 0.35), (1, '#0A0E27', 0)])
    sv.add(f'<rect x="0" y="700" width="{W}" height="1200" fill="{haze}"/>')
    # far back wall with distant signs
    back = box(FL, FT, FR, FB)
    sv.path(back, '#0B0A1E')
    for i in range(7):
        x = rnd.uniform(FL+10, FR-30); y = rnd.uniform(FT+20, FB-120); w = rnd.uniform(8, 40); h = rnd.uniform(6, 70)
        c = rnd.choice([CY, MG, MG, YEL])
        sv.bloom(box(x, y, x+w, y+h), c, 30, passes=((0.6, 0.5), (0.2, 0.7)))
    # walls
    for side in (-1, 1):
        wall = quad(side, 0, 1, 0, 1)
        sv.path(wall, sv.lin(0 if side < 0 else W, 0, FL if side < 0 else FR, 0, [(0, '#07081A'), (0.6, '#121433'), (1, '#24123F')]))
        # floor lines
        lines = []
        for v in np.linspace(0.04, 0.98, 26):
            a, b = wallpt(side, 0, v), wallpt(side, 1, v)
            lines.append(f'M{a[0]:.1f} {a[1]:.1f}L{b[0]:.1f} {b[1]:.1f}')
        sv.add(f'<path d="{"".join(lines)}" stroke="#1C1A3A" stroke-width="1.5" opacity="0.6"/>')
        # windows
        for u in np.linspace(0.05, 0.9, 7):
            for v in (0.12, 0.27, 0.42):
                if rnd.random() < 0.55:
                    q = quad(side, u, u + 0.05, v, v + 0.08)
                    lit = rnd.random() < 0.35
                    col = rnd.choice(['#22306A', '#3A1A5A', '#7A4A3A']) if lit else '#0A0B18'
                    sv.path(q, col, f'opacity="{0.55 if lit else 0.9}"')
                    sv.path(q.difference(q.buffer(-2)), '#000', 'opacity="0.6"')
        # vertical pipes
        for u in (0.02, 0.33, 0.61):
            a, b = wallpt(side, u, 0.0), wallpt(side, u, 0.93)
            sv.add(f'<path d="M{a[0]:.1f} {a[1]:.1f}L{b[0]:.1f} {b[1]:.1f}" stroke="#15172E" stroke-width="{14*(1-u)+3:.1f}"/>')
            sv.add(f'<path d="M{a[0]+3:.1f} {a[1]:.1f}L{b[0]+3:.1f} {b[1]:.1f}" stroke="#2E3360" stroke-width="{3*(1-u)+1:.1f}" opacity="0.7"/>')
        # AC units
        for u, v in ((0.18, 0.58), (0.48, 0.5)):
            q = quad(side, u, u + 0.06, v, v + 0.06)
            sv.path(q, '#1A1D36'); sv.path(q.buffer(-3), '#11132A')
    # neon blade signs projecting from walls
    signs = [(-1, 0.10, 0.56, 0.26, MG, 'BAR'), (-1, 0.42, 0.58, 0.14, CY, None), (1, 0.16, 0.55, 0.28, CY, 'HOTEL'), (1, 0.55, 0.58, 0.12, MG, None), (-1, 0.70, 0.62, 0.08, YEL, None), (1, 0.80, 0.60, 0.07, MG, None)]
    refl = []
    fo = font('Orbitron-VariableFont_wght.ttf', 800)
    for side, u, v, hh, col, txt in signs:
        x, y = wallpt(side, u, v)
        x2, y2 = wallpt(side, u, v + hh)
        depth = (1 - u) * 110 + 18
        xi = x - side * depth
        blade = Polygon([(x, y), (xi, y + 8), (xi, y2 - 8), (x, y2)])
        sv.path(blade, '#0B0C1C')
        frame = blade.difference(blade.buffer(-max(2.5, 7*(1-u)), join_style=2))
        sv.bloom(frame, col, 40*(1-u)+12, passes=((0.9, 0.35), (0.3, 0.6), (0.08, 0.9)))
        if txt:
            t = U(word(fo, txt[0], 10, gap=0))
            hgt_ = (y2 - y) * 0.8 / len(txt)
            letters = []
            for i, ch in enumerate(txt):
                gl = U(word(fo, ch, 1, gap=0)); gb = gl.bounds
                k = min(hgt_ * 0.72, abs(xi - x) * 0.6) / max(gb[3]-gb[1], 1e-6)
                gl = affinity.scale(gl, k, k, origin=(0, 0)); gb = gl.bounds
                cxx = (x + xi) / 2; cyy = y + (y2 - y) * 0.1 + hgt_ * (i + 0.5)
                letters.append(affinity.translate(gl, cxx - (gb[0]+gb[2])/2, cyy - (gb[1]+gb[3])/2))
            sv.bloom(U(letters), col, 22*(1-u)+6, core=None, passes=((0.6, 0.5), (0.15, 0.8)))
            sv.path(U(letters), '#FFFFFF', 'opacity="0.85"')
        else:
            for k in range(4):
                yy = y + (y2 - y) * (0.15 + k * 0.2)
                bar = box(min(x, xi) + abs(xi-x)*0.25, yy, max(x, xi) - abs(xi-x)*0.25, yy + (y2-y)*0.08)
                sv.bloom(bar, col, 15*(1-u)+4, passes=((0.5, 0.5),))
        refl.append(((x + xi) / 2, abs(xi - x), y2, col, 1 - u))
    for side in (-1, 1):
        a, b = wallpt(side, 0, 1), wallpt(side, 1, 1)
        seam = LineString([a, b]).buffer(3)
        sv.bloom(seam, MG if side < 0 else CY, 30, passes=((0.6, 0.35), (0.15, 0.5)), solid=False)
    # ground
    gl, gr = wallpt(-1, 0, 1), wallpt(1, 0, 1)
    ground = Polygon([gl, (FL, FB), (FR, FB), gr, (W, H), (0, H)])
    sv.path(ground, sv.lin(0, FB, 0, H, [(0, '#1A0A2C'), (0.25, '#0A0816'), (1, '#030308')]))
    cp = sv.clip(ground)
    rparts = [f'<g clip-path="url(#{cp})">']
    # haze reflection
    rparts.append(f'<rect x="{FL-60}" y="{FB}" width="{FR-FL+120}" height="900" fill="{sv.lin(0, FB, 0, FB+700, [(0, MG, 0.30), (1, MG, 0)])}" filter="url(#{sv.blur(40)})"/>')
    for cx, w, y2, col, near in refl:
        ry = FB + (FB - y2) * 0.0 + (2100 - FB) * (1 - near) * 0 
        top = max(FB + 10, lerp(FB, 2200, near) - 250)
        rparts.append(f'<rect x="{cx - w*0.4:.1f}" y="{top:.1f}" width="{w*0.8:.1f}" height="{500*near+150:.1f}" fill="{col}" opacity="{0.25+0.25*near:.2f}" filter="url(#{sv.blur(10+18*near)})"/>')
    # wet streaks + puddle ripples
    for _ in range(60):
        y = rnd.uniform(FB + 20, H); x = rnd.uniform(0, W); w = rnd.uniform(30, 200) * (y - FB) / (H - FB)
        rparts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{rnd.uniform(1, 3):.1f}" fill="#8FE9FF" opacity="{rnd.uniform(0.04, 0.14):.2f}"/>')
    for _ in range(14):
        x = rnd.uniform(80, W-80); y = rnd.uniform(FB + 200, H - 300); rx = rnd.uniform(30, 90) * (y - FB) / (H - FB) + 10
        for k in range(3):
            rparts.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx*(1+k*0.6):.1f}" ry="{rx*(1+k*0.6)*0.18:.1f}" fill="none" stroke="#B7F6FF" stroke-width="1.4" opacity="{0.18-k*0.05:.2f}"/>')
    rparts.append('</g>')
    sv.add(''.join(rparts))
    # light shafts
    sv.add(f'<path d="M{VX-40} {FT} L{VX+40} {FT} L{VX+380} {H} L{VX-380} {H}Z" fill="{sv.lin(0, FT, 0, H, [(0, "#FF2BD6", 0.10), (1, "#FF2BD6", 0)])}"/>')
    # rain
    rain = []
    for _ in range(520):
        x = rnd.uniform(-50, W + 50); y = rnd.uniform(-50, H); l = rnd.uniform(25, 110)
        rain.append(f'M{x:.1f} {y:.1f}l{-l*0.14:.1f} {l:.1f}')
    sv.add(f'<path d="{"".join(rain)}" stroke="#A9EEFF" stroke-width="1.6" opacity="0.16"/>')
    big = []
    for _ in range(40):
        x = rnd.uniform(0, W); y = rnd.uniform(0, H); l = rnd.uniform(140, 260)
        big.append(f'M{x:.1f} {y:.1f}l{-l*0.14:.1f} {l:.1f}')
    sv.add(f'<g filter="url(#{sv.blur(2.5)})"><path d="{"".join(big)}" stroke="#D8F9FF" stroke-width="4" opacity="0.14"/></g>')
    # top darkening for logo legibility + vignette
    sv.add(f'<rect width="{W}" height="{H}" fill="{sv.lin(0, 0, 0, H, [(0, "#000", 0.65), (0.42, "#000", 0.25), (0.55, "#000", 0), (0.88, "#000", 0.1), (1, "#000", 0.75)])}"/>')
    sv.add(f'<rect width="{W}" height="{H}" fill="{sv.rad(W/2, H*0.45, H*0.75, [(0.55, "#000", 0), (1, "#000", 0.7)])}"/>')
    return sv

def ui(sv):
    f = font('Orbitron-VariableFont_wght.ttf', 700)
    tap = U(word(f, 'TAP TO START', 40, gap=40*0.3)); tb = tap.bounds
    tap = affinity.translate(tap, W/2 - (tb[0]+tb[2])/2, 2110 - (tb[1]+tb[3])/2)
    tb = tap.bounds
    sv.bloom(tap, CY, 40, passes=((0.4, 0.5), (0.12, 0.7)), solid=False)
    sv.path(tap, '#EFFFFF')
    for sg in (-1, 1):
        x = (tb[0] - 40) if sg < 0 else (tb[2] + 40)
        br = Polygon([(x, 2085), (x - sg*16, 2085), (x - sg*16, 2089), (x - sg*4, 2089), (x - sg*4, 2131), (x - sg*16, 2131), (x - sg*16, 2135), (x, 2135)])
        sv.bloom(br, MG, 20, passes=((0.4, 0.6),))
    f2 = font('Orbitron-VariableFont_wght.ttf', 500)
    for txt, x in (('SETTINGS', 150), ('LEADERBOARD', W - 150)):
        t = U(word(f2, txt, 18, gap=18*0.35)); b = t.bounds
        t = affinity.translate(t, x - (b[0]+b[2])/2, 2420 - b[3]); sv.path(t, '#8C96C8')
    v = U(word(f2, 'TITLE SCREEN MOCKUP', 14, gap=5)); b = v.bounds
    sv.path(affinity.translate(v, W/2 - (b[0]+b[2])/2, 2490 - b[3]), '#4C557F')

_bg_cache = {}
def make(logo_png, out, logo_w=1060, cy=780):
    if 'bg' not in _bg_cache:
        sv = backdrop(); ui(sv)
        _bg_cache['bg'] = Image.open(io.BytesIO(bytes(resvg_py.svg_to_bytes(svg_string=sv.out((0, 0, W, H)))))).convert('RGBA')
    bg = _bg_cache['bg'].copy()
    lg = Image.open(logo_png).convert('RGBA')
    th = int(lg.height * logo_w / lg.width); lg = lg.resize((logo_w, th), Image.LANCZOS)
    # soft dark halo behind logo for separation
    halo = Image.new('L', (W, H), 0)
    a = lg.split()[3].filter(ImageFilter.GaussianBlur(40))
    halo.paste(a, ((W - logo_w)//2, cy - th//2))
    dark = Image.new('RGBA', (W, H), (2, 3, 10, 255)); dark.putalpha(halo.point(lambda p: int(p*0.55)))
    bg.alpha_composite(dark)
    bg.alpha_composite(lg, ((W - logo_w)//2, cy - th//2))
    # film grain
    rng = np.random.default_rng(3)
    arr = np.array(bg.convert('RGB')).astype(np.int16)
    arr += rng.normal(0, 5, arr.shape[:2])[..., None].astype(np.int16)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(out, optimize=True)
