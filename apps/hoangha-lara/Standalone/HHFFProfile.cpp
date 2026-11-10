#include "HHFFProfile.h"
#include "FreeFireReader.h"
struct ReadAdapter {HHFFRead read;void *context;bool operator()(uint64_t a,void *p,size_t n){return read&&read(context,a,p,n);}};
bool hh_ff_supports(HHFFRead read,void *context,uint64_t base){FreeFireESP::Reader<ReadAdapter> reader({read,context});return reader.supports(base);}
bool hh_ff_snapshot_stage(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count,int *stage){
 if(!boxes||!count)return false;*count=0;
 FreeFireESP::Reader<ReadAdapter> reader({read,context});FreeFireESP::Frame frame;
 FreeFireESP::SnapshotStage reason=FreeFireESP::SnapshotStage::Geometry;
 bool sampled=reader.snapshot(base,width,height,frame,&reason);
 if(stage)*stage=static_cast<int>(reason);
 if(!sampled)return false;
 for(size_t i=0;i<frame.count;i++){
  const auto &t=frame.targets[i];boxes[i]={t.x,t.y,t.w,t.h,t.id,t.hp,0,{0}};
  std::memcpy(boxes[i].name,t.name,sizeof(t.name));
 }*count=frame.count;return true;
}
bool hh_ff_snapshot(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count){
 return hh_ff_snapshot_stage(read,context,base,width,height,boxes,count,nullptr);
}
