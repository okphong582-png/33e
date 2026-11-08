#pragma once
#include <math.h>
typedef struct {double x,y;} HHPoint;
typedef struct {double width,height;} HHSize;
static inline HHPoint hh_overlay_point(HHPoint p,HHSize fixed,int orientation){
 switch(orientation){case 2:return (HHPoint){fixed.width-p.x,fixed.height-p.y};case 3:return (HHPoint){fixed.width-p.y,p.x};case 4:return (HHPoint){p.y,fixed.height-p.x};default:return p;}
}
static inline double hh_overlay_angle(int orientation){switch(orientation){case 2:return 3.141592653589793;case 3:return 1.5707963267948966;case 4:return -1.5707963267948966;default:return 0;}}
static inline HHPoint hh_overlay_clamp(HHPoint p,HHSize size,double extent){
 p.x=fmin(fmax(4,p.x),fmax(4,size.width-extent-4));p.y=fmin(fmax(4,p.y),fmax(4,size.height-extent-4));return p;
}
