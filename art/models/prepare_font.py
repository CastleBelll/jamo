"""OFL Noto outlines, subset + static weight for deterministic Blender glyphs."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

art=Path(__file__).resolve().parents[1]
font=TTFont(art/'fonts/NotoSansKR-Regular.ttf')
font=instantiateVariableFont(font,{'wght':900},inplace=True)
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True
sub=subset.Subsetter(options=options);sub.populate(text='ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅍㅎㅏㅓㅕㅗㅛㅜㅣ');sub.subset(font)
for r in font['name'].names:
    if r.nameID in (1,2,3,4,6,16,17):
        value='Regular' if r.nameID in (2,17) else ('JAMOShapeGuide-Regular' if r.nameID==6 else 'JAMO Shape Guide')
        r.string=value.encode(r.getEncoding(),errors='replace')
font.save(art/'models/JAMOShapeGuide.ttf')
print('Created 20-glyph static OFL shape guide')
