_root.gm3Online = false;
_root.gm3StopMusic = _root.stopallmusic;
_root.stopallmusic = function() { _root.gm3StopMusic();_root.gm3BattlePlaying=false; };
_root.gm3Active = false;
// Guard original battle tracks at the point they start. A menu return can
// otherwise re-enter frame 10's battle branch during the original wipe.
for(var trackNumber=2;trackNumber<=4;trackNumber++){
    var originalTrack=_root["music"+trackNumber];
    _root["music"+trackNumber]={sound:originalTrack,start:function(offset,loops){
        if(_root.gotomenu || _root.gm3Panel || _root.gm3ShuttingDown)return;
        this.sound.start(offset,loops);_root.gm3BattlePlaying=true;
        _root.gm3Send("audioEvent",{event:"battleStart"});
    },stop:function(){this.sound.stop();}};
}
_root.gm3SnapshotPending = false;
_root.gm3Previous = {};
_root.gm3Masks = [0,0,0,0];
if(_global.gm3OriginalKey == undefined) _global.gm3OriginalKey = Key.isDown;
_root.gm3NativeKey = _global.gm3OriginalKey;
function gm3KeyDown(key) {
    if (!_root.gm3Online) return _root.gm3NativeKey(key);
    if (key < 200 || key >= 224) return false;
    var slot = Math.floor((key - 200) / 6);
    var bit = (key - 200) % 6;
    return (_root.gm3Masks[slot] & (1 << bit)) != 0;
};
_root.gm3Sounds = [];
_root.gm3OriginalSound = _root.playsound;
_root.gm3OriginalSound2 = _root.playsound2;
_root.playsound = function(s) {
    if(_root.gm3ShuttingDown || _root.gm3Transitioning || (_root.gm3Panel && s!="btn.wav"))return;
    _root.gm3OriginalSound(s);
    _root.gm3TrackEffect(_root.qwersound,"original"+_root.soundnumber);
    if(_root.gm3Active && _root.gm3Sounds.length < 32) _root.gm3Sounds.push("!|"+escape(s)+"|50");
}
ASSetPropFlags(Key,"isDown",0,7);
Key.isDown = _root.gm3KeyDown;
// Loaded AVM1 content uses the outer AIR stage for point hit-tests. Restore the
// original SWF's root-coordinate contract without changing collision shapes.
if(MovieClip.prototype.gm3OriginalHitTest == undefined) MovieClip.prototype.gm3OriginalHitTest = MovieClip.prototype.hitTest;
ASSetPropFlags(MovieClip.prototype,"gm3OriginalHitTest",1);
ASSetPropFlags(MovieClip.prototype,"hitTest",0,7);
MovieClip.prototype.hitTest = function(x,y,shape) {
    if(arguments.length == 1) return this.gm3OriginalHitTest(x);
    var point = {x:x,y:y};
    _root.localToGlobal(point);
    return this.gm3OriginalHitTest(point.x,point.y,shape);
};
_root.playsound2 = function(s) {
    if(_root.gm3ShuttingDown)return;
    if(s=="whoosh.wav"){_root.gm3Whoosh();return;}
    if(_root.gm3Transitioning || _root.gm3Panel)return;
    _root.gm3OriginalSound2(s);
    _root.gm3TrackEffect(_root.qwersound,"original"+_root.soundnumber);
    if(_root.gm3Active && _root.gm3Sounds.length < 32) _root.gm3Sounds.push("!|"+escape(s)+"|100");
};
_root.gm3In = new LocalConnection();
_root.gm3In.allowDomain = function(domain) { return true; };
_root.gm3In.allowInsecureDomain = function(domain) { return true; };
_root.gm3In.command = function(command, data) {
    if(command == "audioToggle") {
        _root.gm3ToggleAudio(data.kind);
    } else if(command == "updateStatus") {
        if(_root.gm3Main){_root.gm3Main.gm3Heading.text="CHECK FOR UPDATES";_root.gm3Main.gm3Description.text=data.message;}
    } else if(command == "shutdown") {
        _root.gm3Shutdown();
    } else if(command == "matchControls") {
        _root.gm3MatchControls(data);
    } else if(command == "openOnline") {
        _root.gm3OpenOnline(data.screen);
    } else if(command == "onlineUI") {
        _root.gm3ShowOnline(data);
    } else if(command == "hideOnline") {
        _root.gm3StopScreenSounds();_root.gm3Panel.removeMovieClip();
        _root.gm3MatchButton._visible=true;
        if(_root.gm3Active && _root.savedata2.data.musicON)_root.music4.start(0,999);
    } else if(command == "onlineBack") {
        _root.gm3StopScreenSounds();_root.gm3Setup=0;_root.gm3Active=false;
        delete _root.gm3NextModel;delete _root.gm3NextOnline;
        _root.gm3ReturningMenu=true;_root.gm3Panel.removeMovieClip();_root.gm3MatchButton.removeMovieClip();_root.gm3Online=false;_root.gotomenu=true;
        if(_root.fadeaway){
            if(_root.fadeaway._currentframe>=8)_root.gm3ReturnAfterFade=true;
            else _root.fadeaway.targetframe=10;
            return;
        }
        var fade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);fade.targetframe=10;
    } else if(command == "inputs") {
        _root.gm3Masks = data.masks;
        if(data.ack >= _root.gm3SnapshotSeq) _root.gm3SnapshotPending = false;
    } else if (command == "input") {
        _root.gm3Masks[Number(data.slot)] = Number(data.mask) & 63;
    } else if (command == "classic") {
        _root.gm3StopScreenSounds();
        _root.gm3Online = false;
        _root.gm3Active = false;
        _root.gamepaused = false;
        _root.gotomenu = true;
        _root.gm3Setup=0;_root.gm3ReturningMenu=true;
        delete _root.gm3NextModel;delete _root.gm3NextOnline;
        if(_root.menup) { _root.menup.swapDepths(49000); delete _root.menup.onEnterFrame; _root.menup.removeMovieClip(); }
        _root.gotoAndStop(10);
    } else if (command == "start") {
        _root.gm3StopScreenSounds();
        _root.gm3Config = data;
        _root.gm3Online = true;
        _root.gm3Active = false;
        _root.gm3Masks = [0,0,0,0];
        _root.gm3SnapshotPending = false;
        _root.gm3Previous = {};
        _root.gm3Setup = 3;
        _root.gotomenu = false;
        _root.gototest = false;
        _root.gotochallenge = false;
        _root.gotocampaign = false;
        _root.gamepaused = false;
        _root.gamewin = false;
        _root.teamgamewin = false;
        _root.mapnumber = data.arena;
        _root.gamemode = data.mode;
        _root.totallives = data.stocks;
        _root.toggle_crates = data.variant != 1 && data.crates!=false;
        _root.toggle_powerups = data.pickups!=false;
        var n = 1;
        while(n <= 4) {
            _root["p"+n+"ptype"] = data.players[n-1] != null ? 1 : (data.bots ? 2 : 0);
            _root["p"+n+"name"] = data.players[n-1] != null ? data.players[n-1] : "Bot " + n;
            var profile=data.loadouts[n-1];
            if(!profile)profile=_root.gm3DefaultProfile(n-1);
            _root["p"+n+"color"] = profile.color;
            _root["p"+n+"shirt"] = profile.shirt;
            _root["p"+n+"hat"] = profile.hat;
            _root["p"+n+"eyes"] = profile.eyes;
            _root["p"+n+"gun"] = data.variant == 1 ? 16 : profile.gun;
            _root["p"+n+"perk"] = profile.perk;
            _root["p"+n+"team"] = profile.team;
            n++;
        }
        _root.gotoAndStop(9);
    } else if(command == "lobby") {
        _root.gm3StopScreenSounds();
        _root.gm3MatchButton.removeMovieClip();
        _root.gm3Active = false;
        _root.gm3Masks = [0,0,0,0];
        _root.gamepaused = true;
    } else if(command == "mute") {
        var allsound = new Sound(); allsound.setVolume(data ? 0 : 100);
    } else if(command == "testInterface") {
        _root.gm3UIAction(data.action);
    } else if(command == "testMain") {
        _root.gm3MainAction(data.action);
    } else if(command == "testFreeze") {
        _root.gamepaused = true;
        _root.gm3MatchButton.removeMovieClip();
    } else if(command == "testTransition") {
        if(!_root.fadeaway){
            if(data.frame==10)_root.gotomenu=true;
            var testFade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);
            testFade.targetframe=data.frame;
        }
    }
};
_root.gm3In.connect("_gm3_game_" + _root.gm3Token);

function gm3Capture(parent, prefix, rows, level) {
    if(level > 12 || rows.length > 1800) return;
    var children = [];
    var known = {};
    var depths = _root.gm3Depths["s" + (parent == _root ? 0 : parent.gm3Symbol)];
    for(var di=0;di<depths.length;di++) {
        var child = parent.getInstanceAtDepth(depths[di]);
        if(child != undefined && child != parent && child._parent == parent && child.getDepth() == depths[di]) {children.push(child);known[depths[di]]=true;}
    }
    for(var key in parent) {
        child=parent[key];
        if((typeof(child)=="movieclip" || child instanceof TextField) && child._parent == parent && !known[child.getDepth()]) {
            children.push(child);known[child.getDepth()]=true;
        }
    }
    for(var ci=0;ci<children.length;ci++) {
        var mc=children[ci];var k=mc._name;
        if(k==undefined || k.indexOf("gm3")==0) continue;
        var path=prefix==""?"d"+mc.getDepth():prefix+"/d"+mc.getDepth();
        if(mc instanceof TextField) {
            rows.push([path,-1,mc.getDepth(),escape(mc.text),mc._visible?1:0,mc._x,mc._y,mc._width,mc._height,mc.textColor].join("|"));
        } else if(typeof(mc)=="movieclip") {
            if(mc.gm3Symbol==undefined && mc._width==0 && mc._height==0)continue;
            var ct=new Color(mc).getTransform();
            var matrix=new flash.geom.Transform(mc).matrix;
            rows.push([path,mc.gm3Symbol==undefined?0:mc.gm3Symbol,mc.getDepth(),mc._currentframe,gm3Round(mc._x),gm3Round(mc._y),gm3Round(mc._xscale),gm3Round(mc._yscale),gm3Round(mc._rotation),gm3Round(mc._alpha),mc._visible?1:0,ct.ra,ct.ga,ct.ba,ct.aa,ct.rb,ct.gb,ct.bb,ct.ab,"",escape(k),matrix.a,matrix.b,matrix.c,matrix.d,matrix.tx,matrix.ty].join("|"));
            if(mc._visible && mc._alpha > 0) gm3Capture(mc,path,rows,level+1);
        }
    }
}
_root.gm3Ticker = _root.createEmptyMovieClip("gm3Ticker",60000);
_root.gm3Ticker.count = 0;
_root.gm3Ticker.onEnterFrame = function() {
    this.count++;
    if(_root.gm3PrepareCharacter>0 && --_root.gm3PrepareCharacter==0)_root.gm3PrepareCharacterMenu();
    _root.gm3MusicTick();
    if(this.count % 35 == 1) {
        _root.gm3Send("ready", "host");
        _root.gm3Send("diagnostics",{menuMusicLoaded:_root.gm3TrackLoaded.main,menuMusicPlaying:_root.gm3MusicPlaying=="main",setupMusicPlaying:_root.gm3MusicPlaying=="setup",battleMusicPlaying:_root.gm3BattlePlaying==true,musicPosition:_root.gm3Tracks[_root.gm3MusicPlaying].position,musicDuration:_root.gm3Tracks.main.duration,rootFrame:_root._currentframe,introFrame:_root.intro._currentframe,screen:_root.gm3Panel?_root.gm3OnlineModel.screen:"original",page:_root.gm3RoomPage,panelX:_root._x+_root.gm3Panel._x,panelY:_root._y+_root.gm3Panel._y,pendingWhoosh:_root.gm3TransitionSounds});
        if(_root.gm3Active) {
            var diag = [];
            for(var d=1;d<=4;d++) { var who=_root["player"+d]; if(who)diag.push({slot:d,x:who._x,y:who._y,lives:who.lives,gun:who.wepnumber}); }
            var tests=[];
            for(var ty=0;ty<900;ty+=25) if(_root.ground.platform.hitTest(450,ty,true))tests.push(ty);
            _root.gm3Send("diagnostics",{frame:_root._currentframe,players:diag,gravity:_root.gravity,rootX:_root._x,rootY:_root._y,bounds:_root.ground.platform.getBounds(_root),hits:tests,masks:_root.gm3Masks,nativeUnchanged:Key.isDown==_root.gm3NativeKey,virtualKey:Key.isDown(206),directKey:_root.gm3KeyDown(206),playerKey:_root.player2.KEYUP});
        }
    }
    if(_root.gm3Setup > 0) {
        _root.gm3Setup--;
        if(_root.gm3Setup == 2) {
            if(_root.menup) { _root.menup.swapDepths(49000); delete _root.menup.onEnterFrame; _root.menup.removeMovieClip(); }
            _root.gotoAndStop(10);
        }
        if(_root.gm3Setup == 0) {
            for(var pn=1;pn<=4;pn++) {
                var human = _root["player"+pn];
                human.KEYUP = 200+(pn-1)*6;human.KEYLEFT=human.KEYUP+1;human.KEYDOWN=human.KEYUP+2;
                human.KEYRIGHT=human.KEYUP+3;human.KEYSHOOT=human.KEYUP+4;human.KEYNADE=human.KEYUP+5;
            }
            _root.stopallmusic();
            if(_root.savedata2.data.musicON) _root.music4.start(0,999);
            _root.gm3Active = true;
            _root.gm3EndSent = false;
            _root.endgamefunction = function() {
                if(!_root.gm3EndSent) {
                    _root.gm3EndSent = true;
                    _root.gm3Active = false;
                    _root.gamepaused = true;
                    var winner = "Round over";
                    if(_root.activeplayers.length == 1) winner = _root.activeplayers[0].displayname + " wins!";
                    if(_root.teamgamewin) winner = "Team " + _root.teamwin + " wins!";
                    _root.gm3Send("finished",winner);
                }
            };
        }
    }
    if(!_root.gm3Active) return;
    if(_root.gm3Config.variant == 2 && _root.cratetime < 280) _root.cratetime = 280;
    if(this.count % 2 == 0 && !_root.gm3SnapshotPending) {
        var rows = [["@",gm3Round(_root._x),gm3Round(_root._y),gm3Round(_root._xscale),gm3Round(_root._yscale)].join("|")];
        _root.gm3Capture(_root,"",rows,0);
        var current = {};
        var delta = [];
        for(var rowIndex=0;rowIndex<rows.length;rowIndex++) {
            var row = rows[rowIndex];
            var rowKey = row.substr(0,row.indexOf("|"));
            current[rowKey] = row;
            if(rowKey == "@" || _root.gm3Previous[rowKey] != row) delta.push(row);
        }
        for(var removed in _root.gm3Previous) if(current[removed] == undefined) delta.push("-|"+removed);
        _root.gm3Previous = current;
        rows = delta.concat(_root.gm3Sounds);
        _root.gm3Sounds = [];
        var scene = rows.join("\n");
        if(scene.length > 250000) { _root.gm3Send("diagnostics",{oversize:scene.length,nodes:rows.length}); return; }
        _root.gm3SnapshotPending = true;
        _root.gm3SnapshotSeq = this.count;
        var total = Math.ceil(scene.length / 32000);
        for(var part = 0; part < total; part++) {
            _root.gm3Out.send("_gm3_air_" + _root.gm3Token,"snapshot",this.count,part,total,scene.substr(part*32000,32000));
        }
    }
};
// Preserve the original Armor Games animation + sound on the first launch.
// Match reloads and returning to the menu explicitly skip both together.
if(_root.gm3SkipIntro == "1") {
    _root.intro.stop();
    stopAllSounds();
    _root.gotoAndStop(9);
}
