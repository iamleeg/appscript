// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASInterpreter.h — AST-walking interpreter for AppScript methods
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
#import "ASASTNode.h"

NS_ASSUME_NONNULL_BEGIN

/// An AST-walking interpreter that evaluates AppScript method bodies.
///
/// `ASInterpreter` is stateless and thread-safe. All mutable execution state
/// (scope stack, return-value holder) is stack-allocated per call to
/// `evaluateMethodBody:withReceiver:selector:arguments:parameterNames:scriptPath:`.
/// Multiple threads may therefore share a single `ASInterpreter` instance and
/// invoke it concurrently without synchronisation.
@interface ASInterpreter : NSObject

/// Evaluates the body statements of a method, and returns the result.
///
/// - Parameters:
///   - body: The array of ASASTNode statement nodes making up the method body.
///   - receiver: The object receiving the method call (`self` inside the method).
///   - selector: The selector being invoked (available as `_cmd` inside the method).
///   - arguments: The (already-boxed) argument objects, parallel to the method's parameter names.
///   - parameterNames: The parameter variable names declared in the method signature.
///   - scriptPath: The path of the `.appscript` file containing this method, for error messages.
/// - Returns: The value returned by a `return` statement, or `nil` if the body completes without returning.
- (nullable id)evaluateMethodBody:(NSArray<ASASTNode *> *)body
                     withReceiver:(id)receiver
                         selector:(NSString *)selector
                        arguments:(NSArray *)arguments
                   parameterNames:(NSArray<NSString *> *)parameterNames
                       scriptPath:(NSString *)scriptPath;

@end

NS_ASSUME_NONNULL_END
