#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef bool (*HHFFRead)(void *,uint64_t,void *,size_t);
typedef struct {float x,y,w,h; uint64_t id; uint16_t hp,number; char name[64]; float headX,headY; float head[3],hip[3];} HHFFBox;
bool hh_ff_supports(HHFFRead read,void *context,uint64_t base);
bool hh_ff_snapshot(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count);
bool hh_ff_snapshot_stage(HHFFRead read,void *context,uint64_t base,float width,float height,HHFFBox boxes[32],size_t *count,int *stage,uint64_t *match,uint64_t *local,bool aim);
#ifdef __cplusplus
}
#endif
