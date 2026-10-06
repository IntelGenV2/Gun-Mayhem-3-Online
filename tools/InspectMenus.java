import java.nio.file.*;
import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.Timelined;
public class InspectMenus {
 public static void main(String[] args)throws Exception{
  SWF swf=new SWF(Files.newInputStream(Path.of(args[0])),false);
  int id=Integer.parseInt(args[1]);
  Timelined timeline=id==0?swf:(DefineSpriteTag)swf.getCharacter(id);
  System.out.println("Frames: "+(id==0?swf.frameCount:((DefineSpriteTag)timeline).frameCount));
  int frame=1;
  for(Tag t:timeline.getTags()){
   if(t instanceof ShowFrameTag)frame++;
   if(t instanceof PlaceObjectTypeTag p){
    var def=swf.getCharacter(p.getCharacterId());
    System.out.println("frame="+frame+" depth="+(p.getDepth()-16384)+" name="+p.getInstanceName()+" matrix="+p.getMatrix()+" def="+def);
    if(def instanceof TextTag txt)System.out.println(txt.getTexts());
   }
  }
  System.exit(0);
 }
}
