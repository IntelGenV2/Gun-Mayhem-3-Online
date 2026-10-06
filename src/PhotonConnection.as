package {
    import flash.desktop.*;
    import flash.events.*;
    import flash.filesystem.File;
    import flash.utils.*;
    public class PhotonConnection {
        public var onOpen:Function, onMessage:Function, onClose:Function;
        public var last:int=0;
        public var closed:Boolean=false;
        private var process:NativeProcess;
        private var buffer:ByteArray=new ByteArray();
        public function connect():void {
            if(!NativeProcess.isSupported)throw new Error("Start the packaged Windows EXE to use Photon.");
            var info:NativeProcessStartupInfo=new NativeProcessStartupInfo();
            info.executable=File.applicationDirectory.resolvePath("photon/PhotonBridge.exe");
            if(!info.executable.exists)throw new Error("Photon files are missing. Extract the whole game ZIP first.");
            process=new NativeProcess();process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,data);
            process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA,function(e:ProgressEvent):void {process.standardError.readUTFBytes(process.standardError.bytesAvailable);});
            process.addEventListener(NativeProcessExitEvent.EXIT,function(e:NativeProcessExitEvent):void {close();});
            process.addEventListener(IOErrorEvent.STANDARD_INPUT_IO_ERROR,function(e:IOErrorEvent):void {close();});
            last=getTimer();process.start(info);
        }
        private function data(e:ProgressEvent):void {
            process.standardOutput.readBytes(buffer,buffer.length,process.standardOutput.bytesAvailable);
            if(buffer.length>700000){close();return;}
            var consumed:int=0;
            for(var i:int=0;i<buffer.length;i++)if(buffer[i]==10){
                buffer.position=consumed;var line:String=buffer.readUTFBytes(i-consumed);consumed=i+1;
                var m:Object;try{m=JSON.parse(line);}catch(error:Error){continue;}
                last=getTimer();
                if(m.t=="bridgeReady"){if(onOpen!=null)onOpen();}
                else if(onMessage!=null)onMessage(m);
                if(closed)return;
            }
            if(consumed){var tail:ByteArray=new ByteArray();buffer.position=consumed;if(buffer.bytesAvailable)buffer.readBytes(tail);buffer=tail;}
        }
        public function send(m:Object):void {
            if(closed || !process || !process.running)return;
            try{process.standardInput.writeUTFBytes(JSON.stringify(m)+"\n");}catch(e:Error){close();}
        }
        public function close():void {
            if(closed)return;closed=true;
            if(process&&process.running)try{process.exit(true);}catch(e:Error){}
            if(onClose!=null)onClose();
        }
    }
}
