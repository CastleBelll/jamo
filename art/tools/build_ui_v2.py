"""JAMO v2 painterly UI source builder (Pillow + NumPy, straight-alpha PNG)."""
from pathlib import Path
import math
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ART = Path(__file__).resolve().parents[1]
INK = (34, 29, 25)
CREAM = (246, 225, 186)
GOLD = (190, 139, 62)


def save(im, name, folder="ui"):
    dst = ART / folder / (name + ".png")
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGBA").save(dst, optimize=True)


def material(mask, color, seed=1, amount=5):
    rng = np.random.default_rng(seed)
    a = np.asarray(mask).astype(np.uint8)
    h, w = a.shape
    grain = rng.normal(0, amount, (h, w))
    grain += np.sin(np.arange(w)[None, :] * .06) * amount * .2
    rgb = np.stack([np.clip(c + grain, 0, 255) for c in color], axis=2).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def rough_stroke(size, seed=1, pressed=False):
    w, h = size
    rng = random.Random(seed)
    im = Image.new("L", size)
    d = ImageDraw.Draw(im)
    top = h * (.26 if pressed else .19)
    bot = h * (.76 if pressed else .81)
    points = [(x, top + rng.uniform(-4, 4)) for x in range(30, w-22, 5)]
    points += [(x, bot + rng.uniform(-4, 4)) for x in range(w-24, 26, -5)]
    d.polygon(points, fill=255)
    # Bristle tails and wet bleed are confined to the 48px slice end caps.
    for _ in range(100):
        y = rng.uniform(top-3, bot+3)
        left = rng.randrange(4, 48)
        right = rng.randrange(w-48, w-3)
        d.line((left, y, 55, y+rng.uniform(-3,3)), fill=rng.randrange(80,240), width=rng.randrange(1,4))
        d.line((w-55, y, right, y+rng.uniform(-3,3)), fill=rng.randrange(80,240), width=rng.randrange(1,4))
    return im


def composite_shadow(im, radius=7, offset=(2,5), opacity=.3):
    a = im.getchannel("A")
    sh = a.filter(ImageFilter.GaussianBlur(radius)).point(lambda v:int(v*opacity))
    sh = ImageChops.offset(sh, *offset)
    base = Image.new("RGBA", im.size, (18,12,8,0))
    base.putalpha(sh)
    return Image.alpha_composite(base, im)


def buttons():
    for kind, names in (("ink", ["normal","hover","pressed","disabled"]), ("paper", ["normal","hover","pressed"])):
        for idx, state in enumerate(names):
            mask = rough_stroke((512,112), 230+idx, state=="pressed")
            if state == "hover":
                bleed = mask.filter(ImageFilter.GaussianBlur(4)).point(lambda v:int(v*.32))
                mask = ImageChops.lighter(mask, bleed)
            if kind == "ink":
                color = (44,37,31) if state=="hover" else ((23,20,18) if state=="pressed" else INK)
                if state=="disabled": color=(90,86,80); mask=mask.point(lambda v:int(v*.55))
            else:
                color = (255,237,202) if state=="hover" else ((224,199,156) if state=="pressed" else CREAM)
            im = material(mask, color, seed=30+idx, amount=3 if kind=="ink" else 4)
            save(composite_shadow(im,3,(0,3),.24), f"btn_{kind}_{state}")


def panels():
    rng=random.Random(501)
    mask=Image.new("L",(512,512)); d=ImageDraw.Draw(mask)
    pts=[(x,20+rng.uniform(-8,8)) for x in range(24,490,8)]
    pts += [(490+rng.uniform(-6,6),y) for y in range(20,492,8)]
    pts += [(x,490+rng.uniform(-8,8)) for x in range(490,22,-8)]
    pts += [(20+rng.uniform(-6,6),y) for y in range(492,20,-8)]
    d.polygon(pts,fill=255)
    paper=material(mask, CREAM, 58, 3)
    fibers=Image.new("RGBA",(512,512)); pd=ImageDraw.Draw(fibers)
    for _ in range(850):
        x,y=rng.randrange(30,482),rng.randrange(30,482)
        pd.line((x,y,x+rng.randrange(2,8),y+1), fill=(167,139,95,rng.randrange(8,22)),width=1)
    paper=Image.alpha_composite(paper,fibers)
    save(composite_shadow(paper,8,(0,6),.32),"panel_paper")
    ink_mask=Image.new("L",(512,512)); d=ImageDraw.Draw(ink_mask)
    pts=[(x,18+rng.uniform(-5,5)) for x in range(20,495,6)]
    pts += [(495+rng.uniform(-4,4),y) for y in range(18,495,6)]
    pts += [(x,495+rng.uniform(-5,5)) for x in range(495,18,-6)]
    pts += [(18+rng.uniform(-4,4),y) for y in range(495,18,-6)]
    d.polygon(pts,fill=223)
    save(material(ink_mask,INK,61,2),"panel_ink")


def hud_bar():
    w,h=1920,140
    yy,xx=np.mgrid[0:h,0:w]
    grain=np.sin(yy*.32+np.sin(xx*.008)*1.3)*4 + np.sin(yy*.78+xx*.002)*2
    rgb=np.stack([np.clip(c+grain,0,255) for c in (45,31,23)],axis=2).astype(np.uint8)
    alpha=np.clip((140-yy)/32,0,1)*245
    im=Image.fromarray(np.dstack([rgb,alpha.astype(np.uint8)]),"RGBA")
    d=ImageDraw.Draw(im); d.line((0,104,w,104),fill=(166,117,53,100),width=2)
    save(im,"hud_bar")


def ring(size=160, empty=False):
    rng=random.Random(140 if empty else 141)
    scale=3; mask=Image.new("L",(size*scale,size*scale)); d=ImageDraw.Draw(mask)
    for j in range(4):
        pts=[]
        for i in range(170):
            ang=i/169*math.tau
            r=(size*.39+j*.8+rng.uniform(-1.6,1.6))*scale
            pts.append((size*scale/2+math.cos(ang)*r,size*scale/2+math.sin(ang)*r))
        if empty:
            for start in range(0,160,18): d.line(pts[start:start+11],fill=150,width=3*scale)
        else:d.line(pts,fill=230,width=3*scale)
    im=material(mask,INK,17,3).resize((size,size),Image.Resampling.LANCZOS)
    save(im,"slot_frame_empty" if empty else "slot_frame")


def bars_tabs():
    for name,color in (("bar_track",INK),("bar_fill",GOLD)):
        mask=rough_stroke((512,40),711 if name=="bar_track" else 712)
        save(material(mask,color,11,3),name)
    for active in (False,True):
        mask=Image.new("L",(256,80)); d=ImageDraw.Draw(mask)
        d.polygon([(12,5),(244,7),(246,63),(226,63),(216,77),(204,64),(10,64)],fill=255 if active else 216)
        im=material(mask,CREAM if active else INK,901,4)
        d=ImageDraw.Draw(im); d.line((25,57,220,57),fill=GOLD+(130,),width=2)
        save(composite_shadow(im,2,(1,2),.2),"tab_active" if active else "tab_inactive")
    im=Image.new("RGBA",(32,16)); d=ImageDraw.Draw(im)
    d.polygon([(1,1),(30,1),(16,15)],fill=INK+(225,))
    save(im,"tooltip_arrow")


def group_c():
    buttons();panels();hud_bar();ring();ring(empty=True);bars_tabs()


if __name__ == "__main__":
    if len(sys.argv)==1 or sys.argv[1]=="C":group_c()
