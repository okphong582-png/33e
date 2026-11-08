#include "../HHGameSchedule.h"
#include <cassert>
#include <iostream>
int main(){
 HHGameSchedule s{};int work=0,geometry=0;
 // Starting/dragging/opening the menu while ESP is off never schedules game work.
 for(int i=0;i<1200;i++){auto w=hh_game_work(&s,false,i*.05);assert(!w.sample&&!w.geometry&&!w.disconnect);}
 auto first=hh_game_work(&s,true,60);assert(first.changed&&first.sample&&first.geometry);
 for(int i=1;i<=200;i++){auto w=hh_game_work(&s,true,60+i*.05);work+=w.sample;geometry+=w.geometry;}
 assert(work<=50&&geometry<=5);
 auto off=hh_game_work(&s,false,71);assert(off.changed&&off.disconnect&&!off.sample&&!off.geometry);
 auto idle=hh_game_work(&s,false,72);assert(!idle.disconnect&&!idle.sample);
 auto again=hh_game_work(&s,true,73);assert(again.changed&&again.sample&&again.geometry);
 std::cout<<"PASS game scheduler: disabled ESP has zero game work, 5 Hz samples, 0.5 Hz geometry, one disconnect per transition\n";
}
