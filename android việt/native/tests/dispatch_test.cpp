#include <cstdint>
#include <limits>
#include <cstdlib>
#include "../SilentDirection.h"
#define CHECK(x) do { if(!(x)) std::abort(); } while(0)
int main() {
    using namespace silent;
    Point p{};CHECK(toward({10,2,0},{10,2,10},p));CHECK(p.z==1&&p.x==0);
    CHECK(!toward({},{},p));CHECK(!toward({},{std::numeric_limits<float>::infinity(),0,0},p));
    CHECK(fresh(100,300,250));CHECK(!fresh(100,300,251));CHECK(!fresh(300,400,250));
    CHECK(!fresh(100,250,250));CHECK(!fresh(100,40000,250));
    Point memory{0,0,1},desired{1,0,0};int calls=0,writes=0;
    auto read=[&](Point& v){v=memory;return true;};
    auto write=[&](Point v){memory=v;++writes;return true;};
    auto result=dispatch(desired,read,write,[]{return true;},[&]{++calls;CHECK(memory.x==1);});
    CHECK(result.redirected&&!result.restoreFailed&&calls==1&&writes==2&&memory.z==1);
    calls=writes=0;
    result=dispatch(desired,read,write,[]{return false;},[&]{++calls;});
    CHECK(!result.redirected&&calls==1&&writes==0);
    calls=writes=0;
    result=dispatch(desired,read,write,[]{return true;},[&]{++calls;memory={0,1,0};});
    CHECK(result.redirected&&calls==1&&writes==1&&memory.y==1);
    calls=writes=0;int currentCalls=0;
    result=dispatch(desired,read,write,[&]{return ++currentCalls==1;},[&]{++calls;});
    CHECK(!result.redirected&&calls==1&&writes==1&&memory.x==1);
    calls=0;
    result=dispatch(desired,[](Point&){return false;},write,[]{return true;},[&]{++calls;});
    CHECK(!result.redirected&&calls==1);
    calls=0;
    result=dispatch(desired,read,[](Point){return false;},[]{return true;},[&]{++calls;});
    CHECK(!result.redirected&&calls==1);
    calls=0;int attempt=0;
    result=dispatch(desired,read,[&](Point v){if(++attempt==2)return false;memory=v;return true;},[]{return true;},[&]{++calls;});
    CHECK(result.redirected&&result.restoreFailed&&calls==1);
    memory={0,0,1};calls=0;
    try {dispatch(desired,read,write,[]{return true;},[&]{++calls;throw 7;});CHECK(false);}
    catch(int value){CHECK(value==7&&calls==1&&memory.z==1);}
}
