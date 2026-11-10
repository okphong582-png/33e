#include "../HHAimMath.h"
#include <cassert>
#include <cmath>
#include <iostream>

int main(){
 using namespace HHAim;
 const auto p=neck({0,1.8f,0},{0,.9f,0});
 assert(std::abs(p.y-1.7f)<.001f);
 const auto fallback=neck({0,1.8f,0},{0,1.8f,0});
 assert(fallback.y==1.8f);
 Candidate candidates[]={
  {1,{0,1,3},{0,0,3},505,400,20,true},
  {2,{0,1,4},{0,0,4},500,400,30,true},
  {3,{0,1,5},{0,0,5},500,400,5,false}
 };
 assert(select(candidates,3,1000,800,100,100,0)==2);
 assert(select(candidates,3,1000,800,100,100,1)==1);
 assert(select(candidates,3,1000,800,100,25,0)==1);
 assert(select(candidates,3,1000,800,2,100,0)==2);
 Quaternion q{};
 assert(look({0,0,0},{0,0,1},q));
 assert(std::abs(q.w-1)<.001f&&std::abs(q.x)<.001f&&std::abs(q.y)<.001f);
 assert(look({0,0,0},{1,0,0},q));
 assert(std::abs(q.y-.7071068f)<.001f&&std::abs(q.w-.7071068f)<.001f);
 assert(!look({0,0,0},{0,0,0},q));
 std::cout<<"PASS aim geometry: neck, target gates, retention and rotations\n";
}
