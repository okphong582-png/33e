#pragma once
#include <math.h>
typedef struct {double x,y;} HHPoint;
typedef struct {double width,height;} HHSize;
typedef struct {double x,y,width,height;} HHRect;

static inline HHRect hh_overlay_stable_rect(HHRect next,const HHRect *previous){
 const double right=next.x+next.width,bottom=next.y+next.height;
 const double tolerance=0.375;
 // Stabilize each axis independently: movement on X must not release jitter on Y.
 // Compare against displayed geometry so small deliberate movements accumulate.
 const int holdX=previous&&fabs(next.x-previous->x)<=tolerance&&
    fabs(right-(previous->x+previous->width))<=tolerance;
 const int holdY=previous&&fabs(next.y-previous->y)<=tolerance&&
    fabs(bottom-(previous->y+previous->height))<=tolerance;
 const double x=holdX?previous->x:round(next.x*4)*0.25;
 const double y=holdY?previous->y:round(next.y*4)*0.25;
 return (HHRect){x,y,holdX?previous->width:round(right*4)*0.25-x,
    holdY?previous->height:round(bottom*4)*0.25-y};
}
static inline HHPoint hh_overlay_point(HHPoint p,HHSize fixed,int orientation){
 switch(orientation){case 2:return (HHPoint){fixed.width-p.x,fixed.height-p.y};case 3:return (HHPoint){fixed.width-p.y,p.x};case 4:return (HHPoint){p.y,fixed.height-p.x};default:return p;}
}
static inline double hh_overlay_angle(int orientation){switch(orientation){case 2:return 3.141592653589793;case 3:return 1.5707963267948966;case 4:return -1.5707963267948966;default:return 0;}}
static inline HHPoint hh_overlay_clamp(HHPoint p,HHSize size,double extent){
 p.x=fmin(fmax(4,p.x),fmax(4,size.width-extent-4));p.y=fmin(fmax(4,p.y),fmax(4,size.height-extent-4));return p;
}
