"""Inspect exported GLB binaries and skinned poses, without a game/editor import."""
import json, struct, hashlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

OUT=Path(__file__).resolve().parent
DT={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def load(path):
    data=path.read_bytes();magic,ver,length=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and ver==2 and length==len(data)
    n,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
    g=json.loads(data[20:20+n]);bn,bk=struct.unpack_from('<II',data,20+n);assert bk==0x004e4942
    blob=data[28+n:28+n+bn]
    def acc(i):
        a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dt=np.dtype(DT[a['componentType']]);nc=NC[a['type']]
        start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',nc*dt.itemsize)
        return np.ndarray((a['count'],nc),dtype=dt,buffer=blob,offset=start,strides=(stride,dt.itemsize)).copy()
    return g,blob,acc

def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=np.array(node.get('rotation',[0,0,0,1]),float);norm=np.linalg.norm([x,y,z,w]);x,y,z,w=np.array([x,y,z,w])/norm
    rot=np.array([[1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w],
                  [2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w],
                  [2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y]])
    m=np.eye(4);m[:3,:3]=rot@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m

def pose(g,acc,animation=None,time=0):
    nodes=[dict(n) for n in g['nodes']]
    if animation:
        for c in animation['channels']:
            s=animation['samplers'][c['sampler']];ts=acc(s['input'])[:,0];vs=acc(s['output']);j=max(0,min(len(ts)-2,np.searchsorted(ts,time)-1))
            u=float(np.clip((time-ts[j])/max(1e-8,ts[j+1]-ts[j]),0,1))
            a,b=vs[j],vs[j+1]
            if c['target']['path']=='rotation' and np.dot(a,b)<0:b=-b
            nodes[c['target']['node']][c['target']['path']]=a*(1-u)+b*u
    worlds={}
    def visit(i,parent):
        worlds[i]=parent@matrix(nodes[i])
        for child in nodes[i].get('children',[]):visit(child,worlds[i])
    for i in g['scenes'][g.get('scene',0)]['nodes']:visit(i,np.eye(4))
    points=[]
    for ni,n in enumerate(nodes):
        if 'mesh' not in n:continue
        for p in g['meshes'][n['mesh']]['primitives']:
            xyz=acc(p['attributes']['POSITION']);v=np.c_[xyz,np.ones(len(xyz))]
            if 'skin' in n:
                skin=g['skins'][n['skin']];ibm=acc(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
                sm=np.array([worlds[j]@ibm[k] for k,j in enumerate(skin['joints'])])
                joints=acc(p['attributes']['JOINTS_0']);weights=acc(p['attributes']['WEIGHTS_0'])
                vv=np.zeros_like(v)
                for col in range(4):vv+=np.einsum('nij,nj->ni',sm[joints[:,col]],v)*weights[:,col,None]
            else:vv=(worlds[ni]@v.T).T
            points.extend(vv[:,:3])
    return np.array(points)

def inspect(path):
    g,blob,acc=load(path);r=json.loads((OUT/'inspection'/f'{path.stem}.json').read_text(encoding='utf-8'))
    triangles=sum(acc(p['indices']).size//3 for m in g['meshes'] for p in m['primitives'])
    assert triangles==r['triangles'] and triangles<=3000
    for mesh in g['meshes']:
        for p in mesh['primitives']:
            v=acc(p['attributes']['POSITION']);ids=acc(p['indices']).ravel().reshape(-1,3)
            volume=np.einsum('ij,ij->i',v[ids[:,0]],np.cross(v[ids[:,1]],v[ids[:,2]])).sum()/6
            assert volume>0,(path.stem,mesh['name'],'inward winding')
    assert len(g['skins'])==1
    bones=[g['nodes'][j]['name'] for j in g['skins'][0]['joints']]
    assert set(bones)=={'root','body','leg.L','leg.R'}
    anims={a['name']:a for a in g['animations']};assert set(anims)=={'idle','walk','hit','purify'}
    durations={}
    for name,a in anims.items():
        lo=min(acc(s['input']).min() for s in a['samplers']);hi=max(acc(s['input']).max() for s in a['samplers'])
        durations[name]=float(hi-lo);assert abs(durations[name]-r['clips'][name])<1e-5
    for image in g['images']:
        assert 'uri' not in image and 'bufferView' in image
        view=g['bufferViews'][image['bufferView']];start=view.get('byteOffset',0)
        assert blob[start:start+8]==b'\x89PNG\r\n\x1a\n'
    assert g['images'] and all('pbrMetallicRoughness' in m for m in g['materials'])
    rest=pose(g,acc);lo,hi=rest.min(axis=0),rest.max(axis=0)
    assert abs(lo[1])<1e-5 and abs(hi[1]-r['height'])<1e-5,(path.stem,lo,hi)
    hit=pose(g,acc,anims['hit'],.08);assert hit[:,1].max()<hi[1]*.95
    gone=pose(g,acc,anims['purify'],.45);assert np.ptp(gone[:,1])<r['height']*.003
    for name in ('idle','walk'):
        start=pose(g,acc,anims[name],0);end=pose(g,acc,anims[name],durations[name])
        assert np.max(abs(start-end))<1e-5,(path.stem,name,'loop seam')
    if r['profile']=='BOUNCE':
        jump=pose(g,acc,anims['walk'],durations['walk']/2);assert jump[:,1].min()>r['height']*.1
    if r['profile']=='ROLL':
        for u in np.linspace(0,1,9):
            rolling=pose(g,acc,anims['walk'],durations['walk']*u)
            assert rolling[:,1].min()>-1e-5,(path.stem,'rolling below floor')
    eye_names=[n.get('name') for n in g['nodes'] if n.get('name','').startswith('Eye_')]
    assert len(eye_names)==(0 if path.stem=='boss_silence' else 2)
    r.update({'glb_triangles':triangles,'glb_bones':bones,'glb_durations':durations,
              'embedded_images':len(g['images']),'rest_min':lo.tolist(),'rest_max':hi.tolist(),
              'checks':'PASS: outward winding, skin, clips, durations, Y-up height/foot, embedded PBR, squash, disappearance, loop seam',
              'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    return r

def main():
    paths=sorted(OUT.glob('char_*.glb'))+sorted(OUT.glob('boss_*.glb'));assert len(paths)==24
    rows=[inspect(p) for p in paths]
    (OUT/'inspection'/'GLB_VALIDATION.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    sheet=Image.new('RGB',(1200,1000),(45,39,32));draw=ImageDraw.Draw(sheet)
    for k,r in enumerate(rows):
        x=(k%6)*200;y=(k//6)*250;im=Image.open(OUT/'previews'/f"{r['asset']}.png").convert('RGBA');im.thumbnail((196,214))
        sheet.paste(im,(x+(200-im.width)//2,y),im);draw.text((x+4,y+215),r['asset'],fill='#ead9b6');draw.text((x+4,y+231),f"{r['triangles']} tri / {r['profile']}",fill='#b8ac92')
    sheet.save(OUT/'previews'/'MODELS_CONTACT.jpg',quality=94)
    print('GLB_PASS',len(rows),'triangles',min(r['triangles'] for r in rows),max(r['triangles'] for r in rows))

if __name__=='__main__':main()
