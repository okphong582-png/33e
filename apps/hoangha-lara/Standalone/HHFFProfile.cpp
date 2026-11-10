#include "HHFFProfile.h"
#include "FreeFireReader.h"
#include "HHAimMath.h"
struct ReadAdapter {HHFFRead read;void *context;bool operator()(uint64_t a,void *p,size_t n){return read&&read(context,a,p,n);}};
bool hh_ff_supports(HHFFRead read,void *context,uint64_t base){FreeFireESP::Reader<ReadAdapter> reader({read,context});return reader.supports(base);}
bool hh_ff_snapshot_stage(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count,int *stage,uint64_t *match,uint64_t *local,float origin[3],bool aim){
 if(!boxes||!count)return false;*count=0;
 if(match)*match=0;if(local)*local=0;
 if(origin)origin[0]=origin[1]=origin[2]=0;
 FreeFireESP::Reader<ReadAdapter> reader({read,context});FreeFireESP::Frame frame;
 FreeFireESP::SnapshotStage reason=FreeFireESP::SnapshotStage::Geometry;
 bool sampled=reader.snapshot(base,width,height,frame,&reason,aim);
 if(stage)*stage=static_cast<int>(reason);
 if(!sampled)return false;
 if(match)*match=frame.match;if(local)*local=frame.local;
 if(origin){origin[0]=frame.origin.x;origin[1]=frame.origin.y;origin[2]=frame.origin.z;}
 for(size_t i=0;i<frame.count;i++){
  const auto &t=frame.targets[i];boxes[i]={t.x,t.y,t.w,t.h,t.id,t.hp,0,{0},t.headX,t.headY,
   {t.head.x,t.head.y,t.head.z},{t.hip.x,t.hip.y,t.hip.z}};
  std::memcpy(boxes[i].name,t.name,sizeof(t.name));
 }*count=frame.count;return true;
}
bool hh_ff_snapshot(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count){
 return hh_ff_snapshot_stage(read,context,base,width,height,boxes,count,nullptr,nullptr,nullptr,nullptr,false);
}
bool hh_ff_neck_rotation(const float origin[3],const float head[3],const float hip[3],float quaternion[4]){
 if(!origin||!head||!hip||!quaternion)return false;
 HHAim::Vec3 from{origin[0],origin[1],origin[2]},h{head[0],head[1],head[2]},b{hip[0],hip[1],hip[2]};
 HHAim::Quaternion q{};
 if(!HHAim::finite(from)||!HHAim::finite(h)||!HHAim::finite(b)||
    !HHAim::look(from,HHAim::neck(h,b),q))return false;
 quaternion[0]=q.x;quaternion[1]=q.y;quaternion[2]=q.z;quaternion[3]=q.w;return true;
}
