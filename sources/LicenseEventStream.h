#pragma once
#include <string>

namespace LicenseEvents {
// Treat events as invalidations only; a fresh HTTPS GET still checks the record,
// server clock and device binding before granting access.
struct Parser {
    std::string pending;
    enum { Refresh=1, Denied=2, Reconnect=4 };
    unsigned Feed(const char *bytes,size_t size) {
        if(size>65536||pending.size()+size>65536){pending.clear();return Reconnect;}
        unsigned result=0;
        for(size_t i=0;i<size;++i)if(bytes[i]!='\r')pending+=bytes[i];
        size_t end;
        while((end=pending.find("\n\n"))!=std::string::npos){
            const auto event=pending.substr(0,end);pending.erase(0,end+2);
            size_t begin=0;
            while(begin<event.size()){
                const size_t next=event.find('\n',begin);
                auto line=event.substr(begin,next==std::string::npos?std::string::npos:next-begin);
                if(line.compare(0,6,"event:")==0){
                    auto name=line.substr(6);while(!name.empty()&&name.front()==' ')name.erase(0,1);
                    if(name=="put"||name=="patch")result|=Refresh;
                    if(name=="cancel"||name=="auth_revoked")result|=Denied;
                }
                if(next==std::string::npos)break;
                begin=next+1;
            }
        }
        return result;
    }
};
}
