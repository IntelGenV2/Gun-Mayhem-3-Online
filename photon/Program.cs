using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Photon.Client;
using Photon.Realtime;

// Transport companion only. Every game rule, graphic and physics update runs in Flash.
sealed class Bridge : IConnectionCallbacks, IMatchmakingCallbacks, IInRoomCallbacks, IOnEventCallback
{
    const string AppId = "e1d6cd78-cff9-4721-85c6-24fd8a32b968";
    const string Version = "gm3-photon-3";
    const byte Control = 1, Scene = 2;
    readonly RealtimeClient client = new();
    readonly ConcurrentQueue<string> commands = new();
    readonly Dictionary<int, int> slots = new();
    readonly bool[] ready = new bool[4];
    readonly JsonObject[] profiles = new JsonObject[4];
    readonly int[] masks = new int[4];
    readonly long[] lastInput = new long[4];
    readonly Stopwatch clock = Stopwatch.StartNew();
    readonly Dictionary<string,string> sceneRows=new();
    DirectLink direct;
    bool relayOnly;
    JsonObject settings = Clean(null);
    bool creating, playing, quitting, requested;
    volatile bool eof;
    string roomCode = "", region = "us";
    int hostActor, localSlot = -1, round, newest = -1;
    long lastHeartbeat;
    static string Text(JsonObject o, string key, string fallback = "") => o?[key]?.ToString() ?? fallback;
    static int Number(JsonObject o, string key, int fallback = 0) => int.TryParse(Text(o,key), out int n) ? n : fallback;
    static bool Flag(JsonObject o, string key) => Text(o,key).Equals("true", StringComparison.OrdinalIgnoreCase);
    static int Clamp(JsonObject o, string key, int lo, int hi, int fallback) { int n=Number(o,key,fallback);return n>=lo && n<=hi?n:fallback; }
    static JsonObject Clean(JsonObject s) => new() { ["arena"]=Clamp(s,"arena",1,21,1), ["mode"]=new[]{1,2,3,4,5,10,11}.Contains(Number(s,"mode",1))?Number(s,"mode",1):1, ["stocks"]=Clamp(s,"stocks",1,20,5), ["variant"]=Clamp(s,"variant",0,2,0), ["bots"]=s==null || Flag(s,"bots"), ["crates"]=s?["crates"]==null || Flag(s,"crates"), ["pickups"]=s?["pickups"]==null || Flag(s,"pickups") };
    static JsonObject Profile(JsonObject p,int slot) => new() {
        ["color"]=Clamp(p,"color",1,20,new[]{15,4,18,9}[slot]), ["shirt"]=Clamp(p,"shirt",1,27,new[]{3,4,5,15}[slot]),
        ["hat"]=Clamp(p,"hat",1,48,new[]{4,9,5,44}[slot]), ["eyes"]=Clamp(p,"eyes",1,12,new[]{1,1,2,11}[slot]),
        ["gun"]=Clamp(p,"gun",1,7,new[]{2,4,1,3}[slot]), ["perk"]=Clamp(p,"perk",1,13,1), ["team"]=Clamp(p,"team",1,2,slot%2+1)
    };
    static void Output(object o) { Console.WriteLine(JsonSerializer.Serialize(o));Console.Out.Flush(); }
    void Error(string message) => Output(new {t="error",message});
    bool Host => localSlot==0 && client.InRoom && client.LocalPlayer.ActorNumber==hostActor;
    public Bridge() { Log.Init(Log.LogOutputOption.Debug);client.AddCallbackTarget(this); }
    public void Run()
    {
        Task.Run(()=> {string line;while((line=Console.ReadLine())!=null){if(line.Length>350000 || commands.Count>128)break;commands.Enqueue(line);}eof=true;});
        Output(new {t="bridgeReady"});
        while(!eof && !quitting)
        {
            for(int i=0;i<32 && commands.TryDequeue(out string line);i++)
                try { Handle(JsonNode.Parse(line) as JsonObject); } catch(Exception e) { Error("Network command failed: "+e.Message); }
            client.Service();
            direct?.Tick();
            if(client.InRoom && direct!=null && direct.CandidatesChanged){direct.CandidatesChanged=false;OfferDirect();}
            if(Host && playing)for(int i=1;i<4;i++)if(masks[i]!=0 && clock.ElapsedMilliseconds-lastInput[i]>1000){masks[i]=0;Output(new {t="input",slot=i,mask=0});}
            if(clock.ElapsedMilliseconds-lastHeartbeat>1000){lastHeartbeat=clock.ElapsedMilliseconds;Output(new {t="heartbeat",ping=client.RealtimePeer.RoundTripTime,directPeers=direct?.ConnectedPeers??0,directSent=direct?.SentFrames??0,directReceived=direct?.ReceivedFrames??0});}
            Thread.Sleep(5);
        }
        client.Disconnect();
        direct?.Dispose();
        for(int i=0;i<10;i++){client.Service();Thread.Sleep(5);}
    }
    void Handle(JsonObject m)
    {
        if(m==null)return;
        string type=Text(m,"t");
        if(type=="quit"){quitting=true;return;}
        if(type=="ping"){Output(new {t="pong",at=Number(m,"at")});return;}
        if(type=="create" || type=="join")
        {
            if(requested)return;
            creating=type=="create";region=Text(m,"region","us").ToLowerInvariant();
            roomCode=Text(m,"code").Trim().ToUpperInvariant();
            if(!creating && !System.Text.RegularExpressions.Regex.IsMatch(roomCode,"^[A-Z0-9]{6}$")){Error("Enter the six-character room code.");return;}
            if(!new[]{"us","usw","eu","asia","au","jp","sa","kr","cae","za","in","tr","uae"}.Contains(region)){Error("Choose a supported Photon region.");return;}
            settings=Clean(m["settings"] as JsonObject);
            relayOnly=Flag(m,"relayOnly");
            client.NickName=new string(Text(m,"name","Player").Where(c=>!char.IsControl(c)&&c!='|').Take(18).ToArray());
            client.AuthValues=new AuthenticationValues(Guid.NewGuid().ToString("N"));requested=true;
            if(!client.ConnectUsingSettings(new AppSettings {AppIdRealtime=AppId,AppVersion=Version,FixedRegion=region,Protocol=ConnectionProtocol.Udp,AuthMode=AuthModeOption.Auth,EnableProtocolFallback=true}))Error("Photon could not begin connecting.");
            return;
        }
        if(!client.InRoom || localSlot<0)return;
        if(type=="state")
        {
            if(!Host || !playing)return;
            string scene=Text(m,"scene");int seq=Number(m,"seq",-1);
            if(scene.Length>250000 || seq<=newest)return;newest=seq;
            var sounds=new List<string>();
            foreach(string row in scene.Split('\n')){int split=row.IndexOf('|');if(split<0)continue;string k=row[..split];if(k=="!")sounds.Add(row);else if(k=="-")sceneRows.Remove(row[2..]);else sceneRows[k]=row;}
            if(sceneRows.Count>2500){Finish("Scene exceeded the network limit");return;}
            string full=string.Join('\n',sceneRows.Values.Concat(sounds));
            byte[] raw=Encoding.UTF8.GetBytes(new JsonObject{["t"]="state",["seq"]=seq,["round"]=round,["full"]=true,["scene"]=full}.ToJsonString());
            using var stream=new MemoryStream();using(var zip=new DeflateStream(stream,CompressionLevel.Fastest,true))zip.Write(raw);
            if(client.RealtimePeer.QueuedOutgoingCommands>200){Error("The connection is too slow for this match. Return to the lobby.");Finish("Connection could not keep up");return;}
            byte[] packet=stream.ToArray();
            foreach(int actor in slots.Keys.Where(a=>a!=hostActor))
                if(direct==null || !direct.SendFrame(actor,packet))client.OpRaiseEvent(Scene,packet,new RaiseEventArgs{TargetActors=new[]{actor}},new SendOptions{Reliability=true,Channel=1});
            return;
        }
        if(Host)Request(client.LocalPlayer.ActorNumber,m);
        else if(type=="ready" || type=="input" || type=="profile")Send(m,new[]{hostActor});
    }
    void Send(JsonObject m,int[] targets=null)
    {
        client.OpRaiseEvent(Control,m.ToJsonString(),new RaiseEventArgs{TargetActors=targets,Receivers=ReceiverGroup.Others},SendOptions.SendReliable);
    }
    void Publish(JsonObject m){Output(m);Send(m);}
    void Request(int actor,JsonObject m)
    {
        if(!Host || !slots.TryGetValue(actor,out int slot))return;
        switch(Text(m,"t"))
        {
            case "profile":if(!playing){profiles[slot]=Profile(m["profile"] as JsonObject,slot);ready[slot]=slot==0;Lobby();}break;
            case "ready":if(!playing){ready[slot]=slot==0 || Flag(m,"ready");Lobby();}break;
            case "settings":if(slot==0 && !playing){settings=Clean(m["settings"] as JsonObject);Array.Clear(ready);ready[0]=true;Lobby();}break;
            case "start":
                if(slot!=0 || playing)return;
                if(slots.Values.Any(s=>!ready[s])){Error("Wait for everyone to press Ready.");return;}
                if(slots.Count<2 && !Flag(settings,"bots")){Error("Invite a friend or enable bots.");return;}
                playing=true;round++;newest=-1;sceneRows.Clear();Array.Clear(masks);client.CurrentRoom.IsOpen=false;
                var names=new JsonArray();for(int i=0;i<4;i++){var p=slots.FirstOrDefault(p=>p.Value==i);names.Add(p.Key==0?null:client.CurrentRoom.Players[p.Key].NickName);}
                var loadouts=new JsonArray();for(int i=0;i<4;i++)loadouts.Add((profiles[i]??Profile(null,i)).DeepClone());
                Publish(new JsonObject{["t"]="start",["round"]=round,["settings"]=settings.DeepClone(),["players"]=names,["loadouts"]=loadouts});break;
            case "input":
                int mask=Number(m,"mask",-1);if(!playing || mask<0 || mask>63)return;
                masks[slot]=mask;lastInput[slot]=clock.ElapsedMilliseconds;Output(new {t="input",slot,mask});break;
            case "finish":if(slot==0 && playing)Finish(Text(m,"message","Round over"));break;
        }
    }
    void Finish(string message)
    {
        playing=false;Array.Clear(masks);Array.Clear(ready);ready[0]=true;client.CurrentRoom.IsOpen=true;
        Publish(new JsonObject{["t"]="finish",["message"]=message[..Math.Min(message.Length,80)]});Lobby();
    }
    void Lobby()
    {
        if(!Host)return;
        var players=new JsonArray();
        for(int i=0;i<4;i++){var p=slots.FirstOrDefault(p=>p.Value==i);players.Add(p.Key==0?null:new JsonObject{["name"]=client.CurrentRoom.Players[p.Key].NickName,["ready"]=ready[i],["profile"]=(profiles[i]??Profile(null,i)).DeepClone()});}
        Publish(new JsonObject{["t"]="lobby",["code"]=roomCode,["region"]=region,["players"]=players,["settings"]=settings.DeepClone(),["playing"]=playing});
    }
    void Assign(Player p)
    {
        if(slots.ContainsKey(p.ActorNumber))return;
        int slot=Enumerable.Range(0,4).FirstOrDefault(i=>!slots.ContainsValue(i),-1);if(slot<0)return;
        slots[p.ActorNumber]=slot;ready[slot]=slot==0;profiles[slot]=Profile(null,slot);
        var msg=new JsonObject{["t"]="welcome",["slot"]=slot,["code"]=roomCode,["region"]=region};
        if(p.IsLocal){localSlot=slot;Output(msg);}else Send(msg,new[]{p.ActorNumber});
    }
    public void OnEvent(EventData e)
    {
        try
        {
            if(e.Code==Control && e.CustomData is string text && text.Length<=5000)
            {
                var m=JsonNode.Parse(text) as JsonObject;if(m==null)return;
                if(Text(m,"t")=="direct") {if(direct!=null && (Host && slots.ContainsKey(e.Sender) || e.Sender==hostActor))direct.Accept(e.Sender,m);return;}
                if(Host){Request(e.Sender,m);return;}
                if(e.Sender!=hostActor)return;
                string type=Text(m,"t");
                if(type=="welcome")localSlot=Number(m,"slot",-1);
                else if(type=="start"){playing=true;round=Number(m,"round");newest=-1;}
                else if(type=="finish")playing=false;
                else if(type!="lobby" && type!="closed")return;
                Output(m);
            }
            else if(e.Code==Scene && !Host && playing && e.Sender==hostActor && e.CustomData is byte[] bytes && bytes.Length<=150000)
            {
                ReceiveScene(e.Sender,bytes);
            }
        }
        catch(Exception e2){Console.Error.WriteLine("Rejected network message: "+e2.Message);}
    }
    public void OnConnected(){}
    public void OnConnectedToMaster()
    {
        if(creating){roomCode=Convert.ToHexString(RandomNumberGenerator.GetBytes(3));client.OpCreateRoom(new EnterRoomArgs{RoomName=roomCode,RoomOptions=new RoomOptions{MaxPlayers=4,IsVisible=false,PlayerTtl=0,EmptyRoomTtl=0}});}
        else client.OpJoinRoom(new EnterRoomArgs{RoomName=roomCode});
    }
    public void OnJoinedRoom()
    {
        hostActor=client.CurrentRoom.MasterClientId;
        if(!relayOnly)try{direct=new DirectLink();direct.SetActor(client.LocalPlayer.ActorNumber);direct.OnFrame=ReceiveScene;}catch(Exception e){Console.Error.WriteLine("Direct link unavailable, using Photon relay: "+e.Message);}
        if(creating){localSlot=0;Assign(client.LocalPlayer);foreach(var p in client.CurrentRoom.Players.Values)Assign(p);Lobby();}
    }
    void OfferDirect(){if(direct==null)return;int[] targets=Host?slots.Keys.Where(a=>a!=hostActor).ToArray():new[]{hostActor};foreach(int target in targets)client.OpRaiseEvent(Control,direct.Offer(target).ToJsonString(),new RaiseEventArgs{TargetActors=new[]{target}},new SendOptions{Reliability=true,Encrypt=true});}
    void ReceiveScene(int sender,byte[] bytes)
    {
        if(Host || !playing || sender!=hostActor || bytes.Length>150000)return;
        try{using var zip=new DeflateStream(new MemoryStream(bytes),CompressionMode.Decompress);using var decoded=new MemoryStream();
            byte[] buffer=new byte[4096];int n;while((n=zip.Read(buffer))>0){if(decoded.Length+n>350000)return;decoded.Write(buffer,0,n);}
            var m=JsonNode.Parse(decoded.ToArray()) as JsonObject;int seq=Number(m,"seq",-1);
            if(Number(m,"round")!=round || seq<=newest)return;newest=seq;Output(m);
        }catch(System.IO.InvalidDataException){}catch(JsonException){}
    }
    public void OnPlayerEnteredRoom(Player player){if(Host){Assign(player);Lobby();OfferDirect();}}
    public void OnPlayerLeftRoom(Player player)
    {
        direct?.Remove(player.ActorNumber);
        if(player.ActorNumber==hostActor){Output(new{t="closed",message="The host left the room."});client.Disconnect();return;}
        if(Host && slots.Remove(player.ActorNumber,out int slot)){masks[slot]=0;ready[slot]=false;Output(new{t="input",slot,mask=0,disconnected=true});Lobby();}
    }
    public void OnMasterClientSwitched(Player player){if(player.ActorNumber!=hostActor){Output(new{t="closed",message="The host left the room."});client.Disconnect();}}
    public void OnDisconnected(DisconnectCause cause){if(!quitting)Output(new{t="closed",message="Photon disconnected: "+cause});}
    public void OnCreateRoomFailed(short code,string message){Error("Could not create room ("+code+"): "+message);}
    public void OnJoinRoomFailed(short code,string message){Error(code==32758?"Room not found. Check the room code and region.":code==32764?"This room is full.":code==32765?"This match has started. Join between rounds.":"Could not join room ("+code+"): "+message);}
    public void OnCustomAuthenticationFailed(string message){Error("Photon authentication failed: "+message);}
    public void OnCreatedRoom(){} public void OnLeftRoom(){} public void OnJoinRandomFailed(short c,string m){}
    public void OnFriendListUpdate(List<FriendInfo> list){} public void OnRegionListReceived(RegionHandler h){}
    public void OnCustomAuthenticationResponse(Dictionary<string,object> d){}
    public void OnRoomPropertiesUpdate(PhotonHashtable p){} public void OnPlayerPropertiesUpdate(Player p,PhotonHashtable changed){}
    static void Main(){try{new Bridge().Run();}catch(Exception e){Console.Error.WriteLine(e);Output(new{t="error",message=e.Message});Environment.ExitCode=1;}}
}
