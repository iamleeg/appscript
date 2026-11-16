// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBlockRegistry.m — Registry of the block signatures Cocoa methods expect
// Copyright (C) 2026 Graham Lee
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

#import "ASBlockRegistry.h"
#import <objc/runtime.h>

static NSString *ASBlockRegistryKey(NSString *className, BOOL isClassMethod, NSString *selectorName,
                                    NSUInteger argumentIndex) {
    return [NSString stringWithFormat:@"%@|%c|%@|%lu", className, isClassMethod ? '+' : '-',
            selectorName, (unsigned long)argumentIndex];
}

@implementation ASBlockRegistry {
    // Owned by _queue: every read and write goes through it.
    dispatch_queue_t _queue;
    NSMutableDictionary<NSString *, ASBridgeSupportBlockSignature *> *_table;
}

+ (ASBlockRegistry *)sharedRegistry {
    static ASBlockRegistry *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[ASBlockRegistry alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.appscript.block-registry", DISPATCH_QUEUE_SERIAL);
        _table = [NSMutableDictionary dictionary];
        [self registerBuiltInSignatures];
    }
    return self;
}

/// Signatures for the framework's own block-taking helpers, so they work where BridgeSupport isn't
/// available (GNUstep) and without loading any.
- (void)registerBuiltInSignatures {
    NSArray<NSString *> *none = @[];
    void (^add)(NSString *, NSString *, NSUInteger, NSArray<NSString *> *, NSString *) =
        ^(NSString *className, NSString *selectorName, NSUInteger index, NSArray<NSString *> *params, NSString *ret) {
            [self registerSignature:[[ASBridgeSupportBlockSignature alloc] initWithClassName:className
                                                                                selectorName:selectorName
                                                                               isClassMethod:NO
                                                                               argumentIndex:index
                                                                      parameterTypeEncodings:params
                                                                          returnTypeEncoding:ret]];
        };
    add(@"NSNumber", @"ifTrue:ifFalse:", 0, none, @"@");
    add(@"NSNumber", @"ifTrue:ifFalse:", 1, none, @"@");
    add(@"NSNumber", @"ifTrue:", 0, none, @"@");
    add(@"NSNumber", @"ifFalse:", 0, none, @"@");
    add(@"NSObject", @"do:while:", 0, none, @"@");
    add(@"NSObject", @"do:while:", 1, none, @"@");
    add(@"NSObject", @"do:until:", 0, none, @"@");
    add(@"NSObject", @"do:until:", 1, none, @"@");
    // The native NSArray methods that took the place of the removed as_sortedArrayUsingBlock: helper
    // (asu-i7f), so sorting and enumerating with a block work on GNUstep too.
    add(@"NSArray", @"sortedArrayUsingComparator:", 0, (@[@"@", @"@"]), @"q");
    add(@"NSArray", @"enumerateObjectsUsingBlock:", 0, (@[@"@", @"Q", @"^B"]), @"v");
}

- (void)registerSignature:(ASBridgeSupportBlockSignature *)signature {
    NSString *key = ASBlockRegistryKey(signature.className, signature.isClassMethod,
                                       signature.selectorName, signature.argumentIndex);
    dispatch_sync(_queue, ^{
        self->_table[key] = signature;
    });
}

- (void)registerSignatures:(NSArray<ASBridgeSupportBlockSignature *> *)signatures {
    for (ASBridgeSupportBlockSignature *signature in signatures) {
        [self registerSignature:signature];
    }
}

- (nullable ASBridgeSupportBlockSignature *)signatureForReceiver:(id)receiver
                                                         selector:(SEL)selector
                                                    argumentIndex:(NSUInteger)argumentIndex {
    if (receiver == nil) {
        return nil;
    }
    BOOL isClassMethod = class_isMetaClass(object_getClass(receiver));
    Class start = isClassMethod ? (Class)receiver : object_getClass(receiver);
    NSString *selectorName = NSStringFromSelector(selector);
    __block ASBridgeSupportBlockSignature *found = nil;
    dispatch_sync(_queue, ^{
        for (Class cls = start; cls != Nil && found == nil; cls = class_getSuperclass(cls)) {
            found = self->_table[ASBlockRegistryKey(NSStringFromClass(cls), isClassMethod,
                                                    selectorName, argumentIndex)];
        }
    });
    return found;
}

@end
