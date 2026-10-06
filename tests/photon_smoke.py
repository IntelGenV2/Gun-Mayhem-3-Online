"""Real Photon Cloud test, using short-lived private rooms and the supplied App ID."""
import json, queue, subprocess, threading, time, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class Client:
    def __init__(self):
        self.events=[];self.q=queue.Queue()
        self.p=subprocess.Popen([str(ROOT/'build/photon/PhotonBridge.exe')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8',creationflags=subprocess.CREATE_NO_WINDOW)
        threading.Thread(target=self.read,daemon=True).start()
        self.wait('bridgeReady')
    def read(self):
        for line in self.p.stdout:
            try:e=json.loads(line);self.events.append(e);self.q.put(e)
            except ValueError:pass
    def send(self,**m):self.p.stdin.write(json.dumps(m)+'\n');self.p.stdin.flush()
    def wait(self,kind,timeout=25,predicate=lambda e:True):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            try:e=self.q.get(timeout=.2)
            except queue.Empty:continue
            if e['t']==kind and predicate(e):return e
            if e['t'] in ('error','closed'):raise AssertionError(e)
        raise AssertionError(f'Timed out awaiting {kind}: {self.events[-6:]}')
    def close(self):
        if self.p.poll() is None:
            self.send(t='quit')
            try:self.p.wait(timeout=4)
            except subprocess.TimeoutExpired:self.p.kill()

def main():
    clients=[]
    try:
        relay='--relay-only' in sys.argv
        host=Client();clients.append(host);host.send(t='create',name='Host',region='us',settings={'bots':False},relayOnly=relay)
        room=host.wait('welcome')['code'];host.wait('lobby');print('Created Photon room',room,flush=True)
        guests=[]
        for i in range(3):
            g=Client();clients.append(g);guests.append(g);g.send(t='join',name='Friend '+str(i),region='us',code=room,relayOnly=relay)
            assert g.wait('welcome')['slot']==i+1
            g.wait('lobby');g.send(t='ready',ready=True)
        host.wait('lobby',predicate=lambda e:all(p and p['ready'] for p in e['players']))
        # Settings changes clear readiness; host cannot start until everyone readies again.
        host.send(t='settings',settings={'arena':2,'mode':1,'stocks':5,'variant':1,'bots':False,'crates':False,'pickups':False})
        host.wait('lobby',predicate=lambda e:e['settings']['variant']==1 and not e['players'][1]['ready'])
        for g in guests:g.wait('lobby',predicate=lambda e:e['settings']['variant']==1);g.send(t='ready',ready=True)
        host.wait('lobby',predicate=lambda e:all(p and p['ready'] for p in e['players']))
        # Only a player's own profile may change, and that player must ready again.
        guests[0].send(t='settings',settings={'arena':21,'mode':3,'stocks':20})
        guests[0].send(t='profile',slot=0,profile={'color':8,'hat':12,'shirt':7,'eyes':3,'gun':5,'perk':3,'team':1})
        update=host.wait('lobby',predicate=lambda e:e['players'][1]['profile']['hat']==12)
        assert update['players'][0]['profile']['hat']==4 and not update['players'][1]['ready']
        assert update['settings']['arena']==2 and not update['settings']['crates'] and not update['settings']['pickups']
        guests[0].send(t='ready',ready=True)
        host.wait('lobby',predicate=lambda e:all(p and p['ready'] for p in e['players']))
        host.send(t='start');start=host.wait('start')
        assert start['loadouts'][1]=={'color':8,'hat':12,'shirt':7,'eyes':3,'gun':5,'perk':3,'team':1}
        for g in guests:g.wait('start')
        # Guests cannot become the game authority.
        guests[0].send(t='finish',message='spoof');guests[0].send(t='state',seq=999,scene='spoof')
        guests[0].send(t='input',mask=18)
        assert host.wait('input',predicate=lambda e:e['slot']==1)['mask']==18
        payload='@|0|0|100|100\n'+'\n'.join(f'd{i}|example-vector-state' for i in range(1000))
        for seq in range(2,8):
            host.send(t='state',seq=seq,scene=payload)
            for g in guests:assert g.wait('state')['scene']==payload
            time.sleep(.1)
        if not relay:
            for g in guests:g.wait('heartbeat',predicate=lambda e:e.get('directReceived',0)>0)
        host.wait('input',timeout=3,predicate=lambda e:e['slot']==1 and e['mask']==0)
        host.send(t='finish',message='Rematch test');host.wait('finish')
        for g in guests:g.wait('finish');g.send(t='ready',ready=True)
        host.wait('lobby',predicate=lambda e:all(p and p['ready'] for p in e['players']))
        host.send(t='start');host.wait('start')
        for g in guests:g.wait('start')
        host.send(t='state',seq=1,scene='@|new round')
        for g in guests:assert g.wait('state')['scene']=='@|new round'
        host.close()
        for g in guests:
            assert g.wait('closed')['message']=='The host left the room.'
        print('PASS: four cloud players, ready/settings, inputs, compressed states, stale input release, authority, rematch, host departure',flush=True)
    finally:
        for c in clients:c.close()
if __name__=='__main__':main()
