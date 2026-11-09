#include "HHFFProfile.h"
#include "FreeFireReader.h"
struct ReadAdapter {HHFFRead read;void *context;bool operator()(uint64_t a,void *p,size_t n){return read&&read(context,a,p,n);}};
bool hh_ff_supports(HHFFRead read,void *context,uint64_t base){FreeFireESP::Reader<ReadAdapter> reader({read,context});return reader.supports(base);}
bool hh_ff_snapshot(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count){
 if(!boxes||!count)return false;*count=0;
 FreeFireESP::Reader<ReadAdapter> reader({read,context});FreeFireESP::Frame frame;
 if(!reader.snapshot(base,width,height,frame))return false;
 for(size_t i=0;i<frame.count;i++){const auto &t=frame.targets[i];boxes[i]={t.x,t.y,t.w,t.h,t.id,t.hp,0};}*count=frame.count;return true;
}
