#import "../sources/InjectedOverlayOwnership.h"

extern "C" BOOL claimOverlay(id host, id owner) { return MizzeClaimOverlay(host, owner); }
extern "C" id overlayOwner(id host) { return MizzeOverlayOwner(host); }
extern "C" void releaseOverlay(id host, id owner) { MizzeReleaseOverlay(host, owner); }
