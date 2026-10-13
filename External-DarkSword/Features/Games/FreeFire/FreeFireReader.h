#pragma once
#include <array>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>

// Read-only profile for the supplied TH 1.132.1 iOS UnityFramework.
// UUID c8de7371-cba7-3e7a-9e09-30b8e1b89073; never reuse for MAX/new OB.
namespace FreeFireESP {
constexpr std::array<uint8_t,16> UUID = {0xc8,0xde,0x73,0x71,0xcb,0xa7,0x3e,0x7a,0x9e,0x09,0x30,0xb8,0xe1,0xb8,0x90,0x73};
constexpr uint64_t FacadeTypeInfo = 0xbb46a50;
constexpr size_t MaxPlayers = 256, MaxTargets = 32;
struct Vec3 { float x=0, y=0, z=0; };
struct Transform { float position[4], rotation[4], scale[4]; };
struct Target { uint64_t id=0; float headX=0,headY=0,footX=0,footY=0,x=0,y=0,w=0,h=0; };
struct Frame { std::array<Target,MaxTargets> targets{}; size_t count=0; };
inline bool valid(uint64_t a) { return a>0x10000 && a<0x80000000000ull && (a&7)==0; }
inline bool finite(Vec3 v) { return std::isfinite(v.x)&&std::isfinite(v.y)&&std::isfinite(v.z)&&std::abs(v.x)<100000&&std::abs(v.y)<100000&&std::abs(v.z)<100000; }

template<class Read> class Reader {
    Read read;
    template<class T> bool value(uint64_t a,T &out) {
        out={};return a>0x10000 && a<0x80000000000ull-sizeof(T) && read(a,&out,sizeof(T));
    }
    bool ptr(uint64_t a,uint64_t &out) { return value(a,out)&&valid(out); }
    bool hp(uint64_t player,uint16_t &out) {
        uint64_t pool,entries,entry;
        return ptr(player+0x70,pool)&&ptr(pool+0x10,entries)&&ptr(entries+0x20,entry)&&value(entry+0x18,out);
    }
    bool position(uint64_t transform,Vec3 &result) {
        uint64_t inner,matrix,list,indices;int32_t index;
        if(!ptr(transform+0x10,inner)||!ptr(inner+0x38,matrix)||!value(inner+0x40,index)||index<0||index>8192||
           !ptr(matrix+0x18,list)||!ptr(matrix+0x20,indices)||!value(list+48ull*index,result)||!finite(result))return false;
        std::array<int32_t,65> visited{};size_t depth=1;visited[0]=index;
        int32_t parent;if(!value(indices+4ull*index,parent))return false;
        while(parent>=0) {
            if(parent>8192||depth>=visited.size())return false;
            for(size_t i=0;i<depth;i++)if(visited[i]==parent)return false;
            visited[depth++]=parent;
            Transform t;if(!value(list+48ull*parent,t))return false;
            const float x=t.rotation[0],y=t.rotation[1],z=t.rotation[2],w=t.rotation[3];
            const float sx=result.x*t.scale[0],sy=result.y*t.scale[1],sz=result.z*t.scale[2];
            result={t.position[0]+sx+sx*(-2*y*y-2*z*z)+sy*(-2*w*z+2*y*x)+sz*(2*z*x+2*w*y),
                    t.position[1]+sy+sx*(2*x*y+2*w*z)+sy*(-2*z*z-2*x*x)+sz*(-2*w*x+2*z*y),
                    t.position[2]+sz+sx*(-2*w*y+2*x*z)+sy*(2*y*z+2*w*x)+sz*(-2*x*x-2*y*y)};
            if(!finite(result)||!value(indices+4ull*parent,parent))return false;
        }
        return parent==-1;
    }
    bool bone(uint64_t player,uint64_t field,Vec3 &out) {
        uint64_t node,transform;return ptr(player+field,node)&&ptr(node+0x10,transform)&&position(transform,out);
    }
    bool context(uint64_t base,uint64_t &game,uint64_t &match,uint64_t &local) {
        uint64_t type,statics;
        if(!ptr(base+FacadeTypeInfo,type)||!ptr(type+0xb8,statics))return false;
        if(!ptr(statics+8,game)&&!ptr(statics,game))return false;
        return ptr(game+0x90,match)&&ptr(match+0xd8,local);
    }
    static bool project(Vec3 v,const float *m,float width,float height,float &x,float &y) {
        const float w=m[3]*v.x+m[7]*v.y+m[11]*v.z+m[15];
        if(!std::isfinite(w)||w<=0.001f)return false;
        x=width*0.5f*(1+(m[0]*v.x+m[4]*v.y+m[8]*v.z+m[12])/w);
        y=height*0.5f*(1-(m[1]*v.x+m[5]*v.y+m[9]*v.z+m[13])/w);
        return std::isfinite(x)&&std::isfinite(y);
    }
public:
    explicit Reader(Read r):read(r) {}
    bool supports(uint64_t base) {
        struct Header { uint32_t magic,cpu,subtype,type,commands,bytes,flags,reserved; } h{};
        if(!valid(base)||!value(base,h)||h.magic!=0xfeedfacf||h.cpu!=0x100000c||h.commands>128||h.bytes>65536)return false;
        uint64_t offset=32,end=32ull+h.bytes;
        for(uint32_t i=0;i<h.commands;i++) {
            struct {uint32_t kind,size;} cmd{};
            if(offset+8>end||!value(base+offset,cmd)||cmd.size<8||(cmd.size&3)||offset+cmd.size>end)return false;
            if(cmd.kind==0x1b) {std::array<uint8_t,16> uuid{};return cmd.size==24&&value(base+offset+8,uuid)&&uuid==UUID;}
            offset+=cmd.size;
        }
        return false;
    }
    bool snapshot(uint64_t base,float width,float height,Frame &out) {
        out={};
        if(!std::isfinite(width)||!std::isfinite(height)||width<1||height<1||width>16384||height>16384)return false;
        uint64_t game,match,local,dict,entries,controller,camera,inner;
        uint8_t myTeam;uint16_t localHP;
        if(!context(base,game,match,local)||!value(local+0x410,myTeam)||!hp(local,localHP)||localHP==0||
           !ptr(match+0x148,dict)||!ptr(dict+0x18,entries)||!ptr(game+0xd8,controller)||!ptr(controller+0x20,camera)||!ptr(camera+0x10,inner))return false;
        int32_t count,version;uint64_t capacity;
        if(!value(dict+0x20,count)||!value(dict+0x24,version)||!value(entries+0x18,capacity)||capacity>MaxPlayers||count<0||uint64_t(count)>capacity)return false;
        struct Entry { int32_t hash,next;uint8_t key;uint8_t padding[7];uint64_t player; };
        static_assert(sizeof(Entry)==24,"Dictionary<byte,Player> ABI");
        std::array<Entry,MaxPlayers> roster{};
        if(count&&!read(entries+0x20,roster.data(),size_t(count)*sizeof(Entry)))return false;
        std::array<float,16> view{},projection{},matrix{};
        if(!value(inner+0x80,view)||!value(inner+0xc0,projection))return false;
        for(float f:view)if(!std::isfinite(f))return false;
        for(float f:projection)if(!std::isfinite(f))return false;
        for(int c=0;c<4;c++)for(int r=0;r<4;r++)for(int k=0;k<4;k++)matrix[c*4+r]+=projection[k*4+r]*view[c*4+k];
        Frame pending{};
        for(int i=0;i<count&&pending.count<MaxTargets;i++) {
            const auto &entry=roster[i];uint64_t player=entry.player;
            if(entry.hash<0||!valid(player)||player==local)continue;
            bool duplicate=false;for(size_t j=0;j<pending.count;j++)if(pending.targets[j].id==player)duplicate=true;
            if(duplicate)continue;
            uint8_t team;uint16_t health;
            if(!value(player+0x410,team)||team==myTeam||!hp(player,health)||!health)continue;
            Vec3 head,foot;
            if(!bone(player,0x6a0,head)||!bone(player,0x6d8,foot))continue;
            Target t;t.id=player;
            if(!project(head,matrix.data(),width,height,t.headX,t.headY)||!project(foot,matrix.data(),width,height,t.footX,t.footY))continue;
            t.h=std::abs(t.footY-t.headY);t.w=t.h*0.48f;t.x=(t.headX+t.footX)*0.5f-t.w*0.5f;t.y=std::min(t.headY,t.footY);
            if(t.h<2||t.h>height*2||t.x+t.w<0||t.x>width||t.y+t.h<0||t.y>height)continue;
            pending.targets[pending.count++]=t;
        }
        uint64_t gameNow,matchNow,localNow,entriesNow;int32_t versionNow,countNow;
        if(!context(base,gameNow,matchNow,localNow)||gameNow!=game||matchNow!=match||localNow!=local||
           !ptr(dict+0x18,entriesNow)||entriesNow!=entries||!value(dict+0x24,versionNow)||versionNow!=version||!value(dict+0x20,countNow)||countNow!=count)return false;
        out=pending;return true;
    }
};
}
