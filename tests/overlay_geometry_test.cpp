#include "../esp/drawing_view/OverlayGeometry.h"
#include <cassert>
#include <cmath>
#include <limits>

static void expectSegment(double x0, double y0, double x1, double y1,
                          double ax, double ay, double bx, double by) {
    assert(OverlayGeometry::ClipSegment(x0, y0, x1, y1, 100, 80));
    assert(std::abs(x0 - ax) < 0.0001 && std::abs(y0 - ay) < 0.0001);
    assert(std::abs(x1 - bx) < 0.0001 && std::abs(y1 - by) < 0.0001);
}

int main() {
    expectSegment(10, 20, 90, 70, 10, 20, 90, 70);
    expectSegment(-100, 40, 200, 40, 0, 40, 100, 40);
    expectSegment(50, -20, 50, 120, 50, 0, 50, 80);
    expectSegment(0, 0, 200, 160, 0, 0, 100, 80);
    expectSegment(200, 160, 0, 0, 100, 80, 0, 0);
    expectSegment(25, 25, 25, 25, 25, 25, 25, 25);
    expectSegment(-1e12, 40, 1e12, 40, 0, 40, 100, 40);
    double x0 = -5, y0 = -10, x1 = -5, y1 = 100;
    assert(!OverlayGeometry::ClipSegment(x0, y0, x1, y1, 100, 80));
    x0 = std::numeric_limits<double>::quiet_NaN();
    assert(!OverlayGeometry::ClipSegment(x0, y0, x1, y1, 100, 80));
    x0 = 0;
    assert(!OverlayGeometry::ClipSegment(x0, y0, x1, y1, 0, 80));
    assert(!OverlayGeometry::ClipSegment(x0, y0, x1, y1, 100,
                                        std::numeric_limits<double>::infinity()));
}
