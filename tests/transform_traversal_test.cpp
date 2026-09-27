#include "../esp/Core/TransformTraversal.h"
#include <cassert>
#include <iostream>
#include <vector>

int main() {
    using TransformTraversal::Walk;
    int reads = 0, applied = 0;
    auto apply = [&](int) { ++applied; return true; };
    // A root is complete without applying a parent.
    assert(Walk(0, [&](int, int &p) { ++reads; p = -1; return true; }, apply));
    assert(reads == 1 && applied == 0);
    // A failed remote read must not be interpreted as parent index zero.
    reads = applied = 0;
    assert(!Walk(8, [&](int, int &p) { ++reads; p = 0; return false; }, apply));
    assert(reads == 1 && applied == 0);
    std::vector<int> parents{1, 2, 0};
    auto read = [&](int index, int &p) { ++reads; p = parents.at(index); return true; };
    reads = applied = 0;
    assert(!Walk(0, read, apply));
    assert(reads == 3 && applied == 2);
    parents = {0};
    assert(!Walk(0, read, apply));
    parents = {-2};
    assert(!Walk(0, read, apply));
    parents = {TransformTraversal::MaxIndex + 1};
    assert(!Walk(0, read, apply));
    assert(!Walk(-1, read, apply));
    assert(!Walk(TransformTraversal::MaxIndex + 1, read, apply));
    // The depth boundary accepts a complete chain, rejects a longer one.
    parents.resize(66);
    for (int i = 0; i < 65; ++i) parents[i] = i + 1;
    parents[64] = -1;
    reads = applied = 0;
    assert(Walk(0, read, apply));
    assert(reads == 65 && applied == 64);
    parents[64] = 65; parents[65] = -1;
    reads = applied = 0;
    assert(!Walk(0, read, apply));
    assert(reads == 65 && applied == 64);
    parents = {1, -1};
    assert(!Walk(0, read, [](int) { return false; }));
    // Repeated corrupt skeletons stay bounded even at maximum player count.
    parents = {1, 2, 0};
    reads = applied = 0;
    for (int frame = 0; frame < 10000; ++frame)
        for (int player = 0; player < 256; ++player)
            assert(!Walk(0, read, apply));
    assert(reads == 10000 * 256 * 3 && applied == 10000 * 256 * 2);
    std::cout << "Transform traversal: all checks passed\n";
}
