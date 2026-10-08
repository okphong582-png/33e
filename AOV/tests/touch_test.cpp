#include "../ui/TouchState.h"
#include "../ui/FingerState.h"
#include <cassert>
#include <limits>
#include <cstdio>
int main() {
    aov::FingerState fingers;
    // Keep a joystick finger down while a different finger taps the menu.
    assert(fingers.update(10,true,false)==aov::FingerPhase::began);
    assert(fingers.update(10,true,false)==aov::FingerPhase::moved);
    assert(fingers.update(20,true,false)==aov::FingerPhase::began);
    assert(fingers.update(10,false,false)==aov::FingerPhase::ended);
    assert(fingers.update(20,true,false)==aov::FingerPhase::moved);
    assert(fingers.update(20,false,false)==aov::FingerPhase::ended);
    assert(fingers.update(20,false,false)==aov::FingerPhase::none);
    assert(fingers.update(20,true,false)==aov::FingerPhase::began);
    assert(fingers.update(20,true,true)==aov::FingerPhase::cancelled);
    assert(fingers.update(20,false,false)==aov::FingerPhase::none);
    aov::TouchState touch;
    // A stationary tap activates once, even if a duplicate lift follows.
    assert(touch.begin(1,40,100,0));
    assert(touch.move(1,43,102,.05));
    assert(touch.finish(1,false,true));
    assert(!touch.finish(1,false,true));
    // A second finger cannot steal or release the original menu gesture.
    assert(touch.begin(8,40,100,1));
    assert(!touch.begin(9,40,100,1.02));
    assert(!touch.finish(9,false,true));
    assert(touch.owns(8));
    assert(touch.finish(8,false,true));
    // Interleaved joystick and menu HID packets must still activate once.
    assert(touch.begin(20,40,100,1.1));
    assert(!touch.move(10,200,200,1.11));
    assert(!touch.finish(10,false,true));
    assert(touch.move(20,41,100,1.12));
    assert(touch.finish(20,false,true));
    // Dragging the A dot must never also open/close the menu.
    assert(touch.begin(2,40,100,2));
    assert(touch.move(2,70,120,2.1));
    assert(touch.move(2,40,100,2.2));
    assert(!touch.finish(2,false,true));
    // Cancellation and release outside the row cannot change a setting.
    assert(touch.begin(3,40,100,3));
    assert(!touch.finish(3,true,true));
    assert(touch.begin(3,40,100,3.1));
    assert(!touch.finish(3,false,false));
    // Recover after a lost release packet, while rejecting a fresh duplicate.
    assert(touch.begin(4,40,100,4));
    assert(!touch.begin(4,40,100,4.1));
    assert(touch.begin(5,40,100,7.1));
    assert(!touch.finish(4,false,true));
    assert(touch.finish(5,false,true));
    // Rotation/multi-touch cancellation resets the gesture immediately.
    assert(touch.begin(6,40,100,8));touch.cancel();
    assert(!touch.finish(6,false,true));
    assert(touch.begin(7,40,100,8.01));
    touch.cancel();
    assert(!touch.begin(0,std::numeric_limits<double>::quiet_NaN(),0,9));
    std::puts("AOV menu touch regressions passed");
}
