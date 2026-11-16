from PIL import Image, ImageDraw, ImageFont
import os
os.chdir('/workspace/logo/round2')
names = {'B1': ('B1_holo_glass', 'CLEAN HOLO GLASS + GLITCH SLICES'), 'B2': ('B2_broken_signal', 'BROKEN SIGNAL / DATA-MOSH'), 'B3': ('B3_neon_hardware', 'NEON-SIGN HARDWARE')}
CW = 1100; pad = 50; OF = '/workspace/logo/fonts/Orbitron-VariableFont_wght.ttf'
def F(sz, w): f = ImageFont.truetype(OF, sz); f.set_variation_by_axes([w]); return f
def fit(im, w): return im.resize((w, int(im.height*w/im.width)), Image.LANCZOS)
cols = []
for k, (n, label) in names.items():
    cols.append((k, label, fit(Image.open(f'{n}.png'), CW-2*pad), fit(Image.open(f'{n}_compact.png'), 560),
                 Image.open(f'{n}_icon.png').convert('RGBA').resize((380, 380), Image.LANCZOS),
                 Image.open(f'{n}_icon.png').convert('RGBA').resize((120, 120), Image.LANCZOS),
                 fit(Image.open(f'{n}_mockup.png').convert('RGBA'), 640)))
LGH = max(c[2].height for c in cols); CPH = max(max(c[3].height, 520) for c in cols); MH = max(c[6].height for c in cols)
H = 160 + LGH + 50 + CPH + 60 + MH + 60
G = 30; sheet = Image.new('RGBA', (3*CW+4*G, H+2*G+80), (6, 8, 20, 255))
for i, (k, label, lg, cp, ic, ict, mock) in enumerate(cols):
    col = Image.new('RGBA', (CW, H), (12, 15, 38, 255)); dr = ImageDraw.Draw(col)
    dr.text((pad, 30), k, font=F(96, 900), fill=(0, 240, 255)); dr.text((pad+190, 74), label, font=F(32, 600), fill=(255, 255, 255))
    y = 160; col.alpha_composite(lg, (pad, y+(LGH-lg.height)//2)); y += LGH+50
    col.alpha_composite(cp, (pad-10, y+(CPH-cp.height)//2))
    col.alpha_composite(ic, (pad+570, y)); col.alpha_composite(ict, (pad+570+380-120, y+395))
    dr.text((pad+570, y+400), 'APP ICON 1024', font=F(22, 700), fill=(0, 240, 255)); dr.text((pad+570, y+432), 'at 380px and 120px', font=F(18, 500), fill=(140, 150, 200))
    y += CPH+60; col.alpha_composite(mock, ((CW-mock.width)//2, y))
    sheet.alpha_composite(col, (G+i*(CW+G), G))
dr = ImageDraw.Draw(sheet)
dr.text((G, H+2*G+12), 'THE NEON CITY BANDIT  -  ROUND 2  -  B1 / B2 / B3  -  original code-generated art; custom BANDIT letterforms; OFL Orbitron for secondary text', font=F(30, 500), fill=(150, 160, 210))
sheet.convert('RGB').save('round2_sheet.png', optimize=True)
sheet.resize((sheet.width//3, sheet.height//3), Image.LANCZOS).convert('RGB').save('/tmp/r2sheet.png')
print(sheet.size)
