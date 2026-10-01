#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <cassert>

int main(int argc, char **argv) {
    @autoreleasepool {
        assert(argc == 3);
        void *first = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        void *second = dlopen(argv[2], RTLD_NOW | RTLD_LOCAL);
        assert(first && second && first != second);
        auto claimA = (BOOL (*)(id, id))dlsym(first, "claimOverlay");
        auto claimB = (BOOL (*)(id, id))dlsym(second, "claimOverlay");
        auto ownerB = (id (*)(id))dlsym(second, "overlayOwner");
        auto releaseB = (void (*)(id, id))dlsym(second, "releaseOverlay");
        assert(claimA && claimB && ownerB && releaseB && claimA != claimB);
        NSObject *host = [NSObject new];
        NSObject *windowA = [NSObject new];
        NSObject *windowB = [NSObject new];
        assert(!claimA(nil, windowA));
        assert(!claimA(host, nil));
        assert(claimA(host, windowA));
        assert(!claimA(host, windowA)); // Repeated launch/retry callback.
        assert(!claimB(host, windowB)); // A separately loaded dylib copy.
        assert(ownerB(host) == windowA);
        releaseB(host, windowB); // A losing initializer cannot clear ownership.
        assert(ownerB(host) == windowA);
        releaseB(host, windowA); // Failed initialization may retry.
        assert(!ownerB(host));
        assert(claimB(host, windowB));
        assert(!claimA(host, windowA));
        releaseB(host, windowB);
        puts("Overlay ownership shared across two dylib images: passed");
    }
}
