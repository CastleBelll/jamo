"""Package model outputs; crop/resize only, preserve straight alpha."""
from pathlib import Path
import json, shutil, sys
from PIL import Image
from finish_generated_v2 import ART, finish

group=sys.argv[1];root=Path(sys.argv[2])
records=json.loads((ART/f'_source_v2/group_{group}.json').read_text(encoding='utf-8'))
sources=ART/f'_source_v2/group_{group}';sources.mkdir(parents=True,exist_ok=True)
for r in records:
    src=root/r['source'];im=Image.open(src)
    if not r.get('opaque'):
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0,(r['name'],im.mode)
    shutil.copy2(src,sources/(r['name']+'.png'))
    if r.get('crop'):
        im=im.crop(im.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox())
        cropped=sources/(r['name']+'_crop.png');im.save(cropped);src=cropped
    finish(src,ART/r['path'],tuple(r['size']),r.get('bottom',False))
    print(r['path'],r['size'],im.mode)
