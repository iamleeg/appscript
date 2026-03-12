// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportParser.m — Parser for Apple BridgeSupport XML documents
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

#import "ASBridgeSupportParser.h"

NSString * const ASBridgeSupportParserErrorDomain = @"ASBridgeSupportParserErrorDomain";

// ---------------------------------------------------------------------------
// Private SAX delegate
// ---------------------------------------------------------------------------

@interface _ASBridgeSupportParserDelegate : NSObject <NSXMLParserDelegate>

@property (nonatomic, readonly) NSMutableArray<ASBridgeSupportFunction *> *functions;
@property (nonatomic, readonly) NSMutableArray<ASBridgeSupportConstant *> *constants;
@property (nonatomic, readonly) NSMutableArray<ASBridgeSupportEnumeration *> *enumerations;

// Per-function parsing state
@property (nonatomic, copy, nullable) NSString *currentFunctionName;
@property (nonatomic, strong, nullable) NSMutableArray<NSString *> *currentArgTypes;
@property (nonatomic, copy, nullable) NSString *currentReturnType;
@property (nonatomic) BOOL currentIsVariadic;
@property (nonatomic) BOOL currentIsInline;
@property (nonatomic) BOOL currentHasFunctionPointerArgs;

// Parser error (if any)
@property (nonatomic, strong, nullable) NSError *parseError;

@end

@implementation _ASBridgeSupportParserDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _functions = [NSMutableArray array];
        _constants = [NSMutableArray array];
        _enumerations = [NSMutableArray array];
    }
    return self;
}

- (void)resetFunctionState {
    self.currentFunctionName = nil;
    self.currentArgTypes = nil;
    self.currentReturnType = nil;
    self.currentIsVariadic = NO;
    self.currentIsInline = NO;
    self.currentHasFunctionPointerArgs = NO;
}

// Returns type64 if present, falls back to type, or nil if neither is present.
- (nullable NSString *)typeFromAttributes:(NSDictionary<NSString *, NSString *> *)attributes {
    NSString *type64 = attributes[@"type64"];
    if (type64) {
        return type64;
    }
    return attributes[@"type"];
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName
  namespaceURI:(nullable NSString *)namespaceURI
 qualifiedName:(nullable NSString *)qName
    attributes:(NSDictionary<NSString *, NSString *> *)attributeDict {

    if ([elementName isEqualToString:@"function"]) {
        [self resetFunctionState];
        self.currentFunctionName = attributeDict[@"name"];
        self.currentArgTypes = [NSMutableArray array];
        self.currentIsVariadic = [attributeDict[@"variadic"] isEqualToString:@"true"];
        self.currentIsInline = [attributeDict[@"inline"] isEqualToString:@"true"];

    } else if ([elementName isEqualToString:@"arg"]) {
        if (self.currentFunctionName == nil) {
            // arg outside a function — ignore
            return;
        }
        if ([attributeDict[@"function_pointer"] isEqualToString:@"true"]) {
            self.currentHasFunctionPointerArgs = YES;
        }
        NSString *type = [self typeFromAttributes:attributeDict];
        if (type) {
            [self.currentArgTypes addObject:type];
        }

    } else if ([elementName isEqualToString:@"retval"]) {
        if (self.currentFunctionName == nil) {
            return;
        }
        self.currentReturnType = [self typeFromAttributes:attributeDict];

    } else if ([elementName isEqualToString:@"constant"]) {
        NSString *name = attributeDict[@"name"];
        NSString *type = [self typeFromAttributes:attributeDict];
        if (name && type) {
            ASBridgeSupportConstant *constant = [[ASBridgeSupportConstant alloc]
                                                 initWithName:name
                                                 typeEncoding:type];
            [self.constants addObject:constant];
        }

    } else if ([elementName isEqualToString:@"enum"]) {
        if ([attributeDict[@"ignore"] isEqualToString:@"true"]) {
            return;
        }
        NSString *name = attributeDict[@"name"];
        NSString *valueString = attributeDict[@"value64"] ?: attributeDict[@"value"];
        if (name && valueString) {
            long long value = [valueString longLongValue];
            ASBridgeSupportEnumeration *enumeration = [[ASBridgeSupportEnumeration alloc]
                                                       initWithName:name
                                                       value:value];
            [self.enumerations addObject:enumeration];
        }
    }
    // All other elements (struct, opaque, cftype, depends_on, class,
    // informal_protocol, function_alias, signatures, etc.) are silently ignored.
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName
  namespaceURI:(nullable NSString *)namespaceURI
 qualifiedName:(nullable NSString *)qName {

    if ([elementName isEqualToString:@"function"]) {
        NSString *name = self.currentFunctionName;
        if (name) {
            NSString *returnType = self.currentReturnType ?: @"v";
            ASBridgeSupportFunction *function = [[ASBridgeSupportFunction alloc]
                                                 initWithName:name
                                                 returnTypeEncoding:returnType
                                                 argumentTypeEncodings:self.currentArgTypes ?: @[]
                                                 isVariadic:self.currentIsVariadic
                                                 isInline:self.currentIsInline
                                                 hasFunctionPointerArguments:self.currentHasFunctionPointerArgs];
            [self.functions addObject:function];
        }
        [self resetFunctionState];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    self.parseError = parseError;
}

@end

// ---------------------------------------------------------------------------
// ASBridgeSupportParser
// ---------------------------------------------------------------------------

@implementation ASBridgeSupportParser

- (instancetype)init {
    return [super init];
}

- (nullable ASBridgeSupportDocument *)parseData:(NSData *)data error:(NSError **)error {
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
    _ASBridgeSupportParserDelegate *delegate = [[_ASBridgeSupportParserDelegate alloc] init];
    xmlParser.delegate = delegate;

    BOOL success = [xmlParser parse];

    if (!success || delegate.parseError != nil) {
        if (error != NULL) {
            NSError *underlying = delegate.parseError ?: [xmlParser parserError];
            NSDictionary *userInfo = nil;
            if (underlying) {
                userInfo = @{ NSUnderlyingErrorKey: underlying };
            }
            *error = [NSError errorWithDomain:ASBridgeSupportParserErrorDomain
                                         code:ASBridgeSupportParserErrorInvalidXML
                                     userInfo:userInfo];
        }
        return nil;
    }

    return [[ASBridgeSupportDocument alloc] initWithFunctions:delegate.functions
                                                    constants:delegate.constants
                                                 enumerations:delegate.enumerations];
}

- (nullable ASBridgeSupportDocument *)parseURL:(NSURL *)url error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) {
        if (error != NULL && *error != nil) {
            NSError *readError = *error;
            *error = [NSError errorWithDomain:ASBridgeSupportParserErrorDomain
                                         code:ASBridgeSupportParserErrorReadFailure
                                     userInfo:@{ NSUnderlyingErrorKey: readError }];
        } else if (error != NULL) {
            *error = [NSError errorWithDomain:ASBridgeSupportParserErrorDomain
                                         code:ASBridgeSupportParserErrorReadFailure
                                     userInfo:nil];
        }
        return nil;
    }
    return [self parseData:data error:error];
}

- (nullable ASBridgeSupportDocument *)parseURL:(NSURL *)url {
    NSError *error = nil;
    ASBridgeSupportDocument *document = [self parseURL:url error:&error];
    if (!document) {
        NSLog(@"ASBridgeSupportParser: warning — failed to parse %@: %@", url, error);
    }
    return document;
}

@end
