// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportStructTests.m — Tests for struct parsing and model classes
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

#import <XCTest/XCTest.h>
#import <AppScript/ASBridgeSupportParser.h>
#import <AppScript/ASBridgeSupportDocument.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASBridgeSupportStructField.h>

@interface ASBridgeSupportStructTests : XCTestCase
@end

@implementation ASBridgeSupportStructTests

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

- (ASBridgeSupportDocument *)parseXML:(NSString *)xml {
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    ASBridgeSupportDocument *doc = [parser parseData:data error:&error];
    XCTAssertNotNil(doc, @"Expected successful parse, got error: %@", error);
    return doc;
}

// ---------------------------------------------------------------------------
// Model classes
// ---------------------------------------------------------------------------

- (void)test_structField_initWithNameTypeEncoding_storesProperties {
    ASBridgeSupportStructField *field = [[ASBridgeSupportStructField alloc]
                                         initWithName:@"width"
                                         typeEncoding:@"d"];
    XCTAssertEqualObjects(field.name, @"width");
    XCTAssertEqualObjects(field.typeEncoding, @"d");
}

- (void)test_struct_initWithCanonicalNameFields_storesProperties {
    ASBridgeSupportStructField *f1 = [[ASBridgeSupportStructField alloc] initWithName:@"x" typeEncoding:@"d"];
    ASBridgeSupportStructField *f2 = [[ASBridgeSupportStructField alloc] initWithName:@"y" typeEncoding:@"d"];
    ASBridgeSupportStruct *s = [[ASBridgeSupportStruct alloc] initWithCanonicalName:@"CGPoint"
                                                                             fields:@[f1, f2]];
    XCTAssertEqualObjects(s.canonicalName, @"CGPoint");
    XCTAssertEqual(s.fields.count, 2u);
    XCTAssertEqualObjects(s.fields[0].name, @"x");
    XCTAssertEqualObjects(s.fields[1].name, @"y");
}

- (void)test_struct_zeroFields_valid {
    ASBridgeSupportStruct *s = [[ASBridgeSupportStruct alloc] initWithCanonicalName:@"Opaque"
                                                                             fields:@[]];
    XCTAssertEqualObjects(s.canonicalName, @"Opaque");
    XCTAssertEqual(s.fields.count, 0u);
}

// ---------------------------------------------------------------------------
// Parser: simple struct (CGSize-like)
// ---------------------------------------------------------------------------

- (void)test_parseData_simpleStruct_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.structs.count, 1u);
    ASBridgeSupportStruct *s = doc.structs[0];
    XCTAssertEqualObjects(s.canonicalName, @"CGSize");
    XCTAssertEqual(s.fields.count, 2u);
    XCTAssertEqualObjects(s.fields[0].name, @"width");
    XCTAssertEqualObjects(s.fields[0].typeEncoding, @"d");
    XCTAssertEqualObjects(s.fields[1].name, @"height");
    XCTAssertEqualObjects(s.fields[1].typeEncoding, @"d");
}

// ---------------------------------------------------------------------------
// Parser: nested struct fields (CGRect-like)
// ---------------------------------------------------------------------------

- (void)test_parseData_nestedStructFields_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSRect' type64='{CGRect=\"origin\"{CGPoint}\"size\"{CGSize}}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.structs.count, 1u);
    ASBridgeSupportStruct *s = doc.structs[0];
    XCTAssertEqualObjects(s.canonicalName, @"CGRect");
    XCTAssertEqual(s.fields.count, 2u);
    XCTAssertEqualObjects(s.fields[0].name, @"origin");
    XCTAssertEqualObjects(s.fields[0].typeEncoding, @"{CGPoint}");
    XCTAssertEqualObjects(s.fields[1].name, @"size");
    XCTAssertEqualObjects(s.fields[1].typeEncoding, @"{CGSize}");
}

// ---------------------------------------------------------------------------
// Parser: opaque struct (zero fields)
// ---------------------------------------------------------------------------

- (void)test_parseData_opaqueStruct_includedWithZeroFields {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='OpaqueHandle' type64='{OpaqueHandle}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.structs.count, 1u);
    ASBridgeSupportStruct *s = doc.structs[0];
    XCTAssertEqualObjects(s.canonicalName, @"OpaqueHandle");
    XCTAssertEqual(s.fields.count, 0u);
}

// ---------------------------------------------------------------------------
// Parser: NSRange name mapping
// ---------------------------------------------------------------------------

- (void)test_parseData_NSRangeNameMapping_canonicalNameIsNSRange {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSRange' type64='{_NSRange=\"location\"Q\"length\"Q}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.structs.count, 1u);
    ASBridgeSupportStruct *s = doc.structs[0];
    XCTAssertEqualObjects(s.canonicalName, @"NSRange",
                          @"_NSRange should be mapped to NSRange");
    XCTAssertEqual(s.fields.count, 2u);
    XCTAssertEqualObjects(s.fields[0].name, @"location");
    XCTAssertEqualObjects(s.fields[0].typeEncoding, @"Q");
    XCTAssertEqualObjects(s.fields[1].name, @"length");
    XCTAssertEqualObjects(s.fields[1].typeEncoding, @"Q");
}

// ---------------------------------------------------------------------------
// Parser: type fallback (type64 absent, use type)
// ---------------------------------------------------------------------------

- (void)test_parseData_structTypeFallback_usesType {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSSize' type='{CGSize=\"width\"d\"height\"d}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.structs.count, 1u);
    XCTAssertEqualObjects(doc.structs[0].canonicalName, @"CGSize");
}

// ---------------------------------------------------------------------------
// Document: structNamed: lookup
// ---------------------------------------------------------------------------

- (void)test_structNamed_existingName_returnsStruct {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportStruct *s = [doc structNamed:@"CGSize"];
    XCTAssertNotNil(s);
    XCTAssertEqualObjects(s.canonicalName, @"CGSize");
}

- (void)test_structNamed_nonexistentName_returnsNil {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertNil([doc structNamed:@"CGPoint"]);
}

// ---------------------------------------------------------------------------
// Mixed document still has other types
// ---------------------------------------------------------------------------

- (void)test_parseData_mixedDocumentWithStruct_allTypesPresent {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"<constant name='M_PI' type64='d'/>"
                    @"<enum name='NSASCIIStringEncoding' value64='1'/>"
                    @"<struct name='NSSize' type64='{CGSize=\"width\"d\"height\"d}'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    XCTAssertEqual(doc.constants.count, 1u);
    XCTAssertEqual(doc.enumerations.count, 1u);
    XCTAssertEqual(doc.structs.count, 1u);
}

@end
