"""Validate the public contract in art/ASSET_MAP.md."""

from pathlib import Path

import soundfile as sf
from PIL import Image


root = Path(__file__).resolve().parents[2]
rows = []
for line in (root / "art" / "ASSET_MAP.md").read_text(encoding="utf-8").splitlines():
    cells = [cell.strip() for cell in line.split("|")[1:-1]]
    if len(cells) == 4 and cells[1].startswith("`art/"):
        rows.append((cells[0], cells[1].strip("`"), cells[2]))

errors = []
png_count = 0
ogg_count = 0
opaque_allowed = {"paper_bg", "lib_bg", "title_screen"}
for asset_id, rel, expected in rows:
    path = root / rel
    if not path.is_file():
        errors.append(f"missing: {asset_id} -> {rel}")
        continue
    if path.suffix == ".png":
        png_count += 1
        im = Image.open(path)
        actual = f"{im.width}×{im.height}"
        if actual != expected:
            errors.append(f"size: {asset_id} expected {expected}, got {actual}")
        if asset_id not in opaque_allowed:
            if im.mode != "RGBA" or im.getextrema()[3][0] != 0:
                errors.append(f"alpha: {asset_id} has no fully transparent pixels")
    elif path.suffix == ".ogg":
        ogg_count += 1
        if sf.info(path).format != "OGG":
            errors.append(f"audio: {asset_id} is not OGG")

if png_count != 104:
    errors.append(f"contract: expected 104 PNGs, found {png_count}")
if ogg_count != 8:
    errors.append(f"contract: expected 8 OGGs, found {ogg_count}")

for error in errors:
    print("FAIL", error)
print(f"asset validation: {'PASS' if not errors else 'FAIL'} ({png_count} PNG, {ogg_count} OGG)")
raise SystemExit(1 if errors else 0)
