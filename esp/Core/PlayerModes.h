#pragma once
#include <cstdint>
struct PlayerModesSnapshot {
    uint64_t ticks=0, postTicks=0, applies=0, restores=0, failedOffset=0;
    uint32_t burrow=0, heldEnemies=0, skipped=0;
    uint32_t teleport=0; // 0 idle, 1 queued, 2 applied locally, 3 rejected/expired
    bool running=false, presenting=false, scoped=false, fakeLag=false;
    float depth=2.0f;
    const char *detail="";
};
void PlayerModesSetEnabled(bool burrow, bool aimLag, bool fakeLag, bool teleport, float depth);
bool PlayerModesRequestTeleport(uint64_t match,uint64_t local,uint64_t target);
void PlayerModesCancel();
int PlayerModesUpdate(uint64_t module);
PlayerModesSnapshot PlayerModesRead();
