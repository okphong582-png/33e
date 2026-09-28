#include "../esp/Core/AimPoint.h"
#include <cassert>
#include <iostream>

int main() {
    Vector3 head(5, 1.8f, 3), hip(5, 0.9f, 3);
    Vector3 neck = AimPoint::Neck(head, hip);
    assert(neck.y > 1.69f && neck.y < head.y);
    assert(neck.x == head.x && neck.z == head.z);
    assert(Vector3::Distance(neck, head) <= 0.101f);
    for (int i = 0; i < 360; ++i) {
        float angle = i * 0.0174532925f;
        Vector3 tiltedHead = hip + Vector3(std::sin(angle) * 0.8f, std::cos(angle) * 0.8f, 0);
        Vector3 point = AimPoint::Neck(tiltedHead, hip);
        assert(AimPoint::Valid(point));
        assert(Vector3::Distance(point, tiltedHead) <= 0.101f);
        assert(Vector3::Distance(point, hip) > 0.69f);
    }
    assert(AimPoint::Neck(head, Vector3()) == head);
    assert(AimPoint::Neck(head, Vector3(0, -100, 0)) == head);
    assert(AimPoint::Neck(Vector3(NAN, 0, 0), hip) == Vector3());
    std::cout << "Neck aim stays near the head for upright and rotated poses\n";
}
