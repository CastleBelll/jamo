# JAMO P6 — rigged porcelain models

## Production and licensing

Blender MCP was present but `get_addon_status` could not connect to a running addon. Per the brief, production used Blender **5.2.1 LTS**, `blender --background --python`, not MCP and not a paid provider.
Editable sources: `blend/<asset>.blend`; generator: `build_models.py`; packed 256×256 glaze images: `textures/`.
Geometry follows the exact compatibility-jamo outlines of Noto Sans KR, weight 900. `JAMOShapeGuide.ttf` is an OFL static subset renamed by `prepare_font.py`; its full SIL OFL text is `OFL-JAMOShapeGuide.txt`. Original font: [Noto Sans KR, Google Fonts](https://github.com/google/fonts/tree/main/ofl/notosanskr), copyright 2014–2021 Adobe, Reserved Font Name Source. Model geometry/materials/animation scripts are locally authored for JAMO; font-derived outlines retain OFL attribution. No external model package.

## Coordinates, skinning, animation

GLB uses **+Y up, front -Z, foot floor Y=0**, character height 1.0 / boss height 2.0 in rest pose. Blender source uses Z up / front +Y and the exporter converts axes. Font outline X is reflected before extrusion so letters read correctly from the declared front.
Four rigid-skin bones: `root`, `body`, `leg.L`, `leg.R`; body and dot eyes follow `body`; each leg/foot follows its leg bone. No cameras/lights exported. Silence intentionally has no eyes, matching its empty silhouette concept, and nine rigid ink chips.
GLB embeds PNG base-color textures with PBR metallic/roughness materials (cream roughness .26 / metallic 0; gray .48; gold metallic .78). Fine glaze/crack marks are base-color details, not displacement or normal maps. The body bone pivots at the torso center (Blender Z=.59), so ROLL rotates around its center, not its bottom edge; its sampled poses are checked against the foot floor. Source-only blend/preview/inspection/texture folders have `.gdignore` to avoid duplicate runtime imports; GLBs at the model root remain importable.
Clips are exact lowercase `idle`, `walk`, `hit`, `purify`. Hit is 0.16 seconds with vertical squash; purify is 0.45 seconds with collapse and 0.001 terminal root scale (scale disappearance, **not animated material alpha**). Idle/walk start/end skin poses match. All clips are sampled at 100 fps, LINEAR interpolation. Motion is in-place; gameplay translates the root.
Gait assignments follow `resources/motion_profiles/*.tres`, which differ from the brief's illustrative list: ㄱ is HEAVY_STEP, ㄴ/ㄹ are SWAY, ㅈ/ㅊ are LIGHT_STEP. ROLL rotates the body and attached eyes; BOUNCE raises the root; GLIDE leaves the legs quiet. Boss ㅇ has a slight rest-shape lean and ROLL gait.

## Inspection

All files were exported/triangulated and rendered in Blender. `validate_models.py` independently parses GLB binary accessors, skin/inverse-bind matrices, sampled clip channels and embedded PNGs. It checks ≤3000 triangles, four expected joints, exact names/durations, rest height/floor, mid-hit height reduction, terminal purify shrink, and idle/walk loop seams. BOUNCE lift and dot-eye counts are also checked.
Reflection winding is corrected before export; positive signed volume is checked per GLB primitive, with backface culling enabled on the opaque materials. Results and hashes: `inspection/GLB_VALIDATION.json`. Visual overview: `previews/MODELS_CONTACT.jpg` (24 Blender renders); individual PNG previews are transparent. Asymmetric forms ㄱ/ㄴ/ㄷ/ㄹ/ㅋ and vowel orientation were visually inspected. No Godot gameplay/import test was run: scene connections and importer options belong to the coordinator.

| GLB file | Jamo | Triangles (Blender = GLB) | Bones | Motion | Walk seconds | Animation names | Height | Result |
|---|---|---:|---:|---|---:|---|---:|---|
| `char_a.glb` | ㅏ | 820 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_bieup.glb` | ㅂ | 864 | 4 | BOUNCE | 0.55 | idle / walk / hit / purify | 1.0 | PASS |
| `char_chieut.glb` | ㅊ | 1322 | 4 | LIGHT_STEP | 0.30 | idle / walk / hit / purify | 1.0 | PASS |
| `char_digeut.glb` | ㄷ | 840 | 4 | HEAVY_STEP | 0.70 | idle / walk / hit / purify | 1.0 | PASS |
| `char_eo.glb` | ㅓ | 820 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_giyeok.glb` | ㄱ | 788 | 4 | HEAVY_STEP | 0.70 | idle / walk / hit / purify | 1.0 | PASS |
| `char_hieut.glb` | ㅎ | 1396 | 4 | SWAY | 0.80 | idle / walk / hit / purify | 1.0 | PASS |
| `char_i.glb` | ㅣ | 764 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_ieung.glb` | ㅇ | 1392 | 4 | ROLL | 0.60 | idle / walk / hit / purify | 1.0 | PASS |
| `char_jieut.glb` | ㅈ | 1282 | 4 | LIGHT_STEP | 0.30 | idle / walk / hit / purify | 1.0 | PASS |
| `char_kieuk.glb` | ㅋ | 844 | 4 | HEAVY_STEP | 0.70 | idle / walk / hit / purify | 1.0 | PASS |
| `char_mieum.glb` | ㅁ | 816 | 4 | BOUNCE | 0.55 | idle / walk / hit / purify | 1.0 | PASS |
| `char_nieun.glb` | ㄴ | 816 | 4 | SWAY | 0.80 | idle / walk / hit / purify | 1.0 | PASS |
| `char_o.glb` | ㅗ | 820 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_pieup.glb` | ㅍ | 944 | 4 | HEAVY_STEP | 0.70 | idle / walk / hit / purify | 1.0 | PASS |
| `char_rieul.glb` | ㄹ | 888 | 4 | SWAY | 0.80 | idle / walk / hit / purify | 1.0 | PASS |
| `char_siot.glb` | ㅅ | 1214 | 4 | LIGHT_STEP | 0.30 | idle / walk / hit / purify | 1.0 | PASS |
| `char_u.glb` | ㅜ | 820 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_yeo.glb` | ㅕ | 876 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `char_yo.glb` | ㅛ | 876 | 4 | GLIDE | 1.00 | idle / walk / hit / purify | 1.0 | PASS |
| `boss_greed.glb` | ㅂ | 864 | 4 | BOUNCE | 0.55 | idle / walk / hit / purify | 2.0 | PASS |
| `boss_ieung.glb` | ㅇ | 1392 | 4 | ROLL | 0.60 | idle / walk / hit / purify | 2.0 | PASS |
| `boss_mieum.glb` | ㅁ | 816 | 4 | BOUNCE | 0.55 | idle / walk / hit / purify | 2.0 | PASS |
| `boss_silence.glb` | ㅁ | 612 | 4 | BOUNCE | 0.55 | idle / walk / hit / purify | 2.0 | PASS |

Rebuild (Python fontTools / Blender bundled numpy; validator also needs Pillow and numpy):

```powershell
python art/models/prepare_font.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python art/models/build_models.py
python art/models/validate_models.py
```
