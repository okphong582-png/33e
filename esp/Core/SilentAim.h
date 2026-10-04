#pragma once
#include <cstdint>
#include "Vector3.h"

// Returns a diagnostic state, not confirmation that a bullet hit its target.
void SilentAimSetEnabled(bool enabled);
void SilentAimClearTarget(void);
int SilentAimUpdate(uint64_t moduleBase, uint64_t match, uint64_t local,
                    uint64_t target, const Vector3 &head);
uint64_t SilentAimRedirectCount(void);
struct SilentAimFailure {
    const char *operation = "";
    int code = 0;
};
SilentAimFailure SilentAimLastFailure(void);
