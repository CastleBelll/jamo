"""Exact-size / straight-alpha finishing for ImageGen v2 source PNGs."""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw, ImageFont, ImageOps

ART=Path(__file__).resolve().parents[1]
CHARS=dict(zip("giyeok nieun digeut rieul mieum bieup siot ieung jieut chieut kieuk pieup hieut a eo yeo o yo u i".split(),"ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅍㅎㅏㅓㅕㅗㅛㅜㅣ"))

def guides():
    dst=ART/"_source_v2/shape_guides";dst.mkdir(parents=True,exist_ok=True)
    f=ImageFont.truetype(str(ART/"fonts/NotoSansKR-Regular.ttf"),820);f.set_variation_by_axes([900])
    for name,ch in CHARS.items():
        im=Image.new("RGB",(1024,1024),"white");d=ImageDraw.Draw(im);b=d.textbbox((0,0),ch,font=f)
        d.text(((1024-b[2]+b[0])/2-b[0],(1024-b[3]+b[1])/2-b[1]),ch,font=f,fill="black")
        im.save(dst/(name+".png"))

def finish(src,dst,size,bottom=False):
    im=Image.open(src).convert("RGBA")
    if bottom:
        # Ignore almost invisible rim-light padding when aligning the feet.
        bbox=im.getchannel("A").point(lambda a:255 if a>32 else 0).getbbox()
        if not bbox:raise ValueError("source has no alpha content")
        im=im.crop(bbox)
        im=ImageOps.contain(im,(size[0]-30,size[1]-28),Image.Resampling.LANCZOS)
        out=Image.new("RGBA",size);out.alpha_composite(im,((size[0]-im.width)//2,size[1]-12-im.height))
    else:out=im.resize(size,Image.Resampling.LANCZOS)
    Path(dst).parent.mkdir(parents=True,exist_ok=True);out.save(dst,optimize=True)

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("src",nargs="?");p.add_argument("dst",nargs="?");p.add_argument("--size",nargs=2,type=int);p.add_argument("--bottom",action="store_true");p.add_argument("--guides",action="store_true");a=p.parse_args()
    if a.guides:guides()
    else:finish(a.src,a.dst,tuple(a.size),a.bottom)
