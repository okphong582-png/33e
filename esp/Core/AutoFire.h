#pragma once
#include <cstdint>
// Shoot only after Silent accepts the target. Presentation and optional swaps
// stay active without a target. Native input runs on the game's update thread.
int AutoFireUpdate(uint64_t base, uint64_t match, uint64_t local, uint64_t target, bool swap=false);
void AutoFireClear();
uint64_t AutoFireStartCount();
uint64_t AutoFireTickCount();
