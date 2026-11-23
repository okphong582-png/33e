#pragma once
namespace MizzeDirectLeasePolicy {
// Only trusted Firebase timestamps and monotonic elapsed time enter this policy.
inline double Remaining(double now,double issued,double expiry,double recordNow,double elapsed){
 if(!(now>0&&now<1e16&&issued>0&&issued<1e16&&expiry>0&&expiry<1e16&&recordNow>0&&recordNow<1e16&&elapsed>=0&&elapsed<12))return 0;
 if(issued>now+2000)return 0;
 double age=now>issued?(now-issued)/1000:0;
 double trusted=now>recordNow?now:recordNow;
 double ttl=12-age,license=(expiry-trusted)/1000;
 if(license<ttl)ttl=license;
 double left=ttl-elapsed;return left>0&&left<=12?left:0;
}
}
