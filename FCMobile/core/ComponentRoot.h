#pragma once
#include "ShotSettings.h"
namespace fcm {
inline bool validPointer(uint64_t p){return p>=0x10000&&p<0x0000800000000000ULL&&(p&7)==0;}
struct ComponentRoot {
    uint64_t global=0,owner=0,table=0,wrapper=0,object=0;
    uint32_t id=0;
    bool match=false;
    bool unchanged(Memory &m)const{
        uint64_t a=0,b=0,c=0,d=0;
        if(!m.read(global,a)||a!=owner)return false;
        if(match)b=a;else if(!m.read(owner+8,b))return false;
        if(match){int32_t count=0;if(!m.read(table+id*32+0x18,count)||count!=1)return false;}
        return b==table&&m.read(table+id*32+0x20,c)&&c==wrapper&&m.read(wrapper+8,d)&&d==object;
    }
};
inline bool resolveComponent(Memory &m,uint64_t image,uint32_t id,bool match,ComponentRoot &out){
    ComponentRoot r;r.match=match;r.id=id;r.global=image+(match?0xa3f4318:0xa263b60);
    if(!m.read(r.global,r.owner)||!validPointer(r.owner))return false;
    if(match)r.table=r.owner;else if(!m.read(r.owner+8,r.table)||!validPointer(r.table))return false;
    // Native component slots contain a count and a pointer to {entity ID, object} records.
    if(match){int32_t count=0;if(!m.read(r.table+id*32+0x18,count)||count!=1)return false;}
    if(!m.read(r.table+id*32+0x20,r.wrapper)||!validPointer(r.wrapper)||
       !m.read(r.wrapper+8,r.object)||!validPointer(r.object))return false;
    out=r;return true;
}
inline bool resolveComponent(Memory &m,uint64_t image,uint32_t id,ComponentRoot &out){
    return resolveComponent(m,image,id,true,out)||resolveComponent(m,image,id,false,out);
}
}
