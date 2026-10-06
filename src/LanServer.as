package {
    import flash.net.ServerSocket;
    import flash.events.*;
    import flash.utils.*;
    import flash.crypto.generateRandomBytes;
    public class LanServer {
        private var listener:ServerSocket;
        private var peers:Array=[];
        private var rooms:Object={};
        private var timer:Timer=new Timer(500);
        public function LanServer(port:int) {
            listener=new ServerSocket(); listener.bind(port,"0.0.0.0"); listener.listen();
            listener.addEventListener(ServerSocketConnectEvent.CONNECT,accept);
            timer.addEventListener(TimerEvent.TIMER,tick); timer.start();
        }
        public static function clean(s:Object):Object {
            if(s==null) s={};
            return {arena:integer(s.arena,1,21,1),mode:[1,2,3,4,5,10,11].indexOf(s.mode)>=0?s.mode:1,
                stocks:integer(s.stocks,1,20,5),variant:integer(s.variant,0,5,0),bots:s.bots===true};
        }
        private static function integer(n:*,lo:int,hi:int,fallback:int):int {
            return n is Number && n==int(n) && n>=lo && n<=hi ? int(n) : fallback;
        }
        private function accept(e:ServerSocketConnectEvent):void {
            if(peers.length>=32) { e.socket.close(); return; }
            var p:Object={c:new Connection(e.socket),room:null,slot:-1,ready:false,rate:0,rateAt:getTimer(),lastInput:0,mask:0};
            peers.push(p);
            p.c.onMessage=function(m:Object):void {
                if(getTimer()-p.rateAt>1000) { p.rate=0;p.rateAt=getTimer(); }
                if(++p.rate>160) { p.c.close(); return; }
                receive(p,m);
            };
            p.c.onClose=function():void { remove(p); };
        }
        private function send(p:Object,m:Object):void { if(p!=null) p.c.send(m); }
        private function broadcast(r:Object,m:Object,except:Object=null):void { for each(var p:Object in r.players) if(p && p!=except) send(p,m); }
        private function lobby(r:Object):void {
            var players:Array=[];
            for each(var p:Object in r.players) players.push(p ? {name:p.name,ready:p.ready}:null);
            broadcast(r,{t:"lobby",code:r.code,players:players,settings:r.settings,playing:r.playing});
        }
        private function error(p:Object,message:String):void { send(p,{t:"error",message:message}); }
        private function receive(p:Object,m:Object):void {
            if(m==null || !(m.t is String)) { p.c.close(); return; }
            if(m.t=="ping") { send(p,{t:"pong",at:m.at});return; }
            if(!p.room) {
                if(m.v!="gm3-1") { error(p,"Game version mismatch. Use the same build."); return; }
                if(m.t!="create" && m.t!="join") return;
                p.name=String(m.name || "Player").replace(/[\x00-\x1f|]/g,"").substr(0,18);
                if(m.t=="create") {
                    var code:String;
                    do { code=generateRandomBytes(3).readUnsignedByte().toString(16); var b:ByteArray=generateRandomBytes(3); code=""; for(var j:int=0;j<3;j++) code+=("0"+b.readUnsignedByte().toString(16)).substr(-2); code=code.toUpperCase(); } while(rooms[code]);
                    p.room={code:code,players:[p,null,null,null],settings:clean(m.settings),playing:false,seq:-1};
                    p.slot=0;p.ready=true;rooms[code]=p.room;
                } else {
                    var r:Object=rooms[String(m.code).toUpperCase().replace(/\s/g,"")];
                    if(!r) { error(p,"Room not found. Check the address and room code.");return; }
                    if(r.playing) { error(p,"This room is in a match. Join after the round.");return; }
                    var slot:int=r.players.indexOf(null);
                    if(slot<0) { error(p,"This room already has four players.");return; }
                    p.room=r;p.slot=slot;p.ready=false;r.players[slot]=p;
                }
                send(p,{t:"welcome",slot:p.slot,code:p.room.code,v:"gm3-1"});lobby(p.room);return;
            }
            r=p.room;
            if(m.t=="ready" && !r.playing) { p.ready=p.slot==0 || m.ready===true; lobby(r); }
            else if(m.t=="settings" && p.slot==0 && !r.playing) {
                r.settings=clean(m.settings); for each(var person:Object in r.players) if(person && person.slot!=0) person.ready=false; lobby(r);
            } else if(m.t=="start" && p.slot==0 && !r.playing) {
                var count:int=0;
                for each(person in r.players) if(person) { count++;if(!person.ready) { error(p,"Wait for everyone to press READY.");return; } }
                if(count<2 && !r.settings.bots) { error(p,"Invite a friend or turn on bots.");return; }
                r.playing=true;r.seq=-1; var names:Array=[];
                for each(person in r.players) names.push(person ? person.name : null);
                broadcast(r,{t:"start",settings:r.settings,players:names});
            } else if(m.t=="input" && r.playing) {
                if(!(m.mask is Number) || m.mask!=int(m.mask) || m.mask<0 || m.mask>63) { p.c.close();return; }
                p.mask=m.mask;p.lastInput=getTimer();send(r.players[0],{t:"input",slot:p.slot,mask:m.mask});
            } else if(m.t=="state" && p.slot==0 && r.playing) {
                if(!(m.seq is Number) || m.seq!=int(m.seq) || m.seq<=r.seq || !(m.scene is String) || m.scene.length>250000) return;
                r.seq=m.seq; broadcast(r,{t:"state",seq:m.seq,scene:m.scene},p);
            } else if(m.t=="finish" && p.slot==0 && r.playing) {
                r.playing=false;
                for each(person in r.players) if(person) { person.ready=person.slot==0;person.mask=0; }
                broadcast(r,{t:"finish",message:String(m.message || "Round over").substr(0,80)});lobby(r);
            }
        }
        private function remove(p:Object):void {
            var index:int=peers.indexOf(p);if(index<0)return;peers.splice(index,1);
            var r:Object=p.room;if(!r)return;p.room=null;
            if(p.slot==0) {
                delete rooms[r.code];
                for each(var other:Object in r.players) if(other && other!=p) { other.room=null;send(other,{t:"closed",message:"The host left the room."}); }
            } else {r.players[p.slot]=null;if(r.playing)send(r.players[0],{t:"input",slot:p.slot,mask:0,disconnected:true});lobby(r);}
        }
        private function tick(e:TimerEvent):void {
            for each(var p:Object in peers.concat()) {
                if(getTimer()-p.c.last>15000)p.c.close();
                else if(p.room && p.room.playing && p.mask && getTimer()-p.lastInput>1000) {p.mask=0;send(p.room.players[0],{t:"input",slot:p.slot,mask:0});}
            }
        }
        public function close():void {timer.stop();listener.close();for each(var p:Object in peers.concat())p.c.close();}
    }
}
