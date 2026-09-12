"""User-authorized local subtitle removal; preserve the complete JAMO strokes."""
from pathlib import Path
from PIL import Image, ImageOps

art=Path(__file__).resolve().parents[1]
source=Image.open(art/'_source_v2/group_D/title_logo.png').convert('RGBA')
# Source lettering ends at y561; subtitle lettering starts below y574.
# This cutoff retains the full JAMO lettering and its visible warm halo.
logo=source.crop((0,0,source.width,574))
bbox=logo.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
logo=logo.crop(bbox)
logo=ImageOps.contain(logo,(1160,380),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(1200,420))
canvas.alpha_composite(logo,((1200-logo.width)//2,(420-logo.height)//2))
canvas.save(art/'title/title_logo.png',optimize=True)
print('JAMO only:',canvas.size,'RGBA; source crop',bbox,'centered')
