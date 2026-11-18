#import <UIKit/UIKit.h>
#import "MainApplication.h"
#import "MainApplicationDelegate.h"
#import "HUDHelper.h"
#import "MizzeLicense.h"
#import "MizzeLogo.h"
@interface LSApplicationWorkspace:NSObject
+(instancetype)defaultWorkspace;
-(BOOL)openApplicationWithBundleID:(NSString *)identifier;
@end
@interface KernelLauncher:UIViewController
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UITextField *key;
@property(nonatomic,strong) UIButton *start;
@property(nonatomic,strong) UIStackView *content;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) CAGradientLayer *gradient;
@property(nonatomic,strong) UISegmentedControl *tabs;
@property(nonatomic,strong) UIView *splash;
@end
@implementation MainApplication
@end
@implementation KernelLauncher
-(UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
 UILabel *l=[UILabel new];l.text=text;l.font=[UIFont systemFontOfSize:size weight:weight];l.textColor=UIColor.whiteColor;l.numberOfLines=0;return l;
}
-(UIButton *)button:(NSString *)title action:(SEL)action primary:(BOOL)primary {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:title forState:UIControlStateNormal];b.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
 [b setTitleColor:primary?[UIColor colorWithRed:.04 green:.16 blue:.18 alpha:1]:UIColor.whiteColor forState:UIControlStateNormal];b.backgroundColor=primary?[UIColor colorWithRed:.65 green:.96 blue:.86 alpha:1]:[UIColor colorWithWhite:1 alpha:.09];b.layer.cornerRadius=20;b.layer.borderWidth=.6;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:.22].CGColor;
 [b.heightAnchor constraintEqualToConstant:56].active=YES;[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
-(void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=[UIColor colorWithRed:.025 green:.045 blue:.08 alpha:1];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 self.gradient=[CAGradientLayer layer];self.gradient.colors=@[(id)[UIColor colorWithRed:.09 green:.27 blue:.31 alpha:1].CGColor,(id)[UIColor colorWithRed:.035 green:.055 blue:.11 alpha:1].CGColor,(id)[UIColor colorWithRed:.13 green:.10 blue:.24 alpha:1].CGColor];self.gradient.startPoint=CGPointMake(0,0);self.gradient.endPoint=CGPointMake(1,1);[self.view.layer insertSublayer:self.gradient atIndex:0];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;[self.view addSubview:scroll];
 UIStackView *outer=[UIStackView new];outer.axis=UILayoutConstraintAxisVertical;outer.spacing=22;outer.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:outer];
 UILabel *eyebrow=[self label:@"HOANGHA × ĐÔNG NHẬT" size:11 weight:UIFontWeightSemibold];eyebrow.textColor=[UIColor colorWithWhite:.8 alpha:1];[outer addArrangedSubview:eyebrow];
 UIStackView *brand=[[UIStackView alloc] initWithArrangedSubviews:@[]];brand.spacing=18;brand.alignment=UIStackViewAlignmentCenter;
 UIImageView *logo=[[UIImageView alloc] initWithImage:MizzeLogoImage()];logo.contentMode=UIViewContentModeScaleAspectFit;logo.layer.cornerRadius=24;logo.clipsToBounds=YES;[logo.widthAnchor constraintEqualToConstant:76].active=YES;[logo.heightAnchor constraintEqualToConstant:76].active=YES;[brand addArrangedSubview:logo];
 UIStackView *titles=[[UIStackView alloc] initWithArrangedSubviews:@[[self label:@"Mizze" size:42 weight:UIFontWeightBold],[self label:@"FFVN · Kernel Edition" size:13 weight:UIFontWeightMedium]]];titles.axis=UILayoutConstraintAxisVertical;titles.spacing=3;[brand addArrangedSubview:titles];[outer addArrangedSubview:brand];
 self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"Trang chủ",@"Dọn VAR",@"Giấy phép"]];self.tabs.selectedSegmentIndex=0;self.tabs.selectedSegmentTintColor=[UIColor colorWithWhite:1 alpha:.19];[self.tabs.heightAnchor constraintEqualToConstant:44].active=YES;[self.tabs addTarget:self action:@selector(buildTab) forControlEvents:UIControlEventValueChanged];[outer addArrangedSubview:self.tabs];
 UIVisualEffectView *glass=[[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];glass.layer.cornerRadius=30;glass.clipsToBounds=YES;glass.layer.borderColor=[UIColor colorWithWhite:1 alpha:.24].CGColor;glass.layer.borderWidth=.7;glass.backgroundColor=UIAccessibilityIsReduceTransparencyEnabled()?[UIColor colorWithWhite:.10 alpha:1]:[UIColor colorWithWhite:1 alpha:.035];[outer addArrangedSubview:glass];
 self.content=[UIStackView new];self.content.axis=UILayoutConstraintAxisVertical;self.content.spacing=18;self.content.translatesAutoresizingMaskIntoConstraints=NO;[glass.contentView addSubview:self.content];
 [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],[outer.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],[outer.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],[outer.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:32],[outer.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-32],[outer.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48],[self.content.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor constant:24],[self.content.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-24],[self.content.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor constant:28],[self.content.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor constant:-28]]];
 [outer addArrangedSubview:[self label:@"FREE FIRE VN 1.134.1     /     MIZZE" size:10 weight:UIFontWeightMedium]];
 MizzeLicenseBegin();[self buildTab];self.timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshStatus) userInfo:nil repeats:YES];
 self.splash=[[UIView alloc] initWithFrame:self.view.bounds];self.splash.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.splash.backgroundColor=self.view.backgroundColor;[self.view addSubview:self.splash];
 UILabel *welcome=[self label:@"HoangHa × Đông Nhật\nMIZZE · KERNEL" size:24 weight:UIFontWeightSemibold];welcome.textAlignment=NSTextAlignmentCenter;welcome.translatesAutoresizingMaskIntoConstraints=NO;[self.splash addSubview:welcome];[NSLayoutConstraint activateConstraints:@[[welcome.centerXAnchor constraintEqualToAnchor:self.splash.centerXAnchor],[welcome.centerYAnchor constraintEqualToAnchor:self.splash.centerYAnchor],[welcome.widthAnchor constraintLessThanOrEqualToAnchor:self.splash.widthAnchor constant:-40]]];
 [UIView animateWithDuration:UIAccessibilityIsReduceMotionEnabled()?0:.45 delay:.65 options:UIViewAnimationOptionCurveEaseOut animations:^{self.splash.alpha=0;} completion:^(BOOL finished){[self.splash removeFromSuperview];self.splash=nil;}];
}
-(void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];self.gradient.frame=self.view.bounds;}
-(void)buildTab {
 for(UIView *v in self.content.arrangedSubviews){[self.content removeArrangedSubview:v];[v removeFromSuperview];}self.start=nil;self.key=nil;
 NSInteger tab=self.tabs.selectedSegmentIndex;
 [self.content addArrangedSubview:[self label:tab==0?@"Sẵn sàng vào trận.":tab==1?@"Không gian gọn gàng.":@"Giấy phép của bạn." size:26 weight:UIFontWeightSemibold]];
 self.status=[self label:@"" size:13 weight:UIFontWeightMedium];self.status.textColor=[UIColor colorWithRed:.68 green:.9 blue:.84 alpha:1];[self.content addArrangedSubview:self.status];
 if(tab==0||tab==2){
  self.key=[UITextField new];self.key.placeholder=@"Nhập key Mizze";self.key.text=MizzeLicenseSavedKey();self.key.secureTextEntry=YES;self.key.autocapitalizationType=UITextAutocapitalizationTypeNone;self.key.autocorrectionType=UITextAutocorrectionTypeNo;self.key.textColor=UIColor.whiteColor;self.key.backgroundColor=[UIColor colorWithWhite:0 alpha:.22];self.key.layer.cornerRadius=16;self.key.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,16,1)];self.key.leftViewMode=UITextFieldViewModeAlways;[self.key.heightAnchor constraintEqualToConstant:54].active=YES;self.key.accessibilityLabel=@"Key Mizze";[self.content addArrangedSubview:self.key];
  [self.content addArrangedSubview:[self button:tab==0?@"Khởi động menu":@"Xác minh key" action:tab==0?@selector(startHUD):@selector(validateKey) primary:YES]];self.start=(UIButton *)self.content.arrangedSubviews.lastObject;
  [self.content addArrangedSubview:[self button:tab==0?@"Dừng menu":@"Xóa key đã lưu" action:tab==0?@selector(stopHUD):@selector(forgetKey) primary:NO]];
  [self.content addArrangedSubview:[self label:@"Key được lưu an toàn trên máy. Cần kết nối mạng để xác minh và duy trì phiên." size:12 weight:UIFontWeightRegular]];
 }else{
  [self.content addArrangedSubview:[self label:@"Dọn tệp tạm của Mizze trong vùng dữ liệu ứng dụng. Dừng menu trước khi dọn." size:14 weight:UIFontWeightRegular]];
  [self.content addArrangedSubview:[self button:@"Dọn dữ liệu tạm" action:@selector(cleanCache) primary:YES]];
 }
 [self refreshStatus];
}
-(void)validateAndStart:(BOOL)launch {
 [self.view endEditing:YES];self.start.enabled=NO;self.status.text=@"Đang xác minh…";
 MizzeLicenseCheck(self.key.text,^(BOOL ok,NSString *text){self.start.enabled=YES;self.status.text=text;if(!ok||!launch)return;NSError *error=nil;if(!IsHUDEnabled()&&!StartHUD(&error)){self.status.text=@"Không mở được menu. Vui lòng thử lại.";return;}
 Class c=NSClassFromString(@"LSApplicationWorkspace");if([c respondsToSelector:@selector(defaultWorkspace)]){id w=[c defaultWorkspace];if([w respondsToSelector:@selector(openApplicationWithBundleID:)])[w openApplicationWithBundleID:@"com.garena.ffvn"];}});
}
-(void)startHUD{[self validateAndStart:YES];}
-(void)validateKey{[self validateAndStart:NO];}
-(void)stopHUD{StopHUD();[self refreshStatus];}
-(void)forgetKey{StopHUD();MizzeLicenseForget();self.key.text=@"";[self refreshStatus];}
-(void)refreshStatus {
 if(self.tabs.selectedSegmentIndex==1)return;
 if(!self.start.enabled)return;
 self.status.text=MizzeLicenseAuthorized()?(IsHUDEnabled()?@"Menu đang hoạt động":@"Đã xác minh · Sẵn sàng"):MizzeLicenseMessage();
}
-(void)cleanCache {
 if(IsHUDEnabled()){self.status.text=@"Dừng menu trước khi dọn dữ liệu tạm.";return;}
 NSString *cache=NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject;
 NSArray *paths=@[[cache stringByAppendingPathComponent:@"MizzeTransient"],[NSTemporaryDirectory() stringByAppendingPathComponent:@"MizzeTransient"]];
 unsigned long long bytes=0;NSError *failure=nil;
 for(NSString *path in paths){NSString *resolved=path.stringByResolvingSymlinksInPath;NSString *base=[path.stringByDeletingLastPathComponent.stringByResolvingSymlinksInPath stringByAppendingString:@"/"];if(![resolved hasPrefix:base])continue;
  NSDirectoryEnumerator *it=[NSFileManager.defaultManager enumeratorAtPath:path];for(NSString *name in it){NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:[path stringByAppendingPathComponent:name] error:nil];bytes+=[a fileSize];}
  if([NSFileManager.defaultManager fileExistsAtPath:path]&&![NSFileManager.defaultManager removeItemAtPath:path error:&failure])break;
 }
 self.status.text=failure?@"Chưa dọn được dữ liệu tạm.":[NSString stringWithFormat:@"Đã dọn %.2f MB dữ liệu tạm.",bytes/1048576.0];
}
-(void)dealloc{[self.timer invalidate];}
@end
@implementation MainApplicationDelegate
-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[KernelLauncher new];[self.window makeKeyAndVisible];return YES;
}
@end
