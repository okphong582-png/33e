#include "../HHOverlayGeometry.h"
#include <cassert>
#include <cmath>
#include <iostream>
int main(){HHSize fixed{375,812};
 auto center=HHPoint{187.5,406};auto a=hh_overlay_point(center,fixed,1);assert(a.x==187.5&&a.y==406);
 auto left=hh_overlay_point({406,187.5},fixed,3),right=hh_overlay_point({406,187.5},fixed,4);assert(left.x==center.x&&left.y==center.y&&right.x==center.x&&right.y==center.y);
 for(int o=1;o<=4;o++){HHSize logical=o>2?HHSize{812,375}:fixed;for(auto p:{HHPoint{29,29},HHPoint{logical.width-29,logical.height-29}}){auto q=hh_overlay_point(p,fixed,o);assert(q.x>=0&&q.x<=fixed.width&&q.y>=0&&q.y<=fixed.height);}}
 auto p=hh_overlay_clamp({1000,-10},{812,375},58);assert(p.x==750&&p.y==4);assert(std::abs(hh_overlay_angle(3)+hh_overlay_angle(4))<1e-9);
 std::cout<<"PASS overlay geometry: both landscape directions, portrait, upside down and bubble clamping\n";
}
