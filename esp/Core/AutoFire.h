#pragma once
#include <cstdint>
// Only arm after the Silent adapter has accepted the same target. Native
// weapon input runs on the game's update thread, never on the HUD thread.
int AutoFireUpdate(uint64_t base, uint64_t match, uint64_t local, uint64_t target);
void AutoFireClear();
uint64_t AutoFireStartCount();
uint64_t AutoFireTickCount();
