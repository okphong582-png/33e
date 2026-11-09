#include "../HHGameSchedule.h"
#include <cassert>
#include <iostream>
int main(){
 HHGameSchedule s{};int work=0,geometry=0;
 // Starting/dragging/opening the menu while ESP is off never schedules game work.
 for(int i=0;i<1200;i++){auto w=hh_game_work(&s,false,i*.05);assert(!w.sample&&!w.geometry&&!w.disconnect);}
 auto first=hh_game_work(&s,true,60);assert(first.changed&&first.sample&&first.geometry);
 hh_game_observe_foreground(&s,123);assert(s.foregroundPID==0);
 hh_game_observe_foreground(&s,123);assert(s.foregroundPID==123);
 hh_game_observe_foreground(&s,456);assert(s.foregroundPID==0);
 hh_game_observe_foreground(&s,456);assert(s.foregroundPID==456);
 hh_game_observe_foreground(&s,0);assert(s.foregroundPID==0);
 hh_game_observe_foreground(&s,456);assert(s.foregroundPID==0);
 for(int i=1;i<=1000;i++){auto w=hh_game_work(&s,true,60+i*.01);work+=w.sample;geometry+=w.geometry;}
 assert(work>=140&&work<=166&&geometry<=5);
 hh_game_sample_finished(&s,70.5);
 assert(!hh_game_work(&s,true,70.51).sample);
 assert(hh_game_work(&s,true,70.52).sample);
 auto off=hh_game_work(&s,false,71);assert(off.changed&&off.disconnect&&!off.sample&&!off.geometry);
 assert(s.foregroundPID==0&&s.observedPID==0);
 auto idle=hh_game_work(&s,false,72);assert(!idle.disconnect&&!idle.sample);
 auto again=hh_game_work(&s,true,73);assert(again.changed&&again.sample&&again.geometry);
 std::cout<<"PASS game scheduler: no work while disabled, stable foreground PID required, bounded polling\n";
}
