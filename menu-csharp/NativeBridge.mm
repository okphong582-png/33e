// Optional same-process adapter. Not included in any existing package target.
#import <Foundation/Foundation.h>
#include "../esp/drawing_view/ESPPrefs.h"
#include <cmath>
#include <cstring>
extern void ESPSyncFromPrefs(void);
namespace {
struct Flag { const char *key; bool fallback; };
constexpr Flag flags[] = {
    {"SilentAim",false},{"AutoFire",false},{"AimLag",false},{"FakeLag",false},
    {"AutoSwapWeapon",false},{"FastFire",false},{"ShootNoReload",false},
    {"ShowFov",true},{"Box",true},{"Box3D",false},{"Name",true},{"Health",true},
    {"Line",false},{"Dis",true},{"Skeleton",false},{"GhostMode",false},
    {"Fly",false},{"RunSpeed",false},{"HideFeatureButtons",false}
};
struct Number { const char *key; float fallback,min,max; };
constexpr Number numbers[] = {
    {"FovSize",40,5,48},{"SilentFovSize",18,5,48},{"SilentHeadPercent",75,0,100},
    {"ESPMaxDistance",150,50,500},{"FlyHeight",4,1,6},{"RunSpeedValue",6,0.1f,30}
};
template<class T,size_t N> const T *Find(const T (&table)[N],const char *key){
    if(!key||strnlen(key,64)>=64)return nullptr;
    for(const auto &item:table)if(!std::strcmp(key,item.key))return &item;
    return nullptr;
}
void Main(dispatch_block_t block){
    if(NSThread.isMainThread)block();else dispatch_sync(dispatch_get_main_queue(),block);
}
}
#define EXPORT extern "C" __attribute__((visibility("default")))
EXPORT int MizzeMenuBridgeVersion(){return 1;}
EXPORT int MizzeMenuGetFlag(const char *key){
    const auto *entry=Find(flags,key);if(!entry)return -1;
    __block int value=0;Main(^{value=ESPPrefsBool([NSString stringWithUTF8String:entry->key],entry->fallback);});
    return value;
}
EXPORT int MizzeMenuSetFlag(const char *key,int value){
    const auto *entry=Find(flags,key);if(!entry||(value!=0&&value!=1))return -1;
    Main(^{
        NSString *name=[NSString stringWithUTF8String:entry->key];
        if(([name isEqualToString:@"SilentAim"]||[name isEqualToString:@"AutoFire"]||[name isEqualToString:@"AimLag"])&&value){
            for(NSString *other in @[@"AimbotFire",@"AimbotScope",@"AimHipAlways"])ESPPrefsSetBool(other,NO);
        }
        if([name isEqualToString:@"AutoFire"]&&value)ESPPrefsSetBool(@"SilentAim",YES);
        if([name isEqualToString:@"SilentAim"]&&!value)ESPPrefsSetBool(@"AutoFire",NO);
        if([name isEqualToString:@"Box3D"]&&value){ESPPrefsSetBool(@"Box",YES);ESPPrefsSetBool(@"CleanESP",NO);}
        ESPPrefsSetBool(name,value);ESPSyncFromPrefs();
    });return 0;
}
EXPORT float MizzeMenuGetValue(const char *key){
    const auto *entry=Find(numbers,key);if(!entry)return NAN;
    __block float value=entry->fallback;Main(^{value=ESPPrefsFloat([NSString stringWithUTF8String:entry->key],entry->fallback);});
    return std::isfinite(value)?fmaxf(entry->min,fminf(entry->max,value)):entry->fallback;
}
EXPORT int MizzeMenuSetValue(const char *key,float value){
    const auto *entry=Find(numbers,key);if(!entry||!std::isfinite(value))return -1;
    value=fmaxf(entry->min,fminf(entry->max,value));
    Main(^{ESPPrefsSetFloat([NSString stringWithUTF8String:entry->key],value);ESPSyncFromPrefs();});return 0;
}
