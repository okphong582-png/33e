#pragma once

// Called on the main thread. The callback runs after the managed Update hook.
void MizzeStartIfixStartup(void (*onReady)());
