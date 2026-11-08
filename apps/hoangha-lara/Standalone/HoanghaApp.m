#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "HoanghaOverlayBridge.h"
#import <CommonCrypto/CommonDigest.h>
#import "xpf.h"

@interface HoanghaViewController : UIViewController
@property(nonatomic, strong) UIButton *startButton;
@property(nonatomic, strong) UIButton *stopButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIActivityIndicatorView *spinner;
@property(nonatomic, strong) UITextView *logView;
@property(nonatomic, strong) dispatch_queue_t operationQueue;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL kernelReady;
@property(nonatomic) BOOL offsetsReady;
@end

static __weak HoanghaViewController *HHScreen;

@implementation HoanghaViewController

- (void)appendLog:(NSString *)line {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [self.logView.text stringByAppendingFormat:@"%@\n", line];
        if (self.logView.text.length > 20000) {
            self.logView.text = [self.logView.text substringFromIndex:self.logView.text.length - 16000];
        }
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

static void HHLog(const char *message) {
    if (message) [HHScreen appendLog:[NSString stringWithUTF8String:message] ?: @""];
}

- (void)setStatus:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{ self.statusLabel.text = text; });
    [self appendLog:text];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    HHScreen = self;
    self.operationQueue = dispatch_queue_create("com.hoangha.lara.operations", DISPATCH_QUEUE_SERIAL);
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = @"Hoangha";

    UILabel *title = [UILabel new];
    title.text = @"hoangha";
    title.font = [UIFont boldSystemFontOfSize:76];
    title.textAlignment = NSTextAlignmentCenter;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.35;
    title.accessibilityTraits |= UIAccessibilityTraitHeader;

    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"Nhấn Start để hiện chữ lớn giữa màn hình.";
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.accessibilityIdentifier = @"hoangha.status";

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *start = [UIButtonConfiguration filledButtonConfiguration];
    start.title = @"Start";
    start.buttonSize = UIButtonConfigurationSizeLarge;
    start.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    self.startButton.configuration = start;
    self.startButton.accessibilityIdentifier = @"hoangha.start";
    [self.startButton addTarget:self action:@selector(startPressed) forControlEvents:UIControlEventTouchUpInside];

    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *stop = [UIButtonConfiguration tintedButtonConfiguration];
    stop.title = @"Stop";
    stop.buttonSize = UIButtonConfigurationSizeLarge;
    stop.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    self.stopButton.configuration = stop;
    self.stopButton.accessibilityIdentifier = @"hoangha.stop";
    [self.stopButton addTarget:self action:@selector(stopPressed) forControlEvents:UIControlEventTouchUpInside];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.accessibilityLabel = @"Đang xử lý";

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:
                            @[title, self.statusLabel, self.spinner, self.startButton, self.stopButton]];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentFill;
    content.spacing = 22;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];

    self.logView = [UITextView new];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.logView.textColor = UIColor.secondaryLabelColor;
    self.logView.backgroundColor = UIColor.clearColor;
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.logView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [content.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor constant:-35],
        [content.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-56],
        [content.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:12],
        [self.logView.topAnchor constraintEqualToAnchor:content.bottomAnchor constant:16],
        [self.logView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [self.logView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [self.logView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-8],
    ]];
    ds_set_log_callback(HHLog);
}

- (BOOL)runtimeSupported {
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    // Keep Lara's version/device restrictions; no offset or exploit changes are made here.
    char machine[128] = {0};
    size_t size = sizeof(machine);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    if (version.majorVersion < 16 || version.majorVersion > 26 ||
        (version.majorVersion == 26 && (version.minorVersion > 0 || version.patchVersion > 1)) ||
        strncmp(machine, "iPhone18,", 9) == 0) {
        [self setStatus:@"Thiết bị/iOS chưa đáp ứng điều kiện của bản Lara gốc."];
        return NO;
    }
    if ([RemoteCall isLiveContainerRuntime] && ![RemoteCall isLiveProcessRuntime]) {
        [self setStatus:@"Hãy mở bằng chế độ LiveContainer có PAC như Lara yêu cầu."];
        return NO;
    }
    return YES;
}

- (BOOL)prepareBundledKernelcache {
    char machine[128] = {0}, build[128] = {0};
    size_t length = sizeof(machine);
    sysctlbyname("hw.machine", machine, &length, NULL, 0);
    length = sizeof(build);
    sysctlbyname("kern.osversion", build, &length, NULL, 0);
    if (strcmp(machine, "iPhone11,2") != 0 || strcmp(build, "22F76") != 0) return YES;

    NSURL *bundled = [NSBundle.mainBundle URLForResource:@"kernelcache-iPhone11,2-22F76" withExtension:nil];
    NSData *data = bundled ? [NSData dataWithContentsOfURL:bundled] : nil;
    if (!data) {
        [self setStatus:@"Bản cài thiếu kernelcache đi kèm cho iPhone XS iOS 18.5."];
        return NO;
    }
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, hash);
    NSMutableString *hex = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(hash); i++) [hex appendFormat:@"%02x", hash[i]];
    if (![hex isEqualToString:@"406b5f62fd2357a8365c8b99f8c1d766a38f0dbe405dee94023f835c324c22b3"]) {
        [self setStatus:@"Kernelcache đi kèm không khớp checksum."];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *documents = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    if (!documents) return NO;
    NSURL *destination = [documents URLByAppendingPathComponent:@"kernelcache"];
    NSData *existing = [NSData dataWithContentsOfURL:destination];
    if ([existing isEqualToData:data]) return YES;
    NSError *error = nil;
    if ([fm fileExistsAtPath:destination.path]) {
        NSURL *backup = [documents URLByAppendingPathComponent:
                         [@"kernelcache-before-hoangha-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        if (![fm copyItemAtURL:destination toURL:backup error:&error]) {
            [self setStatus:[@"Không tạo được backup kernelcache: " stringByAppendingString:error.localizedDescription]];
            return NO;
        }
        NSData *saved = [NSData dataWithContentsOfURL:backup];
        if (!existing || ![saved isEqualToData:existing]) {
            [self setStatus:@"Backup kernelcache chưa được kiểm tra thành công."];
            return NO;
        }
    }
    if (![data writeToURL:destination options:NSDataWritingAtomic error:&error]) {
        [self setStatus:[@"Không lưu được kernelcache: " stringByAppendingString:error.localizedDescription]];
        return NO;
    }
    [self appendLog:@"Đã chuẩn bị kernelcache Apple: iPhone XS / iOS 18.5 / 22F76."];
    return YES;
}

- (BOOL)prepareRuntime {
    if (![self runtimeSupported]) return NO;
    // Resolve Lara's device data before starting its existing kernel/session code.
    if (!self.offsetsReady) {
        [self setStatus:@"Đang chuẩn bị kernelcache trước khi khởi tạo Lara…"];
        if (![self prepareBundledKernelcache]) return NO;
        self.offsetsReady = emergencyfixfunctiontobereplacedlateronquestionmark() || dlkcache();
        if (!self.offsetsReady) {
            const char *detail = xpf_get_error();
            if (detail) [self appendLog:[NSString stringWithUTF8String:detail] ?: @""];
            [self setStatus:@"Chưa đọc được dữ liệu từ kernelcache. Lara chưa được khởi chạy."];
            return NO;
        }
    }
    if (!self.kernelReady || !ds_is_ready()) {
        [self setStatus:@"Đang khởi tạo Lara…"];
        init_offsets();
        offsets_init();
        self.kernelReady = ds_run() == 0 && ds_is_ready();
        if (!self.kernelReady) {
            [self setStatus:@"Lara chưa khởi tạo thành công. Xem log bên dưới."];
            return NO;
        }
    }
    if (!ds_get_our_proc() || !ds_get_our_task()) {
        [self setStatus:@"Lara chưa xác định được tiến trình của app; chưa mở phiên SpringBoard."];
        return NO;
    }
    return YES;
}

- (void)startPressed { [self performOverlay:YES]; }
- (void)stopPressed { [self performOverlay:NO]; }

- (void)performOverlay:(BOOL)show {
    if (self.busy) return;
    self.busy = YES;
    self.startButton.enabled = NO;
    self.stopButton.enabled = NO;
    [self.spinner startAnimating];
    dispatch_async(self.operationQueue, ^{
        @autoreleasepool {
            if ([self prepareRuntime]) {
                [self setStatus:@"Đang kết nối SpringBoard…"];
                RemoteCall *session = [[RemoteCall alloc] initWithProcess:@"SpringBoard" useMigFilterBypass:NO];
                if (!session) {
                    [self setStatus:[RemoteCall lastInitError] ?: @"Không mở được phiên SpringBoard."];
                } else {
                    BOOL success = show ? hoangha_overlay_show(session) : hoangha_overlay_hide(session);
                    NSString *error = hoangha_overlay_last_error();
                    // The static label is retained by SpringBoard; it needs no app-side update loop.
                    int cleanup = [session destroyRemoteCall];
                    if (success) {
                        [self setStatus:show ? @"Đã hiện hoangha ở giữa màn hình. Bạn có thể về Home." : @"Đã ẩn chữ hoangha."];
                    } else {
                        [self setStatus:error.length ? error : @"SpringBoard chưa hoàn tất yêu cầu."];
                    }
                    if (cleanup != 0) [self appendLog:@"Phiên RemoteCall chưa dọn xong; xem log Lara."];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.busy = NO;
                self.startButton.enabled = YES;
                self.stopButton.enabled = YES;
                [self.spinner stopAnimating];
            });
        }
    });
}
@end

@interface HoanghaAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation HoanghaAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:[HoanghaViewController new]];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(HoanghaAppDelegate.class));
    }
}
