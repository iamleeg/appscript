// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportDocument.h — Aggregated model of a parsed BridgeSupport document
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
#import <AppScript/ASBridgeSupportFunction.h>
#import <AppScript/ASBridgeSupportConstant.h>
#import <AppScript/ASBridgeSupportEnumeration.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASBridgeSupportBlockSignature.h>

NS_ASSUME_NONNULL_BEGIN

/// The parsed contents of a BridgeSupport XML document, providing access to C functions,
/// constants, enumeration values, and struct definitions described therein.
@interface ASBridgeSupportDocument : NSObject

/// All C functions declared in the document.
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportFunction *> *functions;

/// All C constants declared in the document.
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportConstant *> *constants;

/// All enumeration constants declared in the document (excludes entries marked ignore='true').
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportEnumeration *> *enumerations;

/// All struct definitions declared in the document, keyed by canonical name.
/// Includes zero-field (opaque) structs.
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportStruct *> *structs;

/// The block signatures of method arguments (`function_pointer='true'` arguments of `<method>` entries).
@property (nonatomic, readonly, copy) NSArray<ASBridgeSupportBlockSignature *> *blockSignatures;

/// Creates a document with no method block signatures.
- (instancetype)initWithFunctions:(NSArray<ASBridgeSupportFunction *> *)functions
                        constants:(NSArray<ASBridgeSupportConstant *> *)constants
                     enumerations:(NSArray<ASBridgeSupportEnumeration *> *)enumerations
                          structs:(NSArray<ASBridgeSupportStruct *> *)structs;

/// Creates a document that also holds method block signatures.
///
/// - Parameters:
///   - functions: The functions.
///   - constants: The constants.
///   - enumerations: The enumerations.
///   - structs: The structs.
///   - blockSignatures: The method block signatures.
- (instancetype)initWithFunctions:(NSArray<ASBridgeSupportFunction *> *)functions
                        constants:(NSArray<ASBridgeSupportConstant *> *)constants
                     enumerations:(NSArray<ASBridgeSupportEnumeration *> *)enumerations
                          structs:(NSArray<ASBridgeSupportStruct *> *)structs
                  blockSignatures:(NSArray<ASBridgeSupportBlockSignature *> *)blockSignatures NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Returns the function with the given name, or nil if no such function exists in the document.
- (nullable ASBridgeSupportFunction *)functionNamed:(NSString *)name;

/// Returns the constant with the given name, or nil if no such constant exists in the document.
- (nullable ASBridgeSupportConstant *)constantNamed:(NSString *)name;

/// Returns the enumeration constant with the given name, or nil if no such enumeration exists in the document.
- (nullable ASBridgeSupportEnumeration *)enumerationNamed:(NSString *)name;

/// Returns the struct with the given canonical name, or nil if no such struct exists in the document.
- (nullable ASBridgeSupportStruct *)structNamed:(NSString *)canonicalName;

@end

NS_ASSUME_NONNULL_END
