#pragma once
#include <stdint.h>
#include <sys/types.h>
#ifdef __cplusplus
extern "C" {
#endif
// 8: installed with target; 7: installed without target; 9: profile/slot
// mismatch; 10: task or VM operation unavailable. Never installs for other FF builds.
int hh_silent_update(pid_t pid,uint64_t base,uint64_t match,uint64_t local,
                     uint64_t target,const float head[3],const float hip[3]);
void hh_silent_clear(void);
void hh_silent_stop(void);
const char *hh_silent_failure(void);
#ifdef __cplusplus
}
#endif
