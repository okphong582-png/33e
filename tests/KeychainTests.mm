#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <cassert>
#include <cstdio>

static NSMutableDictionary<NSString *, NSData *> *records;
static OSStatus updateFailure, addFailure;
static int deletes, adds, updates, reads;
static BOOL duplicateRace;
static NSString *itemKey(CFDictionaryRef raw) {
    NSDictionary *q = (__bridge NSDictionary *)raw;
    assert(!q[(__bridge id)kSecAttrAccessGroup]);
    assert([q[(__bridge id)kSecAttrSynchronizable] isEqual:@NO]);
    return [NSString stringWithFormat:@"%@/%@", q[(__bridge id)kSecAttrService], q[(__bridge id)kSecAttrAccount]];
}
static OSStatus TestCopy(CFDictionaryRef raw, CFTypeRef *out) {
    reads++;
    NSData *value = records[itemKey(raw)];
    if (!value) return errSecItemNotFound;
    if (out) *out = CFBridgingRetain(value);
    return errSecSuccess;
}
static OSStatus TestUpdate(CFDictionaryRef raw, CFDictionaryRef changed) {
    updates++;
    NSString *key = itemKey(raw);
    if (updateFailure) return updateFailure;
    if (!records[key]) return errSecItemNotFound;
    NSDictionary *attributes = (__bridge NSDictionary *)changed;
    assert([attributes[(__bridge id)kSecAttrAccessible] isEqual:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]);
    records[key] = attributes[(__bridge id)kSecValueData];
    return errSecSuccess;
}
static OSStatus TestAdd(CFDictionaryRef raw, CFTypeRef *out) {
    adds++;
    NSString *key = itemKey(raw);
    NSDictionary *q = (__bridge NSDictionary *)raw;
    assert([q[(__bridge id)kSecAttrAccessible] isEqual:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]);
    if (addFailure) return addFailure;
    if (duplicateRace) { duplicateRace = NO; records[key] = [@"racing writer" dataUsingEncoding:NSUTF8StringEncoding]; return errSecDuplicateItem; }
    if (records[key]) return errSecDuplicateItem;
    records[key] = q[(__bridge id)kSecValueData];
    return errSecSuccess;
}
static OSStatus TestDelete(CFDictionaryRef raw) {
    deletes++;
    NSString *key = itemKey(raw);
    if (!records[key]) return errSecItemNotFound;
    [records removeObjectForKey:key];
    return errSecSuccess;
}

#define SecItemCopyMatching TestCopy
#define SecItemUpdate TestUpdate
#define SecItemAdd TestAdd
#define SecItemDelete TestDelete
#import "../app/sources/MizzeKeychain.mm"
#undef SecItemCopyMatching
#undef SecItemUpdate
#undef SecItemAdd
#undef SecItemDelete

static void reset() {
    records = [NSMutableDictionary new];
    updateFailure = addFailure = errSecSuccess;
    deletes = adds = updates = reads = 0;
    duplicateRace = NO;
}
int main() { @autoreleasepool {
    NSString *service = @"test.mizze", *uid = @"device-uid-A", *refresh = @"refresh-credential-AAAAAAAA";
    OSStatus status;
    reset();
    assert(MizzeKeychainWriteIdentity(service, uid, refresh, &status));
    assert(records.count == 1 && adds == 1 && deletes == 0);
    NSDictionary *restored = MizzeKeychainReadIdentity(service, &status);
    assert([restored[@"uid"] isEqual:uid] && [restored[@"refresh"] isEqual:refresh]);
    int previousReads = reads;
    restored = MizzeKeychainReadIdentity(service, &status); // cold caller, durable item survives
    assert(reads > previousReads && [restored[@"uid"] isEqual:uid]);
    assert(MizzeKeychainWriteIdentity(service, uid, @"refresh-credential-BBBBBBBB", &status));
    assert(records.count == 1 && adds == 1 && deletes == 0);
    assert([MizzeKeychainReadIdentity(service, &status)[@"refresh"] isEqual:@"refresh-credential-BBBBBBBB"]);

    NSData *old = records[@"test.mizze/device-session.v1"];
    updateFailure = errSecInteractionNotAllowed;
    assert(!MizzeKeychainWriteIdentity(service, uid, refresh, &status));
    assert(status == errSecInteractionNotAllowed && deletes == 0);
    assert([records[@"test.mizze/device-session.v1"] isEqualToData:old]);

    reset(); addFailure = errSecMissingEntitlement;
    assert(!MizzeKeychainWriteIdentity(service, uid, refresh, &status));
    assert(status == errSecMissingEntitlement && records.count == 0 && deletes == 0);
    reset(); duplicateRace = YES;
    assert(MizzeKeychainWriteIdentity(service, uid, refresh, &status));
    assert(updates == 2 && deletes == 0);

    reset();
    records[@"test.mizze/uid"] = [uid dataUsingEncoding:NSUTF8StringEncoding];
    records[@"test.mizze/refresh"] = [refresh dataUsingEncoding:NSUTF8StringEncoding];
    restored = MizzeKeychainReadIdentity(service, &status);
    assert(restored && records.count == 1 && deletes == 2);
    assert([restored[@"uid"] isEqual:uid] && [restored[@"refresh"] isEqual:refresh]);

    reset();
    records[@"test.mizze/uid"] = [uid dataUsingEncoding:NSUTF8StringEncoding];
    records[@"test.mizze/refresh"] = [refresh dataUsingEncoding:NSUTF8StringEncoding];
    addFailure = errSecMissingEntitlement;
    assert(!MizzeKeychainReadIdentity(service, &status));
    assert(records.count == 2 && deletes == 0 && status == errSecMissingEntitlement);

    reset(); records[@"test.mizze/uid"] = [uid dataUsingEncoding:NSUTF8StringEncoding];
    assert(!MizzeKeychainReadIdentity(service, &status));
    assert(records.count == 1 && adds == 0 && deletes == 0);
    reset(); records[@"test.mizze/device-session.v1"] = [@"broken" dataUsingEncoding:NSUTF8StringEncoding];
    assert(!MizzeKeychainReadIdentity(service, &status) && status == errSecDecode);
    reset();
    assert(!MizzeKeychainWriteIdentity(service, @"", refresh, &status));
    assert(records.count == 0 && adds == 0 && updates == 0);
    assert(MizzeKeychainWriteIdentity(service, uid, refresh, &status));
    assert(MizzeKeychainDelete(service, @"device-session.v1", &status) && records.count == 0);
    puts("PASS: default group, first save, cold restore, refresh rotation, atomic identity, denied/locked writes, duplicate race, migration, partial data, corruption and delete");
} return 0; }
