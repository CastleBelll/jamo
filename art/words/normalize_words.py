"""Canvas-only normalization of original ImageGen PNGs; preserve straight alpha."""
from pathlib import Path
import json, re, hashlib
from PIL import Image, ImageDraw

ART=Path(__file__).resolve().parents[1]
SOURCE=ART/'_source_p6'/'words'
OUT=ART/'words'

def main():
    manifest=json.loads((SOURCE/'prompts.json').read_text(encoding='utf-8'))
    expected={re.search(r'\nid = &"(.*?)"',p.read_text(encoding='utf-8')).group(1) for p in (ART.parent/'resources'/'words').glob('*.tres')}
    assert len(manifest)==24 and {e['id'] for e in manifest}==expected,'all 22 basic + 2 compound IDs required'
    inspection=[]
    for entry in manifest:
        image=Image.open(SOURCE/f"{entry['id']}.png").convert('RGBA')
        alpha=image.getchannel('A');assert alpha.getextrema()[0]==0,'real transparent alpha required'
        box=alpha.point(lambda p:255 if p>8 else 0).getbbox();assert box
        image=image.crop(box);image.thumbnail((224,224),Image.Resampling.LANCZOS)
        tile=Image.new('RGBA',(256,256),(0,0,0,0));tile.alpha_composite(image,((256-image.width)//2,(256-image.height)//2))
        tile.save(OUT/f"word_{entry['id']}.png")
        assert tile.size==(256,256) and tile.getchannel('A').getextrema()[0]==0
        inspection.append({'id':entry['id'],'file':f"art/words/word_{entry['id']}.png",'size':[256,256],
                           'mode':'RGBA','alpha_range':tile.getchannel('A').getextrema(),
                           'source_sha256':hashlib.sha256((SOURCE/f"{entry['id']}.png").read_bytes()).hexdigest(),
                           'sha256':hashlib.sha256((OUT/f"word_{entry['id']}.png").read_bytes()).hexdigest()})
    sheet=Image.new('RGB',(1024,768),'#e9dec8');draw=ImageDraw.Draw(sheet)
    for k,e in enumerate(manifest):
        image=Image.open(OUT/f"word_{e['id']}.png");image.thumbnail((160,160),Image.Resampling.LANCZOS)
        x=(k%6)*170;y=(k//6)*192;sheet.paste(image,(x+5,y),image);draw.text((x+10,y+166),e['id'],fill='#302a22')
    sheet.save(SOURCE/'WORDS_CONTACT.jpg',quality=94)
    (SOURCE/'WORD_VALIDATION.json').write_text(json.dumps(inspection,indent=2),encoding='utf-8')
    print('WORDS_PASS',len(manifest),'256x256 RGBA')

if __name__=='__main__':main()
