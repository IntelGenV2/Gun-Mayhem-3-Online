import test from 'node:test';
import assert from 'node:assert/strict';
import net from 'node:net';
import {createLobbyServer, settings, VERSION} from '../server/server.mjs';

async function peer(port) {
  const socket=net.connect(port,'127.0.0.1');socket.setEncoding('utf8');socket.setNoDelay(true);
  await new Promise((resolve,reject)=>{socket.once('connect',resolve);socket.once('error',reject);});
  let buffer='';const messages=[],waiters=[];
  socket.on('data',data=>{buffer+=data;let at;while((at=buffer.indexOf('\n'))>=0){const m=JSON.parse(buffer.slice(0,at));buffer=buffer.slice(at+1);messages.push(m);for(const check of [...waiters])check();}});
  socket.on('error',()=>{});
  return {socket,send:m=>socket.write(JSON.stringify(m)+'\n'),next:(type,predicate=()=>true)=>new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{waiters.splice(waiters.indexOf(check),1);reject(Error('Timed out: '+type));},2500);
    const check=()=>{const at=messages.findIndex(m=>m.t===type&&predicate(m));if(at<0)return;clearTimeout(timer);waiters.splice(waiters.indexOf(check),1);resolve(messages.splice(at,1)[0]);};waiters.push(check);check();
  }),messages};
}
test('settings reject invalid / unsupported values',()=>{assert.deepEqual(settings({arena:999,mode:999,stocks:-2,variant:9,bots:'true'}),{arena:1,mode:1,stocks:5,variant:0,bots:false});});
test('private rooms, ready gate, host authority, inputs, rematch, disconnect',async t=>{
  const service=createLobbyServer({host:'127.0.0.1',port:0});const {port}=await service.listen();t.after(()=>service.close());
  const host=await peer(port),guest=await peer(port),stranger=await peer(port);
  host.send({t:'create',v:VERSION,name:'Host',settings:{arena:12,bots:false}});
  const {code}=await host.next('welcome');assert.match(code,/^[A-F0-9]{6}$/);
  guest.send({t:'join',v:VERSION,name:'Friend',code});assert.equal((await guest.next('welcome')).slot,1);
  host.send({t:'start'});assert.match((await host.next('error')).message,/READY/);
  guest.send({t:'ready',ready:true});await host.next('lobby',m=>m.players[1]?.ready);
  host.send({t:'start'});assert.equal((await guest.next('start')).settings.arena,12);await host.next('start');
  guest.send({t:'input',slot:0,mask:24});assert.deepEqual(await host.next('input'),{t:'input',slot:1,mask:24});
  guest.send({t:'state',seq:999,scene:'spoof'});
  host.send({t:'state',seq:1,scene:'@|0|0|100|100\nplayer1|823|1|1'});assert.equal((await guest.next('state')).seq,1);
  assert.equal(host.messages.some(m=>m.t==='state'),false);
  stranger.send({t:'join',v:VERSION,name:'Late',code});assert.match((await stranger.next('error')).message,/match/);
  guest.send({t:'finish',message:'spoof'});host.send({t:'ping',at:123});await host.next('pong');assert.equal(host.messages.some(m=>m.t==='finish'),false);
  guest.socket.destroy();assert.equal((await host.next('input',m=>m.disconnected)).mask,0);
  host.send({t:'finish',message:'Round complete'});assert.equal((await host.next('finish')).message,'Round complete');
  stranger.send({t:'join',v:VERSION,name:'New friend',code});assert.equal((await stranger.next('welcome')).slot,1);
  host.socket.destroy();assert.match((await stranger.next('closed')).message,/host left/);
});
test('four player capacity, isolation, versions and malformed traffic',async t=>{
  const service=createLobbyServer({host:'127.0.0.1',port:0});const {port}=await service.listen();t.after(()=>service.close());
  const host=await peer(port);host.send({t:'create',v:VERSION,name:'Host'});const {code}=await host.next('welcome');
  for(let i=1;i<4;i++){const p=await peer(port);p.send({t:'join',v:VERSION,name:'P'+i,code});assert.equal((await p.next('welcome')).slot,i);}
  const fifth=await peer(port);fifth.send({t:'join',v:VERSION,code});assert.match((await fifth.next('error')).message,/four players/);
  fifth.send({t:'create',v:'old'});assert.match((await fifth.next('error')).message,/version mismatch/);
  fifth.send({t:'create',v:VERSION});const other=await fifth.next('welcome');assert.notEqual(other.code,code);
  const bad=await peer(port);const closed=new Promise(resolve=>bad.socket.once('close',resolve));bad.socket.write('{nonsense}\n');await closed;
});
test('fragmented frames, input expiry, settings reset readiness',async t=>{
  const service=createLobbyServer({host:'127.0.0.1',port:0});const {port}=await service.listen();t.after(()=>service.close());
  const h=await peer(port),g=await peer(port);
  const request=JSON.stringify({t:'create',v:VERSION,name:'Host',settings:{bots:true}})+'\n';h.socket.write(request.slice(0,9));h.socket.write(request.slice(9));const {code}=await h.next('welcome');
  g.send({t:'join',v:VERSION,code});await g.next('welcome');g.send({t:'ready',ready:true});await h.next('lobby',m=>m.players[1]?.ready);
  h.send({t:'settings',settings:{arena:10,bots:true}});await h.next('lobby',m=>m.settings.arena===10&&!m.players[1]?.ready);
  g.send({t:'ready',ready:true});await h.next('lobby',m=>m.players[1]?.ready);h.send({t:'start'});await g.next('start');
  g.send({t:'input',mask:8});await h.next('input',m=>m.mask===8);assert.equal((await h.next('input',m=>m.mask===0)).slot,1);
});
