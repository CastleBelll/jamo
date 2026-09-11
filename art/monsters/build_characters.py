"""Run in live Blender via MCP; original ASSET-02 GLBs are read-only sources."""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parent
OUT = BASE / 'characters'
OUT.mkdir(exist_ok=True)
scene = bpy.data.scenes.new('JAMO_ASSET03')
bpy.context.window.scene = scene
scene.world = bpy.data.worlds.new('JAMO studio')
scene.world.color = (.3, .3, .3)

def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = .86
    return m

paper = mat('CharacterPaper', (.72, .58, .39))
edge = mat('CharacterEdge', (.43, .29, .15))
ink = mat('Jamo_Character_Ink', (.016, .009, .006))
old = json.loads((BASE / 'asset_stats.json').read_text(encoding='utf-8'))
stats = []
roots = []
# Eye coordinates are in the original glyph plane, before leg accommodation.
eyes = {'giyeok':(.19,.43), 'nieun':(-.06,.047), 'digeut':(-.05,.55),
        'rieul':(-.04,.55), 'mieum':(.06,.55), 'bieup':(0,.46),
        'siot':(0,.49), 'ieung':(0,.55), 'hieut':(0,.585),
        'eo':(.142,.34), 'yeo':(.142,.40), 'o':(0,.30),
        'u':(0,.35), 'eu':(0,.046), 'i':(0,.36)}

def cube_part(location, scale):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = o.modifiers.new('Soft ink corners', 'BEVEL')
    mod.width = .008
    mod.segments = 1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

for index, entry in enumerate(old['assets']):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.import_scene.gltf(filepath=str(BASE / (entry['id'] + '.glb')))
    glyph = next(o for o in bpy.context.selected_objects if o.type == 'MESH')
    glyph.name = 'Glyph'
    h = max(v.co.z for v in glyph.data.vertices)
    leg_h = min(.105, h * .34)
    for v in glyph.data.vertices:
        v.co.z = leg_h + v.co.z * (h-leg_h) / h
    # Retain material slot names/order; the new default is title-reference paper.
    for slot, source, name in [(0,paper,'Jamo_Ink'), (1,edge,'Jamo_Pressed_Hanji_Edge')]:
        target = glyph.data.materials[slot]
        target.diffuse_color = source.diffuse_color
        next(n for n in target.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Base Color'].default_value = source.diffuse_color
        existing = bpy.data.materials.get(name)
        if existing and existing != target: existing.name = 'Archived_' + name
        target.name = name
    root = bpy.data.objects.new('JamoCharacter', None)
    scene.collection.objects.link(root)
    glyph.parent = root
    parts = [glyph]
    ex, ez = eyes[entry['id']]
    for side, sign in [('L',-1), ('R',1)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=4,
            location=(ex+sign*.021,-.057,leg_h+ez*(h-leg_h)/h))
        eye = bpy.context.object
        eye.name = 'Eye_'+side
        eye.scale = (.010,.010,min(.019,h*.13))
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        eye.data.materials.append(ink)
        eye.parent = root
        parts.append(eye)
    w = entry['dimensions_godot_xyz'][0]
    span = min(.14, w*.26)
    if entry['id'] in ('giyeok','u','eo','yeo'): span=.027
    if entry['id'] in ('ieung','hieut'): span=.045
    if entry['id']=='siot': span=.205
    cx = .196 if entry['id']=='giyeok' else (.141 if entry['id'] in ('eo','yeo') else 0)
    for side, sign in [('L',-1), ('R',1)]:
        x = cx+sign*span
        stem = cube_part((x,0,leg_h*.55),(.024,.028,leg_h*1.10))
        foot = cube_part((x,-.012,leg_h*.12),(.040,.070,leg_h*.24))
        bpy.ops.object.select_all(action='DESELECT')
        stem.select_set(True)
        foot.select_set(True)
        bpy.context.view_layer.objects.active = stem
        bpy.ops.object.join()
        stem.name = 'Leg_'+side
        stem.data.materials.append(ink)
        scene.cursor.location = (x,0,leg_h)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        stem.parent = root
        parts.append(stem)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in parts: o.select_set(True)
    path = OUT / (entry['id']+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        export_animations=False,export_yup=True,use_active_scene=True)
    tris = 0
    for o in parts:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    stats.append(dict(id=entry['id'],glyph=entry['glyph'],triangles=tris,
        previous_triangles=entry['triangles'],added_triangles=tris-entry['triangles'],
        height=h,leg_pivot_height=leg_h,mesh_nodes=5,surfaces=6))
    root.rotation_euler.x=math.radians(-20)
    root.location=(index*.80-5.6,0,.0201)
    for o in parts: o.name=entry['id']+'_'+o.name
    roots.append(root)

doc = dict(assets=stats, slots=['Jamo_Ink','Jamo_Pressed_Hanji_Edge'],
    worst_case_20_plus_core=max(s['triangles'] for s in stats)*20+2780,
    previous_worst_case=13020, catalog_triangles=sum(s['triangles'] for s in stats),
    provenance='Original procedural adaptation of ASSET-02; title_bg.png visual reference; no external assets')
(OUT/'asset_stats.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.007))
bpy.context.object.data.materials.append(mat('Studio paper',(.24,.17,.10)))
for loc,power,size in [((0,-4,7),1700,8),((3,3,5),1100,6)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    o=bpy.context.object
    o.data.energy=power
    o.data.shape='DISK'
    o.data.size=size
    o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(1,-12,11))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,.28))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=12.5
scene.camera=cam
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=3600
scene.render.resolution_y=600
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'lineup_3quarter.png')
for area in [a for screen in bpy.data.screens for a in screen.areas]:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
        area.spaces.active.region_3d.view_location=(0,0,.3)
        area.spaces.active.region_3d.view_distance=10
        area.spaces.active.region_3d.view_perspective='ORTHO'
        area.spaces.active.overlay.show_overlays=False
        area.spaces.active.shading.color_type='MATERIAL'
print('CHARACTERS_BUILT '+json.dumps(doc,ensure_ascii=False))




bpy.app.timers.register(lambda: bpy.ops.render.render(write_still=True) and None, first_interval=1)

