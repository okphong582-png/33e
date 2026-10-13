#include "../Features/License/LicenseEventStream.h"
#include <cassert>
#include <cstring>
#include <iostream>
int main(){
    using namespace LicenseEvents;
    Parser p;
    const char *event="event: patch\r\ndata: {\"path\":\"/lock\",\"data\":null}\r\n\r\n";
    unsigned result=0;
    for(size_t i=0;i<std::strlen(event);++i)result|=p.Feed(event+i,1);
    assert(result==Parser::Refresh&&p.pending.empty());
    const std::string multiple="event: keep-alive\ndata: null\n\nevent: put\ndata: {}\n\nevent: cancel\ndata: null\n\n";
    assert(p.Feed(multiple.data(),multiple.size())==(Parser::Refresh|Parser::Denied));
    const std::string bad(65537,'x');assert(p.Feed(bad.data(),bad.size())==Parser::Reconnect);
    assert(p.pending.empty());
    assert(p.Feed("data: event: patch\n\n",20)==0);
    assert(p.Feed("event: put",10)==0);
    assert(p.Feed("\n\n",2)==Parser::Refresh);
    std::cout<<"License SSE: fragmented frames, combined events, keepalive, cancellation and bounds passed\n";
}
