#pragma once
#include <cstdint>
struct PlayerModesSnapshot {
    uint64_t ticks=0, applies=0, restores=0, failedOffset=0;
    uint32_t burrow=0, heldEnemies=0, skipped=0;
    bool running=false, scoped=false;
    const char *detail="";
};
void PlayerModesSetEnabled(bool burrow, bool aimLag);
void PlayerModesCancel();
int PlayerModesUpdate(uint64_t module);
PlayerModesSnapshot PlayerModesRead();
