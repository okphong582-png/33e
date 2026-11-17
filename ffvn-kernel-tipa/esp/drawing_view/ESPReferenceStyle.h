#pragma once

namespace ESPReferenceStyle {
struct RGB { float r, g, b; };
constexpr RGB Line{1,1,1};
constexpr RGB Fov{1,1,1};
constexpr RGB Skeleton{1,1,1};
constexpr RGB Box{1,1,1};
// Head, hip, left/right shoulders, hands, ankles, shoulder midpoint.
constexpr unsigned char SimpleEdges[][2] = {
    {0,8}, {8,1}, {2,3}, {2,4}, {3,5}, {1,6}, {1,7}
};
}
