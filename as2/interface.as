// Vector-only Flash UI. The original fight continues behind the main menu.
_root.gm3Modes=[1,3,5,2,4,10,11];
_root.gm3ModeNames=["Last Man Standing","Last Team Standing","Survival","1 Hit 1 Kill","Gun Game","Gun Game Reversed","Jetpacks"];
_root.gm3ModeDescriptions=["Free for all. Knock your opponents off the arena. The last player with lives remaining wins.","Fight in two teams. Choose your team on the Players screen. The last team standing wins.","Survive the original waves of enemies together.","Every hit is lethal. Make your shots count.","Work through the original weapon progression with each elimination.","The original Gun Game weapon progression, in reverse.","Take the fight into the air with the original jetpack rules."];
_root.gm3GunNames=["Cool Pistol","Sand Hawk","Glick","Angry Cow","Fifty Eight","Snake","Gold Pistol"];
_root.gm3PerkNames=["None","Lightweight","Triple jump","Minigun crates","No recoil","Blast resist","More ammo","Extra bombs","Random gun","Duck bombs","No reload","Shotgun crates","Explosive body"];
function gm3Text(parent,value,x,y,width,size,color,font,outline) {
    var name="gm3Text"+parent.getNextHighestDepth();
    parent.createTextField(name,parent.getNextHighestDepth(),x,y,width,size*1.55);
    var t=parent[name];var f=new TextFormat(font==undefined?"Century Gothic":font,size,color);
    t.embedFonts=true;t.selectable=false;t.text=value;t.setTextFormat(f);t.setNewTextFormat(f);
    if(outline)t.filters=[new flash.filters.GlowFilter(0x080b10,1,3,3,8,2),new flash.filters.DropShadowFilter(3,90,0,0.8,1,1,1,2)];
    return t;
}
function gm3Rect(parent,x,y,w,h,color,alpha,border) {
    var c=parent.createEmptyMovieClip("gm3Box"+parent.getNextHighestDepth(),parent.getNextHighestDepth());c._x=x;c._y=y;
    if(border!=undefined)c.lineStyle(2,border,100);
    c.beginFill(color,alpha==undefined?100:alpha);c.moveTo(0,0);c.lineTo(w,0);c.lineTo(w,h);c.lineTo(0,h);c.lineTo(0,0);c.endFill();return c;
}
function gm3Box(parent,x,y,w,h,color) {
    var c=_root.gm3Rect(parent,x,y,w,h,color,100,0x0a0e12);
    c.filters=[new flash.filters.DropShadowFilter(4,90,0,0.6,2,2,1,2)];return c;
}
function gm3Button(parent,label,x,y,w,color,action,enabled,h,size) {
    if(h==undefined)h=38;if(size==undefined)size=22;
    var b=_root.gm3Box(parent,x,y,w,h,color);b.gm3Action=action;
    _root.gm3Rect(b,2,2,w-4,2,0xffffff,22);
    var t=_root.gm3Text(b,label,5,(h-size*1.15)/2-1,w-10,size,0xffffff,"Kozuka Gothic Pro B",true);
    var f=t.getTextFormat();f.align="center";t.setTextFormat(f);
    if(enabled==false){b._alpha=48;return b;}
    b.onRollOver=function(){this._alpha=80;};b.onRollOut=function(){this._alpha=100;};
    b.onRelease=function(){if(!_root.fadeaway){_root.playsound("btn.wav");_root.gm3UIAction(this.gm3Action);}};
    return b;
}
function gm3Input(parent,value,x,y,w,max) {
    _root.gm3Box(parent,x,y,w,39,0xffffff);
    var t=_root.gm3Text(parent,value,x+8,y+2,w-16,23,0,"Century Gothic",false);
    t.type="input";t.selectable=true;t.maxChars=max;t._height=36;return t;
}
function gm3DecorateMenu(menu) {
    // Hide the whole old display list, including static text, links and badge.
    menu._visible=false;delete menu.onEnterFrame;
    if(_root.gm3Main)_root.gm3Main.removeMovieClip();
    var p=_root.createEmptyMovieClip("gm3Main",10101);_root.gm3Pin(p);
    var header=_root.gm3Rect(p,28,27,500,124,0x111922,82,0x080b10);
    _root.gm3Rect(header,0,0,7,124,0xffa32b);
    _root.gm3Text(header,"GUN MAYHEM",19,4,413,57,0xffffff,"Tw Cen MT Condensed Extra Bold",true);
    _root.gm3Text(header,"3",413,-2,70,92,0xffa32b,"Tw Cen MT Condensed Extra Bold",true);
    _root.gm3Rect(header,23,78,169,31,0x168cac,100,0x05080b);
    _root.gm3Text(header,"O N L I N E",33,76,159,25,0xffffff,"Tw Cen MT Condensed Extra Bold",true);
    _root.gm3Text(header,"BIG GUNS. BIGGER MAYHEM.",209,86,275,12,0xe5e9ee);
    var panel=_root.gm3Rect(p,579,27,293,544,0x111922,94,0x080b10);
    _root.gm3Rect(panel,0,0,293,5,0xffa32b);
    _root.gm3Text(panel,"PICK YOUR FIGHT",17,14,260,18,0xffb84f,"Kozuka Gothic Pro B");
    _root.gm3MainItem(panel,"CAMPAIGN",17,52,259,43,"campaign","Campaign","Take on the original missions. Bring a friend for local co-op.");
    _root.gm3MainItem(panel,"CUSTOM GAME",17,104,259,43,"custom","Custom game","Build a local match with the original maps, modes and player setup.");
    _root.gm3MainItem(panel,"CHALLENGES",17,156,259,43,"challenges","Challenges","Test your aim and movement in the original challenges.");
    _root.gm3MainItem(panel,"WEAPON LIBRARY",17,208,259,43,"library","Weapon library","Browse the original arsenal and try out your favorites.");
    _root.gm3Rect(panel,17,270,259,1,0xffffff,20);
    _root.gm3Text(panel,"PLAY ONLINE",17,283,259,16,0x65d5f4,"Kozuka Gothic Pro B");
    _root.gm3MainItem(panel,"HOST",17,319,122,49,"host","Host online","Create a private room, set the rules, and invite up to three friends.",0x147f9d);
    _root.gm3MainItem(panel,"JOIN",154,319,122,49,"join","Join online","Enter a friend's room code and choose the same region.",0x147f9d);
    _root.gm3Rect(panel,17,391,259,1,0xffffff,20);
    _root.gm3MainItem(panel,"OPTIONS",17,413,122,39,"options","Options","Change controls, music, sound and graphics quality.");
    _root.gm3MainItem(panel,"CREDITS",154,413,122,39,"credits","Credits","The original creators and the Gun Mayhem 3 Online project.");
    _root.gm3Text(panel,"F11  FULLSCREEN     M  MUTE",20,485,260,12,0xaab5c1);
    _root.gm3Text(panel,"Gun Mayhem 3 Online",20,509,260,11,0x708191);
    var info=_root.gm3Rect(p,28,478,500,93,0x111922,88,0x080b10);
    _root.gm3Rect(info,0,0,7,93,0x168cac);
    p.gm3Heading=_root.gm3Text(info,"LET THE MAYHEM BEGIN",18,8,464,25,0xffb84f,"Tw Cen MT Condensed Extra Bold",true);
    p.gm3Description=_root.gm3Text(info,"Choose a mode on the right.",18,43,461,15,0xe4eaf0);
    _root.gm3MainItem(p,"CHARACTER CUSTOMIZATION",28,166,292,37,"character","Character customization","Choose outfits, faces, colors, weapons and perks using the original editor.");
    _root.gm3MainItem(p,"CHECK FOR UPDATES",333,166,195,37,"updates","Check for updates","Check the latest Gun Mayhem 3 Online release on GitHub.");
    p.gm3Description.wordWrap=true;p.gm3Description.multiline=true;p.gm3Description._height=45;
    p.onEnterFrame=function(){
        if(_root._currentframe!=10 || !_root.gotomenu)this.removeMovieClip();
    };
}
function gm3MainItem(parent,label,x,y,w,h,action,heading,description,color) {
    var b=_root.gm3Box(parent,x,y,w,h,color==undefined?0x303e4b:color);
    b.gm3Action=action;b.gm3Heading=heading;b.gm3Description=description;
    b.gm3Accent=_root.gm3Rect(b,0,0,4,h,0xffa32b);b.gm3Accent._alpha=0;
    _root.gm3Rect(b,5,2,w-8,1,0xffffff,18);
    _root.gm3Text(b,label,12,4,w-23,h<45?25:30,0xffffff,"Tw Cen MT Condensed Extra Bold",true);
    b.onRollOver=function(){this.gm3Accent._alpha=100;this._alpha=90;_root.gm3Main.gm3Heading.text=this.gm3Heading.toUpperCase();_root.gm3Main.gm3Description.text=this.gm3Description;};
    b.onRollOut=function(){this.gm3Accent._alpha=0;this._alpha=100;};
    b.onRelease=function(){if(_root.fadeaway)return;_root.playsound("btn.wav");_root.gm3MainAction(this.gm3Action);};
}
function gm3MainAction(action) {
    if(action=="updates"){_root.gm3Send("onlineAction",{action:"updates"});return;}
    _root.gm3CustomizeOnly=action=="character";
    if(action=="host" || action=="join"){_root.gm3RoomPage="rules";_root.gm3OpenOnline(action);return;}
    var targets={campaign:4,custom:9,character:9,challenges:3,library:8,options:5,credits:7};
    var fade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);fade.targetframe=targets[action];
}
function gm3DecorateCredits(menu) {
    _root.gm3Box(menu,48,473,514,75,0x666666);
    _root.gm3Text(menu,"Gun Mayhem 3 Online",65,480,477,18,0xffffff);
    _root.gm3Text(menu,"IntelGenV2",63,503,480,29,0xffffff,"Kozuka Gothic Pro B",true);
}
function gm3DefaultProfile(slot) {
    return {color:[15,4,18,9][slot],shirt:[3,4,5,15][slot],hat:[4,9,5,44][slot],eyes:[1,1,2,11][slot],gun:[2,4,1,3][slot],perk:1,team:slot%2+1};
}
function gm3UIAction(action) {
    if(action=="characterSave"){_root.gm3SaveCharacterMenu();return;}
    var m=_root.gm3OnlineModel;
    if(_root.gm3NameField)m.name=_root.gm3NameField.text;
    if(_root.gm3CodeField)m.code=_root.gm3CodeField.text;
    var parts=action.split(":");
    if(action=="region"){
        var i=0;while(_root.gm3Regions[i]!=m.region && i<_root.gm3Regions.length)i++;
        m.region=_root.gm3Regions[(i+1)%_root.gm3Regions.length];_root.gm3RenderOnline(m);return;
    }
    if(parts[0]=="page"){
        _root.gm3StopEffects();_root.gm3RoomPage=parts[1];_root.gm3RenderOnline(m);return;
    }
    if(parts[0]=="setting" && m.slot==0 && !m.playing){
        var key=parts[1];var value=parts[2];
        if(key=="stocks")m.settings.stocks=Math.max(1,Math.min(20,m.settings.stocks+Number(value)));
        else if(key=="variant")m.settings.variant=(m.settings.variant+1)%3;
        else if(key=="bots" || key=="crates" || key=="pickups")m.settings[key]=!m.settings[key];
        else m.settings[key]=Number(value);
        _root.gm3Send("onlineAction",{action:"settings",settings:m.settings});return;
    }
    if(parts[0]=="profile" && !m.playing){
        var profile=m.players[m.slot].profile;
        var max={color:20,shirt:27,hat:48,eyes:12,gun:7,perk:13,team:2};var field=parts[1];
        profile[field]=(profile[field]-1+Number(parts[2])+max[field])%max[field]+1;
        _root.gm3SaveLocalProfile(profile);
        _root.gm3Send("onlineAction",{action:"profile",profile:profile});return;
    }
    _root.gm3Send("onlineAction",{action:action,screen:m.screen,name:m.name,region:m.region,code:m.code,profile:_root.gm3ReadLocalProfile()});
}
function gm3Avatar(parent,profile,x,y) {
    var a=parent.attachMovie("gm3_symbol_1277","gm3Avatar"+parent.getNextHighestDepth(),parent.getNextHighestDepth());a._x=x;a._y=y;a._xscale=a._yscale=78;a.stop();a.gm3Profile=profile;a.gm3ApplyCount=0;
    a.onEnterFrame=function(){
        var v=this.gm3Profile;
        this.head.gotoAndStop(v.color);this.body.gotoAndStop(v.color);this.leg1.leg.gotoAndStop(v.color);this.leg2.leg.gotoAndStop(v.color);this.hand2.hand.gotoAndStop(v.color);this.gundisplayhand.gotoAndStop(v.color);
        this.shirt.gotoAndStop(v.shirt);this.hat.gotoAndStop(v.hat);this.eyes.gotoAndStop(v.eyes);this.gundisplay.gotoAndStop(v.gun);
        if(this.hat.getDepth()<this.eyes.getDepth())this.hat.swapDepths(this.eyes);
        this.frame._visible=false;
        // Nested timeline frame-one scripts settle after attachMovie.
        if(++this.gm3ApplyCount>=3){
            _root.gm3Send("diagnostics",{preview:{gun:this.gundisplay._currentframe,shirt:this.shirt._currentframe,hat:this.hat._currentframe,wanted:v}});
            delete this.onEnterFrame;
        }
    };
    return a;
}
function gm3MatchControls(data) {
    var p=_root.createEmptyMovieClip("gm3MatchButton",10160);_root.gm3Pin(p);
    _root.gm3Button(p,"ROOM  [ESC]",750,10,140,0x303e4b,"room",true,28,15);
}
