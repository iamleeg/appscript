// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASFfiSupport.h — libffi type mapping shared by C function calls and block wrappers
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
#include <ffi.h>

NS_ASSUME_NONNULL_BEGIN

/// Skips Objective-C type qualifiers (`r`, `n`, `N`, `o`, `O`, `R`, `V`) at the start of an encoding.
const char *ASFfiSkipQualifiers(const char *p);

/// Maps the type encoding at `*pPtr` to a libffi type, advancing `*pPtr` past it.
///
/// Struct types are built here from their fields; each one allocated is appended to
/// `allocatedStructs` as a pointer `NSValue`, and the caller frees them (and their `elements`
/// arrays) when the libffi call interface is no longer in use.
///
/// - Parameters:
///   - pPtr: A cursor into a type encoding string.
///   - allocatedStructs: Collects the struct `ffi_type`s this call allocates.
/// - Returns: The libffi type, or `NULL` if the encoding isn't supported (unions, bit fields, ...).
ffi_type * _Nullable ASFfiTypeForEncodingCursor(const char * _Nonnull * _Nonnull pPtr,
                                                NSMutableArray<NSValue *> *allocatedStructs);

NS_ASSUME_NONNULL_END
