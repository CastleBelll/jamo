"""Deterministic JAMO S8 asset builder.

Run from the repository root with Python 3 + Pillow. Background source images are
generated separately with OpenAI ImageGen; all typography and icons here are
rendered locally so Korean letterforms never depend on generated-image text.
"""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
FONT_PATH = ART / "fonts" / "NotoSansKR-Regular.ttf"
INK = (45, 42, 36, 255)
INK_SOFT = (79, 72, 61, 255)
PAPER = (246, 238, 216, 255)
GOLD = (191, 145, 58, 255)
RED = (150, 58, 48, 255)
BLUE = (74, 107, 121, 255)


def canvas(size: tuple[int, int], color=(0, 0, 0, 0)) -> Image.Image:
    return Image.new("RGBA", size, color)


def save(im: Image.Image, rel: str) -> None:
    path = ART / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)


def font(size: int, weight: int = 600) -> ImageFont.FreeTypeFont:
    fnt = ImageFont.truetype(str(FONT_PATH), size=size)
    fnt.set_variation_by_axes([weight])
    return fnt


def centered_text(im: Image.Image, text: str, fnt: ImageFont.FreeTypeFont,
                  fill=INK, shadow=True, y_offset=0) -> None:
    d = ImageDraw.Draw(im)
    box = d.textbbox((0, 0), text, font=fnt, stroke_width=0)
    x = (im.width - (box[2] - box[0])) / 2 - box[0]
    y = (im.height - (box[3] - box[1])) / 2 - box[1] + y_offset
    if shadow:
        d.text((x + 1, y + 2), text, font=fnt, fill=(20, 16, 12, 60))
    d.text((x, y), text, font=fnt, fill=fill)


def glyphs() -> None:
    chars = {
        "giyeok": "ㄱ", "nieun": "ㄴ", "digeut": "ㄷ", "rieul": "ㄹ",
        "mieum": "ㅁ", "bieup": "ㅂ", "siot": "ㅅ", "ieung": "ㅇ",
        "jieut": "ㅈ", "chieut": "ㅊ", "kieuk": "ㅋ", "pieup": "ㅍ",
        "hieut": "ㅎ", "a": "ㅏ", "eo": "ㅓ", "yeo": "ㅕ", "o": "ㅗ",
        "yo": "ㅛ", "u": "ㅜ", "i": "ㅣ",
    }
    for name, ch in chars.items():
        im = canvas((56, 56))
        centered_text(im, ch, font(43), shadow=True, y_offset=-1)
        save(im, f"glyphs/glyph_{name}.png")


def framed_icon(size: int, draw_fn, fill=(251, 245, 228, 242)) -> Image.Image:
    scale = 4
    im = canvas((size * scale, size * scale))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((2 * scale, 2 * scale, (size - 2) * scale, (size - 2) * scale),
                        radius=max(3, size // 5) * scale, fill=fill,
                        outline=(60, 53, 43, 180), width=max(1, size // 16) * scale)
    draw_fn(d, scale)
    return im.resize((size, size), Image.Resampling.LANCZOS)


def draw_named_icon(name: str, size: int) -> Image.Image:
    def art(d: ImageDraw.ImageDraw, s: int) -> None:
        c = INK
        gold = GOLD
        w = max(1, size // 10) * s
        mid = size * s / 2
        if name in {"variant_light", "hud_wave", "act_add"}:
            d.polygon([(7*s, mid), ((size-8)*s, 6*s), ((size-8)*s, (size-6)*s)], fill=gold)
            d.line([(5*s, mid), ((size-10)*s, mid)], fill=c, width=w)
        elif name == "variant_heavy":
            for pad in (5, 8): d.rectangle((pad*s, pad*s, (size-pad)*s, (size-pad)*s), outline=c, width=max(s, w//2))
        elif name == "variant_guard":
            seg = [(5,5,12,5),(size-12,5,size-5,5),(5,size-5,12,size-5),(size-12,size-5,size-5,size-5)]
            for x1,y1,x2,y2 in seg: d.line((x1*s,y1*s,x2*s,y2*s), fill=c, width=max(s,w//2))
            d.line((5*s,5*s,5*s,12*s),fill=c,width=max(s,w//2)); d.line(((size-5)*s,(size-12)*s,(size-5)*s,(size-5)*s),fill=c,width=max(s,w//2))
        elif name in {"status_burn", "tag_fire"}:
            d.polygon([(mid, 4*s), ((size-5)*s, (size-10)*s), (mid, (size-4)*s), (6*s, (size-10)*s), (11*s, 10*s), (mid, 16*s)], fill=(192,86,42,255))
            d.polygon([(mid, 13*s), ((size-10)*s,(size-8)*s), (mid,(size-5)*s),(10*s,(size-9)*s)], fill=GOLD)
        elif name in {"status_poison", "tag_dot"}:
            d.ellipse((6*s,8*s,(size-6)*s,(size-5)*s), fill=(86,116,76,255)); d.ellipse((10*s,11*s,14*s,15*s),fill=(240,245,220,180))
        elif name in {"status_slow", "tag_cold"}:
            for ang in (0, math.pi/3, 2*math.pi/3):
                dx,dy=math.cos(ang)*(size/2-5)*s,math.sin(ang)*(size/2-5)*s
                d.line((mid-dx,mid-dy,mid+dx,mid+dy),fill=BLUE,width=max(s,w//2))
        elif name == "hud_stability":
            d.line((5*s,7*s,mid,(size-5)*s,(size-5)*s,7*s),fill=c,width=w); d.line((mid,8*s,mid,(size-5)*s),fill=gold,width=max(s,w//2))
        elif name == "hud_enemy":
            d.ellipse((6*s,7*s,(size-6)*s,(size-5)*s),outline=c,width=w); d.ellipse((10*s,12*s,13*s,15*s),fill=c); d.ellipse(((size-13)*s,12*s,(size-10)*s,15*s),fill=c)
        elif name in {"hud_gold", "bookmark_gold"}:
            d.ellipse((5*s,5*s,(size-5)*s,(size-5)*s),fill=gold,outline=c,width=max(s,w//2)); d.ellipse((10*s,10*s,(size-10)*s,(size-10)*s),outline=PAPER,width=max(s,w//2))
        elif name == "hud_drop":
            d.polygon([(mid,4*s),((size-5)*s,mid),(mid,(size-4)*s),(5*s,mid)],fill=gold,outline=c)
        elif name in {"seal_lock", "lock_on"}:
            d.arc((7*s,4*s,(size-7)*s,(size-10)*s),180,360,fill=c,width=w); d.rounded_rectangle((5*s,11*s,(size-5)*s,(size-4)*s),radius=2*s,fill=gold,outline=c,width=max(s,w//2))
        elif name == "lock_off":
            d.arc((9*s,4*s,(size-5)*s,(size-10)*s),180,310,fill=INK_SOFT,width=w); d.rounded_rectangle((5*s,12*s,(size-5)*s,(size-4)*s),radius=2*s,outline=INK_SOFT,width=max(s,w//2))
        elif name in {"reroll", "act_replace", "cand_replace"}:
            d.arc((5*s,5*s,(size-5)*s,(size-5)*s),30,300,fill=c,width=w); d.polygon([((size-5)*s,9*s),((size-12)*s,5*s),((size-10)*s,13*s)],fill=gold)
        elif name == "pin":
            d.ellipse((8*s,4*s,(size-8)*s,(size-12)*s),fill=RED); d.polygon([(mid,(size-4)*s),(9*s,13*s),((size-9)*s,13*s)],fill=RED)
        elif name == "restore":
            d.arc((5*s,5*s,(size-5)*s,(size-5)*s),80,350,fill=c,width=w); d.line((mid,6*s,mid,(size-6)*s),fill=gold,width=max(s,w//2))
        elif name in {"compound", "badge_compound"}:
            d.ellipse((4*s,7*s,(size//2+3)*s,(size-6)*s),outline=c,width=w); d.ellipse(((size//2-3)*s,7*s,(size-4)*s,(size-6)*s),outline=gold,width=w)
        elif name in {"cat_equip", "tag_weapon"}:
            d.line((7*s,(size-6)*s,(size-7)*s,6*s),fill=c,width=w); d.polygon([((size-7)*s,4*s),((size-5)*s,11*s),((size-12)*s,7*s)],fill=gold)
        elif name == "cat_relic":
            d.ellipse((6*s,5*s,(size-6)*s,(size-5)*s),outline=gold,width=w); d.line((mid,4*s,mid,(size-4)*s),fill=c,width=max(s,w//2))
        elif name in {"cat_special", "tag_luck"}:
            pts=[]
            for i in range(10):
                a=-math.pi/2+i*math.pi/5; r=(size*.38 if i%2==0 else size*.16)*s
                pts.append((mid+math.cos(a)*r,mid+math.sin(a)*r))
            d.polygon(pts,fill=gold,outline=c)
        elif name in {"cat_risk", "tag_risk", "result_fail", "cause_pattern"}:
            d.polygon([(mid,4*s),((size-4)*s,(size-5)*s),(4*s,(size-5)*s)],fill=(230,210,165,255),outline=RED); d.line((mid,10*s,mid,(size-11)*s),fill=RED,width=w)
        elif name == "tag_guard":
            d.polygon([(mid,4*s),((size-5)*s,8*s),((size-7)*s,(size-6)*s),(mid,(size-3)*s),(7*s,(size-6)*s),(5*s,8*s)],fill=BLUE)
        elif name == "tag_auto":
            d.ellipse((5*s,5*s,(size-5)*s,(size-5)*s),outline=c,width=w); d.line((mid,mid,mid,7*s),fill=gold,width=w); d.line((mid,mid,(size-7)*s,mid),fill=gold,width=w)
        elif name == "tag_econ":
            d.rectangle((5*s,7*s,(size-5)*s,(size-5)*s),outline=c,width=w); d.ellipse((8*s,4*s,(size-8)*s,11*s),fill=gold)
        elif name in {"act_skip", "result_abandon"}:
            d.polygon([(7*s,5*s),(mid,(size//2)*s),(7*s,(size-5)*s)],fill=c); d.polygon([(mid,5*s),((size-7)*s,(size//2)*s),(mid,(size-5)*s)],fill=gold)
        elif name == "act_remove":
            d.line((6*s,mid,(size-6)*s,mid),fill=RED,width=w)
        elif name in {"cand_new", "result_complete", "badge_clear"}:
            d.line((6*s,mid,(size//2-2)*s,(size-6)*s,(size-5)*s,6*s),fill=(76,120,76,255),width=w)
        elif name == "cand_rankup":
            d.polygon([(mid,4*s),((size-5)*s,(size-8)*s),(mid,(size-12)*s),(5*s,(size-8)*s)],fill=gold)
        elif name == "cause_reach":
            d.line((5*s,mid,(size-6)*s,mid),fill=RED,width=w); d.polygon([((size-5)*s,mid),((size-12)*s,7*s),((size-12)*s,(size-7)*s)],fill=RED)
        elif name == "bookmark_silver":
            d.polygon([(8*s,4*s),((size-8)*s,4*s),((size-8)*s,(size-4)*s),(mid,(size-9)*s),(8*s,(size-4)*s)],fill=(152,156,158,255))
        elif name == "badge_twelve":
            d.ellipse((4*s,4*s,(size-4)*s,(size-4)*s),fill=gold,outline=c,width=w); d.text((mid,mid),"12",font=font(int(size*.35*s)),anchor="mm",fill=PAPER)
        elif name.startswith("tab_"):
            if name == "tab_hub":
                d.polygon([(5*s,mid),(mid,5*s),((size-5)*s,mid),((size-8)*s,mid),((size-8)*s,(size-5)*s),(8*s,(size-5)*s),(8*s,mid)],fill=c)
            elif name == "tab_research":
                d.ellipse((8*s,5*s,(size-8)*s,(size-11)*s),outline=c,width=w); d.line((mid,(size-11)*s,mid,(size-5)*s),fill=gold,width=w)
            elif name == "tab_codex":
                d.rectangle((6*s,5*s,(size-6)*s,(size-5)*s),outline=c,width=w); d.line((mid,5*s,mid,(size-5)*s),fill=gold,width=max(s,w//2))
            elif name == "tab_records":
                d.line((7*s,mid,12*s,(size-7)*s,(size-6)*s,6*s),fill=c,width=w)
            else:
                d.ellipse((7*s,7*s,(size-7)*s,(size-7)*s),outline=c,width=w); d.ellipse((mid-3*s,mid-3*s,mid+3*s,mid+3*s),fill=gold)
        else:
            d.ellipse((6*s,6*s,(size-6)*s,(size-6)*s),outline=c,width=w)
    return framed_icon(size, art)


def icons() -> None:
    groups = {
        24: ["variant_light","variant_heavy","variant_guard","status_burn","status_poison","status_slow",
             "cat_equip","cat_relic","cat_special","cat_risk","cand_new","cand_rankup","cand_replace",
             "cause_reach","cause_pattern","bookmark_silver","bookmark_gold"],
        20: ["seal_lock","tag_weapon","tag_fire","tag_dot","tag_guard","tag_auto","tag_cold","tag_econ","tag_luck","tag_risk"],
        32: ["hud_wave","hud_stability","hud_enemy","hud_gold","hud_drop","act_add","act_replace","act_skip","act_remove",
             "lock_on","lock_off","reroll","pin","restore","compound","tab_hub","tab_research","tab_codex","tab_records","tab_settings"],
        40: ["result_fail","result_abandon","result_complete"],
        48: ["badge_compound","badge_clear","badge_twelve"],
    }
    for size, names in groups.items():
        for name in names: save(draw_named_icon(name, size), f"ui/{name}.png" if not name.startswith("hud_") else f"hud/{name}.png")


def structural_ui() -> None:
    im=canvas((90,90)); d=ImageDraw.Draw(im); d.rounded_rectangle((5,5,84,84),radius=12,fill=(248,240,218,235),outline=INK,width=3); d.rectangle((11,11,78,78),outline=GOLD,width=2); save(im,"ui/slot_frame.png")
    for name,col in (("rank_pip_on",GOLD),("rank_pip_off",(0,0,0,0))):
        im=canvas((12,12)); d=ImageDraw.Draw(im); d.ellipse((1,1,10,10),fill=col,outline=INK_SOFT,width=1); save(im,f"ui/{name}.png")
    for name,sel in (("tile_jamo",False),("tile_selected",True)):
        im=canvas((72,72)); d=ImageDraw.Draw(im); d.rounded_rectangle((3,3,68,68),radius=10,fill=(248,240,218,245),outline=GOLD if sel else INK_SOFT,width=4 if sel else 2); save(im,f"ui/{name}.png")
    im=canvas((90,90)); d=ImageDraw.Draw(im); d.ellipse((5,5,84,84),fill=(248,240,218,205),outline=INK,width=4); d.arc((13,13,76,76),20,310,fill=GOLD,width=5); save(im,"ui/marker_target.png")


def battlefield() -> None:
    src=Image.open(ART/"backgrounds/paper_bg_source.png").convert("RGBA").resize((1920,1080),Image.Resampling.LANCZOS)
    save(src,"backgrounds/paper_bg.png")
    ov=canvas((1920,1080)); d=ImageDraw.Draw(ov); random.seed(1107)
    for pad,alpha,width in ((0,70,55),(38,40,42),(76,25,30)):
        col=(48,43,36,alpha)
        d.rounded_rectangle((pad-30,pad-30,1920-pad+30,1080-pad+30),radius=90,outline=col,width=width)
    for _ in range(160):
        side=random.choice((0,1,2,3)); x=random.randrange(1920); y=random.randrange(1080)
        if side==0:y=random.randrange(0,90)
        elif side==1:y=random.randrange(990,1080)
        elif side==2:x=random.randrange(0,100)
        else:x=random.randrange(1820,1920)
        r=random.randrange(4,26); d.ellipse((x-r,y-r,x+r,y+r),fill=(38,34,30,random.randrange(8,32)))
    save(ov.filter(ImageFilter.GaussianBlur(5)),"backgrounds/ink_overlay.png")
    for name,hit in (("sentence_row",False),("sentence_row_hit",True)):
        im=canvas((1480,90)); d=ImageDraw.Draw(im); d.rounded_rectangle((3,8,1476,82),radius=10,fill=(249,242,222,228),outline=RED if hit else INK_SOFT,width=4 if hit else 2); d.line((30,68,1450,68),fill=(95,80,58,110),width=1); save(im,f"backgrounds/{name}.png")


def bosses() -> None:
    specs={"boss_mieum":("ㅁ",INK),"boss_silence":("침묵",INK),"boss_ieung":("ㅇ",BLUE),"boss_greed":("탐욕",GOLD)}
    for name,(txt,col) in specs.items():
        im=canvas((360,100)); d=ImageDraw.Draw(im); d.rounded_rectangle((5,8,354,91),radius=22,fill=(249,241,218,230),outline=col,width=4)
        if name=="boss_silence": d.line((32,52,328,45),fill=(25,22,20,210),width=12)
        if name=="boss_ieung": d.arc((35,10,325,90),12,340,fill=GOLD,width=4)
        if name=="boss_greed": d.ellipse((22,8,338,92),outline=GOLD,width=5)
        centered_text(im,txt,font(58 if len(txt)==1 else 44),fill=col,shadow=True,y_offset=-2)
        save(im,f"bosses/{name}.png")


def library() -> None:
    bg=Image.open(ART/"library/lib_bg_source.png").convert("RGBA").resize((1920,1080),Image.Resampling.LANCZOS)
    save(bg,"library/lib_bg.png"); save(bg.copy(),"title/title_screen.png")
    layers={}
    lamp=canvas((1920,1080)); d=ImageDraw.Draw(lamp); d.ellipse((90,520,390,900),fill=(242,185,74,38)); d.ellipse((1540,520,1840,900),fill=(242,185,74,38)); layers["lib_layer_lamp"]=lamp.filter(ImageFilter.GaussianBlur(35))
    sp=canvas((1920,1080)); d=ImageDraw.Draw(sp)
    for x in list(range(25,280,28))+list(range(1640,1900,28)):
        h=120+(x*17)%180; d.rounded_rectangle((x,560-h,x+20,560),radius=3,fill=(74+(x%3)*25,55,40,150),outline=(220,172,72,110),width=2)
    layers["lib_layer_spines"]=sp
    ln=canvas((1920,1080)); d=ImageDraw.Draw(ln)
    for y in range(735,935,28): d.line((500,y,1420,y),fill=(65,54,42,70),width=2)
    layers["lib_layer_lines"]=ln
    hw=canvas((1920,1080)); d=ImageDraw.Draw(hw)
    for i in range(7):
        y=765+i*24; d.arc((650+i*15,y,1250-i*18,y+18),180,350,fill=(43,40,35,90),width=2)
    layers["lib_layer_handwriting"]=hw
    ob=canvas((1920,1080)); d=ImageDraw.Draw(ob); d.polygon([(600,820),(955,760),(955,1030),(540,990)],fill=(250,240,210,190),outline=GOLD); d.polygon([(965,760),(1320,820),(1380,990),(965,1030)],fill=(250,240,210,190),outline=GOLD); d.line((960,770,960,1025),fill=INK_SOFT,width=4); layers["lib_layer_openbook"]=ob
    for name,im in layers.items(): save(im,f"library/{name}.png")
    logo=canvas((600,200)); centered_text(logo,"JAMO",font(126, 700),fill=(245,232,197,255),shadow=True,y_offset=-10); d=ImageDraw.Draw(logo); d.line((112,168,488,168),fill=GOLD,width=4); save(logo,"title/title_logo.png")


def theme_assets() -> None:
    im=canvas((64,64)); d=ImageDraw.Draw(im); d.rounded_rectangle((3,3,60,60),radius=12,fill=(244,235,211,238),outline=INK_SOFT,width=3); d.rectangle((8,8,55,55),outline=(193,147,65,100),width=1); save(im,"ui/panel_9slice.png")
    states={"button_normal":((245,236,211,245),INK_SOFT),"button_hover":((255,247,224,255),GOLD),"button_pressed":((222,207,172,255),INK),"button_disabled":((210,205,191,180),(120,115,104,150))}
    for name,(fill,outline) in states.items():
        im=canvas((64,32)); d=ImageDraw.Draw(im); d.rounded_rectangle((2,2,61,29),radius=8,fill=fill,outline=outline,width=2); save(im,f"ui/{name}.png")
    im=canvas((64,8)); d=ImageDraw.Draw(im); d.rounded_rectangle((0,1,63,6),radius=3,fill=(94,83,65,110)); d.line((4,3,60,3),fill=GOLD,width=2); save(im,"ui/slider_track.png")
    im=canvas((24,24)); d=ImageDraw.Draw(im); d.ellipse((2,2,21,21),fill=PAPER,outline=INK,width=2); d.ellipse((7,7,16,16),fill=GOLD); save(im,"ui/slider_grabber.png")
    for name,on in (("check_on",True),("check_off",False)):
        im=canvas((24,24)); d=ImageDraw.Draw(im); d.rounded_rectangle((2,2,21,21),radius=4,fill=PAPER,outline=INK_SOFT,width=2)
        if on:d.line((6,12,10,17,19,6),fill=GOLD,width=3)
        save(im,f"ui/{name}.png")


def wav(path: Path, seconds: float, kind: str, rate: int=44100) -> None:
    random.seed(sum(map(ord,kind))); frames=[]
    for n in range(int(rate*seconds)):
        t=n/rate; env=max(0.0,1-t/seconds)
        if kind=="hit_ink": v=(random.random()*2-1)*env*0.45 + math.sin(2*math.pi*95*t)*env*.18
        elif kind=="purify": v=math.sin(2*math.pi*(440+900*t)*t)*env*.32
        elif kind=="sentence_hit": v=math.sin(2*math.pi*58*t)*env*.55+(random.random()*2-1)*env*.12
        elif kind=="boss_warning": v=math.sin(2*math.pi*110*t)*(0.6+0.4*math.sin(2*math.pi*5*t))*env*.4
        elif kind=="boss_intro": v=(math.sin(2*math.pi*73*t)+.5*math.sin(2*math.pi*146*t))*math.sin(math.pi*t/seconds)*.25
        elif kind=="page_turn": v=(random.random()*2-1)*math.sin(math.pi*t/seconds)*.22
        else:
            # Frequencies complete an integer number of cycles over 16 seconds and
            # the slow envelope has identical endpoints, producing a clean loop.
            notes=(220,275,330,440) if kind=="bgm_library" else (110,165,220,330)
            fade=.65-.30*math.cos(2*math.pi*t/seconds)
            v=sum(math.sin(2*math.pi*f*t+i*.35) for i,f in enumerate(notes))*fade*.045
        frames.append(max(-32767,min(32767,int(v*32767))))
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),"wb") as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(rate)
        out.writeframes(b"".join(int(x).to_bytes(2,"little",signed=True) for x in frames))


def audio_sources() -> None:
    import soundfile as sf

    durations={"hit_ink":.22,"purify":.65,"sentence_hit":.52,"boss_warning":.85,"boss_intro":1.2,"page_turn":.48,"bgm_library":16.0,"bgm_combat":16.0}
    for name,sec in durations.items():
        dst=ART/"audio"/("sfx" if name not in {"bgm_library","bgm_combat"} else "")/f"{name}.wav"
        wav(dst,sec,name)
        samples, sample_rate = sf.read(dst)
        sf.write(dst.with_suffix(".ogg"), samples, sample_rate, format="OGG", subtype="VORBIS")
        dst.unlink()


if __name__ == "__main__":
    glyphs(); icons(); structural_ui(); battlefield(); bosses(); library(); theme_assets(); audio_sources()
    print("JAMO art assets generated")
