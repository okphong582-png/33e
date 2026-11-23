#import "MZLicenseGate.h"
#import "MizzeLicense.h"
#import "MZTheme.h"
#import "MZUI.h"

@interface MZLicenseLockViewController : UIViewController<UITextFieldDelegate>
@property(nonatomic,strong) UITextField *keyField;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *continueButton;
@property(nonatomic,strong) id observer;
@end
@implementation MZLicenseLockViewController
- (void)dealloc { if (_observer) [[NSNotificationCenter defaultCenter]removeObserver:_observer]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=MZThemeBg();
    UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;
    scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive;[self.view addSubview:scroll];
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=18;
    stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
    UIImageView *logo=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"logo.png"]];
    logo.contentMode=UIViewContentModeScaleAspectFit;
    [logo.heightAnchor constraintEqualToConstant:108].active=YES;[stack addArrangedSubview:logo];
    UILabel *brand=[UILabel new];brand.text=@"MIZZE KERNEL  /  STUDIO";
    brand.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];brand.textColor=MZThemeMuted();brand.textAlignment=NSTextAlignmentCenter;[stack addArrangedSubview:brand];
    UILabel *title=[UILabel new];title.text=@"Chào mừng.";title.font=[UIFont systemFontOfSize:38 weight:UIFontWeightBold];title.textColor=MZThemeText();[stack addArrangedSubview:title];
    UILabel *detail=[UILabel new];detail.text=@"Nhập key để tiếp tục.";detail.textColor=MZThemeMuted();detail.font=[UIFont systemFontOfSize:17];[stack addArrangedSubview:detail];
    UIStackView *card=[UIStackView new];card.axis=UILayoutConstraintAxisVertical;card.spacing=18;card.layoutMargins=UIEdgeInsetsMake(24,22,24,22);card.layoutMarginsRelativeArrangement=YES;card.backgroundColor=MZThemePanel();card.layer.cornerRadius=26;card.layer.borderWidth=1;card.layer.borderColor=MZThemeLine().CGColor;[stack addArrangedSubview:card];
    UILabel *caption=[UILabel new];caption.text=@"KEY TRUY CẬP";caption.font=[UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];caption.textColor=MZThemeMuted();[card addArrangedSubview:caption];
    _keyField=[UITextField new];_keyField.delegate=self;_keyField.placeholder=@"Nhập key";_keyField.secureTextEntry=YES;_keyField.autocorrectionType=UITextAutocorrectionTypeNo;_keyField.autocapitalizationType=UITextAutocapitalizationTypeNone;_keyField.returnKeyType=UIReturnKeyGo;_keyField.textContentType=UITextContentTypePassword;_keyField.textColor=MZThemeText();_keyField.backgroundColor=MZThemeBg();_keyField.layer.cornerRadius=16;_keyField.font=[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular];
    UIView *padding=[[UIView alloc]initWithFrame:CGRectMake(0,0,16,1)];_keyField.leftView=padding;_keyField.leftViewMode=UITextFieldViewModeAlways;[_keyField.heightAnchor constraintEqualToConstant:62].active=YES;_keyField.text=MizzeLicenseSavedKey();[card addArrangedSubview:_keyField];
    _continueButton=[UIButton buttonWithType:UIButtonTypeSystem];[_continueButton setTitle:@"Tiếp tục  →" forState:UIControlStateNormal];_continueButton.backgroundColor=MZThemeAccent();[_continueButton setTitleColor:MZThemeBg() forState:UIControlStateNormal];_continueButton.layer.cornerRadius=17;_continueButton.titleLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];[_continueButton.heightAnchor constraintEqualToConstant:60].active=YES;[_continueButton addTarget:self action:@selector(checkKey) forControlEvents:UIControlEventTouchUpInside];[card addArrangedSubview:_continueButton];
    UIButton *forget=[UIButton buttonWithType:UIButtonTypeSystem];[forget setTitle:@"Xóa key" forState:UIControlStateNormal];forget.tintColor=MZThemeMuted();[forget addTarget:self action:@selector(forgetKey) forControlEvents:UIControlEventTouchUpInside];[card addArrangedSubview:forget];
    _statusLabel=[UILabel new];_statusLabel.font=[UIFont systemFontOfSize:13];_statusLabel.textColor=MZThemeMuted();_statusLabel.numberOfLines=0;_statusLabel.text=MizzeLicenseMessage();[card addArrangedSubview:_statusLabel];
    UILabel *footer=[UILabel new];footer.text=@"FREE FIRE VN  1.134.1";footer.textAlignment=NSTextAlignmentCenter;footer.textColor=MZThemeMuted();footer.font=[UIFont systemFontOfSize:11 weight:UIFontWeightMedium];[stack addArrangedSubview:footer];
    [NSLayoutConstraint activateConstraints:@[
      [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
      [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
      [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
      [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:32],
      [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-32],
      [stack.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
      [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]
    ]];
    __weak __typeof__(self) weakSelf=self;
    _observer=[[NSNotificationCenter defaultCenter]addObserverForName:@"MizzeLicenseStateChanged" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){weakSelf.statusLabel.text=MizzeLicenseMessage();}];
}
- (void)checkKey {
    [_keyField resignFirstResponder];_continueButton.enabled=NO;_continueButton.alpha=.6;_statusLabel.text=@"Đang xác thực…";
    __weak __typeof__(self) weakSelf=self;
    MizzeLicenseCheck(_keyField.text,^(BOOL ok,NSString *text){weakSelf.continueButton.enabled=YES;weakSelf.continueButton.alpha=1;weakSelf.statusLabel.text=ok?@"":text;});
}
- (void)forgetKey { MizzeLicenseForget();_keyField.text=@"";_statusLabel.text=@"Nhập key để tiếp tục."; }
- (BOOL)textFieldShouldReturn:(UITextField *)field { [self checkKey];return NO; }
@end

@implementation MZLicenseGate
+ (BOOL)authorized { return MizzeLicenseAuthorized(); }
+ (UIViewController *)lockViewController { return [MZLicenseLockViewController new]; }
+ (void)startWithAuthorized:(dispatch_block_t)authorized terminal:(void(^)(NSString *))terminal {
    static id observer;
    if(observer)[[NSNotificationCenter defaultCenter]removeObserver:observer];
    __block BOOL wasAuthorized=NO;
    observer=[[NSNotificationCenter defaultCenter]addObserverForName:@"MizzeLicenseStateChanged" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        BOOL current=MizzeLicenseAuthorized();
        if(current&&!wasAuthorized){wasAuthorized=YES;if(authorized)authorized();}
        else if(!current&&wasAuthorized){wasAuthorized=NO;if(terminal)terminal(MizzeLicenseMessage());}
    }];
    MizzeLicenseBegin();
}
@end
