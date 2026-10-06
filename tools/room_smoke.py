"""Exercise real Flash room pages, customization, cancellation and match departure."""
import argparse,json,subprocess,time,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
from photon_smoke import Client

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--air-sdk',type=Path,required=True);parser.add_argument('--name',required=True);parser.add_argument('--scenario',choices=['pages','leave','cancel','join'],default='pages');args=parser.parse_args()
    out=ROOT/'build'/args.name;out.mkdir(exist_ok=True);processes=[];logs=[];native=[]
    def events(role):
        p=out/(role+'.jsonl')
        return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []
    def action(at,cmd,data):return {'at':at,'command':cmd,'data':data}
    def launch(role,config):
        config.update(output=str(out/role),width=1200,height=830,region='us',name=role)
        cfg=out/(role+'.json');cfg.write_text(json.dumps(config));desc=out/(role+'.xml')
        desc.write_text((ROOT/'application.xml').read_text().replace('com.gunmayhem3.online','com.gunmayhem3.online.'+args.name+role))
        log=(out/(role+'.log')).open('w');logs.append(log)
        p=subprocess.Popen([str(args.air_sdk/'bin/adl.exe'),str(desc),str(ROOT/'build'),'--','--test-config='+str(cfg)],stdout=log,stderr=log,creationflags=subprocess.CREATE_NO_WINDOW);processes.append(p)
    def room(role):
        end=time.monotonic()+30
        while time.monotonic()<end:
            codes=[e['code'] for e in events(role) if e['event']=='welcome']
            if codes:return codes[-1]
            time.sleep(.2)
        raise AssertionError('Room did not connect')
    def returned(role,reload):
        ev=events(role);left=[e for e in ev if e['event']=='left'];assert left and left[-1]['reload']==reload,left
        after=[e['data'] for e in ev if e['event']=='game' and e['time']>left[-1]['time']+1500]
        assert len(after)>=2 and all(d.get('rootFrame')==10 and d.get('menuMusicPlaying') and not d.get('battleMusicPlaying') for d in after),after
        assert not any(e['event']=='audio' and e['time']>left[-1]['time'] and e['data']['event']=='battleStart' for e in ev)
        return {'returned_to_menu':True,'battle_audio_stopped':True,'reload':reload}
    try:
        if args.scenario=='pages':
            launch('host',{'host':True,'manual':True,'actions':[
                action(6000,'testInterface',{'action':'page:rules'}),
                action(7500,'testInterface',{'action':'page:map'}),
                action(9000,'testInterface',{'action':'page:players'}),
                action(10500,'testInterface',{'action':'profile:color:1'}),
                action(11500,'testInterface',{'action':'profile:gun:1'}),
                action(12500,'testInterface',{'action':'profile:perk:1'}),
                action(16000,'ui',{'action':'back'})], 'captures':[5000,7000,8500,14000,19000]})
            code=room('host');friend=Client();native.append(friend);friend.send(t='join',name='Friend',region='us',code=code);friend.wait('welcome')
            lobby=friend.wait('lobby',predicate=lambda e:e['players'][0]['profile']['perk']==2)
            assert lobby['players'][0]['profile']['color']==16 and lobby['players'][0]['profile']['gun']==3,lobby
            time.sleep(9)
            ev=events('host');samples=[e['data'] for e in ev if e['event']=='game' and e['data'].get('screen')=='lobby']
            assert {'rules','map','players'} <= {d['page'] for d in samples},samples
            assert all(abs(d['panelX'])<.1 and abs(d['panelY'])<.1 for d in samples),samples
            previews=[e['data']['preview'] for e in ev if e['event']=='game' and 'preview' in e['data']]
            assert previews and all(all(p[k]==p['wanted'][k] for k in ('gun','shirt','hat')) for p in previews),previews
            result=returned('host',False);result['pages']=['rules','map','players'];result['profile_synced']=True
        elif args.scenario=='leave':
            launch('host',{'host':True,'actions':[action(12000,'ui',{'action':'room'}),action(14000,'ui',{'action':'back'})], 'captures':[13000,18000]})
            code=room('host')
            launch('guest',{'code':code,'actions':[action(6000,'ui',{'action':'room'}),action(7000,'testInterface',{'action':'page:players'}),action(10000,'ui',{'action':'back'})], 'captures':[8000,14000]})
            time.sleep(24)
            result={'host':returned('host',False),'guest':returned('guest',True)}
            for role in ('host','guest'):
                assert any(e['event']=='started' for e in events(role))
                samples=[e['data'] for e in events(role) if e['event']=='game' and e['data'].get('screen')=='lobby']
                assert samples and all(abs(d['panelX'])<.1 and abs(d['panelY'])<.1 for d in samples),samples
        elif args.scenario=='join':
            host=Client();native.append(host);host.send(t='create',name='Host',region='us')
            code=host.wait('welcome')['code']
            leave=action(9000,'ui',{'action':'back'});leave['when']='lobby'
            launch('guest',{'code':code,'manual':True,'actions':[leave],'captures':[7000,12000]})
            room('guest');time.sleep(15)
            result=returned('guest',False)
            assert len([e for e in events('guest') if e['event']=='bridge'])==1
        else:
            launch('cancel',{'classic':True,'manual':True,'actions':[action(15000,'ui',{'action':'create','name':'Cancel','region':'us'}),action(15100,'ui',{'action':'back'})], 'captures':[15050,18000]})
            time.sleep(21);result=returned('cancel',False)
            assert len([e for e in events('cancel') if e['event']=='bridge'])==1
        (out/'summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2),flush=True)
    finally:
        for c in native:c.close()
        for p in processes:
            if p.poll() is None:p.terminate()
        for p in processes:p.wait(timeout=5)
        for log in logs:log.close()
if __name__=='__main__':main()
