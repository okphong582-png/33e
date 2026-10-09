package vn.mizze.androidviet;
/** Auxiliary aim never writes the camera field. Restore only our own last value. */
final class AimRotationController {
    record Identity(int pid,long start,long match,long player,long klass){}
    interface Memory { Identity identity()throws Exception; GameGeometry.Q read(long at)throws Exception; void write(long at,GameGeometry.Q q)throws Exception; }
    private Identity owner;private GameGeometry.Q written;
    void apply(Memory memory,boolean active,GameGeometry.Q target)throws Exception{
        Identity live=memory.identity();if(live==null){owner=null;written=null;return;}
        if(!live.equals(owner)){owner=live;written=null;}
        long auxiliary=live.player()+0x628;
        if(!active||target==null){
            if(written!=null&&written.equals(memory.read(auxiliary))){GameGeometry.Q normal=memory.read(live.player()+0x614);if(normal.valid()&&live.equals(memory.identity()))memory.write(auxiliary,normal);}
            written=null;return;
        }
        if(target.valid()&&live.equals(memory.identity())){memory.write(auxiliary,target);written=target;}
    }
}
