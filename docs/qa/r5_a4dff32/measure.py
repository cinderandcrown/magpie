import json, numpy as np
from PIL import Image, ImageDraw
from skimage.metrics import structural_similarity as ssim
from skimage.color import rgb2lab, deltaE_ciede2000
from skimage.feature import canny
from scipy import ndimage
Q='/workspace/qa'
B={'33257aa':f'{Q}/r3_33257aa','9db5db9':f'{Q}/r4_9db5db9','a4dff32':f'{Q}/r5_a4dff32/smoke-artifacts'}
STILLS=['01-title.png','02-midrun.png','03-mop-stomp.png','04-mask-mode.png','05-death-retry.png','06-results.png','08-daily-heist.png']
def load(p,s=0.25):
    im=Image.open(p).convert('RGB'); return np.asarray(im.resize((int(im.width*s),int(im.height*s))),dtype=np.uint8)
def masks(a):
    a=a.astype(int); r,g,b=a[...,0],a[...,1],a[...,2]
    mag=(r>180)&(b>120)&(g<110)&(r-g>90)
    teal=(g>150)&(b>150)&(r<110)
    return mag,teal
def flatmag(a,mag,blk=8):
    L=a.astype(float).mean(-1); h,w=mag.shape; h2,w2=h//blk*blk,w//blk*blk
    m=mag[:h2,:w2].reshape(h2//blk,blk,w2//blk,blk).mean((1,3))
    sd=L[:h2,:w2].reshape(h2//blk,blk,w2//blk,blk).std((1,3))
    flat=(m>0.9)&(sd<6)
    lab,n=ndimage.label(flat); big=max([ (lab==i).sum() for i in range(1,n+1)] or [0])
    return 100*flat.mean(), 100*big/flat.size
def palette(a,k=8):
    im=Image.fromarray(a).quantize(k); pal=np.array(im.getpalette()[:k*3]).reshape(k,3)/255.
    return rgb2lab(pal[None])[0]
def pdist(p1,p2):
    d=np.array([[deltaE_ciede2000(x[None],y[None])[0] for y in p2] for x in p1]); return float((d.min(1).mean()+d.min(0).mean())/2)
res={}
for b,d in B.items():
    res[b]={}
    for s in STILLS:
        try: a=load(f'{d}/{s}')
        except FileNotFoundError: continue
        mag,teal=masks(a); fm,big=flatmag(a,mag)
        res[b][s]=dict(magenta_pct=round(100*mag.mean(),2),teal_pct=round(100*teal.mean(),2),flat_magenta_pct=round(fm,2),largest_flat_magenta_blob_pct=round(big,2),mean_luma=round(float(a.mean()),1))
for s in STILLS:
    try:
        r=load(f"{B['9db5db9']}/{s}"); c=load(f"{B['a4dff32']}/{s}")
    except FileNotFoundError: continue
    res['a4dff32'][s]['ssim_vs_9db5db9']=round(float(ssim(r.mean(-1),c.mean(-1),data_range=255)),3)
    res['a4dff32'][s]['palette_dE_vs_9db5db9']=round(pdist(palette(r),palette(c)),2)
    try:
        n=load(f"{B['33257aa']}/{s}"); res['a4dff32'][s]['palette_dE_vs_33257aa']=round(pdist(palette(n),palette(c)),2)
    except FileNotFoundError: pass
    if s in ('02-midrun.png','04-mask-mode.png','03-mop-stomp.png'):
        er=canny(r.mean(-1)/255,2); ec=canny(c.mean(-1)/255,2)
        ov=np.zeros_like(c); ov[er]=[60,120,255]; ov[ec]=[255,50,50]; ov[er&ec]=[255,255,255]
        blend=(0.5*r+0.5*c).astype(np.uint8)
        Image.fromarray(np.concatenate([r,c,ov,blend],1)).save(f'{Q}/r5_a4dff32/out/overlay_{s}')
json.dump(res,open(f'{Q}/r5_a4dff32/out/scores_a4dff32.json','w'),indent=1)
print(json.dumps(res,indent=1))
