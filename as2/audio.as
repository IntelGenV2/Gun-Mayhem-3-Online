// Menu music and effects have separate owners. Reuse the original Options art.
_root.gm3Effects={};
function gm3TrackEffect(sound,key) {
    if(!sound)return;
    sound.gm3EffectKey=key;_root.gm3Effects[key]=sound;
    sound.onSoundComplete=function(){if(_root.gm3Effects[this.gm3EffectKey]==this)delete _root.gm3Effects[this.gm3EffectKey];};
}
function gm3StopEffects() {
    for(var key in _root.gm3Effects)_root.gm3Effects[key].stop();
    _root.gm3Effects={};_root.gm3Sounds=[];
    _root.gm3SoundEpoch++;_root.gm3TransitionSounds=0;
    _root.gm3Send("audioEvent",{event:"stopEffects",epoch:_root.gm3SoundEpoch});
}
function gm3ToggleAudio(kind) {
    var d=_root.savedata2.data;
    if(kind=="all"){
        if(d.musicON || d.soundON){_root.gm3BeforeMute={music:d.musicON,sounds:d.soundON};d.musicON=false;d.soundON=false;}
        else {d.musicON=_root.gm3BeforeMute?_root.gm3BeforeMute.music:true;d.soundON=_root.gm3BeforeMute?_root.gm3BeforeMute.sounds:true;delete _root.gm3BeforeMute;}
    }else{
        delete _root.gm3BeforeMute;
        if(kind=="music")d.musicON=!d.musicON;
        if(kind=="sounds")d.soundON=!d.soundON;
    }
    _root.gm3AudioTick();_root.gm3MusicTick();
}
function gm3AudioSwitch(parent,kind,label,x) {
    var b=parent.createEmptyMovieClip(kind,parent.getNextHighestDepth());b._x=x;b._y=3;
    var art=b.attachMovie("gm3_symbol_1315","art",1);art.gotoAndStop(1);
    var bounds=art.getBounds(art);var sx=116/(bounds.xMax-bounds.xMin);var sy=23/(bounds.yMax-bounds.yMin);
    art._xscale=sx*100;art._yscale=sy*100;art._x=-bounds.xMin*sx;art._y=-bounds.yMin*sy;
    art.enabled=false;art.useHandCursor=false;
    b.label=_root.gm3Text(b,"",3,2,110,14,0,"Century Gothic");b.gm3Kind=kind;b.gm3Label=label;
    b.onRelease=function(){if(!_root.fadeaway)_root.gm3ToggleAudio(this.gm3Kind);};
    return b;
}
function gm3AudioTick() {
    if(!_root.savedata2)return;
    var d=_root.savedata2.data;
    if(_root.gm3LastMusic!=d.musicON || _root.gm3LastSounds!=d.soundON){
        if(!d.soundON)_root.gm3StopEffects();
        if(!d.musicON){
            _root.gm3StopMenuMusic();
            for(var i=2;i<=4;i++)_root["music"+i].stop();
            _root.gm3Music.stop();_root.gm3BattlePlaying=false;
        }
        _root.gm3LastMusic=d.musicON;_root.gm3LastSounds=d.soundON;_root.savedata2.flush();
        if(_root.menu_options){
            _root.menu_options.btn4.gotoAndStop(d.musicON?3:1);_root.menu_options.btn5.gotoAndStop(d.musicON?1:3);
            _root.menu_options.btn6.gotoAndStop(d.soundON?3:1);_root.menu_options.btn7.gotoAndStop(d.soundON?1:3);
        }
        _root.gm3Send("audioEvent",{event:"preferences",music:d.musicON,sounds:d.soundON});
    }
    var menu=!!_root.gm3Panel || (!_root.gm3Online && _root._currentframe>=3 && (_root._currentframe<10 || _root.gotomenu));
    if(!menu){if(_root.gm3AudioHUD)_root.gm3AudioHUD._visible=false;return;}
    if(!_root.gm3AudioHUD){
        var p=_root.createEmptyMovieClip("gm3AudioHUD",59000);
        _root.gm3AudioSwitch(p,"music","Music",628);_root.gm3AudioSwitch(p,"sounds","Sounds",751);
    }
    var hud=_root.gm3AudioHUD;hud._visible=!_root.gm3Transitioning && !_root.fadeaway;
    _root.gm3Pin(hud);
    hud.music.art.gotoAndStop(d.musicON?3:1);hud.sounds.art.gotoAndStop(d.soundON?3:1);
    hud.music.label.text="Music: "+(d.musicON?"ON":"OFF");hud.sounds.label.text="Sounds: "+(d.soundON?"ON":"OFF");
}
