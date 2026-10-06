package {
    import flash.events.*;
    import flash.net.*;
    import flash.utils.*;
    public class UpdateChecker {
        public static const REPOSITORY:String="https://github.com/IntelGenV2/Gun-Mayhem-3-Online";
        private var loader:URLLoader;
        private var timeout:uint;
        private var status:int;
        private var current:String;
        private var result:Function;
        public function check(version:String,callback:Function):void {
            if(loader)return;
            current=version;result=callback;status=0;loader=new URLLoader();
            loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS,httpStatus);
            loader.addEventListener(HTTPStatusEvent.HTTP_STATUS,httpStatus);
            loader.addEventListener(Event.COMPLETE,complete);
            loader.addEventListener(IOErrorEvent.IO_ERROR,failed);
            loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,failed);
            callback({status:"checking",message:"Checking GitHub Releases..."});
            var request:URLRequest=new URLRequest("https://api.github.com/repos/IntelGenV2/Gun-Mayhem-3-Online/releases/latest");
            request.requestHeaders=[new URLRequestHeader("Accept","application/vnd.github+json")];
            request.userAgent="Gun-Mayhem-3-Online/"+version;
            timeout=setTimeout(function():void {finish({status:"error",message:"Could not reach GitHub. Check your connection and try again."});},15000);
            try{loader.load(request);}catch(e:Error){failed(null);}
        }
        private function httpStatus(e:HTTPStatusEvent):void {status=e.status;}
        private function complete(e:Event):void {
            if(status>=400){failed(null);return;}
            try{finish(classify(current,JSON.parse(String(loader.data))));}
            catch(error:Error){finish({status:"error",message:"GitHub returned an unreadable release. Try again later."});}
        }
        private function failed(e:Event):void {
            if(status==404)finish({status:"none",message:"No public release is available yet. Installed: "+current+"."});
            else if(status==403 || status==429)finish({status:"error",message:"GitHub's request limit was reached. Try again later."});
            else finish({status:"error",message:"Could not check for updates. Check your connection and try again."});
        }
        private function finish(value:Object):void {
            if(!loader)return;
            clearTimeout(timeout);
            loader.removeEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS,httpStatus);loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS,httpStatus);
            loader.removeEventListener(Event.COMPLETE,complete);loader.removeEventListener(IOErrorEvent.IO_ERROR,failed);loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,failed);
            try{loader.close();}catch(e:Error){}loader=null;
            result(value);
        }
        private static function version(value:String):Array {
            var match:Array=/^v?(\d+)\.(\d+)\.(\d+)$/i.exec(value);
            if(!match)return null;return [Number(match[1]),Number(match[2]),Number(match[3])];
        }
        public static function classify(installed:String,release:Object):Object {
            if(!release || release.draft || release.prerelease)return {status:"none",message:"No stable release is available yet."};
            var tag:String=String(release.tag_name);var remote:Array=version(tag),local:Array=version(installed);
            if(!remote || !local)return {status:"error",message:"This release needs a version tag such as v0.5.0."};
            var newer:Boolean=false;
            for(var i:int=0;i<3;i++){if(remote[i]==local[i])continue;newer=remote[i]>local[i];break;}
            if(!newer)return {status:"current",message:"You're up to date. Installed: "+installed+"."};
            var zipped:Boolean=false;
            if(release.assets is Array)for each(var a:Object in release.assets)if(a.state=="uploaded" && /\.zip$/i.test(String(a.name)) && Number(a.size)>0)zipped=true;
            if(!zipped)return {status:"pending",message:tag+" is published, but its game ZIP is not ready yet."};
            return {status:"update",message:"Update "+tag+" is available. Opening its download page.",url:REPOSITORY+"/releases/tag/"+encodeURIComponent(tag)};
        }
    }
}
