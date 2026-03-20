// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASScope.h — Single frame in the AppScript variable scope stack
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

/// A single scope frame in the AppScript variable scope stack.
///
/// Each frame holds a mutable dictionary mapping variable names to their values,
/// and an optional reference to the enclosing (parent) scope. Scope chains are
/// created per method invocation and are not shared between threads.
@interface ASScope : NSObject

/// The enclosing scope, or nil if this is the root scope.
@property (nonatomic, nullable, weak) ASScope *enclosingScope;

/// Initializes a scope frame with the given enclosing scope.
- (instancetype)initWithEnclosingScope:(nullable ASScope *)enclosingScope NS_DESIGNATED_INITIALIZER;

/// Unavailable. Use -initWithEnclosingScope: instead.
- (instancetype)init NS_UNAVAILABLE;

/// Looks up a variable name in this scope and its enclosing scopes. Returns nil if not found.
- (nullable id)valueForName:(NSString *)name;

/// Sets a variable in this scope frame only (does not search enclosing scopes).
- (void)setValue:(nullable id)value forName:(NSString *)name;

/// Updates an existing variable anywhere in the scope chain. Returns NO if not found.
- (BOOL)updateValue:(nullable id)value forName:(NSString *)name;

/// Returns YES if a variable with this name is declared (at any level).
- (BOOL)hasName:(NSString *)name;

/// Returns YES if a variable with this name is declared in THIS scope frame only.
- (BOOL)hasNameLocally:(NSString *)name;

/// Returns a dictionary of all variable bindings visible from this scope frame,
/// walking the full scope chain. Inner scopes shadow outer scopes for duplicate names.
/// AppScript nil values ([ASNull null]) are represented as the NSString @"ASNull".
- (NSDictionary<NSString *, id> *)allVisibleBindings;

@end

NS_ASSUME_NONNULL_END
