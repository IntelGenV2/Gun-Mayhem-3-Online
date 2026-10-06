import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.jpexs.decompiler.flash.*;
import com.jpexs.decompiler.flash.tags.*;
import com.jpexs.decompiler.flash.tags.base.*;
import com.jpexs.decompiler.flash.timeline.Timelined;
import com.jpexs.decompiler.flash.action.parser.script.ActionScript2Parser;
import com.jpexs.decompiler.flash.types.MATRIX;

/** Adds an AS2 bridge without decompiling/recompiling the original game logic. */
public class PatchGame {
    static SWF swf;
    static final int[] UI_ALIASES={1236,1277,926,969,649,1068,1315,1485,1504,1508,1516,1530,60000,60001};
    static DefineSpriteTag buttonSkin(int id,int button){
        DefineSpriteTag sprite=new DefineSpriteTag(swf);sprite.spriteId=id;sprite.frameCount=1;
        PlaceObject2Tag place=new PlaceObject2Tag(swf);place.depth=1;place.characterId=button;place.placeFlagHasCharacter=true;
        place.matrix=new MATRIX();place.placeFlagHasMatrix=true;sprite.addTag(place);sprite.addTag(new ShowFrameTag(swf));sprite.setModified(true);return sprite;
    }
    static void atFrame(DefineSpriteTag sprite, int frame, String source, boolean first) throws Exception {
        int current=1, start=0;
        for(Tag t:sprite.getTags().toArrayList()) {
            if(t instanceof ShowFrameTag) {
                if(current==frame){sprite.addTag(first?start:sprite.indexOfTag(t),code(source));sprite.setModified(true);return;}
                current++;start=sprite.indexOfTag(t)+1;
            }
        }
        throw new IOException("Missing frame "+frame+" in sprite "+sprite.spriteId);
    }
    static String depthMap(Timelined timeline, int symbol) {
        Set<Integer> depths = new TreeSet<>();
        String nested = "";
        for (Tag tag : timeline.getTags()) {
            if (tag instanceof PlaceObjectTypeTag place) depths.add(place.getDepth() - 16384);
            if (tag instanceof DefineSpriteTag sprite) nested += depthMap(sprite, sprite.spriteId);
        }
        return "s" + symbol + ":" + depths.toString() + "," + nested;
    }
    static String read(Path root, String name) throws Exception {
        return Files.readString(root.resolve("as2/" + name));
    }
    static DoActionTag code(String source) throws Exception {
        DoActionTag tag = new DoActionTag(swf);
        tag.setActions(new ActionScript2Parser(swf, tag).actionsFromString(source, "UTF-8"));
        tag.setModified(true);
        return tag;
    }
    static void visit(Timelined timeline, boolean guest) throws Exception {
        for (Tag tag : timeline.getTags().toArrayList()) {
            if (tag instanceof DefineSpriteTag sprite) {
                visit(sprite, guest);
                // Every instance can identify the exact original vector symbol on the wire.
                sprite.addTag(0, code("this.gm3Symbol=" + sprite.spriteId + ";"));
                if(!guest && sprite.spriteId==703)atFrame(sprite,1,"if(this._parent==_root && _root._currentframe==10)_root.gm3DecorateMenu(this);",false);
                if(!guest && sprite.spriteId==1364)atFrame(sprite,1,"_root.gm3DecorateCredits(this);",false);
                if(!guest && sprite.spriteId==1574)atFrame(sprite,1,"if(_root.gm3CustomizeOnly)_root.gm3PrepareCharacter=3;",false);
                if(!guest && (sprite.spriteId==10 || sprite.spriteId==1048 || sprite.spriteId==691 || sprite.spriteId==693))
                    atFrame(sprite,1,"delete this.onPress;this.useHandCursor=false;",false);
                if(!guest && sprite.spriteId==1062)atFrame(sprite,2,"new Color(this.getInstanceAtDepth(-16383)).setRGB(0);new Color(this.frame).setRGB(0);",false);
                if(!guest && sprite.spriteId==672){
                    atFrame(sprite,1,"_root.gm3TransitionStart();",true);
                    atFrame(sprite,8,"_root.gm3TransitionMiddle();",false);
                    atFrame(sprite,15,"_root.gm3TransitionDone();",true);
                }
                sprite.setModified(true);
            } else if (guest && (tag instanceof DoActionTag || tag instanceof DoInitActionTag)) {
                timeline.removeTag(tag);
            } else if (guest && tag instanceof PlaceObjectTypeTag place) {
                place.setClipActions(null);
                place.setPlaceFlagHasClipActions(false);
                tag.setModified(true);
            } else if (guest && tag instanceof DefineButton2Tag button) {
                button.actions.clear();
                tag.setModified(true);
            }
        }
    }
    public static void main(String[] args) throws Exception {
        Path root = Path.of(args[0]).toAbsolutePath();
        Path source = root.resolve("ref/gunmayhem2_decomp.swf");
        Files.createDirectories(root.resolve("build"));
        for (boolean guest : new boolean[]{false, true}) {
            try (InputStream in = Files.newInputStream(source)) { swf = new SWF(in, false); }
            String depths = depthMap(swf, 0);
            String metadata = "_root.gm3Depths={" + depths.substring(0, depths.length()-1) + "};";
            visit(swf, guest);
            if (guest) {
                // Library-only guest: no local physics, AI, scoring, buttons or external links.
                for (Tag t : swf.getTags().toArrayList()) {
                    if (t instanceof PlaceObjectTypeTag || t instanceof RemoveObjectTag ||
                        t instanceof RemoveObject2Tag || t instanceof ShowFrameTag ||
                        t instanceof FrameLabelTag || t instanceof StartSoundTag ||
                        t instanceof SoundStreamHeadTag || t instanceof SoundStreamHead2Tag ||
                        t instanceof SoundStreamBlockTag) swf.removeTag(t);
                }
                swf.addTag(buttonSkin(60000,653));swf.addTag(buttonSkin(60001,656));
                ExportAssetsTag exports = new ExportAssetsTag(swf);
                for (Tag t : swf.getTags()) if (t instanceof DefineSpriteTag sprite) {
                    exports.tags.add(sprite.spriteId);
                    exports.names.add("gm3_symbol_" + sprite.spriteId);
                }
                swf.addTag(exports);
                swf.addTag(code(metadata + read(root, "common.as") + read(root, "menus.as") + read(root, "interface.as") + read(root,"classic.as") + read(root,"audio.as") + read(root, "guest.as")));
                swf.addTag(new ShowFrameTag(swf));
                swf.frameCount = 1;
            } else {
                int frame = 1;
                for (Tag t : swf.getTags().toArrayList()) if (t instanceof ShowFrameTag) {
                    if (frame == 2) {
                        swf.addTag(swf.indexOfTag(t), code(metadata + read(root, "common.as") + read(root, "menus.as") + read(root, "interface.as") + read(root,"classic.as") + read(root,"audio.as") + read(root, "host.as")));
                    }
                    if(frame==9){
                        swf.addTag(swf.indexOfTag(t),buttonSkin(60000,653));swf.addTag(swf.indexOfTag(t),buttonSkin(60001,656));
                        ExportAssetsTag previews=new ExportAssetsTag(swf);
                        for(int id:UI_ALIASES){previews.tags.add(id);previews.names.add("gm3_symbol_"+id);}
                        swf.addTag(swf.indexOfTag(t),previews);
                    }
                    if(frame==10)swf.addTag(swf.indexOfTag(t),code("_root.gm3CameraReady();"));
                    frame++;
                }
                // Keep network-session preferences separate from the original saves.
            }
            swf.compression = SWFCompression.ZLIB;
            Path out = root.resolve("build/" + (guest ? "guest" : "game") + ".swf");
            try (OutputStream output = Files.newOutputStream(out)) { swf.saveTo(output); }
            System.out.println("Built " + out + " (original vector/sound assets retained)");
        }
        System.exit(0);
    }
}
