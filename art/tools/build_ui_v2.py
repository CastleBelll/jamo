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
    shifted=Image.new("L",im.size)
    shifted.paste(sh,offset)
    sh=shifted
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


def painted_icon(name, size=64):
    scale=4; base=64
    ink=Image.new("L",(base*scale,base*scale)); gold=Image.new("L",ink.size)
    d=ImageDraw.Draw(ink); g=ImageDraw.Draw(gold)
    def line(pts,width=6,accent=False):
        target=g if accent else d
        target.line([(x*scale,y*scale) for x,y in pts],fill=255,width=int(width*scale),joint="curve")
    def poly(pts,accent=False):
        (g if accent else d).polygon([(x*scale,y*scale) for x,y in pts],fill=255)
    def ellipse(box,width=0,accent=False):
        box=tuple(x*scale for x in box)
        (g if accent else d).ellipse(box,fill=None if width else 255,outline=255,width=int(width*scale) if width else 1)
    def arc(box,start,end,width=6,accent=False):
        (g if accent else d).arc(tuple(x*scale for x in box),start,end,fill=255,width=int(width*scale))
    if name=="hud_wave":
        line([(15,15),(49,15),(49,49),(15,49),(15,15)],5);ellipse((9,10,20,22),3);ellipse((44,43,55,55),3);line([(22,26),(43,26)],3);line([(22,36),(38,36)],3,True)
    elif name=="hud_stability":
        arc((6,6,58,58),10,345,5);poly([(32,14),(47,20),(44,39),(32,50),(20,39),(17,20)]);line([(25,30),(31,37),(41,25)],3,True)
    elif name=="hud_enemy":
        line([(13,14),(50,14),(50,49)],12);ellipse((22,17,26,21),accent=True);ellipse((34,17,38,21),accent=True)
    elif name=="hud_gold":
        ellipse((8,8,56,56));d.rectangle((25*scale,25*scale,39*scale,39*scale),fill=0);arc((13,13,51,51),190,285,3,True)
    elif name=="hud_drop":
        poly([(24,9),(41,9),(37,20),(50,35),(51,49),(43,56),(20,56),(12,47),(15,33),(26,20)]);line([(24,21),(41,21)],3,True);line([(28,12),(34,17)],2,True)
    elif name in {"act_add","cand_new"}:
        line([(12,32),(52,32)],8);line([(32,12),(32,52)],8);ellipse((46,8,54,16),accent=True)
    elif name in {"act_replace","cand_replace"}:
        line([(10,24),(52,24)],6);poly([(51,15),(60,24),(51,33)]);line([(54,43),(12,43)],6,True);poly([(13,34),(4,43),(13,52)],True)
    elif name in {"act_skip","cause_reach"}:
        line([(8,32),(51,32)],8);poly([(43,14),(59,32),(43,50)]);line([(58,15),(58,50)],3,True)
    elif name=="act_remove":
        line([(15,13),(50,51)],8);line([(50,14),(14,51)],8);ellipse((51,7,57,13),accent=True)
    elif name=="reroll":
        arc((8,8,56,56),35,310,7);poly([(54,9),(59,28),(40,24)],True)
    elif name=="restore":
        line([(42,14),(23,39)],8);poly([(15,36),(29,44),(13,57),(9,53)]);line([(40,15),(48,7)],6,True)
    elif name in {"compound","badge_compound"}:
        line([(9,16),(25,16),(25,42)],7);line([(37,23),(53,23),(53,49)],7);line([(29,33),(36,33)],3,True);poly([(34,26),(41,33),(34,40)],True)
    elif name in {"lock_on","lock_off"}:
        if name=="lock_on":arc((18,8,46,39),180,360,6)
        else:arc((27,5,55,34),180,315,6)
        poly([(14,29),(50,29),(50,55),(14,55)]);ellipse((29,36,35,42),accent=True);line([(32,41),(32,48)],3,True)
    elif name=="pin":
        ellipse((18,8,46,36));poly([(23,31),(41,31),(32,57)]);ellipse((25,13,31,19),accent=True)
    elif name=="cat_equip":
        line([(15,51),(47,14)],7);poly([(44,9),(55,6),(53,18)]);line([(13,37),(29,52)],5,True)
    elif name=="cat_relic":
        ellipse((13,12,51,52),7);line([(26,8),(38,8)],4);poly([(32,22),(42,32),(32,43),(22,32)],True)
    elif name in {"cat_special","badge_clear"}:
        poly([(32,7),(38,24),(56,31),(39,38),(32,57),(25,39),(8,32),(25,24)]);ellipse((43,10,50,17),accent=True)
    elif name in {"cat_risk","cause_pattern"}:
        poly([(32,6),(59,54),(5,54)]);line([(32,23),(32,38)],5,True);ellipse((29,44,35,50),accent=True)
    elif name=="cand_rankup":
        line([(12,31),(32,12),(52,31)],7);line([(15,49),(32,33),(49,49)],7,True)
    elif name=="result_complete":
        arc((6,6,58,58),25,325,5);line([(16,32),(27,44),(48,19)],8,True)
    elif name=="result_fail":
        arc((7,7,57,57),5,160,5);arc((7,7,57,57),185,330,5);line([(20,20),(44,44)],7);line([(44,20),(20,44)],7,True)
    elif name=="result_abandon":
        line([(23,12),(12,12),(12,53),(23,53)],6);line([(26,32),(52,32)],7,True);poly([(46,21),(58,32),(46,43)],True)
    elif name=="tab_hub":
        poly([(8,28),(32,9),(56,28),(49,28),(49,54),(15,54),(15,28)]);poly([(28,35),(37,35),(37,54),(28,54)],True)
    elif name=="tab_research":
        ellipse((10,8,43,42),6);line([(39,39),(55,55)],8);line([(25,16),(25,32)],3,True);line([(17,24),(33,24)],3,True)
    elif name=="tab_codex":
        poly([(7,14),(27,12),(32,17),(37,12),(57,14),(57,52),(36,49),(32,54),(28,49),(7,52)]);line([(32,21),(32,45)],3,True)
    elif name=="tab_records":
        line([(16,8),(49,8),(49,55),(16,55),(16,8)],5);line([(24,22),(42,22)],3);line([(24,33),(42,33)],3,True);line([(24,44),(37,44)],3)
    elif name=="tab_settings":
        ellipse((14,14,50,50),7)
        for a in range(0,360,45):
            x,y=math.cos(math.radians(a)),math.sin(math.radians(a));line([(32+x*20,32+y*20),(32+x*28,32+y*28)],7)
        ellipse((27,27,37,37),accent=True)
    elif name in {"bookmark_gold","bookmark_silver"}:
        poly([(19,7),(46,7),(46,57),(32,46),(19,57)]);line([(25,14),(39,14)],3,True)
    elif name=="badge_twelve":
        ellipse((7,7,57,57),6);f=ImageFont.truetype(str(ART/"fonts/NotoSansKR-Regular.ttf"),26*scale);f.set_variation_by_axes([900]);g.text((32*scale,31*scale),"12",font=f,anchor="mm",fill=255)
    elif name=="variant_light":
        poly([(17,49),(21,25),(40,7),(53,11),(49,29),(29,43)]);line([(15,53),(43,18)],3,True);line([(7,22),(18,19)],2);line([(4,31),(15,28)],2)
    elif name=="variant_heavy":
        poly([(10,22),(18,10),(44,9),(55,24),(51,47),(12,48)]);line([(10,37),(53,37)],6,True);line([(21,13),(29,24),(20,31)],2,True)
    elif name=="variant_guard":
        poly([(32,7),(55,17),(51,42),(32,58),(13,42),(9,17)]);line([(32,15),(32,47)],5,True);line([(20,28),(44,28)],5,True)
    elif name=="status_burn":
        poly([(31,5),(44,23),(40,19),(54,39),(47,54),(31,59),(14,53),(8,40),(19,19),(20,36)]);poly([(31,34),(39,47),(31,55),(24,48)],True)
    elif name=="status_poison":
        poly([(32,6),(48,27),(54,40),(49,54),(32,59),(15,54),(10,40),(17,27)]);ellipse((23,38,33,48),accent=True)
    elif name=="status_slow":
        for a in (0,60,120):
            x,y=math.cos(math.radians(a)),math.sin(math.radians(a));line([(32-x*25,32-y*25),(32+x*25,32+y*25)],4)
        ellipse((27,27,37,37),accent=True)
    else:raise ValueError(name)
    # Dry-brush holes and feathered edges without a rectangular icon backing.
    rng=np.random.default_rng(sum(map(ord,name)))
    a=np.asarray(ink).copy(); edge=np.asarray(ink.filter(ImageFilter.MinFilter(5)))
    noise=rng.random(a.shape)
    a[(edge<a)&(noise>.72)]=(a[(edge<a)&(noise>.72)]*.38).astype(np.uint8)
    a[(edge>0)&(noise>.996)]=40
    im=material(Image.fromarray(a),INK,14,2)
    accent=GOLD
    if name=="status_burn":accent=(191,78,37)
    if name=="status_poison":accent=(93,123,68)
    if name=="status_slow":accent=(79,131,153)
    if name=="bookmark_silver":accent=(169,165,154)
    im=Image.alpha_composite(im,material(gold,accent,15,4))
    return im.resize((size,size),Image.Resampling.LANCZOS)


def ceramic_tile(selected=False,locked=False):
    w=h=144;yy,xx=np.mgrid[0:h,0:w]
    mask=Image.new("L",(w,h));d=ImageDraw.Draw(mask);d.rounded_rectangle((13,9,132,127),radius=22,fill=255)
    edge=np.minimum.reduce([xx-13,132-xx,yy-9,127-yy]);light=np.clip(edge/12,0,1)
    grain=np.random.default_rng(882).normal(0,1.7,(h,w))
    colors=np.stack([np.clip(c+light*13-grain-(yy/h)*12,0,255) for c in (231,213,180)],axis=2).astype(np.uint8)
    im=Image.fromarray(np.dstack([colors,np.asarray(mask)]),"RGBA")
    d=ImageDraw.Draw(im);d.arc((17,13,129,125),185,290,fill=(255,248,219,210),width=3);d.arc((17,13,129,125),10,95,fill=(118,92,59,90),width=3)
    if selected:
        d.rounded_rectangle((11,7,134,129),radius=23,outline=GOLD+(255,),width=4)
        glow=im.getchannel("A").filter(ImageFilter.GaussianBlur(8));glow=ImageChops.subtract(glow,mask).point(lambda v:int(v*.65));under=Image.new("RGBA",im.size,GOLD+(0,));under.putalpha(glow);im=Image.alpha_composite(under,im)
    if locked:
        chain=painted_icon("lock_on",35);im.alpha_composite(chain,(101,101))
    return composite_shadow(im,5,(0,7),.36)


def group_f():
    names=["hud_wave","hud_stability","hud_enemy","hud_gold","hud_drop","act_add","act_replace","act_skip","act_remove","reroll","restore","compound","lock_on","lock_off","pin","cat_equip","cat_relic","cat_special","cat_risk","cand_new","cand_rankup","cand_replace","result_complete","result_fail","result_abandon","cause_reach","cause_pattern","tab_hub","tab_research","tab_codex","tab_records","tab_settings","bookmark_gold","bookmark_silver","badge_clear","badge_compound","badge_twelve","variant_light","variant_heavy","variant_guard","status_burn","status_poison","status_slow"]
    for name in names:
        size=96 if name.startswith(("cat_","cand_","result_")) else (48 if name.startswith("status_") else 64)
        save(painted_icon(name,size),name,"hud" if name.startswith("hud_") else "ui")
    save(ceramic_tile(),"tile_jamo");save(ceramic_tile(True),"tile_jamo_selected");save(ceramic_tile(locked=True),"tile_jamo_locked")


if __name__ == "__main__":
    if len(sys.argv)==1 or sys.argv[1]=="C":group_c()
    elif sys.argv[1]=="F":group_f()
