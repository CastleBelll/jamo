"""Blender 5.2 bpy production: exact OFL outlines, rigid skinning, NLA clips.
Run blender --background --python art/models/build_models.py -- [asset IDs].
Blender: Z up / front +Y; glTF export: Y up / front -Z.
"""
import bpy, math, json, sys, hashlib, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import numpy as np

ART=Path(__file__).resolve().parents[1];OUT=ART/'models'
NAMES='giyeok nieun digeut rieul mieum bieup siot ieung jieut chieut kieuk pieup hieut a eo yeo o yo u i'.split()
CHARS=dict(zip(NAMES,'ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅍㅎㅏㅓㅕㅗㅛㅜㅣ'))
PROFILES={}
import re
for p in (ART.parent/'resources/motion_profiles').glob('*.tres'):
    s=p.read_text(encoding='utf-8');pid=re.search(r'id = &"(.*?)"',s).group(1)
    for ch in re.search(r'jamo = .*?\(\[(.*?)\]\)',s).group(1).split(','):
        PROFILES[ch.strip().strip('"')]=(pid,float(re.search(r'period = ([\d.]+)',s).group(1)))

def activate(obj):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj

def texture(kind):
    size=256;yy,xx=np.mgrid[:size,:size];rng=np.random.default_rng(731)
    points=rng.uniform(0,size,(38,2));d=np.sort(np.stack([(xx-p[0])**2+(yy-p[1])**2 for p in points]),axis=0)
    crack=(np.sqrt(d[1])-np.sqrt(d[0]))<.52
    grain=rng.normal(0,.005,(size,size,1))
    base={'cream':(.88,.81,.66),'black':(.035,.028,.022),'gray':(.43,.43,.42),'gold':(.72,.40,.075)}[kind]
    rgb=np.broadcast_to(np.array(base),(size,size,3)).copy()+grain
    gold=np.array((.72,.40,.10));dark=np.array((.25,.17,.08))
    rgb[crack]=gold if kind in ('black','gold') else (np.array(base)*.84)
    if kind=='gold':
        flakes=(np.sin(xx*.074+np.cos(yy*.052))*np.cos(yy*.073+xx*.019))>.54
        rgb[flakes]=dark
    rgba=np.dstack([np.clip(rgb,0,1),np.ones((size,size))]).astype(np.float32)
    im=bpy.data.images.new('PBR_'+kind,width=size,height=size,alpha=True)
    im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(OUT/'textures'/f'{kind}.png');im.file_format='PNG';im.save();im.pack()
    return im

def materials():
    mats={}
    for kind in ('cream','black','gray','gold'):
        m=bpy.data.materials.new('Porcelain_'+kind);m.use_nodes=True;m.use_backface_culling=True;p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Roughness'].default_value=.26 if kind!='gray' else .48
        p.inputs['Metallic'].default_value=.78 if kind=='gold' else (.10 if kind=='black' else 0)
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=texture(kind)
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']);mats[kind]=m
    m=bpy.data.materials.new('Eyes_Feet_Ink');m.diffuse_color=(.009,.008,.006,1);m.use_nodes=True;m.use_backface_culling=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.24
    mats['ink']=m;return mats

def glyph(ch,mat):
    curve=bpy.data.curves.new('Exact_OFL_Glyph','FONT');curve.body=ch;curve.font=bpy.data.fonts.load(str(OUT/'JAMOShapeGuide.ttf'))
    curve.size=1;curve.extrude=.050;curve.bevel_depth=.013;curve.bevel_resolution=1;curve.resolution_u=2
    obj=bpy.data.objects.new('Porcelain_Body',curve);bpy.context.collection.objects.link(obj)
    obj.rotation_euler.x=math.pi/2;activate(obj);bpy.ops.object.convert(target='MESH')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    vs=[v.co for v in obj.data.vertices];minz=min(v.z for v in vs);maxz=max(v.z for v in vs);scale=.82/(maxz-minz)
    cx=(min(v.x for v in vs)+max(v.x for v in vs))/2
    # Viewed from +Y (glTF -Z), camera screen-right is -X: reflect the outline
    # so asymmetric jamo read correctly from the declared front, never mirrored.
    for v in obj.data.vertices:v.co=Vector((-(v.co.x-cx)*scale,v.co.y*scale,(v.co.z-minz)*scale+.18))
    obj.data.flip_normals() # reflection changes handedness: restore outward winding
    obj.data.materials.append(mat)
    # Planar x/z UVs preserve the generated glaze texture in GLB (no shader baking dependency).
    uv=obj.data.uv_layers.new(name='GlazeUV')
    for loop in obj.data.loops:
        v=obj.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(v.x+.5,v.z)
    for p in obj.data.polygons:p.use_smooth=True
    obj.data.update();return obj

def sphere(name,loc,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def surface(body,z):
    verts=[v.co.copy() for v in body.data.vertices];polys=[list(p.vertices) for p in body.data.polygons]
    tree=BVHTree.FromPolygons(verts,polys)
    width=body.dimensions.x;hits=[]
    for x in np.linspace(-width/2,width/2,220):
        loc,normal,idx,dist=tree.ray_cast(Vector((x,3,z)),Vector((0,-1,0)),6)
        if loc:hits.append(loc)
    return hits

def rig_mesh(obj,rig,bone):
    vg=obj.vertex_groups.new(name=bone);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod=obj.modifiers.new('Rigid_Skin','ARMATURE');mod.object=rig;obj.parent=rig

def rig(body,eye_fraction,silent=False):
    data=bpy.data.armatures.new('Jamo_Rig');arm=bpy.data.objects.new('Armature',data);bpy.context.collection.objects.link(arm)
    hits=surface(body,.18+.82*eye_fraction)
    if not hits:hits=surface(body,.85)
    assert hits,'eye row must intersect exact glyph'
    center=(hits[0].x+hits[-1].x)/2
    # Pick nearest solid stroke point to each intended eye, including two-column glyphs.
    eye_span=min(.14,max(.048,(hits[-1].x-hits[0].x)*.24))
    eyes=[]
    if not silent:
        for sign in (-1,1):
            hit=min(hits,key=lambda v:abs(v.x-(center+sign*eye_span)))
            eyes.append(sphere('Eye_L' if sign<0 else 'Eye_R',(hit.x,hit.y+.011,hit.z),(.025,.019,.025),MATS['ink']))
    low=surface(body,.22)
    if not low:low=surface(body,.27)
    assert low,'leg attachment row must intersect body'
    center=(low[0].x+low[-1].x)/2;span=min(.20,max(.045,(low[-1].x-low[0].x)*.28))
    positions=[center-span,center+span]
    activate(arm);bpy.ops.object.mode_set(mode='EDIT')
    for name,head,tail,parent in [('root',(0,0,0),(0,0,.12),None),('body',(0,0,.59),(0,0,.99),'root'),
                                ('leg.L',(positions[0],0,.19),(positions[0],0,.045),'root'),('leg.R',(positions[1],0,.19),(positions[1],0,.045),'root')]:
        b=data.edit_bones.new(name);b.head=head;b.tail=tail
        if parent:b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');rig_mesh(body,arm,'body')
    for e in eyes:rig_mesh(e,arm,'body')
    for x,bone in zip(positions,('leg.L','leg.R')):
        stem=sphere(bone+'_stem',(x,0,.13),(.021,.025,.075),MATS['ink'])
        foot=sphere(bone+'_foot',(x,.025,.037),(.039,.064,.037),MATS['ink'])
        rig_mesh(stem,arm,bone);rig_mesh(foot,arm,bone)
    return arm

def reset_pose(arm):
    for b in arm.pose.bones:b.location=(0,0,0);b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.scale=(1,1,1)

def clips(arm,profile,period):
    arm.animation_data_create()
    durations={'idle':1.0,'walk':period,'hit':.16,'purify':.45}
    for name,duration in durations.items():
        reset_pose(arm);action=bpy.data.actions.new(name);arm.animation_data.action=action;end=round(duration*100)
        for frame in sorted(set([0,end,*range(0,end+1,max(1,end//8))])):
            reset_pose(arm);u=frame/end;s=math.sin(u*2*math.pi);root=arm.pose.bones['root'];body=arm.pose.bones['body']
            # Bones point along Blender Z: their local Y is vertical and local Z is depth.
            if name=='idle':body.scale=(1+.012*s,1-.01*s,1+.012*s)
            elif name=='hit':
                squash=math.sin(math.pi*u);body.scale=(1+.17*squash,1-.22*squash,1+.10*squash)
            elif name=='purify':
                q=max(.001,1-u);root.scale=(q,q,q);body.rotation_euler.z=.65*u;body.location.y=-.1*u
                for b in ('leg.L','leg.R'):arm.pose.bones[b].rotation_euler.x=(-1 if b.endswith('L') else 1)*u*.7
            elif profile=='ROLL':body.rotation_euler.z=2*math.pi*u
            elif profile=='BOUNCE':root.location.y=.07*(1-math.cos(u*2*math.pi));body.scale=(1-.03*s,1+.04*s,1)
            elif profile=='GLIDE':body.location.y=.008*s
            else:
                amount=.34 if profile=='LIGHT_STEP' else (.20 if profile=='HEAVY_STEP' else .24)
                arm.pose.bones['leg.L'].rotation_euler.x=amount*s;arm.pose.bones['leg.R'].rotation_euler.x=-amount*s
                body.rotation_euler.z=(.065 if profile=='SWAY' else .03)*s
                if profile=='LIGHT_STEP':body.location.y=.025*(1-math.cos(u*4*math.pi))
                if profile=='HEAVY_STEP':body.location.y=.012*(1-math.cos(u*4*math.pi))
            for bone in arm.pose.bones:
                for path in ('location','rotation_euler','scale'):bone.keyframe_insert(path,frame=frame,group=bone.name)
        # Layered Blender 5 actions expose curves via channelbags, not legacy action.fcurves.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        for key in fc.keyframe_points:key.interpolation='LINEAR'
        track=arm.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action);strip.name=name
        track.mute=True
    arm.animation_data.action=None;reset_pose(arm)
    return durations

def camera_preview(asset):
    scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
    if scene.world is None:scene.world=bpy.data.worlds.new('QA_World')
    scene.world.color=(.17,.17,.17)
    size=2 if asset.startswith('boss_') else 1
    bpy.ops.object.camera_add(location=(.9*size,3.2*size,1.4*size));cam=bpy.context.object;cam.name='QA_Camera'
    direction=Vector((0,0,.48*size))-cam.location;cam.rotation_euler=direction.to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.65*size;scene.camera=cam
    for pos,power,size in [((1,2,3),140,3),((-2,1,1),90,2)]:
        bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.view_settings.view_transform='AgX';scene.render.filepath=str(OUT/'previews'/f'{asset}.png');bpy.ops.render.render(write_still=True)

def build(asset):
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    boss=asset.startswith('boss_');name=asset.split('_',1)[1];letter={'silence':'mieum','greed':'bieup'}.get(name,name);ch=CHARS[letter]
    material={'mieum':'black','silence':'gray','ieung':'cream','greed':'gold'}.get(name) if boss else 'cream'
    body=glyph(ch,MATS[material]);fraction={'nieun':.72,'bieup':.51,'siot':.72,'chieut':.68,'hieut':.66,'u':.88}.get(letter,.88)
    if boss and name=='ieung':
        from mathutils import Matrix
        tilt=Matrix.Rotation(.16,4,'Y')
        for v in body.data.vertices:v.co=tilt @ (v.co-Vector((0,0,.59)))+Vector((0,0,.59))
        lo=min(v.co.z for v in body.data.vertices);hi=max(v.co.z for v in body.data.vertices)
        for v in body.data.vertices:v.co.z=.18+(v.co.z-lo)*.82/(hi-lo)
        body.data.update()
    arm=rig(body,fraction,boss and name=='silence');profile,period=PROFILES[ch]
    if boss and name=='silence':
        for j in range(9):
            x=(-1 if j%2 else 1)*(.43+.025*(j%3));z=.32+.07*j
            mesh=bpy.data.meshes.new('Dispersing_Ink');r=.013+.003*(j%3)
            mesh.from_pydata([(x-r,.05,z-r),(x+r,.05,z-r),(x,.05,z+r),(x,.09,z)],[],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)])
            chip=bpy.data.objects.new('Ink_Particle',mesh);bpy.context.collection.objects.link(chip);mesh.materials.append(MATS['ink']);rig_mesh(chip,arm,'body')
    durations=clips(arm,profile,period)
    if boss:arm.scale=(2,2,2)
    bpy.context.scene.render.fps=100;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=100;bpy.context.scene.frame_set(0)
    activate(arm)
    for o in bpy.context.scene.objects:
        if o.type=='MESH':o.select_set(True)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert tris<=3000,(asset,tris)
    file=OUT/f'{asset}.glb'
    bpy.ops.export_scene.gltf(filepath=str(file),export_format='GLB',use_selection=True,export_yup=True,
                              export_animations=True,export_animation_mode='NLA_TRACKS',export_frame_range=False,
                              export_force_sampling=True,export_skins=True,export_extras=True)
    record={'asset':asset,'jamo':ch,'profile':profile,'triangles':tris,'bones':len(arm.data.bones),
            'bone_names':[b.name for b in arm.data.bones],'clips':durations,'height':2 if boss else 1,
            'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    (OUT/'inspection'/f'{asset}.json').write_text(json.dumps(record,indent=2,ensure_ascii=False),encoding='utf-8')
    # Store the actual 1-unit/2-unit rest pose; cameras/lights never enter GLB.
    for track in arm.animation_data.nla_tracks:track.mute=True
    reset_pose(arm);camera_preview(asset)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'blend'/f'{asset}.blend'))
    print('MODEL_PASS',asset,tris)

for folder in ('textures','previews','inspection','blend'):(OUT/folder).mkdir(parents=True,exist_ok=True)
assets=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['char_'+n for n in NAMES]+['boss_'+n for n in ('mieum','silence','ieung','greed')]
for a in assets:
    bpy.ops.wm.read_factory_settings(use_empty=True);MATS=materials();build(a)
