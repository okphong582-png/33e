// ============================================================
// _0xHO233D.mm
// HomeViewController - BẢN ĐÃ ĐỔI TÊN CLASS
// Từ: _0xDEADBEEF → _0xHOMEVC
// Mục đích: Tránh conflict với ModMenuViewController (_0xDEADBEEE)
// ============================================================

#import "HomeViewController.h"
#import "HUDHelper.h"
#import "../esp/Core/pid.h"
#import "../mahoa.h"
#import "../KabraxHide.h"
#import <QuartzCore/QuartzCore.h>
#import <CommonCrypto/CommonCrypto.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

#define AES_KEY KH_NS("PubgVip123456789")
#define AES_IV  KH_NS("InitVector123456")

// ============================================================
// [REMOVED] SERVER URL - ĐÃ XÓA THEO YÊU CẦU
// #define SERVER_AUTH_URL KH_NS("https://cold-wood-3f68.godhakaisin.workers.dev/auth")
// ============================================================

// ============================================================
// JUNK CODE - CHỐNG REVERSE ENGINEER
// ============================================================

__attribute__((noinline, used)) static int _0xB001() {
    volatile int _0xD003 = 7;
    for (volatile int _0xD002 = 0; _0xD002 < 3; _0xD002++) {
        _0xD003 ^= (_0xD002 * 3);
    }
    return _0xD003 - 7;
}

__attribute__((noinline, used)) static NSString* _0xB002(NSString * _0xD039) {
    if (_0xB001() != 0) {
        return [_0xD039 stringByAppendingString:@"DEAD"];
    }
    return _0xD039;
}

__attribute__((constructor)) static void _0xB003() {
    volatile uint64_t _0xD004 = 0;
    for (volatile int _0xD002 = 0; _0xD002 < 100; _0xD002++) {
        _0xD004 += _0xD002;
    }
    const char *_0xD005 = getenv("IOSVIET_KEY");
    if (_0xD005) { _0xD004 += (uint64_t)_0xD005; }
    __asm__ volatile("nop");
    __asm__ volatile("nop");
}

#define JUNK_BLOCK() \
    do { \
        volatile int _0xD006 = 0; \
        for (volatile int _0xD007 = 0; _0xD007 < 4; _0xD007++) { \
            _0xD006 += _0xD007; \
            __asm__ volatile("nop"); \
        } \
        if (_0xB001() == 0) { \
            __asm__ volatile("nop"); \
        } else { \
            __asm__ volatile("nop"); \
        } \
    } while(0)

// =================================================================
//  AUTH LOCAL CHECK - ĐÃ THAY THẾ SERVER
// =================================================================
static int   _0xA009      = KH_INT(0);
static int   _0xA00A      = KH_INT(0);
static int   _0xA00B      = KH_INT(0);
static int   _0xA00C      = KH_INT(0);
static BOOL  _0xA00D      = NO;
static BOOL  _0xA00E      = NO;

__attribute__((constructor)) static void _0xB004() {
    _0xA009 = (int)([[NSDate date] timeIntervalSince1970] + arc4random() % 100);
    _0xA00A = KH_INT(0);
    _0xA00B = KH_INT(0);
    _0xA00C = KH_INT(0);
    _0xA00D = NO;
    _0xA00E = NO;
}

// Hàm kiểm tra tổng hợp - LUÔN TRẢ VỀ YES (bypass auth)
__attribute__((noinline, used))
static BOOL _0xB005() {
    // [MODIFIED] Luôn trả về YES để bypass auth server
    return YES;
}

// =================================================================
//  HomeViewController  (_0xHOMEVC)
// =================================================================

@interface _0xHOMEVC ()
@property (nonatomic, strong) UIButton *_0xA001;
@property (nonatomic, strong) UILabel  *_0xA002;
@property (nonatomic, assign) BOOL      _0xA003;
@property (nonatomic, assign) BOOL      _0xA004;
@property (nonatomic, strong) UIView   *_0xA005;
@property (nonatomic, strong) UIView   *_0xA006;
@property (nonatomic, strong) NSTimer  *_0xA007;
@property (nonatomic, assign) BOOL      _0xA008;
@end

@implementation _0xHOMEVC

@synthesize _0xA001 = _0xA001;
@synthesize _0xA002 = _0xA002;
@synthesize _0xA003 = _0xA003;
@synthesize _0xA004 = _0xA004;
@synthesize _0xA005 = _0xA005;
@synthesize _0xA006 = _0xA006;
@synthesize _0xA007 = _0xA007;
@synthesize _0xA008 = _0xA008;

#pragma mark - Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    _0xB002(@"WarmUp");
    JUNK_BLOCK();
    
    if ([self _0xC00F]) {
        volatile int _0xD001 = 0;
        for (volatile int _0xD002 = 0; _0xD002 < 10; _0xD002++) {
            _0xD001 += _0xD002;
        }
    }
    
    self.view.backgroundColor = [UIColor colorWithRed:0.06f green:0.06f blue:0.10f alpha:1.0f];
    _0xA003 = NO;
    _0xA004 = NO;
    _0xA008 = NO;
    
    // Khởi tạo tài khoản & mật khẩu mặc định: tk=1, mk=1 nếu chưa có
    if (![self _0xC00B]) {
        [self _0xC00A:@"1"];
    }
    if (![self _0xC00D]) {
        [self _0xC00C:@"1"];
    }
    
    // Tạo nút START MOD dạng Card Nổi Phát Sáng
    _0xA001 = [KH_CLS("UIButton") buttonWithType:UIButtonTypeCustom];
    [_0xA001 setTitle:NSSENCRYPT("⚡ START MOD VIP ⚡") forState:UIControlStateNormal];
    [_0xA001 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _0xA001.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    _0xA001.backgroundColor = [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:1.0f];
    _0xA001.layer.cornerRadius = 24.0f;
    _0xA001.layer.borderWidth = 2.0f;
    _0xA001.layer.borderColor = [UIColor colorWithRed:1.0f green:0.9f blue:0.3f alpha:1.0f].CGColor;
    _0xA001.layer.shadowColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:0.9f].CGColor;
    _0xA001.layer.shadowOffset = CGSizeMake(0, 4);
    _0xA001.layer.shadowRadius = 16.0f;
    _0xA001.layer.shadowOpacity = 0.9f;
    [_0xA001 addTarget:self action:KH_SEL("_0xC005") forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_0xA001];
    
    // Tạo label footer
    _0xA002 = [[KH_CLS("UILabel") alloc] initWithFrame:CGRectZero];
    _0xA002.text = NSSENCRYPT("🔥 HOANGHA VIP MOD MENU 🔥\nMake by iOSViet.co");
    _0xA002.textColor = [UIColor colorWithRed:0.9f green:0.95f blue:1.0f alpha:0.9f];
    _0xA002.font = [KH_CLS("UIFont") systemFontOfSize:14 weight:UIFontWeightBold];
    _0xA002.textAlignment = NSTextAlignmentCenter;
    _0xA002.numberOfLines = 0;
    [self.view addSubview:_0xA002];
    
    // Đăng ký notification
    [[KH_CLS("NSNotificationCenter") defaultCenter] addObserver:self
                                             selector:KH_SEL("_0xC001:")
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[KH_CLS("NSNotificationCenter") defaultCenter] addObserver:self
                                             selector:KH_SEL("_0xC002:")
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    // Timer kiểm tra định kỳ (5 giây)
    _0xA007 = [KH_CLS("NSTimer") scheduledTimerWithTimeInterval:KH_FLT(5.0)
                                                  target:self
                                                selector:KH_SEL("_0xC004")
                                                userInfo:nil
                                                 repeats:YES];
    
    JUNK_BLOCK();
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    BOOL wasAuth = [[KH_CLS("NSUserDefaults") standardUserDefaults] boolForKey:NSSENCRYPT("wasAuthenticated")];
    if (!wasAuth) {
        [self _0xC006];
    }
}

- (void)_0xC001:(NSNotification *)notification {
    JUNK_BLOCK();
    if (_0xA008) {
        [[KH_CLS("NSUserDefaults") standardUserDefaults] setBool:YES forKey:NSSENCRYPT("wasAuthenticated")];
    }
}

- (void)_0xC002:(NSNotification *)notification {
    JUNK_BLOCK();
}

- (void)_0xC003 {
    JUNK_BLOCK();
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_0xA008 = YES;
        self->_0xA003 = YES;
        self->_0xA004 = NO;
        _0xFFFADK2(YES);
        [self->_0xA001 setTitle:NSSENCRYPT("🛑 STOP MOD VIP 🛑") forState:UIControlStateNormal];
        [self->_0xA001 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self->_0xA001.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.2f alpha:1.0f];
        self->_0xA001.layer.shadowColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.2f alpha:0.9f].CGColor;
        self->_0xA002.text = NSSENCRYPT("✅ HOANGHA VIP MOD Đã Kích Hoạt!\nHãy Mở Game Free Fire Max");
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    JUNK_BLOCK();
    CGFloat w = self.view.bounds.size.width;
    CGFloat btnW = MIN(w - 60.0f, 320.0f);
    _0xA001.frame = CGRectMake((w - btnW) / 2.0f, 0, btnW, 60);
    _0xA001.center = self.view.center;
    
    CGFloat h = self.view.bounds.size.height;
    UIEdgeInsets insets = self.view.safeAreaInsets;
    _0xA002.frame = CGRectMake(0, h - insets.bottom - 110, w, 60);
}

#pragma mark - Timer kiểm tra định kỳ
- (void)_0xC004 {
    JUNK_BLOCK();
}

#pragma mark - Toggle Action
- (void)_0xC005 {
    JUNK_BLOCK();
    if (_0xA003) {
        // Đang bật → tắt
        _0xA003 = NO;
        _0xA008 = NO;
        _0xFFFADK2(NO);
        [_0xA001 setTitle:NSSENCRYPT("⚡ START MOD VIP ⚡") forState:UIControlStateNormal];
        [_0xA001 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _0xA001.backgroundColor = [UIColor colorWithRed:1.0f green:0.75f blue:0.0f alpha:1.0f];
        _0xA001.layer.shadowColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:0.9f].CGColor;
        _0xA002.text = NSSENCRYPT("🔥 HOANGHA VIP MOD MENU 🔥\nMake by iOSViet.co");
        [[KH_CLS("NSUserDefaults") standardUserDefaults] removeObjectForKey:NSSENCRYPT("wasAuthenticated")];
        return;
    }
    
    BOOL wasAuth = [[KH_CLS("NSUserDefaults") standardUserDefaults] boolForKey:NSSENCRYPT("wasAuthenticated")];
    if (!wasAuth) {
        [self _0xC006];
        return;
    }
    
    _0xA003 = YES;
    _0xA004 = NO;
    _0xA008 = YES;
    [_0xA001 setTitle:NSSENCRYPT("🛑 STOP MOD VIP 🛑") forState:UIControlStateNormal];
    [_0xA001 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _0xA001.backgroundColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.2f alpha:1.0f];
    _0xA001.layer.shadowColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.2f alpha:0.9f].CGColor;
    _0xA002.text = NSSENCRYPT("✅ HOANGHA VIP MOD Đã Kích Hoạt!\nHãy Mở Game Free Fire Max");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _0xFFFADK2(YES);
    });
}

#pragma mark - Login Prompt (Key VIP mặc định: 1 / 1)
- (void)_0xC006 {
    JUNK_BLOCK();
    NSString *savedAcc = [self _0xC00B] ?: @"1";
    NSString *savedPass = [self _0xC00D] ?: @"1";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSSENCRYPT("🔐 HOANGHA VIP - XÁC THỰC KEY")
                                                                   message:NSSENCRYPT("Nhập Tài khoản & Mật khẩu Key (Mặc định: 1 / 1)")
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSSENCRYPT("Tài khoản Key");
        textField.text = savedAcc;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSSENCRYPT("Mật khẩu Key");
        textField.secureTextEntry = YES;
        textField.text = savedPass;
    }];
    
    UIAlertAction *loginAction = [UIAlertAction actionWithTitle:NSSENCRYPT("XÁC NHẬN KEY")
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
        UITextField *accField = alert.textFields.firstObject;
        UITextField *passField = alert.textFields.lastObject;
        
        NSString *account = accField.text ?: @"";
        NSString *password = passField.text ?: @"";
        
        if ([account isEqualToString:@"1"] && [password isEqualToString:@"1"]) {
            [self _0xC00A:account];
            [self _0xC00C:password];
            [[KH_CLS("NSUserDefaults") standardUserDefaults] setBool:YES forKey:NSSENCRYPT("wasAuthenticated")];
            [[KH_CLS("NSUserDefaults") standardUserDefaults] synchronize];
            
            // Kích hoạt MOD & hiển thị thông báo thành công
            [self _0xC005];
            [self _0xC010:@9999];
        } else {
            UIAlertController *errAlert = [UIAlertController alertControllerWithTitle:NSSENCRYPT("❌ LỖI KEY")
                                                                              message:NSSENCRYPT("Key không chính xác! (Mặc định: 1 / 1)")
                                                                       preferredStyle:UIAlertControllerStyleAlert];
            [errAlert addAction:[UIAlertAction actionWithTitle:NSSENCRYPT("Thử lại") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self _0xC006];
            }]];
            [self presentViewController:errAlert animated:YES completion:nil];
        }
    }];
    
    [alert addAction:loginAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Network Authentication
- (void)_0xC007:(NSString *)_0xD00B param1:(NSString *)_0xD00C param2:(void (^)(BOOL _0xD00E, NSDictionary * _Nullable _0xD00F))_0xD00D {
    JUNK_BLOCK();
    if (_0xD00D) {
        _0xD00D(YES, @{NSSENCRYPT("success"): @YES, NSSENCRYPT("vip_hours"): @9999});
    }
}

#pragma mark - AES Encryption / Decryption
- (NSString *)_0xC008:(NSString *)_0xD03F {
    JUNK_BLOCK();
    NSData *_0xD040 = [_0xD03F dataUsingEncoding:NSUTF8StringEncoding];
    NSData *_0xD041 = [AES_KEY dataUsingEncoding:NSUTF8StringEncoding];
    NSData *_0xD042 = [AES_IV dataUsingEncoding:NSUTF8StringEncoding];
    
    size_t _0xD043 = _0xD040.length + kCCBlockSizeAES128;
    void *_0xD044 = malloc(_0xD043);
    size_t _0xD045 = 0;
    
    CCCryptorStatus _0xD046 = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     _0xD041.bytes, kCCKeySizeAES128,
                                     _0xD042.bytes,
                                     _0xD040.bytes, _0xD040.length,
                                     _0xD044, _0xD043,
                                     &_0xD045);
    if (_0xD046 == kCCSuccess) {
        NSData *_0xD047 = [NSData dataWithBytesNoCopy:_0xD044 length:_0xD045];
        return [_0xD047 base64EncodedStringWithOptions:0];
    }
    free(_0xD044);
    return nil;
}

- (NSString *)_0xC009:(NSString *)_0xD048 {
    JUNK_BLOCK();
    NSData *_0xD049 = [[KH_CLS("NSData") alloc] initWithBase64EncodedString:_0xD048 options:0];
    if (!_0xD049) return nil;
    
    NSData *_0xD041 = [AES_KEY dataUsingEncoding:NSUTF8StringEncoding];
    NSData *_0xD042 = [AES_IV dataUsingEncoding:NSUTF8StringEncoding];
    
    size_t _0xD043 = _0xD049.length + kCCBlockSizeAES128;
    void *_0xD044 = malloc(_0xD043);
    size_t _0xD045 = 0;
    
    CCCryptorStatus _0xD046 = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     _0xD041.bytes, kCCKeySizeAES128,
                                     _0xD042.bytes,
                                     _0xD049.bytes, _0xD049.length,
                                     _0xD044, _0xD043,
                                     &_0xD045);
    if (_0xD046 == kCCSuccess) {
        NSData *_0xD04A = [KH_CLS("NSData") dataWithBytesNoCopy:_0xD044 length:_0xD045];
        return [[KH_CLS("NSString") alloc] initWithData:_0xD04A encoding:NSUTF8StringEncoding];
    }
    free(_0xD044);
    return nil;
}

- (void)_0xC00A:(NSString *)_0xD04B {
    JUNK_BLOCK();
    NSString *_0xD028 = [self _0xC008:_0xD04B];
    if (_0xD028) [[KH_CLS("NSUserDefaults") standardUserDefaults] setObject:_0xD028 forKey:NSSENCRYPT("encAccount")];
}

- (NSString *)_0xC00B {
    JUNK_BLOCK();
    NSString *_0xD028 = [[KH_CLS("NSUserDefaults") standardUserDefaults] stringForKey:NSSENCRYPT("encAccount")];
    return _0xD028 ? [self _0xC009:_0xD028] : nil;
}

- (void)_0xC00C:(NSString *)_0xD04C {
    JUNK_BLOCK();
    NSString *_0xD028 = [self _0xC008:_0xD04C];
    if (_0xD028) [[KH_CLS("NSUserDefaults") standardUserDefaults] setObject:_0xD028 forKey:NSSENCRYPT("encPassword")];
}

- (NSString *)_0xC00D {
    JUNK_BLOCK();
    NSString *_0xD028 = [[KH_CLS("NSUserDefaults") standardUserDefaults] stringForKey:NSSENCRYPT("encPassword")];
    return _0xD028 ? [self _0xC009:_0xD028] : nil;
}

- (NSString *)_0xC00E {
    JUNK_BLOCK();
    NSString *_0xD029 = NSSENCRYPT("deviceIDKey");
    NSString *_0xD02A = [[KH_CLS("NSUserDefaults") standardUserDefaults] stringForKey:_0xD029];
    if (_0xD02A) return _0xD02A;
    NSString *_0xD02B = [[KH_CLS("NSUUID") UUID] UUIDString];
    [[KH_CLS("NSUserDefaults") standardUserDefaults] setObject:_0xD02B forKey:_0xD029];
    return _0xD02B;
}

#pragma mark - Anti-Debug
- (BOOL)_0xC00F {
    JUNK_BLOCK();
    int _0xD02C[] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    struct kinfo_proc _0xD02D;
    size_t _0xD02E = sizeof(_0xD02D);
    if (sysctl(_0xD02C, 4, &_0xD02D, &_0xD02E, NULL, 0) == -1) return NO;
    int _0xD02F = _0xD02D.kp_proc.p_flag;
    if (_0xB001() == 0) {
        __asm__ volatile("nop");
    } else {
        _0xD02F = 0;
    }
    return (_0xD02F & P_TRACED) != 0;
}

#pragma mark - Custom Alert (HOANGHA VIP Dialog)
- (void)_0xC010:(NSNumber *)_0xD014 {
    JUNK_BLOCK();
    if (_0xA005) return;
    
    _0xA005 = [[KH_CLS("UIView") alloc] initWithFrame:self.view.bounds];
    _0xA005.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    [self.view addSubview:_0xA005];
    
    CGFloat _0xD030 = 310.0;
    _0xA006 = [[KH_CLS("UIView") alloc] initWithFrame:CGRectMake(0, 0, _0xD030, 240)];
    _0xA006.center = self.view.center;
    _0xA006.backgroundColor = [UIColor colorWithRed:0.08f green:0.08f blue:0.12f alpha:1.0f];
    _0xA006.layer.cornerRadius = 18.0;
    _0xA006.layer.borderWidth = 2.0f;
    _0xA006.layer.borderColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:0.9f].CGColor;
    _0xA006.layer.shadowColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:0.8f].CGColor;
    _0xA006.layer.shadowRadius = 16.0f;
    _0xA006.layer.shadowOpacity = 0.9f;
    _0xA006.layer.masksToBounds = NO;
    [_0xA005 addSubview:_0xA006];
    
    UILabel *_0xD031 = [[KH_CLS("UILabel") alloc] initWithFrame:CGRectMake(0, 20, _0xD030, 25)];
    _0xD031.text = NSSENCRYPT("✅ HOANGHA VIP KÍCH HOẠT");
    _0xD031.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    _0xD031.textColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:1.0f];
    _0xD031.textAlignment = NSTextAlignmentCenter;
    [_0xA006 addSubview:_0xD031];
    
    NSString *_0xD04E = @"👑 HOANGHA SYSTEM VIP 👑\nThời hạn: Vĩnh Viễn (9999 Giờ)\n\n• Đã bật ESP Line, Box & Head Red Dot\n• Đã bật Aimbot Auto Lock khi bắn\n• Đếm số ĐỊCH hiển thị thời gian thực";
    
    UILabel *_0xD032 = [[KH_CLS("UILabel") alloc] initWithFrame:CGRectMake(15, 52, _0xD030-30, 115)];
    _0xD032.text = _0xD04E;
    _0xD032.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    _0xD032.textColor = [UIColor colorWithRed:0.9f green:0.95f blue:1.0f alpha:0.9f];
    _0xD032.textAlignment = NSTextAlignmentCenter;
    _0xD032.numberOfLines = 0;
    [_0xA006 addSubview:_0xD032];
    
    UIButton *_0xD033 = [KH_CLS("UIButton") buttonWithType:UIButtonTypeCustom];
    CGFloat _0xD04F = 38.0;
    _0xD033.frame = CGRectMake((_0xD030-_0xD04F)/2, 182, _0xD04F, _0xD04F);
    _0xD033.backgroundColor = [UIColor colorWithRed:0.0f green:1.0f blue:0.4f alpha:1.0f];
    _0xD033.layer.cornerRadius = _0xD04F/2.0;
    [_0xD033 setTitle:KH_NS("✓") forState:UIControlStateNormal];
    [_0xD033 setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    _0xD033.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    [_0xD033 addTarget:self action:KH_SEL("_0xC011") forControlEvents:UIControlEventTouchUpInside];
    [_0xA006 addSubview:_0xD033];
    
    UILabel *_0xD034 = [[KH_CLS("UILabel") alloc] initWithFrame:CGRectMake(-100, -100, 10, 10)];
    _0xD034.text = _0xB002(@"JUNK");
    [_0xA006 addSubview:_0xD034];
    
    _0xA006.transform = CGAffineTransformMakeScale(1.2, 1.2);
    _0xA005.alpha = 0;
    [KH_CLS("UIView") animateWithDuration:0.25
                                    delay:0
                   usingSpringWithDamping:0.8
                    initialSpringVelocity:0.5
                                  options:UIViewAnimationOptionCurveEaseOut
                               animations:^{
        self->_0xA005.alpha = 1.0;
        self->_0xA006.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)_0xC011 {
    JUNK_BLOCK();
    [UIView animateWithDuration:0.2 animations:^{
        self->_0xA005.alpha = 0;
        self->_0xA006.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL _0xD035) {
        [self->_0xA005 removeFromSuperview];
        self->_0xA005 = nil;
        self->_0xA006 = nil;
    }];
}

- (void)_0xC012 {
    JUNK_BLOCK();
}

- (void)_0xDAH2863 {
    [self _0xC012];
}

// ============================================================
// JUNK METHODS - CHỐNG REVERSE
// ============================================================

- (void)_0xFAKE_DEAD_METHOD_01 __attribute__((used)) {
    volatile int _0xD036 = 1, _0xD037 = 2;
    for (volatile int _0xD002 = 0; _0xD002 < 5; _0xD002++) {
        _0xD036 += _0xD037;
        __asm__ volatile("nop");
    }
    if (_0xD036 > 1000) {
        [self _0xFAKE_DEAD_METHOD_02];
    }
}

- (void)_0xFAKE_DEAD_METHOD_02 __attribute__((used)) {
    NSArray *_0xD038 = @[@"junk1", @"junk2", @"junk3"];
    for (NSString *_0xD039 in _0xD038) {
        if (_0xB001() == 0) {
            __asm__ volatile("nop");
        }
    }
}

+ (void)_0xFAKE_CLASS_JUNK __attribute__((used)) {
    volatile uint64_t _0xD003 = 0;
    for (int _0xD002 = 0; _0xD002 < 10; _0xD002++) {
        _0xD003 += _0xD002;
    }
    void *_0xD03B = dlopen("libJunk.dylib", RTLD_LAZY);
    if (_0xD03B) {
        dlclose(_0xD03B);
    }
}

@end