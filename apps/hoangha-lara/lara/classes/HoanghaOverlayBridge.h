#import <Foundation/Foundation.h>
#import "RemoteCall.h"

NS_ASSUME_NONNULL_BEGIN

/// Uses Lara's existing SpringBoard RemoteCall session. Call off the app's main queue.
bool hoangha_overlay_show(RemoteCall *session);
bool hoangha_overlay_hide(RemoteCall *session);
NSString *hoangha_overlay_last_error(void);
bool hoangha_floating_start(RemoteCall *session, NSData *logo);
bool hoangha_floating_tick(RemoteCall *session);
bool hoangha_floating_stop(RemoteCall *session);


pid_t hoangha_foreground_game(RemoteCall *springboard, CGSize *size, NSInteger *orientation);
void hoangha_floating_layout(RemoteCall *session, CGSize size, NSInteger orientation);
BOOL hoangha_floating_esp_enabled(void);
CGSize hoangha_floating_size(void);
BOOL hoangha_floating_boxes(RemoteCall *session, NSArray<NSValue *> *boxes);
void hoangha_floating_status(RemoteCall *session, NSString *status);

NS_ASSUME_NONNULL_END
