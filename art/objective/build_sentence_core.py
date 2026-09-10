"""Create the JAMO sentence core with Blender; no third-party assets required.

Run: blender --background --python art/objective/build_sentence_core.py
Outputs are written beside this script. Blender Z-up becomes Godot Y-up.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
groups = {}


def material(name, color, roughness=0.9):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    m.node_tree.nodes.clear()
    bsdf = m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    output = m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    return m


paper = material('Core_Paper_ReplaceOnHit', (0.82, 0.66, 0.41))
pages = material('Warm_Hanji', (0.69, 0.53, 0.32))
ink = material('Core_Ink_ReplaceOnHit', (0.043, 0.024, 0.013))
wood = material('Dark_Wood_Binding', (0.095, 0.041, 0.017))
thread = material('Flax_Stitch', (0.47, 0.29, 0.10))
red = material('Cinnabar_Seal', (0.35, 0.047, 0.023))


def register(obj, group, mat):
    obj.data.materials.append(mat)
    groups.setdefault(group, []).append(obj)
    return obj


def box(group, loc, scale, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Soft worn edge', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return register(o, group, mat)


def mesh(group, verts, faces, mat):
    data = bpy.data.meshes.new(group)
    data.from_pydata(verts, [], faces)
    data.update()
    o = bpy.data.objects.new(group, data)
    bpy.context.collection.objects.link(o)
    return register(o, group, mat)


def ribbon(group, points, width, mat):
    # A solid, low-sided stroke is robust to both front and rear views.
    for a, b in zip(points, points[1:]):
        mid = (Vector(a) + Vector(b)) / 2
        delta = Vector(b) - Vector(a)
        o = box(group, mid, (width, width * 0.48, delta.length + width * 0.25), mat)
        o.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()


# Low wide book: a distinct dark outline separates paper from a paper arena.
for side in (-1, 1):
    box('Binding', (side * 0.63, 0, 0.075), (1.28, 1.62, 0.15), wood, 0.035)
box('Binding', (0, 0, 0.11), (0.16, 1.68, 0.19), wood, 0.025)


def page_z(x, layer=0):
    return 0.235 + layer * 0.013 + 0.11 * math.sin(abs(x) / 1.23 * math.pi * 0.85)


# Real thickness and staggered, slightly curled edges; no alpha textures.
for side in (-1, 1):
    for layer in range(5):
        vertices = []
        n = 10
        for end in (-1, 1):
            for i in range(n + 1):
                x = side * (0.045 + (1.15 + layer * 0.012) * i / n)
                y = end * (0.73 + layer * 0.006) + 0.008 * math.sin(i * 1.7 + layer)
                vertices.append((x, y, page_z(x, layer)))
        faces = [(i, i + 1, n + 2 + i, n + 1 + i) for i in range(n)]
        o = mesh('BookPages', vertices, faces, pages if layer < 4 else paper)
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new('Paper thickness', 'SOLIDIFY')
        mod.thickness = 0.009
        bpy.ops.object.modifier_apply(modifier=mod.name)

# Stitched spine and understated ink lines establish an authored manuscript.
for y in (-0.61, -0.34, -0.07, 0.2, 0.47, 0.66):
    ribbon('BindingThread', [(-0.10, y, 0.305), (0, y - 0.018, 0.29), (0.10, y, 0.305)], 0.018, thread)
for side in (-1, 1):
    for row in range(5):
        y = -0.54 + row * 0.225
        for col in range(3):
            x = side * (0.28 + col * 0.27)
            z = page_z(x, 4) + 0.012
            # Hand-built Hangul-like square consonant strokes, not fake font text.
            ribbon('SentenceInk', [(x - 0.065, y, z), (x + 0.055, y, z), (x + 0.055, y + 0.08, z)], 0.015, ink)
            ribbon('SentenceInk', [(x - 0.065, y + 0.08, z), (x - 0.065, y + 0.13, z), (x + 0.055, y + 0.13, z)], 0.012, ink)

# Folded upright sheet: central ridge catches light without a glow/VFX cost.
# Front is Blender -Y, exported Godot +Z.
verts = [(-0.55, 0.075, 0.61), (0, -0.085, 0.54), (0.55, 0.075, 0.61),
         (-0.55, 0.245, 1.86), (0, 0.085, 1.96), (0.55, 0.245, 1.86)]
o = mesh('CorePaper', verts, [(0, 1, 4, 3), (1, 2, 5, 4)], paper)
bpy.context.view_layer.objects.active = o
mod = o.modifiers.new('Folded hanji thickness', 'SOLIDIFY')
mod.thickness = 0.025
bpy.ops.object.modifier_apply(modifier=mod.name)


def face_point(x, z):
    return (x, -0.085 + abs(x) / 0.55 * 0.16 + (z - 0.54) / 1.42 * 0.17 - 0.024, z)


def glyph(points, width=0.066):
    folded = [points[0]]
    for (x1, z1), (x2, z2) in zip(points, points[1:]):
        if x1 * x2 < 0:
            folded.append((0, z1 + (z2 - z1) * (-x1) / (x2 - x1)))
        folded.append((x2, z2))
    ribbon('CoreInk', [face_point(x, z) for x, z in folded], width, ink)


# Explicit Hangul syllable 문 = ㅁ + ㅜ + ㄴ, drawn as original geometry.
glyph([(-0.255, 1.70), (0.25, 1.70), (0.25, 1.40), (-0.255, 1.40), (-0.255, 1.70)])
glyph([(-0.32, 1.23), (0, 1.23), (0.32, 1.23)], 0.074)
glyph([(0, 1.23), (0, 1.04)])
glyph([(-0.25, 0.98), (-0.25, 0.80), (0, 0.80), (0.29, 0.80)], 0.074)
# Brush taper accents break perfectly mechanical stroke ends.
glyph([(0.29, 0.80), (0.35, 0.83)], 0.037)
glyph([(-0.32, 1.23), (-0.37, 1.25)], 0.035)

# Small red ownership seal, also a separate controllable part.
seal = box('Seal', (0.86, -0.54, page_z(0.86, 4) + 0.018), (0.22, 0.19, 0.02), red)
for x in (0.80, 0.90):
    seal_z = page_z(0.86, 4) + 0.033
    ribbon('Seal', [(x, -0.60, seal_z), (x, -0.49, seal_z)], 0.016, paper)

# Keep a small, stable, named mesh set instead of hundreds of draw objects.
for name, objects in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

asset_objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in asset_objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'sentence_core.glb'), export_format='GLB',
                          use_selection=True, export_animations=False, export_yup=True)
triangles = 0
for o in asset_objects:
    o.data.calc_loop_triangles()
    triangles += len(o.data.loop_triangles)
stats = {'triangles': triangles, 'mesh_nodes': len(asset_objects),
         'blender_version': bpy.app.version_string,
         'glb_bytes': (OUT / 'sentence_core.glb').stat().st_size,
         'dimensions_godot_xyz': [2.54, 1.96, 1.68],
         'surface_count': sum(len(o.data.materials) for o in asset_objects),
         'materials': sorted({m.name for o in asset_objects for m in o.data.materials}),
         'provenance': 'Original procedural mesh and solid materials; no downloaded assets or fonts.'}
(OUT / 'asset_stats.json').write_text(json.dumps(stats, indent=2), encoding='utf-8')

# Preview-only floor, camera and lighting are excluded from the exported GLB.
floor_mat = material('Preview_Backdrop', (0.18, 0.125, 0.075))
box('Preview', (0, 0, -0.07), (200, 200, 0.10), floor_mat)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.world.color = (0.22, 0.22, 0.22)
for name, loc, power, size, color in [
    ('Key', (-3, -4, 6), 650, 4, (1, 0.84, 0.63)),
    ('Fill', (4, -1, 4), 430, 4, (0.73, 0.82, 1)),
    ('Rim', (0, 4, 5), 600, 3, (1, 0.72, 0.42))]:
    bpy.ops.object.light_add(type='AREA', location=loc)
    light = bpy.context.object
    light.name = 'Preview_' + name
    light.data.energy = power
    light.data.shape = 'DISK'
    light.data.size = size
    light.data.color = color
    light.rotation_euler = (Vector((0, 0, 0.6)) - light.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(3.0, -5.5, 4.0))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0.85)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.9
scene.camera = camera
scene.render.resolution_x = 1100
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(OUT / 'sentence_core_preview.png')
bpy.ops.render.render(write_still=True)
stats['preview_bytes'] = (OUT / 'sentence_core_preview.png').stat().st_size
(OUT / 'asset_stats.json').write_text(json.dumps(stats, indent=2) + '\n', encoding='utf-8')
print('ASSET_STATS ' + json.dumps(stats))
