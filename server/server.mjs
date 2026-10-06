import net from 'node:net';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

export const VERSION = 'gm3-1';
export const MAX_LINE = 300000;
export function settings(value = {}) {
  const integer = (key, lo, hi, fallback) => Number.isInteger(value[key]) && value[key] >= lo && value[key] <= hi ? value[key] : fallback;
  return {arena: integer('arena', 1, 21, 1), mode: [1,2,3,4,5,10,11].includes(value.mode) ? value.mode : 1,
    stocks: integer('stocks', 1, 20, 5), variant: integer('variant', 0, 5, 0), bots: value.bots === true};
}
export function createLobbyServer({host = '0.0.0.0', port = 47633, maxRooms = 64, maxClients = 256} = {}) {
  const rooms = new Map(), peers = new Set();
  const send = (p, msg) => {
    if (p.socket.destroyed) return;
    // Bound queue latency: a slow guest must reconnect, never accumulate seconds of old gameplay.
    if (p.socket.writableLength > 600000) { p.socket.destroy(); return; }
    p.socket.write(JSON.stringify(msg) + '\n');
  };
  const broadcast = (r, m, except) => r.players.forEach(p => { if (p && p !== except) send(p, m); });
  const lobby = r => broadcast(r, {t:'lobby', code:r.code, players:r.players.map(p => p ? {name:p.name, ready:p.ready} : null), settings:r.settings, playing:r.playing});
  const fail = (p, message) => send(p, {t:'error', message});
  function remove(p) {
    if (!peers.delete(p)) return;
    const r = p.room;
    if (!r) return;
    p.room = null;
    if (p.slot === 0) {
      rooms.delete(r.code);
      r.players.forEach(other => { if(other && other !== p) { other.room = null; send(other, {t:'closed',message:'The host left. Return to the menu to join another room.'}); } });
    } else {
      r.players[p.slot] = null;
      if (r.playing) send(r.players[0], {t:'input',slot:p.slot,mask:0,disconnected:true});
      lobby(r);
    }
  }
  function receive(p, m) {
    if (!m || typeof m !== 'object' || Array.isArray(m) || typeof m.t !== 'string') throw Error('Invalid message');
    if (m.t === 'ping') { send(p,{t:'pong',at:m.at}); return; }
    if (!p.room) {
      if (m.v !== VERSION) { fail(p,'Game version mismatch. Everyone must use the same build.'); return; }
      if (!['create','join'].includes(m.t)) return;
      p.name = String(m.name || 'Player').replace(/[\x00-\x1f|]/g,'').trim().slice(0,18) || 'Player';
      if (m.t === 'create') {
        if (rooms.size >= maxRooms) { fail(p,'This server has no free rooms.'); return; }
        let code;
        do { code = crypto.randomBytes(4).toString('hex').slice(0,6).toUpperCase(); } while(rooms.has(code));
        p.room = {code, players:[p,null,null,null], settings:settings(m.settings), playing:false, seq:-1};
        p.slot = 0; p.ready = true; rooms.set(code,p.room);
      } else {
        const code = String(m.code || '').trim().toUpperCase(), r = rooms.get(code);
        if (!r) { fail(p,'Room not found. Check the server address and room code.'); return; }
        if (r.playing) { fail(p,'This room is in a match. Join after the round.'); return; }
        const slot = r.players.findIndex(x => x === null);
        if (slot < 0) { fail(p,'This room already has four players.'); return; }
        p.room = r; p.slot = slot; p.ready = false; r.players[slot] = p;
      }
      send(p,{t:'welcome',slot:p.slot,code:p.room.code,v:VERSION}); lobby(p.room); return;
    }
    const r = p.room;
    if(m.t === 'ready' && !r.playing) { p.ready = p.slot === 0 || m.ready === true; lobby(r); }
    else if(m.t === 'settings' && p.slot === 0 && !r.playing) {
      r.settings = settings(m.settings); r.players.forEach(x => { if(x && x.slot !== 0) x.ready = false; }); lobby(r);
    } else if(m.t === 'start' && p.slot === 0 && !r.playing) {
      if(r.players.some(x => x && !x.ready)) { fail(p,'Wait for everyone to press READY.'); return; }
      if(r.players.filter(Boolean).length < 2 && !r.settings.bots) { fail(p,'Invite a friend or turn on bots.'); return; }
      r.playing = true; r.seq = -1;
      broadcast(r,{t:'start',settings:r.settings,players:r.players.map(x => x ? x.name : null)});
    } else if(m.t === 'input' && r.playing) {
      if(!Number.isInteger(m.mask) || m.mask < 0 || m.mask > 63) throw Error('Invalid input');
      p.lastInput = Date.now(); p.mask = m.mask;
      send(r.players[0],{t:'input',slot:p.slot,mask:m.mask});
    } else if(m.t === 'state' && p.slot === 0 && r.playing) {
      if(!Number.isInteger(m.seq) || m.seq <= r.seq || typeof m.scene !== 'string' || m.scene.length > 250000) return;
      r.seq = m.seq; broadcast(r,{t:'state',seq:m.seq,scene:m.scene},p);
    } else if(m.t === 'finish' && p.slot === 0 && r.playing) {
      r.playing = false;
      r.players.forEach(x => { if(x) { x.ready = x.slot === 0; x.mask = 0; } });
      broadcast(r,{t:'finish',message:String(m.message || 'Round over').slice(0,80)}); lobby(r);
    }
  }
  const server = net.createServer(socket => {
    if(peers.size >= maxClients) { socket.destroy(); return; }
    socket.setNoDelay(true); socket.setKeepAlive(true,5000); socket.setEncoding('utf8');
    const p = {socket,buffer:'',room:null,slot:-1,last:Date.now(),rateAt:Date.now(),rate:0,mask:0,lastInput:0};
    peers.add(p);
    socket.on('data',data => {
      p.last = Date.now(); p.buffer += data;
      if(p.buffer.length > MAX_LINE * 2) { socket.destroy(); return; }
      let at;
      while((at = p.buffer.indexOf('\n')) >= 0) {
        const line = p.buffer.slice(0,at); p.buffer = p.buffer.slice(at+1);
        if(line.length > MAX_LINE) { socket.destroy(); return; }
        if(Date.now() - p.rateAt > 1000) { p.rate = 0; p.rateAt = Date.now(); }
        if(++p.rate > 160) { socket.destroy(); return; }
        try { receive(p,JSON.parse(line)); } catch { socket.destroy(); return; }
      }
      if(p.buffer.length > MAX_LINE) socket.destroy();
    });
    socket.on('error',()=>{}); socket.on('close',()=>remove(p));
  });
  const timer = setInterval(() => {
    for(const p of peers) {
      if(Date.now() - p.last > 15000) p.socket.destroy();
      else if(p.room?.playing && p.mask && Date.now() - p.lastInput > 1000) {
        p.mask = 0; send(p.room.players[0],{t:'input',slot:p.slot,mask:0});
      }
    }
  },500);
  timer.unref();
  server.on('close',()=>clearInterval(timer));
  return {server, rooms, peers, listen:() => new Promise((resolve,reject) => { server.once('error',reject); server.listen(port,host,()=>{server.off('error',reject);resolve(server.address());}); }),
    close:() => new Promise(resolve => { clearInterval(timer); for(const p of peers) p.socket.destroy(); server.close(resolve); })};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const service = createLobbyServer({host:process.env.HOST || '0.0.0.0',port:Number(process.env.PORT || 47633)});
  service.listen().then(a=>console.log(`Gun Mayhem 3 Online lobby server listening on ${a.address}:${a.port}`)).catch(e=>{console.error(e.message);process.exitCode=1;});
  for(const signal of ['SIGINT','SIGTERM']) process.on(signal,()=>service.close().then(()=>process.exit(0)));
}
