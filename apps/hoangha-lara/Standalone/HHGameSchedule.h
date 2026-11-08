#pragma once
#include <stdbool.h>
#include <math.h>
typedef struct {bool enabled;double sampleAt,geometryAt;} HHGameSchedule;
typedef struct {bool changed,disconnect,sample,geometry;} HHGameWork;
static inline HHGameWork hh_game_work(HHGameSchedule *s,bool requested,double now){
 HHGameWork w={false,false,false,false};if(!isfinite(now))return w;
 if(s->enabled!=requested){w.changed=true;w.disconnect=s->enabled;s->enabled=requested;s->sampleAt=now;s->geometryAt=now;}
 if(!requested)return w;
 if(now>=s->sampleAt){w.sample=true;s->sampleAt=now+0.2;}
 if(w.sample&&now>=s->geometryAt){w.geometry=true;s->geometryAt=now+2.0;}
 return w;
}
