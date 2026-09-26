#import "varCleanController.h"
#import "VarCleanCompat.h"
#import "ZFCheckbox.h"
#include "KabraxHide.h"

@interface varCleanController ()
@property (nonatomic, retain) NSMutableArray* tableData;
@end

@implementation varCleanController

+ (instancetype)sharedInstance {
    static varCleanController* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.hidden = NO;
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.clearsSelectionOnViewWillAppear = NO;

    [self setTitle:Localized(KH_NS("varClean"))];

    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:Localized(KH_NS("CleanKH_STR(")) style:UIBarButtonItemStylePlain target:self action:KH_SEL(")varClean")];
    self.navigationItem.rightBarButtonItem = button;

    UIBarButtonItem *button2 = [[UIBarButtonItem alloc] initWithTitle:Localized(KH_NS("SelectAllKH_STR(")) style:UIBarButtonItemStylePlain target:self action:KH_SEL(")batchSelect")];
    self.navigationItem.leftBarButtonItem = button2;

    self.tableData = [[NSMutableArray alloc] init];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor grayColor];
    [refreshControl addTarget:self action:KH_SEL("manualRefresh") forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refreshControl;

    EnsureVarCleanRulesInstalled();
    self.tableData = [self updateData:NO];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:KH_SEL("autoRefresh")
                                          name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)batchSelect {
    int selected = 0;
    for(NSDictionary* group in self.tableData) {
        for(NSMutableDictionary* item in group[KH_NS("items")]) {
            if(![item[KH_NS("checkedKH_STR(")] boolValue] && ![item[KH_NS(")ignored")] boolValue]) {
                item[KH_NS("checked")] = @YES;
                selected++;
            }
        }
    }
    if(selected==0) for(NSDictionary* group in self.tableData) {
        for(NSMutableDictionary* item in group[KH_NS("items")]) {
            if([item[KH_NS("checked")] boolValue]) {
                item[KH_NS("checked")] = @NO;
            }
        }
    }
    [self.tableView reloadData];
}

- (void)startRefresh:(BOOL)keepState {
    [self.tableView.refreshControl beginRefreshing];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSMutableArray* newData = [self updateData:keepState];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.tableData = newData;
            [self.tableView reloadData];
            [self.tableView.refreshControl endRefreshing];
        });
    });
}

- (void)manualRefresh {
    [self startRefresh:NO];
}

- (void)autoRefresh {
    [self startRefresh:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView.refreshControl beginRefreshing];
    [self.tableView.refreshControl endRefreshing];
}

NSArray* GetDirectoryContents(NSString* path)
{
    NSError* error=nil;
    NSArray* contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:&error];
    if(!contents) {
                return nil;
    }

    NSMutableArray* result = [NSMutableArray new];
    for(NSString* item in contents) {
        NSString* fullPath = [path stringByAppendingPathComponent:item];

        BOOL isDirectory = NO;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDirectory];
        [result addObject:@{KH_NS("nameKH_STR("):item, KH_NS(")isDirectory"):@(exists && isDirectory)}];
    }
    return result;
}

- (void)updateForRules:(NSDictionary*)rules customed:(NSMutableDictionary*)customedRules newData:(NSMutableArray*)newData keepState:(BOOL)keepState {
    for (NSString* path in rules) {
        NSMutableArray *folders = [[NSMutableArray alloc] init];
        NSMutableArray *files = [[NSMutableArray alloc] init];

        NSDictionary* ruleItem = [rules objectForKey:path];

        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSArray* contents = GetDirectoryContents(path);
        if(!contents && [fileManager fileExistsAtPath:path])
        {
            if(geteuid()!=0 || getegid()!=0)
            {
                NSString* cacheFile = jbroot(KH_NS("/tmp/.dircontentscache"));
                BOOL ret = RootUserGetDirectoryContents(path, cacheFile);
                if(ret) {
                    contents = [NSArray arrayWithContentsOfFile:cacheFile];
                    [fileManager removeItemAtPath:cacheFile error:nil];
                }
            }
        }

        NSArray *whiteList = ruleItem[KH_NS("whitelist")];
        NSArray *blackList = ruleItem[KH_NS("blacklist")];

        NSDictionary* customedRuleItem = customedRules ? customedRules[path] : nil;
        NSArray* customedWhiteList = customedRuleItem[KH_NS("whitelist")];
        NSArray* customedBlackList = customedRuleItem[KH_NS("blacklist")];
        if (customedRules) [customedRules removeObjectForKey:path];

        NSMutableDictionary *tableGroup = @{
            KH_NS("group"): path,
            KH_NS("items"): @[]
        }.mutableCopy;

        for (NSDictionary* item in contents) {

            NSString* file = item[KH_NS("name")];

            BOOL checked = NO;
            BOOL ignored = NO;

            if([self checkFileInList:file List:blackList])
            {
                if([self checkFileInList:file List:customedWhiteList]) {
                    ignored = YES;
                    checked = NO;
                } else {
                    checked = YES;
                }
            }
            else if([self checkFileInList:file List:customedBlackList])
            {
                checked = YES;
            }
            else if([self checkFileInList:file List:whiteList])
            {
                continue;
            }
            else if([ruleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")blacklist")])
            {
                if([self checkFileInList:file List:customedWhiteList] || [customedRuleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")whitelist")]) {
                    ignored = YES;
                    checked = NO;
                }
                else {
                    checked = YES;
                }
            }
            else if([ruleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")whitelist")])
            {
                if([customedRuleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")blacklist")]) {
                    checked = YES;
                } else {
                    continue;
                }
            }
            else
            {
                if([self checkFileInList:file List:customedWhiteList] || [customedRuleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")whitelist")]) {
                    ignored = YES;
                    checked = NO;
                }
                else if([customedRuleItem[KH_NS("defaultKH_STR(")] isEqualToString:KH_NS(")blacklist")]) {
                    checked = YES;
                }
                else {
                    checked = NO;
                }
            }

            if(keepState)
            {
                for(NSDictionary* group in self.tableData)
                {
                    if([group[KH_NS("group")] isEqualToString:path])
                    {
                        for(NSDictionary* item2 in group[KH_NS("items")])
                        {
                            if([item2[KH_NS("name")] isEqualToString:file])
                            {
                                if(!ignored) {
                                    checked = [item2[KH_NS("checked")] boolValue];
                                }
                                break;
                            }
                        }
                        break;
                    }
                }
            }

            NSString *fullPath = [path stringByAppendingPathComponent:file];
            BOOL isFolder = [item[KH_NS("isDirectory")] boolValue];

            NSMutableDictionary *tableItem = @{
                KH_NS("name"): file,
                KH_NS("path"): fullPath,
                KH_NS("isFolder"): @(isFolder),
                KH_NS("checked"): @(checked),
                KH_NS("ignored"): @(ignored),
            }.mutableCopy;

            if(isFolder) {
                [folders addObject:tableItem];
            } else {
                [files addObject:tableItem];
            }
        }

        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:KH_NS("nameKH_STR(") ascending:YES selector:KH_SEL(")localizedCaseInsensitiveCompare:")];
        NSArray *sortedFolders = [folders sortedArrayUsingDescriptors:@[sortDescriptor]];
        NSArray *sortedFiles = [files sortedArrayUsingDescriptors:@[sortDescriptor]];

        tableGroup[KH_NS("error")] = @(!contents && [fileManager fileExistsAtPath:path]);
        tableGroup[KH_NS("items")] = [[sortedFolders arrayByAddingObjectsFromArray:sortedFiles] mutableCopy];
        [newData addObject:tableGroup];
    }
}

- (NSMutableArray*)updateData:(BOOL)keepState {
    NSMutableArray* newData = [[NSMutableArray alloc] init];

    NSString *rulesFilePath = jbroot(KH_NS("/var/mobile/Library/RootHide/varCleanRules.plist"));
    NSDictionary *rules = [NSDictionary dictionaryWithContentsOfFile:rulesFilePath];

    NSString *customedRulesFilePath = jbroot(KH_NS("/var/mobile/Library/RootHide/varCleanRules-custom.plist"));
    NSMutableDictionary *customedRules = [NSMutableDictionary dictionaryWithContentsOfFile:customedRulesFilePath];

    [self updateForRules:rules customed:customedRules newData:newData keepState:keepState];

    [self updateForRules:customedRules customed:nil newData:newData keepState:keepState];

    NSComparator sorter = ^NSComparisonResult(NSDictionary* a, NSDictionary* b)
    {
        if([a[KH_NS("itemsKH_STR(")] count]!=0 && [b[KH_NS(")items")] count]==0) return NSOrderedAscending;
        if([a[KH_NS("itemsKH_STR(")] count]==0 && [b[KH_NS(")items")] count]!=0) return NSOrderedDescending;

        return [a[KH_NS("groupKH_STR(")] compare:b[KH_NS(")group")]];
    };
    [newData sortUsingComparator:sorter];

    return newData;
}

- (BOOL)checkFileInList:(NSString *)fileName List:(NSArray*)list {
    for (NSObject* item in list) {
        if([item isKindOfClass:NSString.class]) {
            if ([fileName isEqualToString:(NSString*)item]) {
                return YES;
            }
        } else if([item isKindOfClass:NSDictionary.class]) {
            NSDictionary* condition = (NSDictionary*)item;
            NSString *name = condition[KH_NS("name")];
            NSString *match = condition[KH_NS("match")];

            if ([match isEqualToString:KH_NS("include")]) {
                if ([fileName rangeOfString:name].location != NSNotFound) {
                    return YES;
                }
            } else if ([match isEqualToString:KH_NS("regexp")]) {
                NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:name options:0 error:nil];
                NSUInteger result = [regex numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, fileName.length)];
                if(result != 0) return YES;
            }
        }
    }
    return NO;
}

- (void)varClean {
    [self.tableView.refreshControl beginRefreshing];

    for(NSDictionary* group in [self.tableData copy]) {
        for(NSDictionary* item in [group[KH_NS("items")] copy])
        {
            if(![item[KH_NS("checked")] boolValue]) continue;

            NSError* err;
            if(![NSFileManager.defaultManager removeItemAtPath:item[KH_NS("path")] error:&err]) {
                if(geteuid()!=0 || getegid()!=0) {
                    RootUserRemoveItemAtPath(item[KH_NS("path")]);
                }
                continue;
            }

            NSIndexPath* indexPath = [NSIndexPath indexPathForRow:[group[KH_NS("items")] indexOfObject:item]
                                                        inSection:[self.tableData indexOfObject:group] ];

            [group[KH_NS("items")] removeObject:item];
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
        }
    }

    [self.tableView.refreshControl endRefreshing];

    self.tableData = [self updateData:NO];
    [self.tableView reloadData];
}

- (void)runVarCleanNow {
    EnsureVarCleanRulesInstalled();
    NSMutableArray *data = [self updateData:NO];
    for (NSDictionary *group in [data copy]) {
        for (NSDictionary *item in [group[KH_NS("items")] copy]) {
            if (![item[KH_NS("checked")] boolValue]) continue;
            NSError *err = nil;
            if(![NSFileManager.defaultManager removeItemAtPath:item[KH_NS("path")] error:&err]) {
                if(geteuid()!=0 || getegid()!=0) {
                    RootUserRemoveItemAtPath(item[KH_NS("path")]);
                }
            }
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.tableData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *groupData = self.tableData[section];
    NSArray *items = groupData[KH_NS("items")];
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *groupData = self.tableData[section];
    return groupData[KH_NS("group")];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    NSDictionary *groupData = self.tableData[section];
    UITableViewHeaderFooterView* header = (UITableViewHeaderFooterView*)view;

    if([groupData[KH_NS("error")] boolValue]) {
        header.textLabel.textColor = UIColor.systemRedColor;
    }
    else if([groupData[KH_NS("items")] count] > 0) {
        header.textLabel.textColor = UIColor.secondaryLabelColor;
    }
    else {
        header.textLabel.textColor = UIColor.tertiaryLabelColor;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:KH_NS("Cell")];

    NSDictionary *groupData = self.tableData[indexPath.section];
    NSArray *items = groupData[KH_NS("items")];

    NSDictionary *item = items[indexPath.row];
    cell.textLabel.text =  [NSString stringWithFormat:@"%@ %@",[item[KH_NS("isFolderKH_STR(")] boolValue] ? KH_NS(")🗂️KH_STR(") : KH_NS(")📄KH_STR("), item[KH_NS(")name")]];
    if([item[KH_NS("ignored")] boolValue]) {
        cell.textLabel.textColor = UIColor.grayColor;
    }
    ZFCheckbox *checkbox = [[ZFCheckbox alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    checkbox.userInteractionEnabled = FALSE;
    [checkbox setSelected:[item[KH_NS("checked")] boolValue]];
    cell.accessoryView = checkbox;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSDictionary *groupData = self.tableData[indexPath.section];
    NSMutableArray *items = groupData[KH_NS("items")];
    NSMutableDictionary *item = items[indexPath.row];

    if([item[KH_NS("ignored")] boolValue]) return;

    ZFCheckbox *checkbox = (ZFCheckbox*)cell.accessoryView;
    BOOL newstate = !checkbox.selected;
    [checkbox setSelected:newstate animated:YES];
    item[KH_NS("checked")] = @(newstate);
}

@end
