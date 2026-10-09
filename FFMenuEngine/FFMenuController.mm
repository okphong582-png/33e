#import "FFMenuController.h"
#import "LaraMemoryReader.h"

@interface FFMenuController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIVisualEffectView *blurContainer;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *menuSections;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation FFMenuController

+ (instancetype)sharedMenu {
    static FFMenuController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FFMenuController alloc] init];
    });
    return instance;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    // Blur container (Glassmorphic look)
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurContainer = [[UIVisualEffectView alloc] initWithEffect:blur];
    _blurContainer.frame = CGRectMake(0, 0, 320, 460);
    _blurContainer.center = self.view.center;
    _blurContainer.layer.cornerRadius = 20;
    _blurContainer.clipsToBounds = YES;
    _blurContainer.layer.borderWidth = 1.0;
    _blurContainer.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.5].CGColor;
    [self.view addSubview:_blurContainer];
    
    // Header Label
    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, 280, 30)];
    header.text = @"FF LARA ENGINE v1.0";
    header.textColor = [UIColor colorWithRed:0.0 green:0.9 blue:1.0 alpha:1.0];
    header.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    header.textAlignment = NSTextAlignmentCenter;
    [_blurContainer.contentView addSubview:header];
    
    // Status Label
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 46, 280, 28)];
    _statusLabel.numberOfLines = 2;
    _statusLabel.text = @"DarkSword: Waiting for Exploit...";
    _statusLabel.textColor = [UIColor lightGrayColor];
    _statusLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    [_blurContainer.contentView addSubview:_statusLabel];
    
    // Menu Options Table
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(10, 75, 300, 320) style:UITableViewStyleGrouped];
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:0.5];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [_blurContainer.contentView addSubview:_tableView];
    
    // Close / Hide Button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 405, 280, 40);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.9 alpha:0.8];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn setTitle:@"Hide Menu Overlay" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
    [_blurContainer.contentView addSubview:closeBtn];
    
    [self buildMenuItems];
    [self updateStatus];
}

- (void)buildMenuItems {
    _menuSections = @[
        @{
            @"section": @"Kernel Memory Engine",
            @"items": @[
                @{@"title": @"Attach to FreeFire", @"type": @"action", @"key": @"attach"}
            ]
        },
        @{
            @"section": @"ESP Overlay Options",
            @"items": @[
                @{@"title": @"ESP Box", @"type": @"switch", @"key": @"box"},
                @{@"title": @"ESP Snaplines", @"type": @"switch", @"key": @"line"},
                @{@"title": @"ESP Distance", @"type": @"switch", @"key": @"dist"},
                @{@"title": @"ESP Health Bar", @"type": @"switch", @"key": @"hp"},
                @{@"title": @"FOV Circle", @"type": @"switch", @"key": @"fov"},
                @{@"title": @"Crosshair Overlay", @"type": @"switch", @"key": @"crosshair"}
            ]
        }
    ];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _blurContainer.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

- (void)updateStatus {
    LaraMemoryReader *reader = [LaraMemoryReader sharedInstance];
    if (reader.isKernelReady) {
        if (reader.targetProcAddress != 0) {
            _statusLabel.text = [NSString stringWithFormat:@"DarkSword | PID: %d | Base: 0x%llx", reader.targetPID, (unsigned long long)reader.mainModuleBase];
            _statusLabel.textColor = [UIColor greenColor];
        } else {
            _statusLabel.text = @"DarkSword Ready | Not Attached to FreeFire";
            _statusLabel.textColor = [UIColor yellowColor];
        }
    } else {
        _statusLabel.text = @"Run DarkSword Exploit in Lara first";
        _statusLabel.textColor = [UIColor redColor];
    }
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _menuSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *items = _menuSections[section][@"items"];
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _menuSections[section][@"section"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"FFMenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.3];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSDictionary *item = _menuSections[indexPath.section][@"items"][indexPath.row];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.text = item[@"title"];
    
    NSString *type = item[@"type"];
    if ([type isEqualToString:@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0];
        sw.tag = indexPath.section * 100 + indexPath.row;
        
        ESPConfig cfg = [LaraESPOverlayWindow sharedOverlay].espConfig;
        NSString *key = item[@"key"];
        if ([key isEqualToString:@"box"]) sw.on = cfg.showBox;
        else if ([key isEqualToString:@"line"]) sw.on = cfg.showLine;
        else if ([key isEqualToString:@"dist"]) sw.on = cfg.showDistance;
        else if ([key isEqualToString:@"hp"]) sw.on = cfg.showHealth;
        else if ([key isEqualToString:@"fov"]) sw.on = cfg.showFOVCircle;
        else if ([key isEqualToString:@"crosshair"]) sw.on = cfg.showCrosshair;
        
        [sw addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else if ([type isEqualToString:@"action"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _menuSections[indexPath.section][@"items"][indexPath.row];
    NSString *key = item[@"key"];
    
    if ([key isEqualToString:@"attach"]) {
        LaraMemoryReader *reader = [LaraMemoryReader sharedInstance];
        BOOL success = [reader attachToProcessNamed:@"FreeFire"];
        if (!success) {
            success = [reader attachToProcessNamed:@"FreeFireMax"];
        }
        [self updateStatus];
        if (!success) {
            _statusLabel.text = @"FreeFire process not running. Open game first.";
            _statusLabel.textColor = [UIColor orangeColor];
        }
    }
}

- (void)switchToggled:(UISwitch *)sw {
    NSInteger section = sw.tag / 100;
    NSInteger row = sw.tag % 100;
    NSDictionary *item = _menuSections[section][@"items"][row];
    NSString *key = item[@"key"];
    
    LaraESPOverlayWindow *overlay = [LaraESPOverlayWindow sharedOverlay];
    ESPConfig cfg = overlay.espConfig;
    
    if ([key isEqualToString:@"box"]) cfg.showBox = sw.isOn;
    else if ([key isEqualToString:@"line"]) cfg.showLine = sw.isOn;
    else if ([key isEqualToString:@"dist"]) cfg.showDistance = sw.isOn;
    else if ([key isEqualToString:@"hp"]) cfg.showHealth = sw.isOn;
    else if ([key isEqualToString:@"fov"]) cfg.showFOVCircle = sw.isOn;
    else if ([key isEqualToString:@"crosshair"]) cfg.showCrosshair = sw.isOn;
    
    overlay.espConfig = cfg;
}

- (void)showMenu {
    self.view.hidden = NO;
    [self updateStatus];
}

- (void)hideMenu {
    self.view.hidden = YES;
}

- (void)toggleMenu {
    self.view.hidden = !self.view.hidden;
    if (!self.view.hidden) {
        [self updateStatus];
    }
}

@end
