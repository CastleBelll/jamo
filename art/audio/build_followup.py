"""Project-original follow-up audio, NumPy synthesis / libsndfile Vorbis.

No samples, provider credentials or third-party music are used. Mono 44.1 kHz
matches bgm_combat. Its source has A/E harmonic tones but no beat; boss rhythm
uses a documented 120 BPM grid (32 beats = 16 seconds), not an inferred tempo.
"""
from pathlib import Path
import hashlib, json, sys
import numpy as np
import soundfile as sf

ROOT=Path(__file__).resolve().parent
SR=44100
TAU=2*np.pi
LIMIT=10**(-3/20)

def time(seconds):return np.arange(round(seconds*SR))/SR

def fade_edges(x,attack=.0005,release=.003):
    x=x.copy();a=max(2,round(attack*SR));r=max(2,round(release*SR))
    x[:a]*=np.sin(np.linspace(0,np.pi/2,a))**2
    x[-r:]*=np.cos(np.linspace(0,np.pi/2,r))**2
    return x

def noise(t,seed):
    n=np.random.default_rng(seed).normal(0,1,len(t))
    return np.convolve(n,np.ones(9)/9,mode='same')

def wood(seconds,small=False):
    t=time(seconds);env=np.exp(-t/(.012 if small else .018))
    # Decaying resonances and a short fibrous attack, not a sine-only beep.
    x=(np.sin(TAU*1320*t)+.42*np.sin(TAU*2130*t)+.23*np.sin(TAU*3100*t))*env
    x+=noise(t,11 if small else 17)*np.exp(-t/.005)*.7
    return fade_edges(x,.00035,.003)

def brush_note(t,hz):
    return (np.sin(TAU*hz*t)+.25*np.sin(TAU*hz*2*t))*np.exp(-t/.055)

def confirm():
    t=time(.3);x=brush_note(t,660)
    age=t-.12;mask=age>=0
    x[mask]+=brush_note(age[mask],880)
    x+=noise(t,21)*np.exp(-t/.018)*.12
    return fade_edges(x,.001,.006)

def cancel():
    t=time(.25);x=brush_note(t,220)+.12*noise(t,25)*np.exp(-t/.01)
    return fade_edges(x,.001,.006)

def purified():
    t=time(1);x=np.zeros_like(t)
    for i,(hz,level,decay) in enumerate([(440,1,.28),(880,.5,.22),(1320,.24,.19),(1760,.13,.16)]):
        x+=level*np.sin(TAU*hz*t+i*.18)*np.exp(-t/decay)
    # Small upward cleansing shimmer; reverberant tail occupies the full second.
    shimmer=np.sin(TAU*(660*t+220*t*t))*np.exp(-t/.23)*.14
    x+=shimmer+noise(t,30)*np.exp(-t/.035)*.08
    return fade_edges(x,.001,.009)

def boss_layer():
    t=time(16);x=(np.cos(TAU*55*t)+.32*np.cos(TAU*110*t)+.15*np.cos(TAU*165*t))*.029
    x*=.9+.1*np.cos(TAU*t/16)
    # Every pulse is periodic in the full 16-second buffer. No global fade or
    # inserted silence: the continuous integer-cycle A/E drone bridges the seam.
    for step in range(64):
        if step%8==0:amp=.085
        elif step%8==4:amp=.060
        elif step%8 in (3,7):amp=.020
        else:continue
        age=np.mod(t-step*.25,16)
        attack=1-np.exp(-age/.0012)
        phase=TAU*(55*age+35*.028*(1-np.exp(-age/.028)))
        drum=(np.cos(phase)+.26*np.cos(phase*1.53))*np.exp(-age/.085)*attack
        x+=amp*drum
    return x

def write(name,x,peak_db):
    # Conservative headroom is rechecked after lossy decoding.
    peak=np.max(np.abs(x));x=x*(10**(peak_db/20)/peak)
    dest=ROOT/name;dest.parent.mkdir(parents=True,exist_ok=True)
    sf.write(dest,x,SR,format='OGG',subtype='VORBIS')
    return dest

def metrics(path,seconds,loop=False):
    info=sf.info(path);x,sr=sf.read(path)
    assert sr==SR and info.channels==1 and info.format=='OGG' and info.subtype=='VORBIS',info
    assert len(x)==round(seconds*SR),(path,len(x),seconds)
    peak=float(np.max(np.abs(x)));assert peak<=LIMIT,(path,peak)
    active=np.flatnonzero(np.abs(x)>10**(-60/20))
    head=float(active[0]/SR);tail=float((len(x)-1-active[-1])/SR)
    assert head<=.004 and tail<=.012,(path,head,tail)
    result={'path':'art/audio/'+str(path.relative_to(ROOT)).replace('\\','/'),
            'frames':len(x),'duration_seconds':len(x)/sr,'sample_rate':sr,
            'channels':info.channels,'format':info.format,'codec':info.subtype,
            'decoded_sample_peak_dbfs':float(20*np.log10(peak)),
            'leading_below_minus60_seconds':head,'trailing_below_minus60_seconds':tail,
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    if loop:
        jump=float(abs(x[0]-x[-1]));edge=np.r_[x[-441:],x[:441]]
        # Static seam continuity evidence; not a claim of in-engine listening.
        assert jump<.01,(path,jump)
        assert np.sqrt(np.mean(x[:441]**2))>.002 and np.sqrt(np.mean(x[-441:]**2))>.002
        result['loop_boundary_sample_jump']=jump
        result['edge_20ms_rms_dbfs']=float(20*np.log10(np.sqrt(np.mean(edge**2))))
    return result

def run():
    combat,sr=sf.read(ROOT/'bgm_combat.ogg');assert sr==SR and len(combat)==16*SR
    specs=[('bgm_boss_layer.ogg',boss_layer(),16,-18,True),
           ('sfx/ui_click.ogg',wood(.1),.1,-8,False),
           ('sfx/ui_confirm.ogg',confirm(),.3,-8,False),
           ('sfx/ui_cancel.ogg',cancel(),.25,-10,False),
           ('sfx/ui_hover.ogg',wood(.05,True),.05,-24,False),
           ('sfx/boss_purified.ogg',purified(),1,-8,False)]
    results=[]
    for name,x,seconds,db,loop in specs:results.append(metrics(write(name,x,db),seconds,loop))
    boss,_=sf.read(ROOT/'bgm_boss_layer.ogg');mix=combat+boss
    mix_peak=float(20*np.log10(np.max(np.abs(mix))));assert mix_peak<=-3,mix_peak
    report={'method':'project-original deterministic synthesis; no third-party samples',
            'combat_source_sha256':hashlib.sha256((ROOT/'bgm_combat.ogg').read_bytes()).hexdigest(),
            'tonal_basis_hz':[55,110,165,220,330],
            'rhythm_bpm':120,'beats_in_loop':32,'combat_has_existing_beat':False,
            'unity_gain_combat_plus_boss_sample_peak_dbfs':mix_peak,'assets':results}
    (ROOT/'FOLLOWUP_VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

def check():
    report=json.loads((ROOT/'FOLLOWUP_VALIDATION.json').read_text(encoding='utf-8'))
    for r in report['assets']:
        p=ROOT/Path(r['path']).relative_to('art/audio')
        actual=metrics(p,r['duration_seconds'],p.name=='bgm_boss_layer.ogg')
        assert actual['sha256']==r['sha256'],p
    assert hashlib.sha256((ROOT/'bgm_combat.ogg').read_bytes()).hexdigest()==report['combat_source_sha256']
    print('PASS: 6 Vorbis files, 44.1kHz, exact frames/durations, decoded peaks <= -3dBFS, short edge silence, boss loop continuity and source hashes')

if __name__=='__main__':
    if '--check' in sys.argv:check()
    else:run()
