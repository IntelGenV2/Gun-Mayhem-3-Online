// Flash-native online screens and a single owner for menu music/transition sound.
_root.gm3Tracks = {};
_root.gm3TrackLoaded = {};
_root.gm3MusicPlaying = "";
_root.gm3Transitioning = false;
_root.gm3SoundEpoch = 0;
_root.gm3TransitionSounds = 0;
_root.gm3RoomPage="rules";
_root.gm3ShuttingDown=false;
_root.gm3AudioDepth = 61000;
_root.gm3OnlineModel = {screen:"host",name:"Player",region:"us",notice:""};
_root.gm3Regions = ["us","usw","eu","asia","au","jp","sa","kr","cae","za","in","tr","uae"];
_root.gm3Modes = [1,2,3,4,5,10,11];
_root.gm3ModeNames = ["Lives battle","One shot","Teams","Gun game","Survival","Reverse gun game","Jetpacks"];
_root.gm3Variants = ["Original rules","Sniper Showdown","Supply Storm"];
function gm3LoadTrack(key,path) {
    var clip=_root.createEmptyMovieClip("gm3Track_"+key,59990+(_root.gm3TrackIndex++));
    var sound=new Sound(clip);sound.gm3Key=key;
    sound.onLoad=function(ok){_root.gm3TrackLoaded[this.gm3Key]=ok;};
    _root.gm3Tracks[key]=sound;sound.loadSound(path,false);
}
_root.gm3TrackIndex=0;
gm3LoadTrack("main","audio/gm1-menu.mp3");
gm3LoadTrack("setup","audio/gm1-setup.mp3");
function gm3StopMenuMusic() {
    for(var k in _root.gm3Tracks)_root.gm3Tracks[k].stop();
    _root.gm3MusicPlaying="";
}
function gm3StopScreenSounds() {
    stopAllSounds();_root.gm3StopMenuMusic();_root.gm3Sounds=[];
    _root.gm3Effects={};
    _root.gm3BattlePlaying=false;
    _root.gm3SoundEpoch++;_root.gm3TransitionSounds=0;
    _root.gm3Send("audioEvent",{event:"stopAll",epoch:_root.gm3SoundEpoch});
}
function gm3TransitionStart() {
    if(_root.gm3MusicPlaying=="setup")_root.gm3StopEffects();
    else _root.gm3StopScreenSounds();
    _root.gm3Transitioning=true;
    _root.gm3Send("audioEvent",{event:"transitionStart"});
}
function gm3TransitionMiddle() {
    if(_root._currentframe!=10 || !_root.gotomenu)_root.gm3Main.removeMovieClip();
    if(_root.gm3NextOnline!=undefined) {
        if(_root.menup){_root.menup.swapDepths(49000);_root.menup.removeMovieClip();}
        if(_root.gm3Panel)_root.gm3Panel.removeMovieClip();
        var screen=_root.gm3NextOnline;delete _root.gm3NextOnline;
        if(_root.gm3NextModel!=undefined){_root.gm3OnlineModel=_root.gm3NextModel;screen=_root.gm3NextModel.screen;delete _root.gm3NextModel;}
        _root.gm3OnlineModel.screen=screen;
        _root._x=0;_root._y=0;_root._xscale=100;_root._yscale=100;
        _root.gm3RenderOnline(_root.gm3OnlineModel);
        _root.gm3Send("onlineAction",{action:"open",screen:screen});
    }
}
function gm3TransitionDone() {
    _root.gm3Transitioning=false;
    _root.gm3Send("audioEvent",{event:"transitionDone"});
}
function gm3Whoosh() {
    if(!_root.savedata2.data.soundON)return;
    var c=_root.createEmptyMovieClip("gm3Whoosh"+(_root.gm3AudioDepth++),_root.gm3AudioDepth);
    c.s=new Sound(c);c.s.attachSound("whoosh.wav");c.s.setVolume(100);
    c.s.gm3Epoch=_root.gm3SoundEpoch;c.s.gm3Clip=c;
    _root.gm3Effects["wipe"+_root.gm3AudioDepth]=c.s;
    _root.gm3TransitionSounds++;
    c.s.onSoundComplete=function(){
        if(this.gm3Epoch==_root.gm3SoundEpoch)_root.gm3TransitionSounds=Math.max(0,_root.gm3TransitionSounds-1);
        _root.gm3Send("audioEvent",{event:"whooshDone",pending:_root.gm3TransitionSounds});
        this.gm3Clip.removeMovieClip();
    };
    c.s.start(0,1);
}
function gm3MusicTick() {
    if(_root.gm3ShuttingDown)return;
    _root.gm3AudioTick();
    if(_root.gm3ReturnAfterFade && !_root.fadeaway){
        _root.gm3ReturnAfterFade=false;
        var returnFade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);returnFade.targetframe=10;
    }
    // Network replies can arrive during a wipe; apply the newest screen only
    // once the current animation has released the stage.
    if(!_root.fadeaway && !_root.gm3Transitioning && _root.gm3NextModel!=undefined){
        var queued=_root.gm3NextModel;delete _root.gm3NextModel;
        _root.gm3ShowOnline(queued);
    }
    var desired="";
    if(_root.gm3Panel)desired="setup";
    else if(!_root.gm3Online && _root._currentframe>=3 && _root._currentframe<=9)desired="setup";
    else if(_root._currentframe==10 && _root.gotomenu && !_root.gm3Online)desired="main";
    if(!_root.savedata2.data.musicON)desired="";
    // A setup track already in progress belongs to the whole submenu session.
    // Only a new/different track waits for the complete wipe and its sound.
    if(desired=="setup" && _root.gm3MusicPlaying=="setup")return;
    if(_root.gm3Transitioning || _root.fadeaway || _root.gm3TransitionSounds>0)desired="";
    if(desired!=_root.gm3MusicPlaying){
        _root.gm3StopMenuMusic();
        if(desired!="" && _root.gm3TrackLoaded[desired]){
            _root.gm3Tracks[desired].start(0.1,999);_root.gm3MusicPlaying=desired;
            _root.gm3Send("audioEvent",{event:"musicStart",track:desired,pending:_root.gm3TransitionSounds,transition:_root.gm3Transitioning,fade:!!_root.fadeaway});
        }
    }
}
// Original options call music1.start; queue through the music owner instead.
_root.music1={start:function(){_root.gm3MusicTick();},stop:function(){}};
function gm3OpenOnline(screen) {
    if(_root.fadeaway)return;
    _root.gm3NextOnline=screen;
    var fade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);fade.targetframe=9;
}
function gm3ShowOnline(model) {
    if(_root.gm3Panel){
        if(_root.gm3OnlineModel.screen!=model.screen)_root.gm3StopEffects();
        _root.gm3RenderOnline(model);return;
    }
    if(_root.gm3Active){_root.gm3StopScreenSounds();_root.gm3RenderOnline(model);return;}
    _root.gm3NextModel=model;
    _root.gm3OpenOnline(model.screen);
}
function gm3Pin(mc) {
    if(!mc)return;
    mc._x=-_root._x*100/_root._xscale;mc._y=-_root._y*100/_root._yscale;
    mc._xscale=10000/_root._xscale;mc._yscale=10000/_root._yscale;
}
function gm3CameraReady() {
    _root.gm3OriginalFrame=_root.onEnterFrame;
    _root.onEnterFrame=function(){
        if(!_root.gm3Panel || _root.gm3Active)_root.gm3OriginalFrame();
        else {_root._x=0;_root._y=0;_root._xscale=100;_root._yscale=100;}
        _root.gm3Pin(_root.gm3Main);_root.gm3Pin(_root.gm3Panel);_root.gm3Pin(_root.gm3MatchButton);
        _root.gm3Pin(_root.gm3AudioHUD);
    };
    _root.gm3OriginalReturn=_root.returntomenu;
    _root.returntomenu=function(){
        _root.gm3OriginalReturn();_root.gm3Main.removeMovieClip();
        if(_root.gm3ReturningMenu){
            // Jump away first: gotoAndPlay on the current last frame wraps
            // the movie instead of running that frame's setup script again.
            _root.gotomenu=true;_root.gotoAndStop(9);
            if(_root.menup){_root.menup.swapDepths(49000);_root.menup.removeMovieClip();}
        }
    };
    if(_root.gm3ReturningMenu){_root.gm3ReturningMenu=false;_root.gm3StopScreenSounds();}
}
function gm3Shutdown() {
    _root.gm3ShuttingDown=true;_root.gm3StopScreenSounds();
    _root.gm3Active=false;_root.gm3Setup=0;
    delete _root.gm3NextModel;delete _root.gm3NextOnline;
    delete _root.onEnterFrame;delete _root.gm3Ticker.onEnterFrame;
    _root.gm3Send("stopped",_root.gm3Token);_root.stop();
}
