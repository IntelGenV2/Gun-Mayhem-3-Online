"""Launch two isolated real AIR/Flash clients and preserve logs/screenshots."""
import argparse
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--name',default='photon-smoke');parser.add_argument('--arena',type=int,default=1);parser.add_argument('--variant',type=int,default=0);parser.add_argument('--seconds',type=int,default=20);parser.add_argument('--air-sdk',type=Path,default=ROOT/'vendor/air-sdk');parser.add_argument('--packaged-host',action='store_true');parser.add_argument('--rematch',action='store_true');parser.add_argument('--freeze',action='store_true');parser.add_argument('--players',type=int,choices=[2,3,4],default=2);args=parser.parse_args()
    build=ROOT/'build';out=build/args.name;out.mkdir(exist_ok=True)
    app=(ROOT/'application.xml').read_text();port=47720
    procs=[];logs=[]
    def launch(role,config):
        desc=out/(role+'.xml');desc.write_text(app.replace('com.gunmayhem3.online','com.gunmayhem3.online.'+args.name+role))
        config['output']=str(out/role);cfg=out/(role+'.json');cfg.write_text(json.dumps(config))
        log=open(out/(role+'.log'),'w');logs.append(log)
        command=[str(ROOT/'dist/Gun Mayhem 3 Online/Gun Mayhem 3 Online.exe'),'--test-config='+str(cfg)] if args.packaged_host and role=='host' else [str(args.air_sdk/'bin/adl.exe'),str(desc),str(build),'--','--test-config='+str(cfg)]
        p=subprocess.Popen(command,stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW);procs.append(p)
    def events(role):
        path=out/(role+'.jsonl')
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
    try:
        launch('host',{'host':True,'region':'us','name':'Host','arena':args.arena,'variant':args.variant,'rematch':args.rematch,'freeze':args.freeze,'testPlayers':args.players,'width':1366,'height':900})
        deadline=time.monotonic()+40
        code=None
        while time.monotonic()<deadline:
            welcome=[e for e in events('host') if e['event']=='welcome']
            if welcome:code=welcome[-1]['code'];break
            time.sleep(.2)
        if not code:raise RuntimeError('Host failed to create a room')
        launch('guest',{'host':False,'region':'us','name':'Friend','code':code,'freeze':args.freeze,'width':1100,'height':760})
        for index in range(2,args.players):launch('guest'+str(index),{'host':False,'region':'us','name':'Friend '+str(index),'code':code,'freeze':args.freeze})
        time.sleep(args.seconds)
        host=events('host');guest=events('guest');games=[e['data'] for e in host if e['event']=='game' and 'players' in e['data']];stats=[e for e in guest if e['event']=='stats']
        summary={'arena':args.arena,'variant':args.variant,'players':args.players,'host_bridge':any(e['event']=='bridge' for e in host),'guest_bridge':any(e['event']=='bridge' for e in guest),'guest_snapshots':max([e['snapshots'] for e in stats]or[0]),'direct_snapshots':max([e.get('directReceived',0) for e in guest if e['event']=='network']or[0]),'diagnostic_samples':len(games),'rounds':len([e for e in host if e['event']=='started']),'host_events':len(host),'guest_events':len(guest)}
        (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2),flush=True)
        assert summary['host_bridge'] and summary['guest_bridge'] and summary['guest_snapshots']>30
        assert games,'No original-engine gameplay samples'
        if args.rematch:assert summary['rounds']>=2,'Rematch failed'
        for index in range(2,args.players):assert any(e['event']=='stats' and e['snapshots']>30 for e in events('guest'+str(index)))
        # A real fight may legitimately spend most lives, especially with snipers.
        # Verify living fighters still occupy the arena rather than requiring
        # an arbitrary score after a variable-duration test.
        assert any(100<p['y']<600 and p['lives']>0 for g in games[-5:] for p in g['players']),'No living fighter remained in the original arena'
        if args.variant==1:assert all(p['gun']==16 for g in games for p in g['players']),'Sniper preset did not apply'
    finally:
        for p in reversed(procs):
            if p.poll() is None:p.terminate()
        for p in procs:
            try:p.wait(timeout=5)
            except subprocess.TimeoutExpired:p.kill()
        for log in logs:log.close()
if __name__=='__main__':main()
