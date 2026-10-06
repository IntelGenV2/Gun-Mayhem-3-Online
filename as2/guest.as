stop();
_root.gm3Nodes = {};
_root.gm3Pieces = [];
_root.gm3Last = -1;
_root.gm3SceneRows = {};
_root.gm3SoundDepth = 70000;
_root.gm3MusicClip = _root.createEmptyMovieClip("gm3MusicClip",71000);
_root.gm3Music = new Sound(_root.gm3MusicClip);
_root.gm3Music.attachSound("music444.mp3");
_root.gm3In = new LocalConnection();
_root.gm3In.allowDomain = function(domain) { return true; };
_root.gm3In.allowInsecureDomain = function(domain) { return true; };
_root.savedata2=SharedObject.getLocal("arena2gamedata2");
if(_root.savedata2.data.musicON){_root.gm3Music.start(0,999);_root.gm3BattlePlaying=true;}
_root.playsound=function(s){
    if(!_root.savedata2.data.soundON || s!="btn.wav")return;
    if(!_root.gm3ButtonClip)_root.createEmptyMovieClip("gm3ButtonClip",59989);
    _root.gm3ButtonSound=new Sound(_root.gm3ButtonClip);
    _root.gm3ButtonSound.attachSound(s);_root.gm3ButtonSound.setVolume(50);_root.gm3ButtonSound.start(0,1);
    _root.gm3TrackEffect(_root.gm3ButtonSound,"button");
};
_root.gm3In.command=function(command,data){
    if(command=="audioToggle")_root.gm3ToggleAudio(data.kind);
    else if(command=="shutdown")_root.gm3Shutdown();
    else if(command=="testInterface")_root.gm3UIAction(data.action);
    else if(command=="matchControls")_root.gm3MatchControls(data);
    else if(command=="onlineUI"){
        if(!_root.gm3Panel)_root.gm3StopScreenSounds();
        else if(_root.gm3OnlineModel.screen!=data.screen)_root.gm3StopEffects();
        _root.gm3RenderOnline(data);
    }
    else if(command=="hideOnline"){
        _root.gm3StopScreenSounds();_root.gm3Panel.removeMovieClip();
        _root.gm3MatchButton._visible=true;
        if(_root.savedata2.data.musicON){_root.gm3Music.start(0,999);_root.gm3BattlePlaying=true;}
    }else if(command=="lobby"){_root.gm3StopScreenSounds();_root.gm3MatchButton.removeMovieClip();}
};
function gm3Apply(scene) {
    if(_root.gm3ShuttingDown)return;
    var changes=scene.split("\n");var sounds=[];
    for(var ri=0;ri<changes.length;ri++) {
        var row=changes[ri];
        if(row=="")continue;
        var key=row.substr(0,row.indexOf("|"));
        if(key=="!")sounds.push(row);
        else if(key=="-")delete _root.gm3SceneRows[row.substr(2)];
        else _root.gm3SceneRows[key]=row;
    }
    var keys=[];for(var rowKey in _root.gm3SceneRows)keys.push(rowKey);keys.sort();
    var all=[];for(ri=0;ri<keys.length;ri++)all.push(_root.gm3SceneRows[keys[ri]]);
    gm3Render(all.concat(sounds).join("\n"));
}
function gm3Render(scene) {
    _root.gm3ApplyStart = _root.gm3Last;
    var rows = scene.split("\n");
    var seen = {};
    for(var i = 0; i < rows.length; i++) {
        var a = rows[i].split("|");
        if(a[0] == "!") {
            if(_root.gm3Panel || !_root.savedata2.data.soundON)continue;
            _root.gm3SoundDepth++;
            if(_root.gm3SoundDepth > 70100) _root.gm3SoundDepth = 70001;
            var soundClip = _root.createEmptyMovieClip("gm3Sound" + _root.gm3SoundDepth,_root.gm3SoundDepth);
            soundClip.s = new Sound(soundClip); soundClip.s.attachSound(unescape(a[1])); soundClip.s.setVolume(Number(a[2])); soundClip.s.start(0,0);
            _root.gm3TrackEffect(soundClip.s,"guest"+_root.gm3SoundDepth);
            continue;
        }
        if(a[0] == "@") {
            _root._x = Number(a[1]); _root._y = Number(a[2]);
            _root._xscale = Number(a[3]); _root._yscale = Number(a[4]);
            continue;
        }
        var path = a[0]; var slash = path.lastIndexOf("/");
        var parent = slash == -1 ? _root : _root.gm3Nodes[path.substr(0,slash)];
        if(parent == undefined) continue;
        var name = a[20] == undefined ? path.substr(slash+1) : unescape(a[20]);
        if(name == "__proto__" || name == "constructor" || name.indexOf("gm3") == 0) continue;
        var mc = parent.getInstanceAtDepth(Number(a[2])); var symbol = Number(a[1]);
        if(symbol == -1) {
            seen[path] = true;
            if(mc instanceof TextField) { mc.autoSize="none"; mc.text = unescape(a[3]); mc._visible = Number(a[4]) == 1;mc._x=Number(a[5]);mc._y=Number(a[6]);mc._width=Number(a[7]);mc._height=Number(a[8]);mc.textColor=Number(a[9]); }
            continue;
        }
        if(typeof(mc) != "movieclip" || (symbol != 0 && mc.gm3Symbol != symbol)) {
            if(typeof(mc) == "movieclip") { mc.swapDepths(65000); mc.removeMovieClip(); }
            if(symbol > 0) mc = parent.attachMovie("gm3_symbol_"+symbol,name,Number(a[2]));
            else mc = parent.createEmptyMovieClip(name,Number(a[2]));
        }
        if(mc == undefined) continue;
        seen[path] = true; _root.gm3Nodes[path] = mc;
        mc.gotoAndStop(Number(a[3]));
        mc._x = Number(a[4]); mc._y = Number(a[5]);
        mc._xscale = Number(a[6]); mc._yscale = Number(a[7]);
        mc._rotation = Number(a[8]); mc._alpha = Number(a[9]); mc._visible = Number(a[10]) == 1;
        var transform = new flash.geom.Transform(mc);
        transform.matrix = new flash.geom.Matrix(Number(a[21]),Number(a[22]),Number(a[23]),Number(a[24]),Number(a[25]),Number(a[26]));
        new Color(mc).setTransform({ra:Number(a[11]),ga:Number(a[12]),ba:Number(a[13]),aa:Number(a[14]),rb:Number(a[15]),gb:Number(a[16]),bb:Number(a[17]),ab:Number(a[18])});

    }
    for(var old in _root.gm3Nodes) {
        if(!seen[old]) {
            var gone = _root.gm3Nodes[old];
            gone.swapDepths(65000); gone.removeMovieClip(); delete _root.gm3Nodes[old];
        }
    }
    // Original scripts sometimes remove a timeline child (e.g. the mystery box).
    // Hide such unscripted defaults on the guest even if they were never replicated.
    for(var parentPath in _root.gm3Nodes) {
        var container = _root.gm3Nodes[parentPath];
        var depths = _root.gm3Depths["s" + container.gm3Symbol];
        for(var di=0;di<depths.length;di++) {
            var child=container.getInstanceAtDepth(depths[di]);
            if(child!=container && child._parent==container && !seen[parentPath+"/d"+depths[di]]) child._visible=false;
        }
    }
    _root.gm3Pin(_root.gm3Panel);_root.gm3Pin(_root.gm3MatchButton);
    _root.gm3Pin(_root.gm3AudioHUD);
    _root.gm3Applied = _root.gm3Last;
    _root.gm3Send("sceneApplied",_root.gm3Last);
    if(_root.gm3Last % 40 == 0) {
        var diag=[];
        for(var d=1;d<=4;d++) {var who=_root["player"+d];diag.push({slot:d,x:who._x,y:who._y});}
        _root.gm3Send("diagnostics",{applied:_root.gm3Last,players:diag,rootX:_root._x,rootY:_root._y});
    }
}
_root.gm3In.scene = function(seq, part, total, data) {
    if(_root.gm3ShuttingDown)return;
    if(seq < _root.gm3Last || total > 20 || total < 1 || part >= total) return;
    if(seq != _root.gm3Last) { _root.gm3Last = seq; _root.gm3Pieces = []; _root.gm3Received = 0; }
    if(_root.gm3Pieces[part] == undefined) _root.gm3Received++;
    _root.gm3Pieces[part] = data;
    if(_root.gm3Received == total) _root.gm3Apply(_root.gm3Pieces.join(""));
};
_root.gm3In.connect("_gm3_game_" + _root.gm3Token);
_root.gm3Ticker = _root.createEmptyMovieClip("gm3Ticker",60000);
_root.gm3Ticker.count = 0;
_root.gm3Ticker.onEnterFrame = function() {
    this.count++;
    _root.gm3MusicTick();
    if(this.count % 35 == 1) {
        _root.gm3Send("ready","guest");
        _root.gm3Send("diagnostics",{last:_root.gm3Last,begin:_root.gm3ApplyStart,applied:_root.gm3Applied,parts:_root.gm3Received,battleMusicPlaying:!!_root.gm3BattlePlaying,menuMusicPlaying:_root.gm3MusicPlaying=="main",setupMusicPlaying:_root.gm3MusicPlaying=="setup",screen:_root.gm3Panel?_root.gm3OnlineModel.screen:"game",page:_root.gm3RoomPage,panelX:_root._x+_root.gm3Panel._x*_root._xscale/100,panelY:_root._y+_root.gm3Panel._y*_root._yscale/100});
    }
};
