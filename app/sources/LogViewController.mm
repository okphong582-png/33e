#import "LogViewController.h"
#import "MZLogView.h"
#import "MZUI.h"
#import "MZTheme.h"

@interface LogViewController ()
@property (nonatomic, strong) MZLogView *logView;
@end

@implementation LogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Log";
    self.view.backgroundColor = MZThemeBg();
    MZUIApplyNavigationBarStyle(self.navigationController.navigationBar);

    _logView = [[MZLogView alloc] initWithFrame:CGRectZero];
    // Pinned to the safe area, not to a frame worked out from safeAreaInsets.
    // That inset is the status bar on its own and stops short of the
    // navigation bar, so the console started under the bar and the top of the
    // header card was hidden behind it.
    _logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_logView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_logView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [_logView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [_logView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [_logView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    MZUIApplyNavigationBarStyle(self.navigationController.navigationBar);
    [_logView refresh];
}

@end