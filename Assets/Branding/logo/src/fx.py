import sys; sys.path.insert(0, '/workspace/logo/src'); sys.path.insert(0, '/workspace/logo/round2/src')
from lib import *
from glyphs import *
CY, MG, NV, LIME, YEL = '#00F0FF', '#FF2BD6', '#0A0E27', '#C6FF1A', '#FFE14D'

class Svg:
    def __init__(self, prefix):
        self.p = prefix; self.defs = []; self.body = []; self.n = 0
    def id(self, k):
        self.n += 1; return f'{self.p}{k}{self.n}'
    def blur(self, std, extra=''):
        i = self.id('bl')
        self.defs.append(f'<filter id="{i}" x="-60%" y="-120%" width="220%" height="340%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="{std:.2f}"/>{extra}</filter>')
        return i
    def lin(self, x1, y1, x2, y2, stops):
        i = self.id('lg')
        st = ''.join(f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{a}"' if a is not None else '') + '/>' for o, c, a in [(s + (None,))[:3] for s in stops])
        self.defs.append(f'<linearGradient id="{i}" gradientUnits="userSpaceOnUse" x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}">{st}</linearGradient>')
        return f'url(#{i})'
    def rad(self, cx, cy, r, stops):
        i = self.id('rg')
        st = ''.join(f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{a}"' if a is not None else '') + '/>' for o, c, a in [(s + (None,))[:3] for s in stops])
        self.defs.append(f'<radialGradient id="{i}" gradientUnits="userSpaceOnUse" cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}">{st}</radialGradient>')
        return f'url(#{i})'
    def noise(self, freq, alpha, seed=3, stretch=None):
        i = self.id('nz')
        bf = f'{freq}' if stretch is None else f'{stretch[0]} {stretch[1]}'
        self.defs.append(f'<filter id="{i}" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feTurbulence type="fractalNoise" baseFrequency="{bf}" numOctaves="2" seed="{seed}" result="n"/>'
                         f'<feColorMatrix in="n" type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  1 0 0 0 0" result="w"/>'
                         f'<feComponentTransfer in="w" result="w2"><feFuncA type="linear" slope="{alpha*2.2:.3f}" intercept="{-alpha*0.6:.3f}"/></feComponentTransfer>'
                         f'<feComposite in="w2" in2="SourceGraphic" operator="in"/></filter>')
        return i
    def clip(self, g):
        i = self.id('cp'); self.defs.append(f'<clipPath id="{i}"><path d="{d(g)}"/></clipPath>'); return i
    def scan(self, x, y, w, h, gap, dark=0.5, color=NV):
        """horizontal scanline pattern as explicit rects (no tiling seams)"""
        rows = []; yy = y
        while yy < y + h:
            rows.append(f'M{x:.1f} {yy:.2f}h{w:.1f}v{gap*0.42:.2f}h{-w:.1f}Z'); yy += gap
        return f'<path d="{"".join(rows)}" fill="{color}" fill-opacity="{dark}"/>'
    def add(self, s): self.body.append(s)
    def path(self, g, fill, extra=''):
        if g is None or g.is_empty: return
        self.body.append(f'<path d="{d(g)}" fill="{fill}" {extra}/>')
    def bloom(self, g, color, scale, core=None, passes=((0.45, 0.35), (0.16, 0.6), (0.05, 0.9)), solid=True):
        """multi-pass gaussian neon bloom + optional hot core shape"""
        dd = d(g)
        for std, op in passes:
            f = self.blur(std * scale)
            self.body.append(f'<g filter="url(#{f})" opacity="{op}"><path d="{dd}" fill="{color}"/></g>')
        if solid: self.body.append(f'<path d="{dd}" fill="{color}"/>')
        if core is not None and not core.is_empty: self.body.append(f'<path d="{d(core)}" fill="#FFFFFF"/>')
    def out(self, vb, width=None, pad=0):
        x, y, w, h = vb
        x -= pad; y -= pad; w += 2*pad; h += 2*pad
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:.2f} {y:.2f} {w:.2f} {h:.2f}" width="{w if width is None else width:.0f}" height="{h if width is None else width*h/w:.0f}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

def slices(g, bands, bounds=None):
    """bands: list of (y0, y1, dx). returns (moved geometry, list of moved band pieces)"""
    rest = g; pieces = []
    for y0, y1, dx in bands:
        b = box(-1e5, y0, 1e5, y1)
        sl = g.intersection(b); rest = rest.difference(b)
        pieces.append(affinity.translate(sl, dx, 0))
    return U([rest] + pieces), pieces

def solid(g):
    ps = [g] if isinstance(g, Polygon) else [p for p in g.geoms if isinstance(p, Polygon)]
    return U([Polygon(p.exterior) for p in ps])

def secondary(text, cap, track=0.55, wght=600):
    f = font('Orbitron-VariableFont_wght.ttf', wght)
    return U(word(f, text, cap, gap=cap*track))

def edges(g, dx, dy):
    """highlight edge band facing (-dx,-dy) direction"""
    return g.difference(affinity.translate(g, dx, dy))

def save(svg, path, width=2048):
    open(path.replace('.png', '.svg'), 'w').write(svg) if path.endswith('.png') and False else None
    render(svg, path, width)
