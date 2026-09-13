"""Resize/canvas-fit generated references to the exact production dimensions."""
from pathlib import Path
from PIL import Image, ImageOps
import json, hashlib

SOURCE=Path(__file__).resolve().parent
ART=SOURCE.parents[1]

def main():
    rows=json.loads((SOURCE/'prompts.json').read_text(encoding='utf-8'))
    results=[]
    for row in rows:
        source=SOURCE/f"{row['id']}.png";image=Image.open(source).convert('RGB')
        result=ImageOps.fit(image,tuple(row['size']),method=Image.Resampling.LANCZOS)
        output=ART.parent/row['path'];result.save(output)
        assert Image.open(output).size==tuple(row['size'])
        results.append({'id':row['id'],'file':row['path'],'size':list(result.size),'mode':'RGB',
                        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                        'sha256':hashlib.sha256(output.read_bytes()).hexdigest()})
    (SOURCE/'REFERENCE_VALIDATION.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    print('REFERENCE_PASS',len(results),'1920x1080')

if __name__=='__main__':main()
