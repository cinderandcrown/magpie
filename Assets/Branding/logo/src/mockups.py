import sys; sys.path.insert(0, '/workspace/logo/round2/src')
import alley
from alley import *
from PIL import Image, ImageDraw
o = '/workspace/logo/round2/'
LW = 1170
sv = backdrop(); ui(sv)
base = Image.open(io.BytesIO(bytes(resvg_py.svg_to_bytes(svg_string=sv.out((0, 0, W, H)))))).convert('RGBA')
for n in ['B1_holo_glass', 'B2_broken_signal', 'B3_neon_hardware']:
    bg = base.copy()
    if n.startswith('B3'):
        lg = Image.open(o+n+'_compact.png'); th = int(lg.height*LW/lg.width)
        a = np.array(lg)[:, :, 3]; rows = np.where(a.max(1) > 200)[0]; cols = np.where(a.max(0) > 200)[0]
        top = 740 - th//2 + int(rows[0]*th/lg.height) + 20
        xl = (W-LW)//2 + int(cols[0]*LW/lg.width) + 90; xr = (W-LW)//2 + int(cols[-1]*LW/lg.width) - 90
        dr = ImageDraw.Draw(bg)
        for x in (xl, xr):
            for y in range(-10, top, 26):
                dr.ellipse((x-7, y, x+7, y+30), outline=(70, 78, 110, 255), width=4)
                dr.line((x-2, y+4, x-2, y+26), fill=(130, 140, 180, 255), width=1)
    alley._bg_cache['bg'] = bg
    make(o+n+'_compact.png', o+n+'_mockup.png', logo_w=LW, cy=740)
