package vn.mizze.androidviet;

import org.junit.Test;
import java.io.IOException;
import java.util.HashMap;
import static org.junit.Assert.*;

public class TransformNodeReaderTest {
    static final long BASE=0x10000000,NODE=0x20000000,KLASS=0x20001000,TRANSFORM=0x20002000;
    static class Fixture implements TransformNodeReader.Memory {
        final HashMap<Long,Long> pointers=new HashMap<>();final HashMap<Long,String> strings=new HashMap<>();final HashMap<Long,Integer> code=new HashMap<>();
        Fixture(String name,String ns,long getter){pointers.put(NODE,KLASS);pointers.put(KLASS+16,0x30000000L);pointers.put(KLASS+24,0x30001000L);strings.put(0x30000000L,name);strings.put(0x30001000L,ns);pointers.put(NODE+16,TRANSFORM);code.put(BASE+getter,0xF9400800);code.put(BASE+getter+4,0xD65F03C0);}
        public long pointer(long address)throws Exception{Long p=pointers.get(address);if(p==null)throw new IOException("Unmapped pointer");return p;}
        public String string(long address)throws Exception{String value=strings.get(address);if(value==null)throw new IOException("Unmapped string");return value;}
        public int instruction(long address)throws Exception{Integer word=code.get(address);if(word==null)throw new IOException("Unmapped code");return word;}
    }
    @Test public void resolvesObfuscatedAndroidNodeUsingVerifiedGetter()throws Exception{
        Fixture memory=new Fixture("BFOONIGAIFK","",0x70D847C);assertEquals(TRANSFORM,TransformNodeReader.resolve(NODE,BASE,memory));
        memory.pointers.put(NODE+16,TRANSFORM+0x1000);assertEquals(TRANSFORM+0x1000,TransformNodeReader.resolve(NODE,BASE,memory));
    }
    @Test public void supportsBothNamedNodeImplementations()throws Exception{
        assertEquals(TRANSFORM,TransformNodeReader.resolve(NODE,BASE,new Fixture("TransformNode","",0x3793898)));
        assertEquals(TRANSFORM,TransformNodeReader.resolve(NODE,BASE,new Fixture("TransformNode","GCommon",0x8251764)));
    }
    @Test(expected=IOException.class) public void rejectsSameNameInUnverifiedNamespace()throws Exception{TransformNodeReader.resolve(NODE,BASE,new Fixture("BFOONIGAIFK","Other",0x70D847C));}
    @Test(expected=IOException.class) public void rejectsChangedGetterInsteadOfFollowingGuessedOffset()throws Exception{Fixture memory=new Fixture("BFOONIGAIFK","",0x70D847C);memory.code.put(BASE+0x70D847C,0xF9400C00);TransformNodeReader.resolve(NODE,BASE,memory);}
    @Test(expected=IOException.class) public void rejectsMissingTransformPointer()throws Exception{Fixture memory=new Fixture("BFOONIGAIFK","",0x70D847C);memory.pointers.put(NODE+16,0L);TransformNodeReader.resolve(NODE,BASE,memory);}
}
