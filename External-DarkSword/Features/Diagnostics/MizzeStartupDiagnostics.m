#import "MizzeStartupDiagnostics.h"
#include <unistd.h>
static NSString *MizzeLogPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"Mizze-startup.log"];
}
void MizzeRecordStage(NSString *stage, NSString *detail) {
    @synchronized(NSProcessInfo.class) {
        NSString *path=MizzeLogPath();
        NSData *old=[NSData dataWithContentsOfFile:path];
        if(old.length>65536)old=nil;
        NSString *line=[NSString stringWithFormat:@"%@ pid=%d %@ — %@\n",NSDate.date,getpid(),stage,detail?:@""];
        NSMutableData *data=old?[old mutableCopy]:[NSMutableData data];
        [data appendData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [data writeToFile:path atomically:YES];
    }
}
NSString *MizzeStartupReport(void) {
    @synchronized(NSProcessInfo.class) {
        return [NSString stringWithContentsOfFile:MizzeLogPath() encoding:NSUTF8StringEncoding error:nil]?:@"Chưa có nhật ký khởi tạo.";
    }
}
