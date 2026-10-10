package vn.mizze.androidviet;

import java.io.IOException;

/** All three ITransformNode implementations found in the supplied Android metadata. */
final class TransformNodeReader {
    interface Memory {long pointer(long address)throws Exception;String string(long address)throws Exception;int instruction(long address)throws Exception;}
    private static boolean valid(long p){return p>=0x10000&&p<0x0001000000000000L&&(p&7)==0;}
    static long resolve(long node,long module,Memory memory)throws Exception{
        if(!valid(node))throw new IOException("Missing bone node");long klass=memory.pointer(node);
        if(!valid(klass))throw new IOException("Invalid bone class");
        String name=memory.string(memory.pointer(klass+0x10)),namespace=memory.string(memory.pointer(klass+0x18));long getter;
        if(name.equals("BFOONIGAIFK")&&namespace.isEmpty())getter=0x70D847CL;
        else if(name.equals("TransformNode")&&namespace.isEmpty())getter=0x3793898L;
        else if(name.equals("TransformNode")&&namespace.equals("GCommon"))getter=0x8251764L;
        else throw new IOException("Unknown transform node: "+namespace+"."+name);
        // Each native getter is exactly ldr x0,[x0,#0x10]; ret. Check before using its field.
        if(memory.instruction(module+getter)!=0xF9400800||memory.instruction(module+getter+4)!=0xD65F03C0)throw new IOException("Transform node getter mismatch: "+name);
        long transform=memory.pointer(node+0x10);if(!valid(transform))throw new IOException("Missing managed Transform: "+name);
        return transform;
    }
}
