import java.nio.file.*;
import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.base.*;
public class InspectSkin {
 public static void main(String[] args)throws Exception{
  SWF swf=new SWF(Files.newInputStream(Path.of(args[0])),false);
  for(int i=1;i<args.length;i++){int id=Integer.parseInt(args[i]);var t=swf.getCharacter(id);System.out.println(id+" "+t+" "+((BoundedTag)t).getRect());}
  System.exit(0);
 }
}
