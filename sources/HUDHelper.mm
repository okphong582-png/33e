#import "HUDHelper.h"
#import "LicenseSession.h"
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

extern "C" char **environ;
extern "C" int posix_spawnattr_set_persona_np(const posix_spawnattr_t *, uid_t, uint32_t);
extern "C" int posix_spawnattr_set_persona_uid_np(const posix_spawnattr_t *, uid_t);
extern "C" int posix_spawnattr_set_persona_gid_np(const posix_spawnattr_t *, uid_t);

static pid_t spawnedHUD = 0;
static NSString *StatusPath(void) { return [ROOT_PATH_NS(PID_PATH) stringByAppendingString:@".state.plist"]; }
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
        if (waitpid(pid, &status, WNOHANG) == pid) { spawnedHUD = 0; return NO; }
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
    NSDictionary *status = ReadStatus();
    if (([status[@"state"] isEqual:@"ready"] || [status[@"state"] isEqual:@"starting"]) &&
        !IsOurHUD(ReadPID())) return @"Tiến trình menu đã dừng. Bấm Start để mở lại.";
    return [status[@"message"] isKindOfClass:NSString.class] ? status[@"message"] : @"Menu chưa khởi động.";
}
static BOOL StartError(NSError **error, int code, NSString *message) {
    WriteStatus(@"failed", message, 0);
    if (error) *error = [NSError errorWithDomain:@"HoanghaHUD" code:code userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
BOOL StartHUD(NSError **error) {
    if (![LicenseSession shared].authorized) return StartError(error, 1, @"Cần xác thực key online trước khi mở menu.");
    if (IsOurHUD(ReadPID())) return YES;
    NSString *hash = [NSUserDefaults.standardUserDefaults stringForKey:@"LicenseHash"];
    NSCharacterSet *invalid = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    if (hash.length != 64 || [hash rangeOfCharacterFromSet:invalid].location != NSNotFound)
        return StartError(error, 2, @"Không tìm thấy phiên key. Vui lòng đăng nhập lại.");
    NSString *executable = NSBundle.mainBundle.executablePath;
    if (!executable.length) return StartError(error, 3, @"Không tìm thấy file chạy của ứng dụng.");

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
        const char *args[] = {executable.fileSystemRepresentation, "-hud", hash.UTF8String, NULL};
        result = posix_spawn(&spawnedHUD, executable.fileSystemRepresentation, NULL, &attr, (char **)args, environ);
    }
    posix_spawnattr_destroy(&attr);
    if (result != 0) {
        spawnedHUD = 0;
        return StartError(error, result, [NSString stringWithFormat:@"Không mở được menu (%d: %s).", result, strerror(result)]);
    }
    return YES;
}
void StopHUD(void) {
    pid_t pid = ReadPID();
    notify_post(NOTIFY_DESTROY_HUD);
    if (IsOurHUD(pid)) kill(pid, SIGTERM);
    if (spawnedHUD != pid && IsOurHUD(spawnedHUD)) kill(spawnedHUD, SIGTERM);
    if (spawnedHUD > 1) { int status; waitpid(spawnedHUD, &status, WNOHANG); }
    unlink([ROOT_PATH_NS(PID_PATH) fileSystemRepresentation]);
    WriteStatus(@"stopped", @"Menu đã dừng.", 0);
}
void HUDMarkStarting(void) {
    [[NSString stringWithFormat:@"%d", getpid()] writeToFile:ROOT_PATH_NS(PID_PATH) atomically:YES encoding:NSUTF8StringEncoding error:nil];
    WriteStatus(@"starting", @"Đang xác thực phiên menu…", getpid());
}
void HUDMarkReady(void) { WriteStatus(@"ready", @"Nút GIF đang chạy. Chạm để mở menu.", getpid()); }
void RequestExitHUDWithMessage(NSString *message) {
    if (ReadPID() == getpid()) {
        WriteStatus(@"stopped", message ?: @"Menu đã dừng.", 0);
        unlink([ROOT_PATH_NS(PID_PATH) fileSystemRepresentation]);
    }
    exit(0);
}
void RequestExitHUD(void) { RequestExitHUDWithMessage(@"Menu đã dừng."); }
void _0xFFFADK2(BOOL enabled) { if (enabled) StartHUD(NULL); else StopHUD(); }
