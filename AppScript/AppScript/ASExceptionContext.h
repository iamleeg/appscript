// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASExceptionContext.h — Description of a failed message send passed to an exception handler
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Describes the message send that failed. Immutable.
@interface ASExceptionContext : NSObject

/// The receiver of the failed send, or `nil` if it was `nil`.
@property (nonatomic, readonly, nullable) id receiver;
/// The selector that was being sent.
@property (nonatomic, readonly, nullable) SEL selector;
/// Path of the script containing the send, if known.
@property (nonatomic, readonly, copy, nullable) NSString *scriptPath;
/// One-based line number of the send, or 0 if unknown.
@property (nonatomic, readonly) NSUInteger line;
/// Local variables visible at the send.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *locals;
/// The hybrid ObjC + AppScript call stack, innermost frame first.
@property (nonatomic, readonly, copy) NSArray<NSString *> *hybridCallStack;
/// YES if the exception originated outside AppScript (for example in Objective-C
/// code called from a script) rather than from the interpreter itself.
@property (nonatomic, readonly) BOOL crossedScriptBoundary;

- (instancetype)initWithReceiver:(nullable id)receiver
                        selector:(nullable SEL)selector
                      scriptPath:(nullable NSString *)scriptPath
                            line:(NSUInteger)line
                          locals:(NSDictionary<NSString *, id> *)locals
                 hybridCallStack:(NSArray<NSString *> *)hybridCallStack
           crossedScriptBoundary:(BOOL)crossedScriptBoundary NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
