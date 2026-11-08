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

NS_ASSUME_NONNULL_END
