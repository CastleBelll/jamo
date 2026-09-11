"""Original procedural JAMO glyphs. Blender 5.2, no fonts or external assets.
Run with --background --factory-startup --python art/monsters/build_jamo.py.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = .88
    return m

ink = material('Jamo_Ink', (.043, .024, .013))
edge = material('Jamo_Pressed_Hanji_Edge', (.30, .185, .085))
parts = []

def solid(points):
    n = len(points)
    verts = [(x, y, z) for y in (-.055, .055) for x, z in points]
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    data = bpy.data.meshes.new('Stroke')
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new('Stroke', data)
    bpy.context.collection.objects.link(obj)
    parts.append(obj)
    return obj

def bar(x1, z1, x2, z2, width=.092):
    dx, dz = x2-x1, z2-z1
    length = math.hypot(dx, dz)
    px, pz = -dz/length*width/2, dx/length*width/2
    return solid([(x1+px,z1+pz),(x1-px,z1-pz),(x2-px,z2-pz),(x2+px,z2+pz)])

def ring(cx, cz, rx, rz, width=.09, count=32):
    # Connected annulus; an actual opening, never a painted dark disk.
    verts = [(cx+math.cos(i*math.tau/count)*a,y,cz+math.sin(i*math.tau/count)*b)
             for y in (-.055,.055) for a,b in ((rx,rz),(rx-width,rz-width)) for i in range(count)]
    faces=[]
    for i in range(count):
        j=(i+1)%count
        faces += [(i,j,count+j,count+i), (2*count+i,3*count+i,3*count+j,2*count+j),
                  (i,2*count+i,2*count+j,j),(count+i,count+j,3*count+j,3*count+i)]
    data=bpy.data.meshes.new('OpenRing')
    data.from_pydata(verts,[],faces)
    data.update()
    obj=bpy.data.objects.new('OpenRing',data)
    bpy.context.collection.objects.link(obj)
    parts.append(obj)

def square():
    # Four mitred sections meet without overlapping faces on the visible plane.
    outer=[(-.25,0),(.25,0),(.25,.60),(-.25,.60)]
    inner=[(-.155,.095),(.155,.095),(.155,.505),(-.155,.505)]
    for i in range(4):
        j=(i+1)%4
        solid([outer[i],outer[j],inner[j],inner[i]])

names=[('giyeok','ㄱ','SWAY'),('nieun','ㄴ','HEAVY_STEP'),('digeut','ㄷ','HEAVY_STEP'),
       ('rieul','ㄹ','SWAY'),('mieum','ㅁ','BOUNCE'),('bieup','ㅂ','HEAVY_STEP'),
       ('siot','ㅅ','LIGHT_STEP'),('ieung','ㅇ','ROLL'),('hieut','ㅎ','BOUNCE'),
       ('eo','ㅓ','SWAY'),('yeo','ㅕ','SWAY'),('o','ㅗ','GLIDE'),('u','ㅜ','GLIDE'),
       ('eu','ㅡ','GLIDE'),('i','ㅣ','SWAY')]
stats=[]
models=[]
for name,glyph,motion in names:
    parts=[]
    if name=='giyeok': solid([(-.25,.6),(.25,.6),(.25,0),(.155,0),(.155,.505),(-.25,.505)])
    elif name=='nieun': solid([(-.25,.6),(-.155,.6),(-.155,.095),(.25,.095),(.25,0),(-.25,0)])
    elif name=='digeut': solid([(.25,.6),(-.25,.6),(-.25,0),(.25,0),(.25,.095),(-.155,.095),(-.155,.505),(.25,.505)])
    elif name=='rieul': solid([(-.25,.6),(.25,.6),(.25,.255),(-.155,.255),(-.155,.095),(.25,.095),(.25,0),(-.25,0),(-.25,.35),(.155,.35),(.155,.505),(-.25,.505)])
    elif name=='mieum': square()
    elif name=='bieup':
        solid([(-.25,.6),(-.155,.6),(-.155,.095),(.155,.095),(.155,.6),(.25,.6),(.25,0),(-.25,0)])
        bar(-.155,.25,.155,.25)
        bar(-.155,.46,.155,.46)
    elif name=='siot': solid([(-.28,0),(-.17,0),(0,.43),(.17,0),(.28,0),(.052,.6),(-.052,.6)])
    elif name=='ieung': ring(0,.30,.27,.30)
    elif name=='hieut':
        ring(0,.205,.23,.205,.083,24)
        bar(-.25,.47,.25,.47,.075)
        bar(-.14,.585,.14,.585,.075)
    elif name in ('eo','yeo'):
        bar(.10,.046,.10,.554)
        for z in ([.30] if name=='eo' else [.23,.40]): bar(-.23,z,.10,z)
    elif name in ('o','u'):
        z=.046 if name=='o' else .554
        bar(-.27,z,.27,z)
        bar(0,z,0,.55 if name=='o' else .046)
    elif name=='eu': bar(-.30,.046,.30,.046)
    elif name=='i': bar(0,.046,0,.554)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name='Glyph'
    # Weld touching ring sections and recalculate normals before beveling.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.00001)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.clear()
    obj.data.materials.append(ink)
    obj.data.materials.append(edge)
    for face in obj.data.polygons: face.material_index=0 if abs(face.normal.y)>.9 else 1
    bevel=obj.modifiers.new('Pressed soft edge','BEVEL')
    bevel.width=.006
    bevel.segments=1
    bevel.affect='EDGES'
    bevel.material=1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    min_z=min(v.co.z for v in obj.data.vertices)
    center_x=(min(v.co.x for v in obj.data.vertices)+max(v.co.x for v in obj.data.vertices))/2
    for vertex in obj.data.vertices:
        vertex.co.z-=min_z
        vertex.co.x-=center_x
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    obj.data.calc_loop_triangles()
    triangles=len(obj.data.loop_triangles)
    assert triangles<=1000,(name,triangles)
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_yup=True)
    obj.name='Preview_'+name
    stats.append(dict(id=name,glyph=glyph,motion_profile=motion,triangles=triangles,mesh_nodes=1,surfaces=2,
                      dimensions_godot_xyz=[round(obj.dimensions.x,5),round(obj.dimensions.z,5),round(obj.dimensions.y,5)],glb_bytes=path.stat().st_size))
    models.append(obj)
    # Match existing Lean (-20 degrees around Godot X); no baked lean in GLB.
    obj.rotation_euler.x=math.radians(-20)
    obj.location=((len(models)-1)%5*1.15-2.30, (len(models)-1)//5*1.65-1.65, .02)

stats_doc=dict(blender_version=bpy.app.version_string,assets=stats,triangle_budget_per_monster=1000,
               worst_case_20_plus_core=max(s['triangles'] for s in stats)*20+2780,
               provenance='Original procedural geometry and solid materials; no external assets, fonts, textures, rigs or animations.',
               slots=['Jamo_Ink','Jamo_Pressed_Hanji_Edge'])
(OUT/'asset_stats.json').write_text(json.dumps(stats_doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
floor=material('Preview warm paper',(.64,.49,.30))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012))
bpy.context.object.data.materials.append(floor)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.world.color=(.3,.3,.3)
for loc,power,size in [((-3,-4,7),950,5),((4,1,6),700,4)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object
    light.data.energy=power
    light.data.size=size
    light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-8,9.53))
camera=bpy.context.object
camera.location=Vector((0,0,.25))+Vector((0,-8,8*math.tan(math.radians(50))))
camera.rotation_euler=(Vector((0,0,.25))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=6.7
scene.camera=camera
scene.render.resolution_x=1500
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'jamo_lineup_3quarter.png')
bpy.ops.render.render(write_still=True)
print('JAMO_BUILD_PASS '+json.dumps(stats_doc,ensure_ascii=False))
