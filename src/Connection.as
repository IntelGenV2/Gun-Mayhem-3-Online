package {
    import flash.net.Socket;
    import flash.events.*;
    import flash.utils.getTimer;
    import flash.utils.ByteArray;
    public class Connection {
        public var socket:Socket;
        public var onMessage:Function;
        public var onClose:Function;
        public var onOpen:Function;
        private var buffer:ByteArray = new ByteArray();
        private var scan:int=0;
        public var last:int = 0;
        public var closed:Boolean = false;
        public function Connection(existing:Socket = null) {
            socket = existing || new Socket();
            socket.addEventListener(ProgressEvent.SOCKET_DATA, data);
            socket.addEventListener(Event.CONNECT, function(e:Event):void { last=getTimer(); if(onOpen!=null) onOpen(); });
            socket.addEventListener(Event.CLOSE, ended);
            socket.addEventListener(IOErrorEvent.IO_ERROR, ended);
            socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, ended);
            last=getTimer();
        }
        public function connect(host:String,port:int):void { socket.connect(host,port); }
        private function data(e:ProgressEvent):void {
            last=getTimer();
            socket.readBytes(buffer,buffer.length,socket.bytesAvailable);
            if(buffer.length > 600000) { close(); return; }
            var consumed:int=0;
            for(;scan<buffer.length;scan++) {
                if(buffer[scan]!=10)continue;
                if(scan-consumed>300000){close();return;}
                buffer.position=consumed;var line:String=buffer.readUTFBytes(scan-consumed);consumed=scan+1;
                try {var m:Object=JSON.parse(line);if(onMessage!=null)onMessage(m);}
                catch(error:Error){close();return;}
            }
            if(consumed){var tail:ByteArray=new ByteArray();buffer.position=consumed;if(buffer.bytesAvailable)buffer.readBytes(tail,0,buffer.bytesAvailable);buffer=tail;scan=buffer.length;}
            if(buffer.length>300000) close();
        }
        public function send(message:Object):void {
            if(closed || !socket.connected) return;
            if(socket.bytesPending>600000) { close(); return; }
            try { socket.writeUTFBytes(JSON.stringify(message)+"\n"); socket.flush(); }
            catch(error:Error) { close(); }
        }
        private function ended(e:Event):void { close(); }
        public function close():void {
            if(closed) return;
            closed=true;
            try { socket.close(); } catch(error:Error) {}
            if(onClose!=null) onClose();
        }
    }
}
