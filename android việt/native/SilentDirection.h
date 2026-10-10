#pragma once
#include <cstdint>
#include <cmath>
#include <cstring>

namespace silent {
struct Point { float x{}, y{}, z{}; };
inline bool finite(Point p) { return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z); }
inline bool toward(Point origin, Point target, Point& result) {
    if(!finite(origin)||!finite(target)) return false;
    const double x=double(target.x)-origin.x,y=double(target.y)-origin.y,z=double(target.z)-origin.z;
    const double length=std::sqrt(x*x+y*y+z*z);
    if(!std::isfinite(length)||length<0.001||length>10000) return false;
    result={float(x/length),float(y/length),float(z/length)};
    return finite(result);
}
inline bool fresh(uint64_t sample,uint64_t lease,uint64_t now) {
    return sample>0&&sample<=now&&now-sample<=150&&lease>now&&lease-now<=30000;
}
struct DispatchResult { bool redirected{},restoreFailed{}; };
// The original handler runs exactly once. Restore only the value we still own.
template<class Read,class Write,class Current,class Original>
DispatchResult dispatch(Point desired,Read read,Write write,Current current,Original original) {
    Point before{};
    if(!finite(desired)||!current()||!read(before)||!finite(before)) { original();return {}; }
    if(!write(desired)) { original();return {}; }
    if(!current()) {
        original();return {};
    }
    const auto restore=[&]{Point after{};
        return current()&&read(after)&&std::memcmp(&after,&desired,sizeof(Point))==0&&!write(before);};
    try { original(); } catch(...) { restore();throw; }
    return {true,restore()};
}
}
