// Online screens reuse the original menu artwork and 900x600 proportions.
function gm3Skin(parent,id,x,y,w,h) {
    var art=parent.attachMovie("gm3_symbol_"+id,"gm3Skin"+parent.getNextHighestDepth(),parent.getNextHighestDepth());art.gotoAndStop(1);
    var r=art.getBounds(art);var aw=r.xMax-r.xMin;var ah=r.yMax-r.yMin;
    if(w==undefined)w=aw;if(h==undefined)h=ah;
    art._xscale=100*w/aw;art._yscale=100*h/ah;art._x=x-r.xMin*w/aw;art._y=y-r.yMin*h/ah;art.enabled=false;
    return art;
}
function gm3ClassicButton(p,label,x,y,w,h,action,enabled,style,selected,size) {
    var b=p.createEmptyMovieClip("gm3ClassicButton"+p.getNextHighestDepth(),p.getNextHighestDepth());b._x=x;b._y=y;
    var id=style=="next"?60000:style=="back"?60001:1508;
    b.art=_root.gm3Skin(b,id,0,0,w,h);b.gm3Selected=selected;
    b.onEnterFrame=function(){this.art.stop();this.art.chosen._alpha=this.gm3Selected?100:0;delete this.onEnterFrame;};
    var strong=style=="next" || style=="back";
    var t=_root.gm3Text(b,label,5,Math.max(0,(h-(size==undefined?23:size)*1.35)/2),w-10,size==undefined?23:size,strong?0xffffff:0,strong?"Kozuka Gothic Pro B":"Century Gothic",strong);
    var f=t.getTextFormat();f.align="center";t.setTextFormat(f);
    b.gm3Action=action;
    if(enabled==false){b._alpha=65;return b;}
    b.onRollOver=function(){this._alpha=85;};b.onRollOut=function(){this._alpha=100;};
    b.onRelease=function(){if(!_root.fadeaway){_root.playsound("btn.wav");_root.gm3UIAction(this.gm3Action);}};
    return b;
}
function gm3ClassicHeader(p,title) {
    _root.gm3Skin(p,1068,49,25);
    _root.gm3Text(p,title,42,7,554,39,0xffffff,"Kozuka Gothic Pro B",true);
}
function gm3ClassicBadge(p,title,x,y,w) {
    _root.gm3Skin(p,1516,x,y,w,46);
    var t=_root.gm3Text(p,title,x+4,y+2,w-8,28,0xffffff,"Kozuka Gothic Pro B",true);var f=t.getTextFormat();f.align="center";t.setTextFormat(f);
}
function gm3ClassicInput(p,value,x,y,w,max) {
    _root.gm3Rect(p,x,y,w,35,0xffffff,100,0);
    var t=_root.gm3Text(p,value,x+7,y+2,w-14,23,0);t.type="input";t.selectable=true;t.maxChars=max;t._height=33;return t;
}
function gm3RenderOnline(model) {
    _root.gm3MatchButton._visible=false;
    if(_root.gm3OnlineModel.screen!="lobby" && model.screen=="lobby")_root.gm3RoomPage="rules";
    _root.gm3OnlineModel=model;
    if(_root.gm3Panel)_root.gm3Panel.removeMovieClip();
    if(!_root.gm3Active && !_root.gm3Nodes){delete _root.onEnterFrame;_root._x=0;_root._y=0;_root._xscale=100;_root._yscale=100;}
    var p=_root.createEmptyMovieClip("gm3Panel",10150);_root.gm3Pin(p);
    _root.gm3Rect(p,0,0,900,600,0x333333);_root.gm3NameField=undefined;_root.gm3CodeField=undefined;
    if(model.screen=="lobby"){_root.gm3Room(p,model);return;}
    var host=model.screen=="host";var form=host || model.screen=="join";
    _root.gm3ClassicHeader(p,form?(host?"Host Online":"Join Online"):"Connecting");
    if(form){
        _root.gm3Skin(p,1485,71,113);_root.gm3ClassicBadge(p,"Player",133,91,174);
        _root.gm3Text(p,"Name",89,163,270,24,0);_root.gm3NameField=_root.gm3ClassicInput(p,model.name,90,204,264,18);
        _root.gm3Text(p,"Region",89,259,270,24,0);_root.gm3ClassicButton(p,String(model.region).toUpperCase()+"   >",90,302,264,37,"region",true);
        if(!host){_root.gm3Text(p,"Room code",89,362,270,24,0);_root.gm3CodeField=_root.gm3ClassicInput(p,model.code==undefined?"":model.code,90,405,264,6);_root.gm3CodeField.restrict="A-Za-z0-9";}
        else _root.gm3Text(p,"Up to 4 players",88,397,280,21,0);
        _root.gm3Skin(p,649,434,128);_root.gm3ClassicBadge(p,host?"Host a room":"Join a room",458,91,256);
        var help=_root.gm3Text(p,host?"Choose the rules, map and players. Share the room code and region with your friends.":"Enter the room code and choose the same region as your host. Customize your player, then press Ready.",459,163,360,22,0);help.wordWrap=true;help._height=174;
        var preview=_root.gm3Avatar(p,_root.gm3ReadLocalProfile(),650,475);preview._xscale=preview._yscale=115;
        _root.gm3ClassicButton(p,"BACK TO MENU",40,535,273,50,"back",true,"back");
        _root.gm3ClassicButton(p,host?"CREATE ROOM":"JOIN ROOM",555,530,329,60,host?"create":"join",true,"next");
    }else{
        _root.gm3Skin(p,649,237,190);
        _root.gm3ClassicBadge(p,"Please wait",292,153,256);
        _root.gm3Text(p,"Connecting to Photon...",265,245,375,24,0);
        _root.gm3Text(p,"Region: "+String(model.region).toUpperCase(),267,309,375,23,0);
        _root.gm3ClassicButton(p,"CANCEL",40,535,273,50,"back",true,"back");
    }
    _root.gm3Notice(p,model.notice);
}
function gm3Notice(p,value) {
    var width=_root.gm3OnlineModel.screen=="lobby"&&_root.gm3RoomPage=="players"?390:810;
    var t=_root.gm3Text(p,value==undefined?"":value,44,493,width,16,0xffdb85);t.wordWrap=true;t._height=34;
}
function gm3Room(p,m) {
    var page=_root.gm3RoomPage;
    _root.gm3ClassicHeader(p,page=="rules"?"Game Setup":page=="map"?"Map Selection":"Player Setup");
    _root.gm3ClassicButton(p,String(m.region).toUpperCase()+" / "+m.code+"  (copy)",604,33,237,28,"copy",true,null,false,16);
    if(page=="rules")_root.gm3Rules(p,m);else if(page=="map")_root.gm3Map(p,m);else _root.gm3Players(p,m);
    _root.gm3Notice(p,m.notice);
    var back=page=="rules"||m.playing?"back":"page:"+(page=="map"?"rules":"map");
    _root.gm3ClassicButton(p,page=="rules"||m.playing?"LEAVE ROOM":"BACK",40,535,273,50,back,true,"back");
    if(m.playing){
        if(m.slot==0)_root.gm3ClassicButton(p,"End round",333,545,196,37,"endRound",true,null,false,20);
        _root.gm3ClassicButton(p,"RESUME",555,530,329,60,"resume",true,"next");
    }else if(page!="players"){
        _root.gm3ClassicButton(p,"CONTINUE",555,530,329,60,"page:"+(page=="rules"?"map":"players"),true,"next");
    }else{
        var allReady=true;for(var i=0;i<4;i++)if(m.players[i]&&!m.players[i].ready)allReady=false;
        _root.gm3ClassicButton(p,m.slot==0?"START!":m.players[m.slot].ready?"NOT READY":"READY",555,530,329,60,m.slot==0?"start":"ready",m.slot!=0||allReady,"next");
        _root.gm3Text(p,allReady?"Ready!":"Waiting for players",330,548,218,15,0xffffff);
    }
}
function gm3Rules(p,m) {
    var s=m.settings;var editable=m.slot==0&&!m.playing;
    _root.gm3Skin(p,1485,71,113);_root.gm3ClassicBadge(p,"Modes",144,91,161);
    for(var i=0;i<7;i++)_root.gm3ClassicButton(p,_root.gm3ModeNames[i],42,154+i*47,350,40,"setting:mode:"+_root.gm3Modes[i],editable,null,s.mode==_root.gm3Modes[i],21);
    var desc=p.attachMovie("gm3_symbol_1504","gm3ModeDescription",p.getNextHighestDepth());desc._x=436;desc._y=99;desc.gotoAndStop(s.mode);
    _root.gm3Skin(p,649,431,293);_root.gm3ClassicBadge(p,"More options",449,271,239);
    _root.gm3ClassicButton(p,"Crates: "+(s.variant==1||!s.crates?"OFF":"ON"),450,335,183,35,"setting:crates",editable&&s.variant!=1,null,false,19);
    _root.gm3ClassicButton(p,"Pickups: "+(s.pickups?"ON":"OFF"),650,335,185,35,"setting:pickups",editable,null,false,19);
    _root.gm3Text(p,"Lives:",452,392,120,26,0);
    _root.gm3ClassicButton(p,"-",593,389,45,36,"setting:stocks:-1",editable);
    var count=_root.gm3ClassicInput(p,String(s.stocks),651,389,118,2);count.type="dynamic";count.selectable=false;
    _root.gm3ClassicButton(p,"+",782,389,45,36,"setting:stocks:1",editable);
    _root.gm3ClassicButton(p,_root.gm3Variants[s.variant]+"   >",450,449,380,35,"setting:variant",editable,null,false,20);
}
function gm3Map(p,m) {
    var editable=m.slot==0&&!m.playing;
    _root.gm3Skin(p,1485,71,113);_root.gm3ClassicBadge(p,"Maps",144,91,161);
    _root.gm3Text(p,"New maps",51,148,163,20,0);
    _root.gm3Text(p,"Classic maps",223,148,174,20,0);
    var names=["Castle","Highway","Sub Base","Alien Planet","Venice","Avalon","Space Station","Ski Lift","Jungle"];
    for(var i=1;i<=9;i++)_root.gm3ClassicButton(p,names[i-1],45,185+(i-1)*33,165,29,"setting:arena:"+i,editable,null,m.settings.arena==i,16);
    var classics=["No Name","Dessert Duel","Underwater Slaughter","Solar Shootout","Great Wall Brawl","Mushroom Mountain","Desert Destruction","Hovering Houses","Midnight Wood","Polar Pwn4ge","Grim City","Safari Showdown"];
    for(i=10;i<=21;i++)_root.gm3ClassicButton(p,classics[i-10],225,184+(i-10)*26,184,24,"setting:arena:"+i,editable,null,m.settings.arena==i,13);
    var art=p.attachMovie("gm3_symbol_1236","gm3MapArt",p.getNextHighestDepth());art._x=531;art._y=141;art.gotoAndStop(m.settings.arena);
}
function gm3Players(p,m) {
    for(var i=0;i<4;i++){
        var player=m.players[i];var x=20+i*220;var profile=player?player.profile:_root.gm3DefaultProfile(i);var editable=i==m.slot&&!m.playing;var active=player||m.settings.bots;
        _root.gm3Skin(p,1485,x+7,114,202,379);_root.gm3ClassicBadge(p,"Player "+(i+1),x+16,91,174);
        var name=_root.gm3Text(p,player?player.name:m.settings.bots?"CPU opponent":"Empty slot",x+13,145,189,18,0);var f=name.getTextFormat();f.align="center";name.setTextFormat(f);
        if(active){var avatar=_root.gm3Avatar(p,profile,x+108,278);if(i==m.slot)p.gm3Preview=avatar;}
        if(!player){_root.gm3Text(p,m.settings.bots?"Original AI":"Invite a friend",x+28,351,170,20,0);continue;}
        var fields=["color","hat","shirt","eyes","gun","perk","team"];var labels=["Color","Hat","Shirt","Face","Gun","Perk","Team"];
        for(var j=0;j<7;j++){
            var y=290+j*25;_root.gm3ClassicButton(p,"<",x+12,y,28,22,"profile:"+fields[j]+":-1",editable,null,false,15);
            var val=fields[j]=="team"?(profile.team==1?"Red":"Blue"):profile[fields[j]];var text=labels[j]+": "+val;
            if(fields[j]=="gun")text=_root.gm3GunNames[profile.gun-1];if(fields[j]=="perk")text=_root.gm3PerkNames[profile.perk-1];
            var t=_root.gm3Text(p,text,x+44,y+1,126,13,0);f=t.getTextFormat();f.align="center";t.setTextFormat(f);
            _root.gm3ClassicButton(p,">",x+174,y,28,22,"profile:"+fields[j]+":1",editable,null,false,15);
        }
        _root.gm3Text(p,i==0?"HOST":player.ready?"READY":"NOT READY",x+16,469,182,12,player.ready?0x22632b:0x823a28);
    }
    _root.gm3ClassicButton(p,"Empty slots: "+(m.settings.bots?"CPU opponents":"Friends only"),446,496,422,29,"setting:bots",m.slot==0&&!m.playing,null,false,17);
}
function gm3ReadLocalProfile() {
    var saved=SharedObject.getLocal("arena2gamedata");var profile=_root.gm3DefaultProfile(0);var max={color:20,shirt:27,hat:48,eyes:12,gun:7,perk:13,team:2};
    for(var key in profile){var n=Number(saved.data["p1"+key]);if(n>=1 && n<=max[key])profile[key]=n;}
    return profile;
}
function gm3SaveLocalProfile(profile) {
    var saved=SharedObject.getLocal("arena2gamedata");for(var key in profile)saved.data["p1"+key]=profile[key];saved.flush();
}
function gm3PrepareCharacterMenu() {
    var menu=_root.menup;menu.frame=1;menu._x=0;menu.menufade.gotoAndStop(2);
    for(var i=1;i<=4;i++)menu["menu"+i].gotoAndStop(2);
    menu.btn_start.enabled=false;menu.btn_back.enabled=false;
    var p=_root.createEmptyMovieClip("gm3CharacterChrome",10155);
    _root.gm3Rect(p,0,0,900,85,0x333333);_root.gm3ClassicHeader(p,"Character Customization");
    _root.gm3Rect(p,0,523,900,77,0x333333);
    _root.gm3Text(p,"Player 1 is your saved online fighter.",43,547,477,21,0xffffff);
    _root.gm3ClassicButton(p,"SAVE AND RETURN",555,530,329,60,"characterSave",true,"next",false,23);
    p.onEnterFrame=function(){if(_root._currentframe!=9 || !_root.gm3CustomizeOnly)this.removeMovieClip();};
}
function gm3SaveCharacterMenu() {
    var menu=_root.menup;if(!menu || menu.editedit)return;
    menu.WRITE_DATA();menu.savedata.flush();_root.gm3CustomizeOnly=false;
    _root.gm3CharacterChrome.removeMovieClip();_root.gotomenu=true;
    var fade=_root.attachMovie("fadeaway","fadeaway",_root.fadedepth);fade.targetframe=10;
}
