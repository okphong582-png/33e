#pragma once

namespace ESPReferenceStyle {
struct RGB { float r, g, b; };
constexpr RGB Line{0.79f, 0.96f, 0.94f};
constexpr RGB Fov{0.89f, 0.99f, 0.98f};
constexpr RGB Skeleton{0.14f, 1.0f, 0.20f};
constexpr RGB Box{0.79f, 0.96f, 0.94f};
// Head, hip, left/right shoulders, hands, ankles, shoulder midpoint.
constexpr unsigned char SimpleEdges[][2] = {
    {0,8}, {8,1}, {2,3}, {2,4}, {3,5}, {1,6}, {1,7}
};
}
