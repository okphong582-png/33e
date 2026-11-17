#pragma once
#include <cstring>
namespace GameImageSelection {
inline bool UnityFramework(const char *path) {
    if (!path || !*path) return false;
    const char *leaf=std::strrchr(path,'/');
    return std::strcmp(leaf ? leaf+1 : path,"UnityFramework")==0;
}
}
