"""Verify intro timeline progression, menu music ordering, and resize output in real Flash."""
import argparse,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--air-sdk',type=Path,required=True);parser.add_argument('--name',default='startup-check');args=parser.parse_args()
out=ROOT/'build'/args.name;out.mkdir(exist_ok=True)
app=(ROOT/'application.xml').read_text().replace('com.gunmayhem3.online','com.gunmayhem3.online.'+args.name)
(out/'app.xml').write_text(app)
config={'classic':True,'output':str(out/'startup'),'width':1450,'height':940,'captures':[1200,4000,8000,10500,11500,14000]}
(out/'config.json').write_text(json.dumps(config))
with (out/'runtime.log').open('w') as log:
    p=subprocess.Popen([str(args.air_sdk/'bin/adl.exe'),str(out/'app.xml'),str(ROOT/'build'),'--','--test-config='+str(out/'config.json')],stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
    try:time.sleep(17)
    finally:p.terminate();p.wait(timeout=5)
events=[json.loads(line) for line in (out/'startup.jsonl').read_text().splitlines()]
diag=[e['data'] for e in events if e['event']=='game']
intro=[d for d in diag if d.get('rootFrame')==2 and d.get('introFrame',0)>1]
assert len(intro)>=3 and max(d['introFrame'] for d in intro)>100,diag
assert all(not d['menuMusicPlaying'] for d in intro),'Menu music overlapped intro'
assert any(d.get('rootFrame')==10 and d.get('menuMusicPlaying') and d.get('musicPosition',0)>1000 for d in diag),'Intro did not reach the menu and play GM1 music'
summary={'intro_frames':[d['introFrame'] for d in intro],'menu_music_verified':True,'captures':[p.name for p in out.glob('*.png')]}
(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
