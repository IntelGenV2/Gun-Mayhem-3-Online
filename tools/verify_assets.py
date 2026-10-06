"""Prove the host keeps original SWF art, maps, placements and game bytecode."""
import hashlib
import json
import struct
import zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def unpack(path):
    raw=Path(path).read_bytes()
    body=zlib.decompress(raw[8:]) if raw[:3]==b'CWS' else raw[8:]
    rect_size=(5+4*(body[0]>>3)+7)//8
    return body[:rect_size+4], tags(body[rect_size+4:])

def tags(data):
    pos=0;out=[]
    while pos<len(data):
        header=struct.unpack_from('<H',data,pos)[0];pos+=2
        kind=header>>6;size=header&63
        if size==63:size=struct.unpack_from('<I',data,pos)[0];pos+=4
        payload=data[pos:pos+size];pos+=size
        if kind==0:break
        out.append((kind,payload))
    return out

def verify(original,modified,counts,sprite=0):
    cursor=0
    for kind,data in original:
        while cursor<len(modified) and modified[cursor][0] in (12,56) and modified[cursor]!=(kind,data):
            added(modified[cursor],counts);cursor+=1
        assert cursor<len(modified),f'Missing original tag {kind}'
        nk,nd=modified[cursor];cursor+=1
        assert kind==nk,f'Original tag {kind} replaced with {nk}'
        if kind==39:
            assert data[:4]==nd[:4],'Original sprite ID/frame count changed'
            verify(tags(data[4:]),tags(nd[4:]),counts,struct.unpack_from('<H',data)[0]);counts['original_sprites']+=1
        else:
            assert data==nd,f'Original tag payload changed: tag {kind}'
            counts['unchanged_original_tags']+=1
            if kind==12:counts['unchanged_original_action_blocks']+=1
    while cursor<len(modified):
        added(modified[cursor],counts);cursor+=1

def added(tag,counts):
    kind,data=tag
    if kind==12:counts['added_action_blocks']+=1;return
    assert kind==56,'Unexpected added tag'
    expected=struct.pack('<H',4)+b''.join(struct.pack('<H',i)+f'gm3_symbol_{i}'.encode()+b'\0' for i in (1236,1277,926,969))
    assert data==expected,'Unexpected asset aliases'
    counts['preview_alias_blocks']+=1

if __name__=='__main__':
    source=ROOT/'ref/gunmayhem2_decomp.swf';built=ROOT/'build/game.swf'
    header,a=unpack(source);new_header,b=unpack(built);assert header==new_header
    result={'original_sprites':0,'unchanged_original_tags':0,'unchanged_original_action_blocks':0,'added_action_blocks':0,'preview_alias_blocks':0}
    verify(a,b,result)
    assert result['preview_alias_blocks']==1
    result['source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
    result['original_art_maps_and_game_code_preserved']=True
    (ROOT/'build/asset-verification.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))
