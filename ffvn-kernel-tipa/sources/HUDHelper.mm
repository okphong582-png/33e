#import "HUDHelper.h"
#import "MizzeLicense.h"

#import "rootless.h"
#import "../esp/Core/libproc.h"
#import <spawn.h>
#import <notify.h>
#import <sys/wait.h>
#import <signal.h>
#import <errno.h>
#import <limits.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <mach/mach.h>

extern "C" char **environ;
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t *, uid_t, uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *, uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *, uid_t);

static pid_t spawnedHUD = 0;
static void WriteStatus(NSString *state, NSString *message, pid_t pid);
static NSString *StatusPath(void) { return [ROOT_PATH_NS(PID_PATH) stringByAppendingString:@".state.plist"]; }
static NSString *HealthPath(void) { return [ROOT_PATH_NS(PID_PATH) stringByAppendingString:@".health.plist"]; }
static NSDictionary *ReadStatus(void) { return [NSDictionary dictionaryWithContentsOfFile:StatusPath()] ?: @{}; }
static pid_t ReadPID(void) {
    NSString *text = [NSString stringWithContentsOfFile:ROOT_PATH_NS(PID_PATH) encoding:NSUTF8StringEncoding error:nil];
    long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
    if (![scanner scanLongLong:&value] || !scanner.isAtEnd || value <= 1 || value > INT_MAX) return 0;
    return (pid_t)value;
}
static BOOL ProcessAlive(pid_t pid) {
    if (pid <= 1) return NO;
    if (pid == spawnedHUD) {
        int status = 0;
        if (waitpid(pid, &status, WNOHANG) == pid) {
            spawnedHUD = 0;
            NSDictionary *saved = ReadStatus();
            if ([saved[@"state"] isEqual:@"ready"] || [saved[@"state"] isEqual:@"starting"]) {
                NSString *message;
                if (WIFSIGNALED(status)) {
                    message = [NSString stringWithFormat:@"Tiến trình menu bị dừng bởi signal %d. Gửi mã này để kiểm tra lỗi.", WTERMSIG(status)];
                } else {
                    message = [NSString stringWithFormat:@"Tiến trình menu kết thúc (exit %d).", WIFEXITED(status) ? WEXITSTATUS(status) : -1];
                }
                WriteStatus(@"failed", message, 0);
            }
            return NO;
        }
    }
    return kill(pid, 0) == 0 || errno == EPERM;
}
static BOOL IsOurHUD(pid_t pid) {
    if (pid <= 1 || pid == getpid() || !ProcessAlive(pid)) return NO;
    char path[PATH_MAX] = {0};
    if (proc_pidpath(pid, path, sizeof(path)) <= 0) return pid == spawnedHUD;
    NSString *candidate = [[NSString stringWithUTF8String:path] stringByResolvingSymlinksInPath];
    return [candidate isEqualToString:[NSBundle.mainBundle.executablePath stringByResolvingSymlinksInPath]];
}
static void WriteStatus(NSString *state, NSString *message, pid_t pid) {
    NSDictionary *value = @{@"state":state, @"message":message ?: @"", @"pid":@(pid)};
    [value writeToFile:StatusPath() atomically:YES];
}
BOOL IsHUDEnabled(void) {
    NSDictionary *status = ReadStatus();
    pid_t pid = ReadPID();
    return [status[@"state"] isEqual:@"ready"] && [status[@"pid"] intValue] == pid && IsOurHUD(pid);
}
NSString *HUDLastStatusMessage(void) {
    BOOL running = IsOurHUD(ReadPID());
    NSDictionary *status = ReadStatus();
    if (([status[@"state"] isEqual:@"ready"] || [status[@"state"] isEqual:@"starting"]) &&
        !running) {
        NSDictionary *health = [NSDictionary dictionaryWithContentsOfFile:HealthPath()];
        if ([health[@"pid"] intValue] == [status[@"pid"] intValue]) {
            return [NSString stringWithFormat:@"Menu dừng ngoài dự kiến. Lần cuối: %.0f MB, %.1f ms/khung, %@.",
                    [health[@"memoryMB"] doubleValue], [health[@"frameMS"] doubleValue], health[@"aim"] ?: @"chờ dữ liệu"];
        }
        return @"Tiến trình menu dừng ngoài dự kiến; chưa có mã lỗi từ iOS. Bấm Start để mở lại.";
    }
    NSString *current = [status[@"message"] isKindOfClass:NSString.class] ? status[@"message"] : @"Menu chưa khởi động.";
    NSDictionary *lastAim = [NSDictionary dictionaryWithContentsOfFile:[StatusPath() stringByAppendingString:@".attempt.plist"]];
    BOOL haveAttempt = [lastAim[@"pid"] intValue] == ReadPID();
    if (!haveAttempt) lastAim = [NSDictionary dictionaryWithContentsOfFile:[StatusPath() stringByAppendingString:@".aim.plist"]];
    if (running && [lastAim[@"pid"] intValue] == ReadPID() && [lastAim[@"message"] isKindOfClass:NSString.class]) {
        NSTimeInterval age = MAX(0, NSDate.date.timeIntervalSince1970 - [lastAim[@"time"] doubleValue]);
        return [NSString stringWithFormat:@"%@\n\n%@, %.0f giây trước\n%@", current,
                haveAttempt ? @"Lần aim kích hoạt gần nhất" : @"Trong trận", age, lastAim[@"message"]];
    }
    return current;
}
static BOOL StartError(NSError **error, int code, NSString *message) {
    WriteStatus(@"failed", message, 0);
    if (error) *error = [NSError errorWithDomain:@"HoanghaHUD" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
BOOL StartHUD(NSError **error) {
    if (!MizzeLicenseAuthorized()) return StartError(error, 401, @"Cần xác minh key qua mạng trước khi mở menu.");
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable.length) return StartError(error, 3, @"Không tìm thấy file chạy của ứng dụng.");

    int destroyToken = 0;
    if (notify_register_check(NOTIFY_DESTROY_HUD, &destroyToken) == NOTIFY_STATUS_OK) {
        notify_set_state(destroyToken, 0);
        notify_cancel(destroyToken);
    }

    posix_spawnattr_t attr;
    int result = posix_spawnattr_init(&attr);
    if (result != 0) return StartError(error, result, @"Không tạo được cấu hình tiến trình menu.");
    result = posix_spawnattr_set_persona_np(&attr, 99, 1);
    if (!result) result = posix_spawnattr_set_persona_uid_np(&attr, 0);
    if (!result) result = posix_spawnattr_set_persona_gid_np(&attr, 0);
    if (!result) result = posix_spawnattr_setpgroup(&attr, 0);
    if (!result) result = posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP);
    if (!result) {
        unlink([ROOT_PATH_NS(PID_PATH) fileSystemRepresentation]);
        WriteStatus(@"starting", @"Đang mở menu và kiểm tra phiên…", 0);
        const char *args[] = {executable.fileSystemRepresentation, "-hud",  NULL};
        result = posix_spawn(&spawnedHUD, executable.fileSystemRepresentation, NULL, &attr, (char **)args, environ);
    }
    posix_spawnattr_destroy(&attr);
    if (result != 0) {
        spawnedHUD = 0;
        return StartError(error, result, [NSString stringWithFormat:@"Không mở được menu (%d: %s).", result, strerror(result)]);
    }
    return YES;
}
void StopHUDWithMessage(NSString *message) {
    pid_t pid = ReadPID();
    int destroyToken = 0;
    if (notify_register_check(NOTIFY_DESTROY_HUD, &destroyToken) == NOTIFY_STATUS_OK) {
        notify_set_state(destroyToken, 1);
        notify_post(NOTIFY_DESTROY_HUD);
        notify_cancel(destroyToken);
    } else {
        notify_post(NOTIFY_DESTROY_HUD);
    }
    if (IsOurHUD(pid)) kill(pid, SIGTERM);
    if (spawnedHUD != pid && IsOurHUD(spawnedHUD)) kill(spawnedHUD, SIGTERM);
    if (spawnedHUD > 1) { int status; waitpid(spawnedHUD, &status, WNOHANG); }
    spawnedHUD = 0;
    unlink([ROOT_PATH_NS(PID_PATH) fileSystemRepresentation]);
    WriteStatus(@"stopped", message ?: @"Menu đã dừng.", 0);
}
void StopHUD(void) { StopHUDWithMessage(@"Menu đã dừng."); }
static void HUDUncaughtException(NSException *exception) {
    WriteStatus(@"failed", [NSString stringWithFormat:@"Menu gặp lỗi %@. Gửi tên lỗi này để kiểm tra.", exception.name], 0);
}
void HUDMarkStarting(void) {
    NSSetUncaughtExceptionHandler(HUDUncaughtException);
    [[NSString stringWithFormat:@"%d", getpid()] writeToFile:ROOT_PATH_NS(PID_PATH) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    WriteStatus(@"starting", @"Đang khởi động menu kernel…", getpid());
}
void HUDMarkReady(void) { WriteStatus(@"ready", @"Nút Mizze đang chạy. Chạm để mở menu.", getpid()); }
void HUDUpdateKernelStatus(NSString *message) {
    static NSString *previous = nil;
    static CFAbsoluteTime lastWrite = 0;
    @synchronized(NSFileManager.defaultManager) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if ([previous isEqualToString:message] || now - lastWrite < 1) return;
        previous = [message copy];
        lastWrite = now;
        WriteStatus(@"ready", message, getpid());
    }
}
void HUDRecordAimStatus(NSString *message, BOOL activated) {
    static CFAbsoluteTime lastWrite = 0;
    static CFAbsoluteTime lastAttempt = 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (activated && now - lastAttempt >= 1) {
        lastAttempt = now;
        NSDictionary *attempt = @{@"pid":@(getpid()), @"time":@(NSDate.date.timeIntervalSince1970), @"message":message};
        [attempt writeToFile:[StatusPath() stringByAppendingString:@".attempt.plist"] atomically:YES];
    }
    if (now - lastWrite < 1) return;
    lastWrite = now;
    NSDictionary *record = @{@"pid":@(getpid()), @"time":@(NSDate.date.timeIntervalSince1970), @"message":message};
    [record writeToFile:[StatusPath() stringByAppendingString:@".aim.plist"] atomically:YES];
}
void HUDRecordFrame(double milliseconds, int players, NSString *aimState) {
    static NSTimeInterval nextSample = 0;
    const NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (now < nextSample) return;
    nextSample = now + 5;
    mach_task_basic_info_data_t info = {};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    const BOOL haveMemory = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS;
    NSDictionary *sample = @{@"pid":@(getpid()), @"frameMS":@(milliseconds),
        @"memoryMB":@(haveMemory ? info.resident_size / (1024.0 * 1024.0) : 0),
        @"players":@(players), @"aim":aimState ?: @"chờ dữ liệu"};
    // One bounded record, never a growing log and never license/key data.
    [sample writeToFile:HealthPath() atomically:YES];
}
void RequestExitHUDWithMessage(NSString *message) {
    if (ReadPID() == getpid()) {
        WriteStatus(@"stopped", message ?: @"Menu đã dừng.", 0);
        unlink([ROOT_PATH_NS(PID_PATH) fileSystemRepresentation]);
    }
    exit(0);
}
void RequestExitHUD(void) { RequestExitHUDWithMessage(@"Menu đã dừng."); }
void _0xFFFADK2(BOOL enabled) { if (enabled) StartHUD(NULL); else StopHUD(); }
