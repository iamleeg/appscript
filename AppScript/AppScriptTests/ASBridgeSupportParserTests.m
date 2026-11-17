// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASBridgeSupportParserTests.m — Tests for ASBridgeSupportParser and related model classes
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
#import <AppScript/ASBridgeSupportFunction.h>
#import <AppScript/ASBridgeSupportConstant.h>
#import <AppScript/ASBridgeSupportEnumeration.h>

@interface ASBridgeSupportParserTests : XCTestCase
@end

@implementation ASBridgeSupportParserTests

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

- (NSData *)dataFromXMLString:(NSString *)xml {
    return [xml dataUsingEncoding:NSUTF8StringEncoding];
}

- (ASBridgeSupportDocument *)parseXML:(NSString *)xml {
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSError *error = nil;
    ASBridgeSupportDocument *doc = [parser parseData:[self dataFromXMLString:xml] error:&error];
    XCTAssertNotNil(doc, @"Expected successful parse, got error: %@", error);
    return doc;
}

// ---------------------------------------------------------------------------
// Function parsing
// ---------------------------------------------------------------------------

- (void)test_parseData_functionNoArgs_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='abort'></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    ASBridgeSupportFunction *fn = doc.functions[0];
    XCTAssertEqualObjects(fn.name, @"abort");
    XCTAssertEqualObjects(fn.returnTypeEncoding, @"v");
    XCTAssertEqual(fn.argumentTypeEncodings.count, 0u);
    XCTAssertFalse(fn.isVariadic);
    XCTAssertFalse(fn.isInline);
    XCTAssertFalse(fn.hasFunctionPointerArguments);
}

- (void)test_parseData_functionWithArgs_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'>"
                    @"<arg type64='d'/>"
                    @"<retval type64='d'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    ASBridgeSupportFunction *fn = doc.functions[0];
    XCTAssertEqualObjects(fn.name, @"sin");
    XCTAssertEqualObjects(fn.returnTypeEncoding, @"d");
    XCTAssertEqual(fn.argumentTypeEncodings.count, 1u);
    XCTAssertEqualObjects(fn.argumentTypeEncodings[0], @"d");
}

- (void)test_parseData_variadicFunction_markedVariadic {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='NSLog' variadic='true'>"
                    @"<arg type64='@'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    ASBridgeSupportFunction *fn = doc.functions[0];
    XCTAssertTrue(fn.isVariadic);
    XCTAssertFalse(fn.isInline);
}

- (void)test_parseData_inlineFunction_markedInline {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='OSAtomicAdd32' inline='true'>"
                    @"<arg type64='i'/>"
                    @"<arg type64='^i'/>"
                    @"<retval type64='i'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    ASBridgeSupportFunction *fn = doc.functions[0];
    XCTAssertTrue(fn.isInline);
    XCTAssertFalse(fn.isVariadic);
}

- (void)test_parseData_functionWithFunctionPointerArg_markedAccordingly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='atexit'>"
                    @"<arg function_pointer='true'/>"
                    @"<retval type64='i'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    ASBridgeSupportFunction *fn = doc.functions[0];
    XCTAssertTrue(fn.hasFunctionPointerArguments);
}

- (void)test_parseData_functionBlockArgument_recordsSignatureNotFunctionArguments {
    // asu-ugk: a block argument's nested <arg>/<retval> describe the block, not the function.
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='notify_register_dispatch'>"
                    @"<arg type64='*'/><arg type64='^i'/><arg type64='@'/>"
                    @"<arg function_pointer='true' type64='@?'><arg type64='i'/><retval type64='v'/></arg>"
                    @"<retval type64='I'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportFunction *fn = [self parseXML:xml].functions.firstObject;

    XCTAssertEqualObjects(fn.argumentTypeEncodings, (@[@"*", @"^i", @"@", @"@?"]));
    XCTAssertEqualObjects(fn.returnTypeEncoding, @"I");
    XCTAssertFalse(fn.hasFunctionPointerArguments, @"a block argument isn't a C function pointer");
    ASBridgeSupportBlockSignature *block = fn.blockSignatures[@3];
    XCTAssertEqualObjects(block.parameterTypeEncodings, @[@"i"]);
    XCTAssertEqualObjects(block.returnTypeEncoding, @"v");
    XCTAssertEqualObjects(block.selectorName, @"notify_register_dispatch");
    XCTAssertEqual(block.argumentIndex, 3u);
}

- (void)test_parseData_functionBlockAndFunctionPointer_onlyBlockRecorded {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='mixed'>"
                    @"<arg function_pointer='true' type64='^?'><arg type64='i'/><retval type64='v'/></arg>"
                    @"<arg function_pointer='true' type64='@?'><retval type64='v'/></arg>"
                    @"<retval type64='v'/>"
                    @"</function>"
                    @"</signatures>";
    ASBridgeSupportFunction *fn = [self parseXML:xml].functions.firstObject;

    XCTAssertEqualObjects(fn.argumentTypeEncodings, (@[@"^?", @"@?"]));
    XCTAssertTrue(fn.hasFunctionPointerArguments);
    XCTAssertEqualObjects(fn.blockSignatures.allKeys, @[@1]);
}

// ---------------------------------------------------------------------------
// Constant parsing
// ---------------------------------------------------------------------------

- (void)test_parseData_constant_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='NSBundleDidLoadNotification' type64='@'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.constants.count, 1u);
    ASBridgeSupportConstant *constant = doc.constants[0];
    XCTAssertEqualObjects(constant.name, @"NSBundleDidLoadNotification");
    XCTAssertEqualObjects(constant.typeEncoding, @"@");
}

- (void)test_parseData_numericConstant_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='M_PI' type64='d'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.constants.count, 1u);
    ASBridgeSupportConstant *constant = doc.constants[0];
    XCTAssertEqualObjects(constant.name, @"M_PI");
    XCTAssertEqualObjects(constant.typeEncoding, @"d");
}

// ---------------------------------------------------------------------------
// Enumeration parsing
// ---------------------------------------------------------------------------

- (void)test_parseData_enumeration_parsedCorrectly {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSASCIIStringEncoding' value64='1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.enumerations.count, 1u);
    ASBridgeSupportEnumeration *enumeration = doc.enumerations[0];
    XCTAssertEqualObjects(enumeration.name, @"NSASCIIStringEncoding");
    XCTAssertEqual(enumeration.value, 1LL);
}

- (void)test_parseData_enumIgnoreTrue_skipped {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSUTFStringEncoding' value64='4' ignore='true'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.enumerations.count, 0u);
}

// ---------------------------------------------------------------------------
// Mixed document
// ---------------------------------------------------------------------------

- (void)test_parseData_mixedDocument_allTypesPresent {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"<constant name='M_PI' type64='d'/>"
                    @"<enum name='NSASCIIStringEncoding' value64='1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 1u);
    XCTAssertEqual(doc.constants.count, 1u);
    XCTAssertEqual(doc.enumerations.count, 1u);
}

- (void)test_parseData_emptySignatures_returnsEmptyDocument {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.functions.count, 0u);
    XCTAssertEqual(doc.constants.count, 0u);
    XCTAssertEqual(doc.enumerations.count, 0u);
}

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------

- (void)test_parseData_invalidXML_returnsNilWithError {
    NSString *xml = @"this is not xml at all <<<";
    NSData *data = [self dataFromXMLString:xml];
    ASBridgeSupportParser *parser = [[ASBridgeSupportParser alloc] init];
    NSError *error = nil;
    ASBridgeSupportDocument *doc = [parser parseData:data error:&error];
    XCTAssertNil(doc);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, ASBridgeSupportParserErrorDomain);
    XCTAssertEqual(error.code, ASBridgeSupportParserErrorInvalidXML);
}

// ---------------------------------------------------------------------------
// Fallback attribute handling
// ---------------------------------------------------------------------------

- (void)test_parseData_enumValueFallback_usesValue {
    // value64 absent; only value present
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSASCIIStringEncoding' value='1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.enumerations.count, 1u);
    XCTAssertEqual(doc.enumerations[0].value, 1LL);
}

- (void)test_parseData_typeFallback_usesType {
    // type64 absent; only type present
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='NSNotFound' type='i'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.constants.count, 1u);
    XCTAssertEqualObjects(doc.constants[0].typeEncoding, @"i");
}

// ---------------------------------------------------------------------------
// Document lookup methods
// ---------------------------------------------------------------------------

- (void)test_functionNamed_existingName_returnsFunction {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportFunction *fn = [doc functionNamed:@"sin"];
    XCTAssertNotNil(fn);
    XCTAssertEqualObjects(fn.name, @"sin");
}

- (void)test_constantNamed_existingName_returnsConstant {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<constant name='M_PI' type64='d'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportConstant *constant = [doc constantNamed:@"M_PI"];
    XCTAssertNotNil(constant);
    XCTAssertEqualObjects(constant.name, @"M_PI");
}

- (void)test_enumerationNamed_existingName_returnsEnumeration {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<enum name='NSASCIIStringEncoding' value64='1'/>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportEnumeration *enumeration = [doc enumerationNamed:@"NSASCIIStringEncoding"];
    XCTAssertNotNil(enumeration);
    XCTAssertEqualObjects(enumeration.name, @"NSASCIIStringEncoding");
}

- (void)test_functionNamed_nonexistentName_returnsNil {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    ASBridgeSupportFunction *fn = [doc functionNamed:@"cos"];
    XCTAssertNil(fn);
}

// ---------------------------------------------------------------------------
// Method block signatures (function_pointer arguments of <method> entries)
// ---------------------------------------------------------------------------

- (void)test_parseData_methodBlockArgument_registersSignature {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<class name='NSArray'>"
                    @"<method selector='enumerateObjectsUsingBlock:'>"
                    @"<arg function_pointer='true' index='0' type64='@?'>"
                    @"<arg type64='@'/><arg type64='Q'/><arg type64='^B' type_modifier='o'/>"
                    @"<retval type64='v'/>"
                    @"</arg>"
                    @"</method>"
                    @"</class>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.blockSignatures.count, 1u);
    ASBridgeSupportBlockSignature *sig = doc.blockSignatures.firstObject;
    XCTAssertEqualObjects(sig.className, @"NSArray");
    XCTAssertEqualObjects(sig.selectorName, @"enumerateObjectsUsingBlock:");
    XCTAssertFalse(sig.isClassMethod);
    XCTAssertEqual(sig.argumentIndex, 0u);
    NSArray *expectedParams = @[@"@", @"Q", @"^B"];
    XCTAssertEqualObjects(sig.parameterTypeEncodings, expectedParams);
    XCTAssertEqualObjects(sig.returnTypeEncoding, @"v");
}

- (void)test_parseData_classMethodBlockArgumentAtLaterIndex_recordsClassMethodAndIndex {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<class name='NSTimer'>"
                    @"<method class_method='true' selector='scheduledTimerWithTimeInterval:repeats:block:'>"
                    @"<arg index='0' type64='d'/><arg index='1' type64='B'/>"
                    @"<arg function_pointer='true' index='2' type64='@?'><arg type64='@'/><retval type64='v'/></arg>"
                    @"<retval type64='@'/>"
                    @"</method>"
                    @"</class>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.blockSignatures.count, 1u, @"only the function-pointer argument is a block signature");
    ASBridgeSupportBlockSignature *sig = doc.blockSignatures.firstObject;
    XCTAssertTrue(sig.isClassMethod);
    XCTAssertEqual(sig.argumentIndex, 2u);
    NSArray *expectedParams = @[@"@"];
    XCTAssertEqualObjects(sig.parameterTypeEncodings, expectedParams);
}

- (void)test_parseData_methodWithoutBlockArgument_registersNothing {
    NSString *xml = @"<?xml version='1.0'?>"
                    @"<signatures version='1.0'>"
                    @"<class name='NSArray'>"
                    @"<method selector='objectAtIndex:'><arg index='0' type64='Q'/><retval type64='@'/></method>"
                    @"</class>"
                    @"<function name='sin'><arg type64='d'/><retval type64='d'/></function>"
                    @"</signatures>";
    ASBridgeSupportDocument *doc = [self parseXML:xml];
    XCTAssertEqual(doc.blockSignatures.count, 0u);
    XCTAssertEqual(doc.functions.count, 1u, @"function parsing is unaffected by method parsing");
}

@end
