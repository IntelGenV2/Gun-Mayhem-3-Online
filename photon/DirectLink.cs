using System.Buffers.Binary;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text.Json.Nodes;

// Photon exchanges authenticated room-member candidates. STUN discovers the router mapping.
// Full snapshots tolerate loss; Photon carries the same snapshot if the direct path stalls.
sealed class DirectLink : IDisposable
{
    sealed class Peer
    {
        public byte[] Key;
        public byte[] ReceiveKey=RandomNumberGenerator.GetBytes(32);
        public List<IPEndPoint> Candidates=new();
        public IPEndPoint Active;
        public long LastSeen,LastAck;
        public int Frame=-1,Count,Received;
        public byte[][] Parts;
    }
    readonly Socket udp=new(AddressFamily.InterNetwork,SocketType.Dgram,ProtocolType.Udp);
    readonly byte[] transaction=RandomNumberGenerator.GetBytes(12);
    readonly Dictionary<int,Peer> peers=new();
    readonly byte[] receive=new byte[65536];
    readonly List<IPEndPoint> local=new();
    readonly Task<IPAddress[]> lookup=Dns.GetHostAddressesAsync("stun.cloudflare.com");
    IPEndPoint stun,external;
    long lastProbe,lastStun;
    int actor,frame;
    public bool CandidatesChanged=true;
    public int ReceivedFrames,SentFrames;
    public Action<int,byte[]> OnFrame;
    public int ConnectedPeers=>peers.Values.Count(p=>Now-p.LastAck<1000);
    static long Now=>Environment.TickCount64;
    public DirectLink()
    {
        udp.Bind(new IPEndPoint(IPAddress.Any,0));udp.Blocking=false;
        int port=((IPEndPoint)udp.LocalEndPoint).Port;
        foreach(var ni in NetworkInterface.GetAllNetworkInterfaces().Where(i=>i.OperationalStatus==OperationalStatus.Up))
            foreach(var u in ni.GetIPProperties().UnicastAddresses)
                if(u.Address.AddressFamily==AddressFamily.InterNetwork && !IPAddress.IsLoopback(u.Address))local.Add(new IPEndPoint(u.Address,port));
    }
    public void SetActor(int value){actor=value;CandidatesChanged=true;}
    public JsonObject Offer(int target)
    {
        if(!peers.TryGetValue(target,out var peer)){peer=new Peer();peers[target]=peer;}
        var addresses=new JsonArray();foreach(var p in local.Take(8))addresses.Add(p.ToString());if(external!=null)addresses.Add(external.ToString());
        return new JsonObject{["t"]="direct",["key"]=Convert.ToBase64String(peer.ReceiveKey),["endpoints"]=addresses};
    }
    public void Accept(int from,JsonObject offer)
    {
        if(from==actor)return;
        byte[] remoteKey=Convert.FromBase64String(offer["key"]?.ToString()??"");if(remoteKey.Length!=32)return;
        if(!peers.TryGetValue(from,out var p)){p=new Peer();peers[from]=p;}
        p.Key=remoteKey;p.Candidates.Clear();
        if(offer["endpoints"] is JsonArray endpoints)foreach(var node in endpoints.Take(9))
            if(IPEndPoint.TryParse(node?.ToString(),out var end) && end.AddressFamily==AddressFamily.InterNetwork && end.Port>1024 && !end.Address.Equals(IPAddress.Any) && end.Address.GetAddressBytes()[0]<224)p.Candidates.Add(end);
    }
    public void Remove(int id)=>peers.Remove(id);
    void Send(Peer p,IPEndPoint target,byte kind,int seq=0,int part=0,int total=1,ReadOnlySpan<byte> payload=default)
    {
        if(target==null || p.Key==null)return;
        byte[] packet=new byte[50+payload.Length];packet[0]=0x47;packet[1]=0x33;packet[2]=kind;
        BinaryPrimitives.WriteInt32BigEndian(packet.AsSpan(4),actor);BinaryPrimitives.WriteInt32BigEndian(packet.AsSpan(8),seq);
        BinaryPrimitives.WriteUInt16BigEndian(packet.AsSpan(12),(ushort)part);BinaryPrimitives.WriteUInt16BigEndian(packet.AsSpan(14),(ushort)total);
        BinaryPrimitives.WriteUInt16BigEndian(packet.AsSpan(16),(ushort)payload.Length);payload.CopyTo(packet.AsSpan(50));
        byte[] mac=HMACSHA256.HashData(p.Key,packet);mac.CopyTo(packet,18);
        try{udp.SendTo(packet,target);}catch(SocketException){}
    }
    public bool SendFrame(int target,byte[] payload)
    {
        if(payload.Length>150000 || !peers.TryGetValue(target,out var p) || p.Active==null || Now-p.LastSeen>2000)return false;
        int seq=++frame,total=(payload.Length+999)/1000;
        for(int i=0;i<total;i++)Send(p,p.Active,2,seq,i,total,payload.AsSpan(i*1000,Math.Min(1000,payload.Length-i*1000)));
        SentFrames++;return Now-p.LastAck<750;
    }
    public void Tick()
    {
        if(stun==null && lookup.IsCompletedSuccessfully){var ip=lookup.Result.FirstOrDefault(a=>a.AddressFamily==AddressFamily.InterNetwork);if(ip!=null)stun=new IPEndPoint(ip,3478);}
        if(stun!=null && Now-lastStun>(external==null?1000:15000))
        {
            lastStun=Now;byte[] request=new byte[20];request[1]=1;BinaryPrimitives.WriteUInt32BigEndian(request.AsSpan(4),0x2112A442);transaction.CopyTo(request,8);
            try{udp.SendTo(request,stun);}catch(SocketException){}
        }
        if(actor>0 && Now-lastProbe>400)
        {
            lastProbe=Now;foreach(var p in peers.Values)foreach(var end in p.Candidates)Send(p,end,0);
        }
        for(int turn=0;turn<512 && udp.Poll(0,SelectMode.SelectRead);turn++)
        {
            EndPoint source=new IPEndPoint(IPAddress.Any,0);int n;
            try{n=udp.ReceiveFrom(receive,ref source);}catch(SocketException){break;}
            var from=(IPEndPoint)source;
            if(n>=20 && from.Equals(stun) && receive[0]==1 && receive[1]==1 && receive.AsSpan(8,12).SequenceEqual(transaction))
            {
                for(int off=20;off+4<=n;){int type=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(off)),size=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(off+2));off+=4;if(off+size>n)break;
                    if(type==0x20 && size==8 && receive[off+1]==1){int port=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(off+2))^0x2112;uint ip=BinaryPrimitives.ReadUInt32BigEndian(receive.AsSpan(off+4))^0x2112A442;byte[] a=new byte[4];BinaryPrimitives.WriteUInt32BigEndian(a,ip);var candidate=new IPEndPoint(new IPAddress(a),port);if(!candidate.Equals(external)){external=candidate;CandidatesChanged=true;}}
                    off+=(size+3)&~3;}
                continue;
            }
            if(n<50 || n>1050 || receive[0]!=0x47 || receive[1]!=0x33)continue;
            int sender=BinaryPrimitives.ReadInt32BigEndian(receive.AsSpan(4));if(!peers.TryGetValue(sender,out var peer))continue;
            byte[] receivedMac=receive.AsSpan(18,32).ToArray();receive.AsSpan(18,32).Clear();
            if(!CryptographicOperations.FixedTimeEquals(receivedMac,HMACSHA256.HashData(peer.ReceiveKey,receive.AsSpan(0,n))))continue;
            int kind=receive[2],seq=BinaryPrimitives.ReadInt32BigEndian(receive.AsSpan(8));
            peer.Active=from;peer.LastSeen=Now;
            if(kind==0){Send(peer,from,1);continue;}
            if(kind==1)continue;
            if(kind==3){peer.LastAck=Now;continue;}
            if(kind!=2)continue;
            int part=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(12)),total=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(14)),size2=BinaryPrimitives.ReadUInt16BigEndian(receive.AsSpan(16));
            if(total<1 || total>150 || part>=total || size2!=n-50 || seq<peer.Frame)continue;
            if(seq>peer.Frame){peer.Frame=seq;peer.Count=total;peer.Parts=new byte[total][];peer.Received=0;}
            if(peer.Count!=total || peer.Parts==null || peer.Parts[part]!=null)continue;
            peer.Parts[part]=receive.AsSpan(50,size2).ToArray();peer.Received++;
            if(peer.Received==total){byte[] combined=new byte[peer.Parts.Sum(p=>p.Length)];int offset=0;foreach(var piece in peer.Parts){piece.CopyTo(combined,offset);offset+=piece.Length;}peer.Parts=null;ReceivedFrames++;Send(peer,from,3,seq);OnFrame?.Invoke(sender,combined);}
        }
    }
    public void Dispose()=>udp.Dispose();
}
