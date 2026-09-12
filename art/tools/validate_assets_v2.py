"""Verify v2 final PNG contracts from the asset map and changed-file set."""
from pathlib import Path
import re, subprocess
from PIL import Image

root=Path(__file__).resolve().parents[2]
asset_map=(root/'art/ASSET_MAP.md').read_text(encoding='utf-8')
sizes={}
for line in asset_map.splitlines():
    m=re.search(r'`(art/[^`]+\.png)`\s*\|\s*(\d+)×(\d+)',line)
    if m:
        path,w,h=m.groups();expected=(int(w),int(h))
        assert path not in sizes or sizes[path]==expected,(path,sizes.get(path),expected)
        sizes[path]=expected
changed=subprocess.check_output(['git','diff','--name-only','5811a36','--','art'],cwd=root,text=True).splitlines()
finals=[p for p in changed if p.endswith('.png') and '/_source_v2/' not in p]
assert len(finals)==94,(len(finals),finals)
opaque={'art/title/title_screen.png','art/library/lib_bg_dim.png','art/backgrounds/combat_desk.png'}
for p in finals:
    im=Image.open(root/p)
    assert p in sizes and im.size==sizes[p],(p,im.size,sizes.get(p))
    assert im.mode=='RGBA',(p,im.mode)
    if p in opaque:assert im.getchannel('A').getextrema()==(255,255),p
    else:
        low,high=im.getchannel('A').getextrema()
        assert low==0 and high>0,(p,(low,high))
v=Image.open(root/'art/backgrounds/ink_vignette.png')
assert v.getpixel((960,540))[3]==0,'vignette center must be transparent'
for n in ['NanumMyeongjo-Regular','NanumMyeongjo-Bold','NanumBrushScript-Regular']:
    assert (root/'art/fonts'/f'{n}.ttf').stat().st_size>10000,n
print('PASS: 94 final PNG paths/sizes/RGBA/alpha, vignette center, 3 Nanum fonts')
