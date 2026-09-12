"""Copy selected ImageGen sources and normalize sprite canvas only."""
from pathlib import Path
import json, shutil, sys
from PIL import Image, ImageDraw
from finish_generated_v2 import ART, finish, CHARS

source_root=Path(sys.argv[1])
records=json.loads((ART/'_source_v2/character_sources.json').read_text(encoding='utf-8'))
out=ART/'_source_v2/characters';out.mkdir(parents=True,exist_ok=True)
sheet=Image.new('RGB',(5*276,4*290),(54,43,32));draw=ImageDraw.Draw(sheet)
for idx,name in enumerate(CHARS):
    src=source_root/records[name]
    im=Image.open(src)
    assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,(name,im.mode)
    shutil.copy2(src,out/(name+'.png'))
    dst=ART/'glyphs'/('char_'+name+'.png');finish(src,dst,(256,256),True)
    x,y=(idx%5)*276,(idx//5)*290
    tile=Image.open(dst);sheet.paste(tile,(x+10,y+10),tile)
    draw.text((x+10,y+268),name,fill=(244,225,191))
sheet.save(ART/'_source_v2/characters_contact.png')
