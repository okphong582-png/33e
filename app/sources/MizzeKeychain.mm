#import "MizzeKeychain.h"

static NSString *const identityAccount = @"device-session.v1";
static NSMutableDictionary *MizzeKeychainQuery(NSString *service, NSString *account) {
    // Let Security.framework use the installed app's actual access groups.
    // New writes go to the first (private) group in the signed entitlements.
    return [@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService:service,
              (__bridge id)kSecAttrAccount:account,
              (__bridge id)kSecAttrSynchronizable:@NO} mutableCopy];
}

NSData *MizzeKeychainRead(NSString *service, NSString *account, OSStatus *status) {
    NSMutableDictionary *query = MizzeKeychainQuery(service, account);
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    OSStatus code = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    id value = CFBridgingRelease(result);
    if (code == errSecSuccess && ![value isKindOfClass:NSData.class]) code = errSecDecode;
    if (status) *status = code;
    return code == errSecSuccess ? value : nil;
}

BOOL MizzeKeychainWrite(NSString *service, NSString *account, NSData *data, OSStatus *status) {
    if (!service.length || !account.length || !data.length || data.length > 16384) {
        if (status) *status = errSecParam;
        return NO;
    }
    NSMutableDictionary *query = MizzeKeychainQuery(service, account);
    NSDictionary *attributes = @{
        (__bridge id)kSecValueData:data,
        (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    // Update in place: a failed update must not delete an existing identity.
    OSStatus code = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (code == errSecItemNotFound) {
        NSMutableDictionary *add = [query mutableCopy];
        [add addEntriesFromDictionary:attributes];
        code = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
        if (code == errSecDuplicateItem)
            code = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    }
    if (code == errSecSuccess) {
        NSData *saved = MizzeKeychainRead(service, account, &code);
        if (code == errSecSuccess && ![saved isEqualToData:data]) code = errSecDecode;
    }
    if (status) *status = code;
    return code == errSecSuccess;
}

BOOL MizzeKeychainDelete(NSString *service, NSString *account, OSStatus *status) {
    OSStatus code = SecItemDelete((__bridge CFDictionaryRef)MizzeKeychainQuery(service, account));
    if (status) *status = code;
    return code == errSecSuccess || code == errSecItemNotFound;
}

static BOOL MizzeIdentityValid(id record) {
    if (![record isKindOfClass:NSDictionary.class]) return NO;
    id version = record[@"v"], uid = record[@"uid"], refresh = record[@"refresh"];
    return [version isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)version) != CFBooleanGetTypeID() && [version intValue] == 1 &&
        [uid isKindOfClass:NSString.class] && [uid length] >= 8 && [uid length] <= 128 &&
        [refresh isKindOfClass:NSString.class] && [refresh length] >= 16 && [refresh length] <= 4096;
}

BOOL MizzeKeychainWriteIdentity(NSString *service, NSString *uid, NSString *refresh, OSStatus *status) {
    NSDictionary *record = @{@"v":@1, @"uid":uid ?: @"", @"refresh":refresh ?: @""};
    if (!MizzeIdentityValid(record)) { if (status) *status = errSecParam; return NO; }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:record
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    return MizzeKeychainWrite(service, identityAccount, data, status);
}

NSDictionary *MizzeKeychainReadIdentity(NSString *service, OSStatus *status) {
    OSStatus code;
    NSData *data = MizzeKeychainRead(service, identityAccount, &code);
    if (code == errSecSuccess) {
        id record = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil];
        if (MizzeIdentityValid(record)) { if (status) *status = errSecSuccess; return record; }
        if (status) *status = errSecDecode;
        return nil;
    }
    if (code != errSecItemNotFound) { if (status) *status = code; return nil; }

    // Upgrade only a complete older pair. Denied writes leave the old pair intact.
    OSStatus uidStatus, refreshStatus;
    NSData *uidData = MizzeKeychainRead(service, @"uid", &uidStatus);
    NSData *refreshData = MizzeKeychainRead(service, @"refresh", &refreshStatus);
    NSString *uid = uidData ? [[NSString alloc] initWithData:uidData encoding:NSUTF8StringEncoding] : nil;
    NSString *refresh = refreshData ? [[NSString alloc] initWithData:refreshData encoding:NSUTF8StringEncoding] : nil;
    NSDictionary *record = @{@"v":@1, @"uid":uid ?: @"", @"refresh":refresh ?: @""};
    if (uidStatus == errSecSuccess && refreshStatus == errSecSuccess && MizzeIdentityValid(record)) {
        if (!MizzeKeychainWriteIdentity(service, uid, refresh, &code)) {
            if (status) *status = code;
            return nil;
        }
        MizzeKeychainDelete(service, @"uid", NULL);
        MizzeKeychainDelete(service, @"refresh", NULL);
        if (status) *status = errSecSuccess;
        return record;
    }
    if (status) *status = uidStatus != errSecSuccess && uidStatus != errSecItemNotFound ? uidStatus :
                         refreshStatus != errSecSuccess && refreshStatus != errSecItemNotFound ? refreshStatus : errSecItemNotFound;
    return nil;
}
