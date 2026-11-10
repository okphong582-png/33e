#import <UIKit/UIKit.h>
#import <AVFAudio/AVFAudio.h>
#import <unistd.h>
#import <sys/sysctl.h>
#import "darksword.h"
#import "offsets.h"
#import "utils.h"
#import "HoanghaOverlayBridge.h"
#import "HHFreeFireReader.h"
#import "HHGameSchedule.h"
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
@property(nonatomic) BOOL kernelAttempted;
@property(nonatomic, strong) NSURL *journalURL;
@property(atomic) BOOL floatingRunning;
@property(nonatomic, strong) AVAudioPlayer *keepAlivePlayer;
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

- (void)appendJournal:(NSString *)text {
    @synchronized (self) {
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:self.journalURL.path];
        if (file) {
            [file seekToEndOfFile];
            NSString *line = [NSString stringWithFormat:@"%@ %@\n", NSDate.date, text];
            [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [file synchronizeFile];
            [file closeFile];
        }
    }
}

- (void)setStatus:(NSString *)text {
    [self appendJournal:text];
    dispatch_async(dispatch_get_main_queue(), ^{ self.statusLabel.text = text; });
    [self appendLog:text];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    HHScreen = self;
    self.operationQueue = dispatch_queue_create("com.hoangha.lara.operations", DISPATCH_QUEUE_SERIAL);
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.075 blue:0.12 alpha:1];
    self.title = @"HOANGHA";
    NSURL *documents = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    self.journalURL = [documents URLByAppendingPathComponent:
                       [NSString stringWithFormat:@"Hoangha-v1.5.8-%@.log", NSUUID.UUID.UUIDString]];
    [NSFileManager.defaultManager createFileAtPath:self.journalURL.path contents:[NSData data] attributes:nil];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Log"
        style:UIBarButtonItemStylePlain target:self action:@selector(shareLog:)];

    UILabel *eyebrow = [UILabel new];
    eyebrow.text = @"LARA  /  FF TH 1.132.1";
    eyebrow.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
    eyebrow.textColor = UIColor.systemTealColor;
    eyebrow.textAlignment = NSTextAlignmentCenter;

    UILabel *title = [UILabel new];
    title.text = @"HOANGHA";
    title.font = [UIFont systemFontOfSize:52 weight:UIFontWeightBlack];
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.35;
    title.accessibilityTraits |= UIAccessibilityTraitHeader;

    UILabel *subtitle = [UILabel new];
    subtitle.text = @"ESP  ·  BOX  ·  TÊN  ·  HP";
    subtitle.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
    subtitle.textColor = UIColor.systemTealColor;
    subtitle.textAlignment = NSTextAlignmentCenter;

    self.statusLabel = [UILabel new];
    self.statusLabel.text = @"Nhấn Bắt đầu, mở FF TH rồi bật ESP Box trong menu nổi.";
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = UIColor.whiteColor;
    self.statusLabel.backgroundColor = [UIColor colorWithRed:0.10 green:0.15 blue:0.23 alpha:1];
    self.statusLabel.layer.cornerRadius = 14;
    self.statusLabel.clipsToBounds = YES;
    self.statusLabel.accessibilityIdentifier = @"hoangha.status";

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *start = [UIButtonConfiguration filledButtonConfiguration];
    start.title = @"Bắt đầu";
    start.buttonSize = UIButtonConfigurationSizeLarge;
    start.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    start.baseBackgroundColor = UIColor.systemTealColor;
    start.baseForegroundColor = UIColor.blackColor;
    self.startButton.configuration = start;
    self.startButton.accessibilityIdentifier = @"hoangha.start";
    [self.startButton addTarget:self action:@selector(startPressed) forControlEvents:UIControlEventTouchUpInside];

    self.stopButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *stop = [UIButtonConfiguration tintedButtonConfiguration];
    stop.title = @"Dừng";
    stop.buttonSize = UIButtonConfigurationSizeLarge;
    stop.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    stop.baseBackgroundColor = [UIColor colorWithRed:0.16 green:0.22 blue:0.32 alpha:1];
    stop.baseForegroundColor = UIColor.whiteColor;
    self.stopButton.configuration = stop;
    self.stopButton.accessibilityIdentifier = @"hoangha.stop";
    [self.stopButton addTarget:self action:@selector(stopPressed) forControlEvents:UIControlEventTouchUpInside];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.accessibilityLabel = @"Đang xử lý";

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:
                            @[eyebrow, title, subtitle, self.statusLabel, self.spinner, self.startButton, self.stopButton]];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentFill;
    content.spacing = 14;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];

    self.logView = [UITextView new];
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.logView.textColor = UIColor.secondaryLabelColor;
    self.logView.backgroundColor = [UIColor colorWithRed:0.09 green:0.12 blue:0.18 alpha:1];
    self.logView.layer.cornerRadius = 14;
    self.logView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.logView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [content.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-56],
        [content.topAnchor constraintEqualToAnchor:safe.topAnchor constant:20],
        [self.statusLabel.heightAnchor constraintGreaterThanOrEqualToConstant:58],
        [self.logView.topAnchor constraintEqualToAnchor:content.bottomAnchor constant:18],
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
        if (self.kernelAttempted) {
            [self setStatus:@"Phiên khởi tạo trước chưa thành công. App không chạy lại khởi tạo trong phiên này."];
            return NO;
        }
        self.kernelAttempted = YES;
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

- (void)shareLog:(UIBarButtonItem *)sender {
    if (!self.journalURL) return;
    UIActivityViewController *share = [[UIActivityViewController alloc]
        initWithActivityItems:@[self.journalURL] applicationActivities:nil];
    share.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:share animated:YES completion:nil];
}

- (void)startKeepAlive {
    NSError *error = nil;
    AVAudioSession *audio = AVAudioSession.sharedInstance;
    if (![audio setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault
                   options:AVAudioSessionCategoryOptionMixWithOthers error:&error] ||
        ![audio setActive:YES error:&error]) {
        [self appendLog:[@"Không bật được chế độ nền: " stringByAppendingString:error.localizedDescription ?: @""]];
        return;
    }
    uint32_t sampleRate=8000, samples=8000, dataBytes=samples*2, riffSize=36+dataBytes;
    uint32_t fmtSize=16, byteRate=sampleRate*2;
    uint16_t format=1, channels=1, alignment=2, bits=16;
    NSMutableData *wav=[NSMutableData data];
    [wav appendBytes:"RIFF" length:4]; [wav appendBytes:&riffSize length:4];
    [wav appendBytes:"WAVEfmt " length:8]; [wav appendBytes:&fmtSize length:4];
    [wav appendBytes:&format length:2]; [wav appendBytes:&channels length:2];
    [wav appendBytes:&sampleRate length:4]; [wav appendBytes:&byteRate length:4];
    [wav appendBytes:&alignment length:2]; [wav appendBytes:&bits length:2];
    [wav appendBytes:"data" length:4]; [wav appendBytes:&dataBytes length:4];
    [wav appendData:[NSData dataWithBytesNoCopy:calloc(1,dataBytes) length:dataBytes freeWhenDone:YES]];
    self.keepAlivePlayer=[[AVAudioPlayer alloc] initWithData:wav error:&error];
    self.keepAlivePlayer.numberOfLoops=-1;
    self.keepAlivePlayer.volume=0;
    [self.keepAlivePlayer prepareToPlay];
    if (![self.keepAlivePlayer play]) [self appendLog:@"Chế độ nền chưa chạy; nút có thể ngừng phản hồi khi app bị treo nền."];
}

- (void)performOverlay:(BOOL)show {
    if (!show && self.floatingRunning) {
        self.floatingRunning=NO;
        self.busy=YES;
        self.startButton.enabled=NO;
        self.stopButton.enabled=NO;
        [self.spinner startAnimating];
        [self setStatus:@"Đang tắt nút nổi và đóng phiên…"];
        return;
    }
    if (self.busy || self.floatingRunning) return;
    self.busy=YES;
    self.startButton.enabled=NO;
    self.stopButton.enabled=NO;
    [self.spinner startAnimating];
    [self startKeepAlive];
    dispatch_async(self.operationQueue, ^{
        @autoreleasepool {
            if ([self prepareRuntime]) {
                [self setStatus:@"Đang kết nối SpringBoard…"];
                RemoteCall *session=[[RemoteCall alloc] initWithProcess:@"SpringBoard" useMigFilterBypass:NO];
                if (!session) {
                    [self setStatus:[RemoteCall lastInitError] ?: @"Không mở được phiên SpringBoard."];
                } else {
                    session.parkWorkerBetweenCalls=YES;
                    NSURL *url=[NSBundle.mainBundle URLForResource:@"bubble-logo" withExtension:@"png"];
                    NSData *logo=url ? [NSData dataWithContentsOfURL:url] : nil;
                    [self setStatus:@"Đang tạo nút logo và menu nhỏ…"];
                    BOOL success=show ? hoangha_floating_start(session,logo) : hoangha_overlay_hide(session);
                    if (show && success) {
                        self.floatingRunning=YES;
                        [self setStatus:@"Đã hiện nút nổi. Mở menu và bật ESP Box."];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.busy=NO;
                            self.startButton.enabled=NO;
                            self.stopButton.enabled=YES;
                            [self.spinner stopAnimating];
                        });
                        HHFreeFireReader *reader=nil;
                        HHGameSchedule schedule={0};
                        NSString *lastStatus=nil;
                        NSString *waitingStatus=nil;
                        CFAbsoluteTime lastBoxesAt=0;
                        CFAbsoluteTime menuAt=0;
                        while (self.floatingRunning) {
                            @autoreleasepool {
                                CFAbsoluteTime tickNow=CFAbsoluteTimeGetCurrent();
                                if(tickNow>=menuAt){
                                    menuAt=tickNow+0.1;
                                    if(!hoangha_floating_tick(session)){self.floatingRunning=NO;success=NO;break;}
                                }
                                BOOL enabled=hoangha_floating_esp_enabled();
                                HHGameWork work=hh_game_work(&schedule,enabled,CFAbsoluteTimeGetCurrent());
                                if(work.disconnect){
                                    hoangha_floating_boxes(session,@[]);
                                    [reader disconnect];reader=nil;
                                    lastBoxesAt=0;
                                    [self setStatus:@"ESP đã tắt; đã đóng kết nối game"];
                                }
                                if(work.changed&&enabled){
                                    [self setStatus:@"Bạn đã bật ESP; đang chờ FF TH ổn định ở màn hình ngang"];
                                    reader=[HHFreeFireReader new];
                                }
                                if(work.sample){
                                    if(work.geometry){
                                        pid_t previousPID=schedule.foregroundPID;
                                        pid_t pid=hoangha_foreground_game(session,&waitingStatus);
                                        hh_game_observe_foreground(&schedule,pid);
                                        if(previousPID>0&&previousPID!=schedule.foregroundPID)[reader disconnect];
                                    }
                                    BOOL connected=schedule.foregroundPID>0&&[reader connectIfNeededForPID:schedule.foregroundPID];
                                    CFAbsoluteTime sampleStarted=CFAbsoluteTimeGetCurrent();
                                    NSArray *boxes=connected?[reader boxesForSize:hoangha_floating_size()]:@[];
                                    NSString *capability=[reader takeAimCapabilityReport];
                                    if(capability.length){[self appendJournal:capability];[self appendLog:capability];}
                                    CFAbsoluteTime now=CFAbsoluteTimeGetCurrent();
                                    BOOL keepBriefly=connected&&!boxes&&lastBoxesAt>0&&now-lastBoxesAt<0.10;
                                    if(!keepBriefly){
                                        lastBoxesAt=boxes.count?sampleStarted:0;
                                        if(!hoangha_floating_boxes(session,boxes?:@[])){success=NO;self.floatingRunning=NO;break;}
                                    }
                                    hh_game_sample_finished(&schedule,CFAbsoluteTimeGetCurrent());
                                }
                                NSString *status=@"ESP Box đang tắt · chưa kết nối game";
                                if(enabled)status=schedule.foregroundPID>0?reader.status:(waitingStatus?:@"Đang chờ FF TH mở");
                                if(![lastStatus isEqualToString:status]){hoangha_floating_status(session,status);[self setStatus:status];lastStatus=status;}
                            }
                            CFAbsoluteTime wakeAt=schedule.enabled?MIN(menuAt,schedule.sampleAt):menuAt;
                            double delay=MAX(0.005,MIN(0.1,wakeAt-CFAbsoluteTimeGetCurrent()));
                            usleep((useconds_t)(delay*1000000));
                        }
                        [reader disconnect];
                    }
                    NSString *error=hoangha_overlay_last_error();
                    if (!hoangha_floating_stop(session)) success=NO;
                    [self setStatus:@"Đang đóng phiên RemoteCall…"];
                    [session destroyRemoteCall];
                    if (success) [self setStatus:@"Đã tắt nút nổi và menu."];
                    else [self setStatus:error.length ? error : @"Phiên nút nổi chưa hoạt động. Xem Log để kiểm tra."];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self.floatingRunning=NO;
                self.busy=NO;
                self.startButton.enabled=YES;
                self.stopButton.enabled=YES;
                [self.spinner stopAnimating];
                [self.keepAlivePlayer stop];
                self.keepAlivePlayer=nil;
                [AVAudioSession.sharedInstance setActive:NO
                    withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
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
