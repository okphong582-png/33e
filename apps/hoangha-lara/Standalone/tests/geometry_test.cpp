#include "../HHOverlayGeometry.h"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){HHSize fixed{375,812};
 auto center=HHPoint{187.5,406};auto a=hh_overlay_point(center,fixed,1);assert(a.x==187.5&&a.y==406);
 auto left=hh_overlay_point({406,187.5},fixed,3),right=hh_overlay_point({406,187.5},fixed,4);assert(left.x==center.x&&left.y==center.y&&right.x==center.x&&right.y==center.y);
 for(int o=1;o<=4;o++){HHSize logical=o>2?HHSize{812,375}:fixed;for(auto p:{HHPoint{29,29},HHPoint{logical.width-29,logical.height-29}}){auto q=hh_overlay_point(p,fixed,o);assert(q.x>=0&&q.x<=fixed.width&&q.y>=0&&q.y<=fixed.height);}}
 auto p=hh_overlay_clamp({1000,-10},{812,375},58);assert(p.x==750&&p.y==4);assert(std::abs(hh_overlay_angle(3)+hh_overlay_angle(4))<1e-9);
 HHRect old{100,50,20,40};
 auto jitter=hh_overlay_stable_rect({100.2,49.8,20.1,40.2},&old);
 assert(jitter.x==old.x&&jitter.y==old.y&&jitter.width==old.width&&jitter.height==old.height);
 auto pan=hh_overlay_stable_rect({70.15,91.35,23.2,43.6},&old);
 assert(pan.x==70.25&&pan.y==91.25&&pan.width==23&&pan.height==43.75);
 auto resize=hh_overlay_stable_rect({100,50,20,41},&old);
 assert(resize.height==41);
 auto horizontal=hh_overlay_stable_rect({140,50.3,20,40},&old);
 assert(horizontal.x==140&&horizontal.y==50&&horizontal.height==40);
 auto vertical=hh_overlay_stable_rect({100.3,90,20,40},&old);
 assert(vertical.x==100&&vertical.width==20&&vertical.y==90);
 auto slow=old;
 for(int step=1;step<=100;step++){
  double x=100+step*0.1;
  slow=hh_overlay_stable_rect({x,50,20,40},&slow);
  assert(std::abs(slow.x-x)<=0.375+1e-9);
 }
 assert(slow.x>109.5);
 auto reverse=hh_overlay_stable_rect({20,10,20,40},&horizontal);
 assert(reverse.x==20&&reverse.y==10);
 std::cout<<"PASS overlay geometry: orientation, bubble bounds, static jitter and immediate camera movement\n";
}
