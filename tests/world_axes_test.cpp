#include "../esp/drawing_view/WorldAxes.h"
#include <cassert>
#include <limits>
#include <iostream>

static constexpr double width=844,height=390;
static void bounded(const WorldAxes::Triad &triad) {
    assert(triad.valid);
    for(const auto &axis : triad.axes) {
        assert(axis.valid);
        for(const auto &p : {axis.from,axis.to}) {
            assert(std::isfinite(p.x)&&std::isfinite(p.y));
            assert(p.x>=0&&p.x<=width&&p.y>=0&&p.y<=height);
        }
    }
}
int main() {
    using namespace WorldAxes;
    // Orbit the camera around a fixed enemy. The three axes stay in world space.
    for(int degrees=0;degrees<=360;++degrees) {
        const double angle=degrees*3.141592653589793/180;
        const float c=std::cos(angle),s=std::sin(angle);
        float m[16]={c,0,0,-s, 0,1,0,0, -s,0,0,-c, 0,0,0,5};
        const auto triad=Project({0,0,0},m,width,height);
        bounded(triad);assert(!triad.edge);
        assert(std::abs(triad.axes[0].from.x-width*.5)<1e-6);
        const double xdx=triad.axes[0].to.x-triad.axes[0].from.x;
        const double zdx=triad.axes[2].to.x-triad.axes[2].from.x;
        if(std::abs(c)>.01)assert(xdx*c>0);
        if(std::abs(s)>.01)assert(zdx*(-s)>0);
        assert(triad.axes[1].to.y<triad.axes[1].from.y);
        const double expectedX=width*.5*(1+.65*c/(5-.65*s));
        assert(std::abs(triad.axes[0].to.x-expectedX)<1e-4);
    }
    float m[16]={1,0,0,0, 0,1,0,0, 0,0,0,-1, 0,0,0,5};
    // Pitch and roll change screen directions without changing the world axes.
    for (double pitch : {-1.2,0.0,1.2}) for (double roll : {0.0,.7}) for (int yaw=0;yaw<360;yaw+=15) {
        const double a=yaw*3.141592653589793/180;
        const double right[3]={std::cos(a),0,-std::sin(a)};
        const double up[3]={-std::sin(a)*std::sin(pitch),std::cos(pitch),-std::cos(a)*std::sin(pitch)};
        const double back[3]={std::sin(a)*std::cos(pitch),std::sin(pitch),std::cos(a)*std::cos(pitch)};
        float camera[16]={};camera[15]=5;
        for(int i=0;i<3;++i) {
            camera[i*4]=right[i]*std::cos(roll)+up[i]*std::sin(roll);
            camera[i*4+1]=up[i]*std::cos(roll)-right[i]*std::sin(roll);
            camera[i*4+3]=-back[i];
        }
        const auto axes=Project({0,0,0},camera,width,height);bounded(axes);
        for(int i=0;i<3;++i) {
            const double w=5+.65*camera[i*4+3];
            assert(std::abs(axes.axes[i].to.x-width*.5*(1+.65*camera[i*4]/w))<1e-4);
            assert(std::abs(axes.axes[i].to.y-height*.5*(1-.65*camera[i*4+1]/w))<1e-4);
        }
    }
    for(Vec3 enemy : {Vec3{30,0,0},Vec3{-30,0,0},Vec3{0,30,0},Vec3{0,0,10},Vec3{10,3,10}}) {
        const auto triad=Project(enemy,m,width,height);bounded(triad);assert(triad.edge);
    }
    // An axis that crosses the near plane must produce finite clipped geometry.
    const auto near=Project({.001,0,4.98},m,width,height);
    assert(near.valid);for(const auto &axis : near.axes) if(axis.valid) {
        assert(std::isfinite(axis.to.x)&&std::isfinite(axis.to.y));
        assert(axis.to.x>=0&&axis.to.x<=width&&axis.to.y>=0&&axis.to.y<=height);
    }
    assert(!Project({0,0,0},nullptr,width,height).valid);
    assert(!Project({0,0,0},m,0,height).valid);
    assert(!Project({std::numeric_limits<double>::quiet_NaN(),0,0},m,width,height).valid);
    m[4]=std::numeric_limits<float>::infinity();
    assert(!Project({0,0,0},m,width,height).valid);
    std::cout<<"World XYZ: 360-degree rotation, edge markers and near clipping passed\n";
}
