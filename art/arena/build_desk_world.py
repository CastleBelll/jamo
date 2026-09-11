"""Original ASSET-04 geometry. Execute in live Blender through MCP.

Only writes art/arena; existing scenes and source assets are preserved.
Optional globals: ARENA_SIZES=[(name,width,depth)], RENDER_PREVIEW=False.
Blender Z-up maps to Godot Y-up; front is Blender -Y / Godot +Z.
"""
import bpy
import math
import json
import hashlib
from pathlib import Path
from mathutils import Vector
import numpy as np

OUT = Path(__file__).resolve().parent
REPO = OUT.parent.parent
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes.new('JAMO_ASSET04')
bpy.context.window.scene = scene
stats = []
assets = {}

def material(name, color, roughness=.8, metal=0):
    m = bpy.data.materials.new('Desk_' + name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metal
    return m

paper = material('Hanji', (.69,.57,.40))
edge = material('PaperEdges', (.52,.40,.25))
wood = material('Walnut', (.115,.059,.026))
brass = material('AgedBrass', (.27,.16,.055), .48, .65)
ink = material('Inkstone', (.022,.028,.025), .48)
leather = material('Oxblood', (.095,.032,.019))
cloth = material('IndigoCloth', (.035,.064,.064))
ceramic = material('Clay', (.19,.093,.047))
leaf = material('OliveLeaves', (.075,.13,.038))
lamp = material('WarmLanternPaper', (.72,.39,.105))
p = next(n for n in lamp.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
p.inputs['Emission Color'].default_value = (.9,.36,.065,1)
p.inputs['Emission Strength'].default_value = .55

def texture(mat, name, kind):
    # Deterministic, seamless original color maps. No procedural shader dependency.
    n=512
    rng=np.random.default_rng(404 if kind=='paper' else 405)
    y,x=np.mgrid[0:n,0:n].astype(np.float32)/n
    if kind=='paper':
        v=.91 + .025*np.sin(2*math.pi*x*3)*np.cos(2*math.pi*y*2)
        v+=rng.normal(0,.017,(n,n))
        fibers=(rng.random((n,n))>.991)*rng.uniform(.015,.08,(n,n))
        v-=fibers
        colors=(.77,.67,.50)
    else:
        wave=np.sin(2*math.pi*(y*24+.13*np.sin(2*math.pi*x*2)))
        v=.80+.07*wave+.025*np.sin(2*math.pi*y*71)
        v+=rng.normal(0,.012,(n,n))
        colors=(.25,.13,.065)
    data=np.ones((n,n,4),dtype=np.float32)
    for c in range(3): data[:,:,c]=np.clip(v*colors[c],0,1)
    im=bpy.data.images.new(name,width=n,height=n)
    im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(data.ravel())
    im.filepath_raw=str(OUT/(name+'.png'))
    im.file_format='PNG'
    im.save()
    im.pack()
    node=mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=im
    bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])

texture(paper,'hanji_color','paper')
texture(wood,'walnut_color','wood')

def box(name, loc, size, mat, bevel=0, rot=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object
    o.name=name
    o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft worn edges','BEVEL')
        mod.width=bevel
        mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=o.modifiers[-1].name)
    o.rotation_euler.z=rot
    o.data.materials.append(mat)
    return o

def cone(name,loc,r1,r2,depth,mat,vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=depth,location=loc)
    o=bpy.context.object
    o.name=name
    o.data.materials.append(mat)
    return o

def rod(name,a,b,r,mat,vertices=8):
    a,b=Vector(a),Vector(b)
    o=cone(name,(a+b)/2,r,r,(b-a).length,mat,vertices)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def mesh(name,verts,faces,mat):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    o=bpy.data.objects.new(name,data)
    scene.collection.objects.link(o)
    data.materials.append(mat)
    return o

def finish(name,objects,notes):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    o=objects[0]
    o.name=name
    scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    # Object-local planar UVs retain physical grain density for every size variant.
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for poly in o.data.polygons:
        normal=poly.normal
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            if abs(normal.z)>.5: pair=(v.x/4,v.y/4)
            elif abs(normal.y)>.5: pair=(v.x/4,v.z/4)
            else: pair=(v.y/4,v.z/4)
            uv.data[li].uv=pair
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
        use_active_scene=True,export_animations=False,export_yup=True)
    o.data.calc_loop_triangles()
    verts=[o.matrix_world@Vector(v) for v in o.bound_box]
    lo=[min(v[i] for v in verts) for i in range(3)]
    hi=[max(v[i] for v in verts) for i in range(3)]
    stats.append(dict(id=name,triangles=len(o.data.loop_triangles),mesh_nodes=1,
        surfaces=len(set(p.material_index for p in o.data.polygons)),
        bounds_min=[lo[0],lo[2],-hi[1]],bounds_max=[hi[0],hi[2],-lo[1]],
        bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),notes=notes))
    assets[name]=o
    o.hide_render=True
    o.hide_set(True)
    return o

sizes=globals().get('ARENA_SIZES',[('arena_square_8',8,8),('arena_wide_10x8',10,8),('arena_large_12x9',12,9)])
for name,w,d in sizes:
    parts=[box('Thin walnut writing board',(0,0,-.145),(w+.24,d+.24,.21),wood,.035)]
    parts += [box('Compressed page layers',(0,0,-.054),(w+.035,d+.035,.09),edge,.012)]
    # Top edge stays at 0: compatible with existing character ground offset.
    parts += [box('Quiet paper play surface',(0,0,-.012),(w,d,.024),paper)]
    # A tiny folded paper corner and edge fibres soften the manufactured rectangle.
    parts.append(mesh('Turned paper corner',[(w/2-.23,d/2,.004),
        (w/2,d/2-.23,.004),(w/2-.20,d/2-.20,.047)],[(0,1,2)],edge))
    # Short, low-contrast crease fragments point front-to-back without painting lanes.
    crease=material(name+'_Crease',(.57,.47,.33))
    for x in (-w*.27,w*.27):
        for y,length in [(-d*.35,.68),(-d*.14,.45),(d*.08,.6)]:
            parts.append(mesh('Fold trace',[(x-.008,y, .001),(x+.008,y,.001),
                (x+.004,y+length,.001),(x-.004,y+length,.001)],[(0,1,2,3)],crease))
    # Sparse ruling lives in the margins, clear of monster approach lanes.
    for side in (-1,1):
        for i in range(5):
            y=-d*.34+i*d*.17
            parts.append(box('Margin ruling',(side*(w*.5-.19),y,.001),(.11,.012,.001),edge))
    o=finish(name,parts,dict(paper_width=w,paper_depth=d,top_y=0,desk_y=-.25,scale_xz_range=[.8,1.25]))

# Four separate props, all bottom-centred at origin and independently placeable.
parts=[]
for j,(w,d,h,angle,cover) in enumerate([(1.8,1.25,.27,-.07,leather),(1.6,1.3,.31,.09,cloth),(1.7,1.12,.24,-.025,leather)]):
    z=sum([.31,.35,.28][:j])
    for k in (0,h):
        parts.append(box('Book cover',(0,0,z+k+.02),(w,d,.04),cover,.016,angle))
    parts.append(box('Book page block',(0,0,z+h/2+.02),(w-.10,d-.075,h-.035),edge,.01,angle))
    parts.append(box('Rounded spine',(-w/2+.035,0,z+h/2+.02),(.07,d,h),cover,.022,angle))
    for y in (-d*.30,d*.30):
        parts.append(box('Spine band',(-w/2-.007,y,z+h/2+.02),(.018,.055,h*.8),brass,.005))
    for dz in (-.055,0,.055):
        parts.append(box('Page separation',(0,-d/2+.025,z+h/2+dz),(.95*w,.008,.007),paper))
parts.append(box('Top label',(.15,0,.943),(.47,.58,.008),paper,.002,-.025))
parts.append(box('Bookmark tail',(.38,-.71,.32),(.13,.34,.014),leather,.008))
finish('prop_book_stack',parts,dict(role='back-left perimeter',bottom_y=0))

parts=[cone('Lamp foot',(0,0,.055),.40,.36,.11,brass,16),
    cone('Lamp plinth',(0,0,.14),.29,.27,.08,ink,12),
    cone('Lantern warm paper',(0,0,.75),.255,.255,1.08,lamp,8),
    cone('Lower lantern collar',(0,0,.24),.33,.32,.12,brass,12),
    cone('Upper lantern collar',(0,0,1.31),.32,.34,.12,brass,12),
    cone('Lantern cap',(0,0,1.46),.38,.12,.19,ink,12),
    cone('Cap finial',(0,0,1.59),.07,.035,.10,brass,8)]
for i in range(4):
    a=math.pi/4+i*math.pi/2
    x,y=.267*math.cos(a),.267*math.sin(a)
    parts.append(rod('Lantern frame',(x,y,.26),(x,y,1.32),.021,brass))
for i in range(8):
    a,b=math.pi*i/8,math.pi*(i+1)/8
    parts.append(rod('Carry loop',(.17*math.cos(a),0,1.65+.17*math.sin(a)),
        (.17*math.cos(b),0,1.65+.17*math.sin(b)),.017,brass,6))
finish('prop_lantern',parts,dict(role='back-left beyond books',bottom_y=0,real_light=False))

parts=[box('Inkstone base',(0,0,.075),(1.25,.72,.15),ink,.08),
    box('Ink pool',(0,-.015,.156),(.86,.41,.013),ink,.06)]
for x in (-.52,.52): parts.append(box('Raised inkstone rim',(x,0,.185),(.1,.58,.10),ink,.022))
parts.append(box('Inkstone back rim',(0,.27,.185),(1.06,.09,.10),ink,.025))
parts.append(box('Brush rest',(.0,-.53,.065),(.58,.20,.13),ceramic,.035))
for x in (-.17,.16):
    parts.append(rod('Bamboo brush',(x,-.87,.17),(x+.20,.76,.32),.032,wood,8))
    parts.append(rod('Brush brass ferrule',(x,-.87,.17),(x-.017,-1.01,.157),.038,brass,8))
    o=cone('Ink brush hairs',(x-.026,-1.105,.148),.003,.044,.22,ink,8)
    o.rotation_euler.x=math.pi/2+.09
    parts.append(o)
finish('prop_brush_inkstone',parts,dict(role='right edge outside play surface',bottom_y=0))

parts=[cone('Clay pot',(0,0,.28),.29,.42,.56,ceramic,12),
    cone('Pot lip',(0,0,.565),.455,.455,.11,ceramic,12),
    cone('Visible soil',(0,0,.623),.392,.392,.006,ink,12)]
for j in range(5):
    a=j*2.399
    tip=Vector((math.cos(a)*.42,math.sin(a)*.42,1.05+j*.105))
    start=Vector((0,0,.62))
    parts.append(rod('Plant stem',start,tip,.015,leaf,6))
    for t in (.6,1):
        base=start.lerp(tip,t)
        direction=Vector((math.cos(a+.65)*.46,math.sin(a+.65)*.46,.09))
        mid=base+direction*.5
        side=Vector((-direction.y,direction.x,.03))*.40
        verts=[base,mid+side,base+direction,mid-side,mid+Vector((0,0,.095))]
        parts.append(mesh('Faceted olive leaf',verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],leaf))
finish('prop_potted_plant',parts,dict(role='back-right perimeter',bottom_y=0))

parts=[]
for i in range(9):
    parts.append(box('Walnut desk plank',(0,(i-4)*2,-.12),(32,1.993,.24),wood,.014))
finish('desk_background',parts,dict(role='continuous desk below arena',top_y=0,recommended_y=-.255))

# Preview composition is intentionally separate from individually exported GLBs.
def show(name,loc,rot=0):
    o=assets[name]
    o.hide_render=False
    o.hide_set(False)
    o.location=loc
    o.rotation_euler.z=rot
    return o

preview_floor='arena_wide_10x8' if 'arena_wide_10x8' in assets else sizes[0][0]
show(preview_floor,(0,0,0))
show('desk_background',(0,0,-.255))
show('prop_book_stack',(-6.12,3.10,-.255),-.10)
show('prop_lantern',(-5.90,.88,-.255))
show('prop_potted_plant',(6.02,3.5,-.255))
show('prop_brush_inkstone',(6.15,-.1,-.255),-.1)

def reference(path,loc,scale=1,lean=0):
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objs=set(scene.objects)-before
    root=bpy.data.objects.new('Preview reference only',None)
    scene.collection.objects.link(root)
    for o in objs:
        if o.parent not in objs: o.parent=root
    root.location=loc
    root.scale=(scale,)*3
    root.rotation_euler.x=math.radians(lean)
    return root

reference(REPO/'art/objective/sentence_core.glb',(0,2.55,0),.75)
preview_chars=[('giyeok',-3.2,-2.7),('ieung',-.9,-3),('mieum',2.8,-2.6),
    ('siot',-2,-1.1),('hieut',1.8,-.9),('nieun',-3.6,.8),
    ('bieup',3.4,.6),('digeut',-.5,.6)]
for name,x,y in preview_chars:
    reference(REPO/('art/monsters/characters/'+name+'.glb'),(x,y,.0201),1,-20)

world=bpy.data.worlds.new('Desk dusk studio')
world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs[0].default_value=(.23,.19,.15,1)
background.inputs[1].default_value=.5
scene.world=world
for name,loc,power,size,color in [('Window key',(-7,-1,9),1900,7,(1,.76,.49)),
    ('Soft fill',(5,-4,7),950,8,(.64,.75,1)),('Rear rim',(1,7,8),1000,6,(1,.75,.46))]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    o=bpy.context.object
    o.name=name
    o.data.energy=power
    o.data.shape='DISK'
    o.data.size=size
    o.data.color=color
    o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-13,15.49))
cam=bpy.context.object
cam.name='Preview_Orthographic_50deg'
cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=15.6
scene.camera=cam
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'desk_world_3quarter.png')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            s=area.spaces.active
            s.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            s.region_3d.view_location=(0,0,.1)
            s.region_3d.view_distance=17
            s.region_3d.view_perspective='ORTHO'
            s.overlay.show_overlays=False
            s.shading.color_type='MATERIAL'
            s.shading.light='STUDIO'
doc=dict(assets=stats,environment_budget_triangles=4000,
    active_environment_triangles=sum(s['triangles'] for s in stats if not s['id'].startswith('arena_'))+
        next(s['triangles'] for s in stats if s['id']==preview_floor),
    combat_baseline_triangles=18460,
    provenance='Original procedural geometry and color maps; existing project assets read-only in preview; no external service',
    preview_camera=dict(godot_position=[0,15.49,13],pitch_degrees=-50,width=15.6),
    preview_floor=preview_floor,preview_characters=len(preview_chars))
(OUT/'asset_stats.json').write_text(json.dumps(doc,indent=2),encoding='utf-8')
print('DESK_WORLD_BUILT '+json.dumps(doc))
if globals().get('RENDER_PREVIEW',True):
    bpy.app.timers.register(lambda: bpy.ops.render.render(write_still=True) and None,first_interval=1)
