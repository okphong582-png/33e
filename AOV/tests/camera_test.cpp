#include "../core/CameraZoom.h"
#include <cassert>
#include <cstdio>
#include <map>
#include <limits>
struct Fake: aov::Memory {
    std::map<uint64_t,uint8_t> bytes;
    unsigned int writes=0;
    bool deny=false,denyFlag=false;
    bool copy(uint64_t address,void *out,size_t size) override {
        auto p=static_cast<uint8_t *>(out);
        for(size_t i=0;i<size;i++){auto it=bytes.find(address+i);if(it==bytes.end())return false;p[i]=it->second;}return true;
    }
    bool store(uint64_t address,const void *value,size_t size) override {
        if(deny||(denyFlag&&size==1))return false;
        auto p=static_cast<const uint8_t *>(value);
        for(size_t i=0;i<size;i++)if(!bytes.count(address+i))return false;
        for(size_t i=0;i<size;i++){bytes[address+i]=p[i];}
        writes++;return true;
    }
    template<class T>void put(uint64_t address,T value){
        auto p=reinterpret_cast<uint8_t *>(&value);for(size_t i=0;i<sizeof(value);i++)bytes[address+i]=p[i];
    }
    float value(uint64_t address){float x=0;assert(read(address,x));return x;}
};
int main(){
    constexpr uint64_t base=0x100000,method=0x20000,owner=0x21000,context=0x22000,klass=0x23000,statics=0x24000,system=0x25000,moba=0x26000,native=0x27000;
    Fake m;m.put(base+aov::cameraMethod,method);m.put(method+aov::methodContext,owner);
    m.put(owner+aov::classContext,context);m.put(context+aov::contextClass,klass);m.put(klass+aov::staticFields,statics);m.put(statics,system);
    m.put(system+aov::mobaCamera,moba);m.put(moba+aov::nativeCamera,native);
    m.put(moba+aov::cameraStarted,uint8_t(1));m.put(moba+aov::cameraDirty,uint8_t(0));
    m.put(moba+aov::cameraZoomAmount,20.f);m.put(moba+aov::cameraAdditionZoom,2.f);
    aov::CameraZoom zoom;
    assert(zoom.update(m,base,1)==aov::ZoomState::off&&m.writes==0);
    assert(zoom.update(m,base,2)==aov::ZoomState::active);
    assert(m.value(moba+aov::cameraAdditionZoom)==24.f); // (20+2)*2-20
    auto writes=m.writes;
    assert(zoom.update(m,base,2)==aov::ZoomState::active&&m.writes==writes);
    assert(zoom.update(m,base,4)==aov::ZoomState::active);
    assert(m.value(moba+aov::cameraAdditionZoom)==68.f); // No compounding.
    assert(zoom.update(m,base,1)==aov::ZoomState::off);
    assert(m.value(moba+aov::cameraAdditionZoom)==2.f);
    // Game-owned changes become the new baseline and survive disabling.
    assert(zoom.update(m,base,2)==aov::ZoomState::active);
    m.put(moba+aov::cameraAdditionZoom,3.f);
    assert(zoom.update(m,base,2)==aov::ZoomState::active);
    assert(m.value(moba+aov::cameraAdditionZoom)==26.f);
    assert(zoom.update(m,base,1)==aov::ZoomState::off&&m.value(moba+aov::cameraAdditionZoom)==3.f);
    // Permissions and partial writes cannot leave a changed float behind.
    m.deny=true;assert(zoom.update(m,base,2)==aov::ZoomState::denied);m.deny=false;
    m.denyFlag=true;assert(zoom.update(m,base,2)==aov::ZoomState::denied);m.denyFlag=false;
    assert(m.value(moba+aov::cameraAdditionZoom)==3.f);
    // A changed native pointer must not restore a previous scene's value.
    assert(zoom.update(m,base,2)==aov::ZoomState::active);
    m.put(moba+aov::nativeCamera,native+0x1000);m.put(moba+aov::cameraAdditionZoom,5.f);
    assert(zoom.update(m,base,1)==aov::ZoomState::off&&m.value(moba+aov::cameraAdditionZoom)==5.f);
    // Bad/unstarted objects are read-only until a valid camera is available.
    m.put(moba+aov::cameraStarted,uint8_t(0));writes=m.writes;
    assert(zoom.update(m,base,2)==aov::ZoomState::waiting&&m.writes==writes);
    m.put(moba+aov::cameraStarted,uint8_t(1));m.put(moba+aov::cameraZoomAmount,std::numeric_limits<float>::quiet_NaN());
    assert(zoom.update(m,base,2)==aov::ZoomState::waiting&&m.writes==writes);
    assert(aov::zoomMultiplier(-1)==1&&aov::zoomMultiplier(99)==4&&aov::zoomMultiplier(2.16f)==2.2f);
    assert(aov::zoomMultiplier(std::numeric_limits<float>::infinity())==1);
    std::puts("AOV camera zoom: bounds, restore, permissions and stale cameras passed");
}
