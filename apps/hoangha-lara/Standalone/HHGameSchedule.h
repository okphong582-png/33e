#pragma once
#include <stdbool.h>
#include <math.h>
typedef struct {bool enabled;double sampleAt,geometryAt;int observedPID,foregroundPID;} HHGameSchedule;
typedef struct {bool changed,disconnect,sample,geometry;} HHGameWork;
static inline void hh_game_sample_finished(HHGameSchedule *s,double now){
 if(s->enabled&&isfinite(now))s->sampleAt=fmax(s->sampleAt,now+0.012);
}
static inline void hh_game_observe_foreground(HHGameSchedule *s,int pid){
 s->foregroundPID=s->enabled&&pid>0&&pid==s->observedPID?pid:0;
 s->observedPID=s->enabled?pid:0;
}
static inline HHGameWork hh_game_work(HHGameSchedule *s,bool requested,double now){
 HHGameWork w={false,false,false,false};if(!isfinite(now))return w;
 if(s->enabled!=requested){w.changed=true;w.disconnect=s->enabled;s->enabled=requested;s->sampleAt=now;s->geometryAt=now;hh_game_observe_foreground(s,0);}
 if(!requested)return w;
 if(now>=s->sampleAt){w.sample=true;s->sampleAt=now+0.06;}
 if(w.sample&&now>=s->geometryAt){w.geometry=true;s->geometryAt=now+2.0;}
 return w;
}
