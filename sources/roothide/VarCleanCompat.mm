
#import "VarCleanCompat.h"
#include "KabraxHide.h"
#import <UIKit/UIKit.h>

extern "C" BOOL RootUserRemoveItemAtPath(NSString *path) {
    if (!path.length) return NO;
    NSError *err = nil;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:&err];
    (void)err;
    return ok;
}

extern "C" BOOL RootUserGetDirectoryContents(NSString *path, NSString *cacheFile) {
    if (!path.length || !cacheFile.length) return NO;
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    if (!contents) {
                return NO;
    }
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:contents.count];
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        BOOL isDirectory = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory];
        [result addObject:@{KH_NS("nameKH_STR("): item ?: @")KH_STR(", KH_NS(")isDirectory"): @(exists && isDirectory)}];
    }
    return [result writeToFile:cacheFile atomically:YES];
}

static NSString *VarCleanRulesInstallPath(void) {
    return jbroot(KH_NS("/var/mobile/Library/RootHide/varCleanRules.plist"));
}

extern "C" void EnsureVarCleanRulesInstalled(void) {
    NSString *dst = VarCleanRulesInstallPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:dst]) return;

    NSString *dir = [dst stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *src = [[NSBundle mainBundle] pathForResource:KH_NS("varCleanRulesKH_STR(") ofType:KH_NS(")plist")];
    if (!src.length) {
                return;
    }
    NSError *err = nil;
    [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&err];
    (void)err;
}
