// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportParser.h — Parser for Apple BridgeSupport XML documents
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
#import <AppScript/ASBridgeSupportDocument.h>

NS_ASSUME_NONNULL_BEGIN

/// The error domain for errors produced by ASBridgeSupportParser.
extern NSString * const ASBridgeSupportParserErrorDomain;

/// Error codes in the ASBridgeSupportParserErrorDomain.
typedef NS_ENUM(NSInteger, ASBridgeSupportParserError) {
    /// The XML data was malformed and could not be parsed.
    ASBridgeSupportParserErrorInvalidXML = 1,
    /// The file at the given URL could not be read.
    ASBridgeSupportParserErrorReadFailure = 2,
};

/// Parses Apple BridgeSupport XML documents into an in-memory ASBridgeSupportDocument model.
///
/// BridgeSupport files describe the C API surface of a framework, including functions,
/// constants, and enumerations, using Objective-C type encodings.
@interface ASBridgeSupportParser : NSObject

- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// Parses a .bridgesupport file at the given URL.
///
/// - Parameter url: The URL of the .bridgesupport file to parse.
/// - Parameter error: On failure, set to an error in ASBridgeSupportParserErrorDomain.
/// - Returns: A parsed document, or nil on failure.
- (nullable ASBridgeSupportDocument *)parseURL:(NSURL *)url error:(NSError **)error;

/// Parses BridgeSupport XML from raw data.
///
/// This variant is useful for testing without writing files to disk.
///
/// - Parameter data: UTF-8 encoded BridgeSupport XML data.
/// - Parameter error: On failure, set to an error in ASBridgeSupportParserErrorDomain.
/// - Returns: A parsed document, or nil on failure.
- (nullable ASBridgeSupportDocument *)parseData:(NSData *)data error:(NSError **)error;

/// Convenience variant for AppScript callers that cannot pass NSError** parameters.
///
/// Returns nil and logs a warning via NSLog on failure.
///
/// - Parameter url: The URL of the .bridgesupport file to parse.
/// - Returns: A parsed document, or nil on failure.
- (nullable ASBridgeSupportDocument *)parseURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
