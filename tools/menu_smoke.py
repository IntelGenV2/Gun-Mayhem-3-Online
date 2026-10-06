"""Exercise original Flash menu wipes and assert music waits for animation/sound."""
import argparse,json,subprocess,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--air-sdk',type=Path,required=True)
parser.add_argument('--name',default='menu-check')
args=parser.parse_args()
out=ROOT/'build'/args.name;out.mkdir(exist_ok=True)
(out/'app.xml').write_text((ROOT/'application.xml').read_text().replace('com.gunmayhem3.online','com.gunmayhem3.online.'+args.name))
actions=[
    (16000,'testTransition',{'frame':5}),
    (19000,'testTransition',{'frame':9}),
    (22000,'testTransition',{'frame':6}),
    (25000,'testTransition',{'frame':10}),
    (28000,'openOnline',{'screen':'host'}),
    (31000,'onlineBack',None),
    (34000,'openOnline',{'screen':'join'}),
    (37000,'onlineBack',None),
    (40000,'testTransition',{'frame':7}),
    (43000,'testTransition',{'frame':10}),
]
config={'classic':True,'name':'Menu Tester','output':str(out/'menus'),'width':1366,'height':900,
        'actions':[{'at':at,'command':command,'data':data} for at,command,data in actions],
        'captures':[15000]+[at+2000 for at,_,_ in actions]}
(out/'config.json').write_text(json.dumps(config))
with (out/'runtime.log').open('w') as log:
    p=subprocess.Popen([str(args.air_sdk/'bin/adl.exe'),str(out/'app.xml'),str(ROOT/'build'),'--','--test-config='+str(out/'config.json')],stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW)
    try:time.sleep(47)
    finally:p.terminate();p.wait(timeout=5)
events=[json.loads(line) for line in (out/'menus.jsonl').read_text().splitlines()]
diag=[e['data'] for e in events if e['event']=='game']
audio=[e['data'] for e in events if e['event']=='audio']
transition=False;completed=0;stops=0;starts=[]
for event in audio:
    if event['event']=='stopAll':stops+=1
    elif event['event']=='transitionStart':
        assert not transition,'Overlapping menu transitions'
        transition=True
    elif event['event']=='transitionDone':transition=False;completed+=1
    elif event['event']=='musicStart':
        assert not transition and not event['transition'] and not event['fade'] and event['pending']==0,event
        starts.append(event['track'])
assert completed>=11 and stops>=11,(completed,stops)
assert starts==['main','setup','setup','setup','main','setup','main','setup','main','setup','main'],starts
for frame in (5,9,6):assert any(d['rootFrame']==frame and d['setupMusicPlaying'] and d['screen']=='original' for d in diag),frame
for screen in ('host','join'):assert any(d['screen']==screen and d['setupMusicPlaying'] for d in diag),screen
assert any(d['rootFrame']==10 and d['menuMusicPlaying'] and d.get('musicPosition',0)>1000 for d in diag)
summary={'transitions_completed':completed,'all_sound_resets':stops,'track_sequence':starts,'music_waited_for_animation_and_sound':True,'screens':['main','options','game setup','postgame','host','join','credits']}
(out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
