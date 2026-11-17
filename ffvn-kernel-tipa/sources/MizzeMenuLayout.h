#pragma once
#include <algorithm>
#include <cmath>
namespace MizzeMenuLayout {
struct Metrics { double width,height,sidebar,header,contentWidth; };
inline Metrics Measure(double availableWidth,double availableHeight) {
    if (!std::isfinite(availableWidth) || availableWidth<=0) availableWidth=375;
    if (!std::isfinite(availableHeight) || availableHeight<=0) availableHeight=667;
    const bool landscape=availableWidth>availableHeight;
    const double width=std::max(1.0,std::min(350.0,availableWidth-16));
    const double height=std::max(1.0,std::min(landscape?316.0:350.0,availableHeight-16));
    const double rail=48;
    return {width,height,rail,44,std::max(1.0,width-rail-24)};
}
}
