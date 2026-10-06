package {
    import flash.display.*;
    import flash.events.*;
    import flash.text.*;
    import flash.net.*;
    import flash.geom.*;
    import flash.utils.*;
    import flash.desktop.*;
    import flash.filesystem.*;
    import flash.system.LoaderContext;
    import flash.media.*;
    import flash.ui.Keyboard;

    [SWF(width="900",height="600",frameRate="35",backgroundColor="#000000")]
    public class Main extends Sprite {
        // The original game and online menus both render inside the Flash stage.
        private const modes:Array=[1,2,3,4,5,10,11];
        private const regions:Array=["us","usw","eu","asia","au","jp","sa","kr","cae","za","in","tr","uae"];
        private var viewport:Sprite=new Sprite();
        private var game:Loader;
        private var incoming:LocalConnection;
        private var outgoing:LocalConnection;
        private var token:String="";
        private var conn:PhotonConnection;
        private var state:String="classic";
        private var slot:int=-1;
        private var code:String="";
        private var playerName:String="Player";
        private var region:String="us";
        private var settings:Object={arena:1,mode:1,stocks:5,variant:0,bots:true,crates:true,pickups:true};
        private var players:Array=[null,null,null,null];
        private var notice:String="";
        private var held:Object={};
        private var timer:Timer=new Timer(100);
        private var ticks:int=0;
        private var ping:int=0;
        private var muted:Boolean=false;
        private var pending:Object;
        private var bridgeReady:Boolean=false;
        private var pieces:Array=[];
        private var pieceSeq:int=-1;
        private var pieceCount:int=0;
        private var sceneCount:int=0;
        private var sceneSize:int=0;
        private var lastScene:int=0;
        private var inputMasks:Array=[0,0,0,0];
        private var inputEdges:Array=[0,0,0,0];
        private var inputDirty:Boolean=false;
        private var snapshotAck:int=-1;
        private var sceneWaiting:Boolean=false;
        private var latestScene:Object;
        private var testScene:String="";
        private var guestRows:Object={};
        private var sentRows:Object={};
        private var soundRows:Array=[];
        private var newestSequence:int=-1;
        private var test:Object;
        private var testStarted:int=0;
        private var captured:Boolean=false;
        private var roundCount:int=0;
        private var dataSave:SharedObject;
        private var guestRenderer:Boolean=false;
        private var queuedLoad:Object;
        private var switching:Boolean=false;
        private var connectionGeneration:int=0;
        private var localProfile:Object;
        private var updateChecker:UpdateChecker=new UpdateChecker();
        private var appVersion:String;

        public function Main() {
            var descriptor:XML=NativeApplication.nativeApplication.applicationDescriptor;
            appVersion=String(descriptor.children().(localName()=="versionNumber")[0]);
            stage.scaleMode=StageScaleMode.NO_SCALE;stage.align=StageAlign.TOP_LEFT;stage.frameRate=35;
            addChild(viewport);viewport.scrollRect=new Rectangle(0,0,900,600);
            stage.addEventListener(Event.RESIZE,resizeGame);stage.addEventListener(FullScreenEvent.FULL_SCREEN,resizeGame);resizeGame();
            try {dataSave=SharedObject.getLocal("gm3-online-settings");if(dataSave.data.name)playerName=dataSave.data.name;if(regions.indexOf(dataSave.data.region)>=0)region=dataSave.data.region;}catch(e:Error){}
            stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDown);stage.addEventListener(KeyboardEvent.KEY_UP,keyUp);
            stage.addEventListener(Event.DEACTIVATE,function(e:Event):void {held={};sendInput();});
            addEventListener(Event.ENTER_FRAME,flushInputs);
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE,invoke);
            NativeApplication.nativeApplication.addEventListener(Event.EXITING,function(e:Event):void {disconnect();});
            timer.addEventListener(TimerEvent.TIMER,tick);timer.start();
            loadGame(false,{command:"startup",data:null});
        }
        private function invoke(e:InvokeEvent):void {
            for each(var arg:String in e.arguments)if(arg.indexOf("--test-config=")==0) {
                var f:File=new File(arg.substr(14)),s:FileStream=new FileStream();s.open(f,FileMode.READ);test=JSON.parse(s.readUTFBytes(s.bytesAvailable));s.close();
                region=test.region || region;playerName=test.name || "Tester";
                if(test.width){stage.nativeWindow.width=test.width;stage.nativeWindow.height=test.height;resizeGame();}
                if(test.arena)settings.arena=test.arena;if(test.variant)settings.variant=test.variant;if(test.mode)settings.mode=test.mode;
                if(test.classic){testStarted=getTimer();}
                else if(test.host)connect(true);else connect(false,test.code);
            }
        }
        private var pendingUI:Object;
        private var inlineMenu:Boolean=false;
        private var connectScreen:String="host";
        private function showOnline(model:Object):void {
            model.name=playerName;model.region=region;model.notice=notice;
            inlineMenu=true;held={};sendInput();
            if(!bridgeReady){pendingUI=model;return;}
            command("onlineUI",model);
        }
        private function renderConnect(screen:String=null):void {
            if(screen)connectScreen=screen;
            showOnline({screen:connectScreen,code:""});
        }
        private function onlineAction(m:Object):void {
            if(m.action=="open"){
                if(m.screen=="host" || m.screen=="join"){if(conn)renderLobby();else renderConnect(m.screen);}
                return;
            }
            if(m.name!=null)playerName=String(m.name).replace(/[\x00-\x1f|]/g,"").substr(0,18)||"Player";
            if(regions.indexOf(m.region)>=0)region=m.region;
            if(dataSave){dataSave.data.name=playerName;dataSave.data.region=region;dataSave.flush();}
            switch(m.action){
                case "create":localProfile=m.profile;connectScreen="host";connect(true);break;
                case "join":localProfile=m.profile;connectScreen="join";connect(false,String(m.code));break;
                case "updates":updateChecker.check(appVersion,updateResult);break;
                case "back":leave();break;
                case "room":renderLobby();break;
                case "endRound":endRound();break;
                case "profile":if(conn&&state=="lobby")conn.send({t:"profile",profile:m.profile});break;
                case "settings":if(conn&&slot==0&&state=="lobby")conn.send({t:"settings",settings:m.settings});break;
                case "copy":Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT,invite());notice="Invite copied.";renderLobby();break;
                case "start":if(conn&&slot==0)conn.send({t:"start"});break;
                case "ready":if(conn&&slot>0&&players[slot])conn.send({t:"ready",ready:!players[slot].ready});break;
                case "resume":inlineMenu=false;command("hideOnline",null);break;
                default:
                    if(!conn||slot!=0||state=="playing")return;
                    if(m.action=="Arena")settings.arena=settings.arena%21+1;
                    else if(m.action=="Rules")settings.mode=modes[(modes.indexOf(settings.mode)+1)%modes.length];
                    else if(m.action=="Extra rules")settings.variant=(settings.variant+1)%3;
                    else if(m.action=="Lives")settings.stocks=settings.stocks>=20?1:settings.stocks+1;
                    else if(m.action=="Empty slots")settings.bots=!settings.bots;
                    else return;
                    conn.send({t:"settings",settings:settings});
            }
        }
        private function connect(create:Boolean,room:String=""):void {
            disconnect();notice="";
            try {
                state="connecting";showOnline({screen:"connecting"});
                var active:PhotonConnection=new PhotonConnection();conn=active;var generation:int=connectionGeneration;
                conn.onOpen=function():void {if(conn!=active||generation!=connectionGeneration)return;active.send({t:create?"create":"join",name:playerName,region:region,code:room,settings:settings});};
                conn.onMessage=function(m:Object):void {if(conn==active&&generation==connectionGeneration)receive(m);};
                conn.onClose=function():void {if(conn!=active||generation!=connectionGeneration)return;notice="Photon connection closed. Check your internet connection.";leave();};conn.connect();
            }catch(e:Error){notice=e.message;disconnect();state="classic";renderConnect();}
        }
        private function receive(m:Object):void {
            switch(m.t){
                case "heartbeat":ping=m.ping;if(test)writeTest({event:"network",directPeers:m.directPeers,directSent:m.directSent,directReceived:m.directReceived});break;
                case "welcome":slot=m.slot;code=m.code;state="lobby";if(localProfile)conn.send({t:"profile",profile:localProfile});writeTest({event:"welcome",slot:slot,code:code});break;
                case "lobby":players=m.players;settings=m.settings;if(state!="playing")renderLobby();break;
                case "error":writeTest({event:"error",message:m.message});notice=m.message;if(state=="connecting"){disconnect();state="classic";renderConnect();}else renderLobby();break;
                case "closed":notice=m.message;leave();break;
                case "start":notice="";state="playing";sceneCount=0;sceneSize=0;lastScene=getTimer();held={};roundCount++;
                    var cfg:Object=m.settings;cfg.players=m.players;cfg.loadouts=m.loadouts;loadGame(slot!=0,slot==0?{command:"start",data:cfg}:null);
                    inlineMenu=false;pendingUI=null;stage.nativeWindow.activate();testStarted=getTimer();captured=false;writeTest({event:"started",slot:slot,round:roundCount});break;
                case "input":if(slot==0){inputEdges[m.slot] |= int(m.mask) & ~int(inputMasks[m.slot]);inputMasks[m.slot]=m.mask;inputDirty=true;}break;
                case "state":if(slot!=0&&state=="playing"){lastScene=getTimer();sceneCount++;sceneSize=m.scene.length;if(m.full)guestRows={};mergeScene(m.seq,m.scene);}break;
                case "finish":state="lobby";held={};command("lobby",null);notice=m.message;renderLobby();writeTest({event:"finished",message:m.message});break;
                case "pong":ping=getTimer()-int(m.at);break;
            }
        }
        private function renderLobby():void {
            if(conn)showOnline({screen:"lobby",slot:slot,code:code,players:players,settings:settings,playing:state=="playing"});
        }
        private function invite():String {
            return "Gun Mayhem 3 Online\nPhoton region: "+region.toUpperCase()+"\nRoom: "+code;
        }
        private function endRound():void {if(conn&&state=="playing"&&slot==0)conn.send({t:"finish",message:"Host returned to the lobby"});else if(conn)renderLobby();}
        private function updateResult(value:Object):void {
            command("updateStatus",value);writeTest({event:"update",data:value});
            if(value.status=="update" && !test)try{navigateToURL(new URLRequest(value.url),"_blank");}catch(e:Error){command("updateStatus",{message:"Update available. Visit github.com/IntelGenV2/Gun-Mayhem-3-Online/releases"});}
        }
        private function leave():void {
            var reload:Boolean=guestRenderer||switching;
            disconnect();inlineMenu=false;pendingUI=null;state="classic";code="";players=[null,null,null,null];
            SoundMixer.stopAll();
            if(reload)loadGame(false,{command:"classic",data:null});
            else command("onlineBack",null);
            writeTest({event:"left",reload:reload});
        }
        private function loadGame(guest:Boolean,start:Object):void {
            queuedLoad={guest:guest,start:start};
            SoundMixer.stopAll();
            if(switching)return;
            if(game&&bridgeReady){
                switching=true;command("shutdown",null);bridgeReady=false;
                var oldToken:String=token;
                setTimeout(function():void {if(switching&&token==oldToken)completeLoad();},350);
            }else completeLoad();
        }
        private function stopped(value:Object):void {if(switching)completeLoad();}
        private function completeLoad():void {
            if(!queuedLoad)return;
            var guest:Boolean=queuedLoad.guest,start:Object=queuedLoad.start;queuedLoad=null;switching=false;
            guestRenderer=guest;
            unloadGame();pending=start;bridgeReady=false;pieces=[];pieceSeq=-1;pieceCount=0;token=String(new Date().time)+"_"+int(Math.random()*1000000);
            sceneWaiting=false;latestScene=null;guestRows={};sentRows={};soundRows=[];newestSequence=-1;inputMasks=[0,0,0,0];inputEdges=[0,0,0,0];inputDirty=false;snapshotAck=-1;
            incoming=new LocalConnection();incoming.allowDomain("*");incoming.client={stopped:stopped,ready:ready,snapshot:snapshot,finished:finished,diagnostics:diagnostics,sceneApplied:sceneApplied,onlineAction:onlineAction,audioEvent:audioEvent};incoming.addEventListener(StatusEvent.STATUS,function(e:StatusEvent):void{});incoming.connect("_gm3_air_"+token);
            outgoing=new LocalConnection();outgoing.addEventListener(StatusEvent.STATUS,function(e:StatusEvent):void{if(test&&e.level=="error")writeTest({event:"bridgeError"});});
            game=new Loader();game.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void {notice=e.text;renderConnect();});
            var skipIntro:Boolean=!(start&&start.command=="startup");
            var context:LoaderContext=new LoaderContext();context.parameters={gm3Token:token,gm3SkipIntro:skipIntro?"1":"0"};viewport.addChild(game);game.load(new URLRequest((guest?"guest":"game")+".swf?gm3Token="+token+"&gm3SkipIntro="+(skipIntro?"1":"0")),context);
        }
        private function ready(kind:String):void {if(bridgeReady)return;bridgeReady=true;if(pending){command(pending.command,pending.data);pending=null;}if(pendingUI){showOnline(pendingUI);pendingUI=null;}if(kind=="guest"&&newestSequence>=0)deliverLatest();if(state=="playing")command("matchControls",{slot:slot});writeTest({event:"bridge",kind:kind});}
        private function command(name:String,data:Object):void {if(outgoing&&bridgeReady)outgoing.send("_gm3_game_"+token,"command",name,data);}
        private function snapshot(seq:int,part:int,total:int,data:String):void {
            if(switching||state!="playing"||slot!=0||total<1||total>20||part>=total||seq<pieceSeq)return;
            if(seq!=pieceSeq){pieceSeq=seq;pieces=[];pieceCount=0;}if(pieces[part]==null)pieceCount++;pieces[part]=data;
            if(pieceCount==total){var scene:String=pieces.join("");testScene=scene;sceneCount++;sceneSize=scene.length;lastScene=getTimer();snapshotAck=seq;inputDirty=true;conn.send({t:"state",seq:seq,scene:scene});}
        }
        private function mergeScene(seq:int,scene:String):void {
            if(seq<=newestSequence)return;newestSequence=seq;
            for each(var row:String in scene.split("\n")) {
                var split:int=row.indexOf("|");if(split<0)continue;var key:String=row.substr(0,split);
                if(key=="!"){soundRows.push(row);if(soundRows.length>32)soundRows.shift();}
                else if(key=="-")delete guestRows[row.substr(2)];
                else if(key=="@" || /^d-?\d+(\/d-?\d+)*$/.test(key))guestRows[key]=row;
            }
            if(bridgeReady&&!sceneWaiting)deliverLatest();else latestScene={seq:seq};
        }
        private function deliverLatest():void {
            var changed:Array=[];var next:Object={};var all:Array=[];
            for(var key:String in guestRows){var row:String=guestRows[key];all.push(row);next[key]=row;if(sentRows[key]!==row)changed.push(row);}
            if(all.length>2500){conn.close();return;}
            for(key in sentRows)if(!guestRows.hasOwnProperty(key))changed.push("-|"+key);
            sentRows=next;testScene=all.join("\n");changed=changed.concat(soundRows);soundRows=[];latestScene=null;
            deliverScene(newestSequence,changed.join("\n"));
        }
        private function deliverScene(seq:int,scene:String):void {
            sceneWaiting=true;var total:int=Math.ceil(scene.length/32000);for(var i:int=0;i<total;i++)outgoing.send("_gm3_game_"+token,"scene",seq,i,total,scene.substr(i*32000,32000));
            if(total==0)sceneWaiting=false;
        }
        private function sceneApplied(seq:int):void {sceneWaiting=false;if(latestScene)deliverLatest();}
        private function flushInputs(e:Event):void {
            if(slot!=0||state!="playing"||!bridgeReady||!inputDirty)return;
            var all:Array=[];var clearPulse:Boolean=false;
            for(var i:int=0;i<4;i++){all[i]=int(inputMasks[i])|int(inputEdges[i]);if(all[i]!=inputMasks[i])clearPulse=true;inputEdges[i]=0;}
            inputDirty=clearPulse;command("inputs",{masks:all,ack:snapshotAck});
        }
        private function finished(message:String):void {if(conn&&slot==0)conn.send({t:"finish",message:message});}
        private function unloadGame():void {
            bridgeReady=false;if(incoming)try{incoming.close();}catch(e:Error){}incoming=null;outgoing=null;
            SoundMixer.stopAll();
            if(game){try{game.unloadAndStop(true);}catch(e2:Error){try{game.unload();}catch(e3:Error){}}if(game.parent)game.parent.removeChild(game);game=null;}
        }
        private function disconnect():void {connectionGeneration++;held={};slot=-1;if(conn){conn.onOpen=null;conn.onMessage=null;conn.onClose=null;conn.close();conn=null;}}
        private function resizeGame(e:Event=null):void {
            var fit:Number=Math.min(stage.stageWidth/900,stage.stageHeight/600);
            viewport.scaleX=viewport.scaleY=fit;
            viewport.x=Math.round((stage.stageWidth-900*fit)/2);viewport.y=Math.round((stage.stageHeight-600*fit)/2);
            graphics.clear();graphics.beginFill(0x000000);graphics.drawRect(0,0,stage.stageWidth,stage.stageHeight);graphics.endFill();
            stage.invalidate();
        }
        private function fullscreen():void {stage.displayState=stage.displayState==StageDisplayState.NORMAL?StageDisplayState.FULL_SCREEN_INTERACTIVE:StageDisplayState.NORMAL;}
        private function toggleMute():void {command("audioToggle",{kind:"all"});}
        private function keyDown(e:KeyboardEvent):void {var repeat:Boolean=held[e.keyCode];held[e.keyCode]=true;if(!repeat&&e.keyCode==Keyboard.F11)fullscreen();if(!repeat&&!inlineMenu&&e.keyCode==77)toggleMute();if(!repeat&&e.keyCode==Keyboard.ESCAPE&&conn&&state=="playing"){if(inlineMenu)onlineAction({action:"resume"});else renderLobby();}sendInput();}
        private function keyUp(e:KeyboardEvent):void {delete held[e.keyCode];sendInput();}
        private function mask():int {return (held[38]||held[87]?1:0)|(held[37]||held[65]?2:0)|(held[40]||held[83]?4:0)|(held[39]||held[68]?8:0)|(held[90]||held[74]?16:0)|(held[88]||held[75]?32:0);}
        private function sendInput():void {if(conn&&state=="playing")conn.send({t:"input",mask:inlineMenu?0:mask()});}
        private function smokeReady():Boolean {var count:int=0;for each(var p:Object in players)if(p){count++;if(!p.ready)return false;}return count>=int(test.testPlayers||2);}
        private function tick(e:TimerEvent):void {
            ticks++;if(conn){if(getTimer()-conn.last>15000)conn.close();if(conn&&state=="playing")sendInput();}
            if(test){
                if(test.actions&&test.actions.length&&bridgeReady&&getTimer()-testStarted>test.actions[0].at&&(!test.actions[0].when||test.actions[0].when==state)){
                    var action:Object=test.actions.shift();if(action.command=="ui")onlineAction(action.data);else if(action.command=="testUpdate")updateResult(UpdateChecker.classify(appVersion,action.data));else command(action.command,action.data);
                    writeTest({event:"testAction",command:action.command,data:action.data});
                }
                if(test.captures&&test.captures.length&&getTimer()-testStarted>test.captures[0]){var captureAt:int=test.captures.shift();var originalOutput:String=test.output;test.output=originalOutput+"-"+captureAt;captureTest();test.output=originalOutput;}
                if(state=="playing"&&test.host&&test.freeze&&!test.frozen&&getTimer()-testStarted>7000){test.frozen=true;command("testFreeze",null);}
                if(!test.manual&&state=="lobby"&&test.host&&smokeReady()&&(!test.didStart || test.rematch&&roundCount==1)){test.didStart=true;conn.send({t:"start"});}
                if(state=="playing"&&test.host&&test.rematch&&roundCount==1&&getTimer()-testStarted>7000&&!test.ended){test.ended=true;conn.send({t:"finish",message:"Test rematch"});}
                if(!test.manual&&state=="lobby"&&!test.host&&slot>0&&players[slot]&&!players[slot].ready)conn.send({t:"ready",ready:true});
                if(state=="playing"&&!test.host){held[39]=ticks%30<12;held[38]=ticks%22<5;held[90]=true;}
                if(state=="playing"&&ticks%20==0)writeTest({event:"stats",snapshots:sceneCount,bytes:sceneSize,ping:ping,bridge:bridgeReady});
                if((state=="playing"||state=="classic")&&bridgeReady&&getTimer()-testStarted>(test.freeze?14000:6000)&&!captured){captured=true;captureTest();}
            }
        }
        private function audioEvent(data:Object):void {writeTest({event:"audio",data:data});}
        private function diagnostics(data:Object):void {if(test)writeTest({event:"game",data:data});}
        private function writeTest(data:Object):void {if(!test||!test.output)return;data.time=getTimer();var s:FileStream=new FileStream();s.open(new File(test.output+".jsonl"),FileMode.APPEND);s.writeUTFBytes(JSON.stringify(data)+"\n");s.close();}
        private function captureTest():void {if(!test.output)return;var bmp:BitmapData=new BitmapData(stage.stageWidth,stage.stageHeight,false,0x141414);bmp.draw(this);var bytes:ByteArray=bmp.encode(bmp.rect,new PNGEncoderOptions());var s:FileStream=new FileStream();s.open(new File(test.output+".png"),FileMode.WRITE);s.writeBytes(bytes);s.close();s.open(new File(test.output+".scene.txt"),FileMode.WRITE);s.writeUTFBytes(testScene);s.close();bmp.dispose();writeTest({event:"capture",width:stage.stageWidth,height:stage.stageHeight,scale:viewport.scaleX});}
    }
}
