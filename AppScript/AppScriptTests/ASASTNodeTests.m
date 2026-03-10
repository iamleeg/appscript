// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASASTNodeTests.m — Unit tests for all AppScript AST node classes
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

@import XCTest;
@import AppScript;

#import "ASASTNode.h"
#import "ASClassDefinitionNode.h"
#import "ASCategoryDefinitionNode.h"
#import "ASPropertyNode.h"
#import "ASMethodNode.h"
#import "ASVariableDeclarationNode.h"
#import "ASAssignmentNode.h"
#import "ASMessageSendNode.h"
#import "ASBlockLiteralNode.h"
#import "ASReturnNode.h"
#import "ASIdentifierNode.h"
#import "ASStringLiteralNode.h"
#import "ASNumberLiteralNode.h"
#import "ASArrayLiteralNode.h"
#import "ASDictionaryLiteralNode.h"

/// Tests for every AST node class, verifying designated initializers and computed properties.
@interface ASASTNodeTests : XCTestCase
@end

@implementation ASASTNodeTests

// ---------------------------------------------------------------------------
// ASASTNode

- (void)test_initWithLine_column_setsLineAndColumnNumber {
    ASIdentifierNode *node = [[ASIdentifierNode alloc] initWithName:@"self" line:3 column:7];
    XCTAssertEqual(node.lineNumber, 3u);
    XCTAssertEqual(node.columnNumber, 7u);
}

// ---------------------------------------------------------------------------
// ASPropertyNode

- (void)test_initWithPropertyName_modifiers_line_column_setsAllProperties {
    NSArray<NSString *> *modifiers = @[@"strong", @"readonly"];
    ASPropertyNode *node = [[ASPropertyNode alloc] initWithPropertyName:@"title"
                                                              modifiers:modifiers
                                                                   line:5
                                                                 column:1];
    XCTAssertEqualObjects(node.propertyName, @"title");
    XCTAssertEqualObjects(node.modifiers, modifiers);
    XCTAssertEqual(node.lineNumber, 5u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithPropertyName_modifiers_line_column_copiesModifiers {
    NSMutableArray<NSString *> *modifiers = [NSMutableArray arrayWithObject:@"weak"];
    ASPropertyNode *node = [[ASPropertyNode alloc] initWithPropertyName:@"delegate"
                                                              modifiers:modifiers
                                                                   line:1
                                                                 column:1];
    [modifiers addObject:@"assign"];
    XCTAssertEqual(node.modifiers.count, 1u, @"Mutating the source array must not affect the stored modifiers");
}

// ---------------------------------------------------------------------------
// ASMethodNode — designated initializer

- (void)test_initWithSelectorParts_parameterNames_body_isClassMethod_line_column_setsAllProperties {
    ASIdentifierNode *selfNode = [[ASIdentifierNode alloc] initWithName:@"self" line:1 column:1];
    ASReturnNode *returnNode = [[ASReturnNode alloc] initWithValue:selfNode line:2 column:5];
    ASMethodNode *node = [[ASMethodNode alloc] initWithSelectorParts:@[@"init"]
                                                      parameterNames:@[]
                                                                body:@[returnNode]
                                                       isClassMethod:NO
                                                                line:1
                                                              column:1];
    XCTAssertEqualObjects(node.selectorParts, @[@"init"]);
    XCTAssertEqualObjects(node.parameterNames, @[]);
    XCTAssertEqual(node.body.count, 1u);
    XCTAssertEqual(node.isClassMethod, NO);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

// ASMethodNode — selector computed property, 0-arg

- (void)test_selector_zeroArgMethod_returnsPartWithoutColon {
    ASMethodNode *node = [[ASMethodNode alloc] initWithSelectorParts:@[@"description"]
                                                      parameterNames:@[]
                                                                body:@[]
                                                       isClassMethod:NO
                                                                line:1
                                                              column:1];
    XCTAssertEqualObjects(node.selector, @"description");
}

// ASMethodNode — selector computed property, 1-arg

- (void)test_selector_oneArgMethod_returnsPartWithTrailingColon {
    ASMethodNode *node = [[ASMethodNode alloc] initWithSelectorParts:@[@"setTitle"]
                                                      parameterNames:@[@"title"]
                                                                body:@[]
                                                       isClassMethod:NO
                                                                line:1
                                                              column:1];
    XCTAssertEqualObjects(node.selector, @"setTitle:");
}

// ASMethodNode — selector computed property, multi-arg

- (void)test_selector_multiArgMethod_joinsSelectorPartsWithColons {
    ASMethodNode *node = [[ASMethodNode alloc] initWithSelectorParts:@[@"writeToFile", @"atomically"]
                                                      parameterNames:@[@"path", @"flag"]
                                                                body:@[]
                                                       isClassMethod:YES
                                                                line:4
                                                              column:1];
    XCTAssertEqualObjects(node.selector, @"writeToFile:atomically:");
    XCTAssertEqual(node.isClassMethod, YES);
}

// ---------------------------------------------------------------------------
// ASClassDefinitionNode

- (void)test_initWithClassName_superclassName_protocolNames_properties_methods_line_column_setsAllProperties {
    ASPropertyNode *prop = [[ASPropertyNode alloc] initWithPropertyName:@"name"
                                                             modifiers:@[@"copy"]
                                                                  line:2
                                                                column:5];
    ASMethodNode *method = [[ASMethodNode alloc] initWithSelectorParts:@[@"description"]
                                                        parameterNames:@[]
                                                                  body:@[]
                                                         isClassMethod:NO
                                                                  line:3
                                                                column:1];
    ASClassDefinitionNode *node = [[ASClassDefinitionNode alloc] initWithClassName:@"Dog"
                                                                    superclassName:@"Animal"
                                                                     protocolNames:@[@"NSCopying"]
                                                                        properties:@[prop]
                                                                           methods:@[method]
                                                                              line:1
                                                                            column:1];
    XCTAssertEqualObjects(node.className, @"Dog");
    XCTAssertEqualObjects(node.superclassName, @"Animal");
    XCTAssertEqualObjects(node.protocolNames, @[@"NSCopying"]);
    XCTAssertEqual(node.properties.count, 1u);
    XCTAssertEqual(node.methods.count, 1u);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithClassName_superclassName_nil_setsNilSuperclassName {
    ASClassDefinitionNode *node = [[ASClassDefinitionNode alloc] initWithClassName:@"Root"
                                                                    superclassName:nil
                                                                     protocolNames:@[]
                                                                        properties:@[]
                                                                           methods:@[]
                                                                              line:1
                                                                            column:1];
    XCTAssertNil(node.superclassName);
}

// ---------------------------------------------------------------------------
// ASCategoryDefinitionNode

- (void)test_initWithClassName_categoryName_methods_line_column_setsAllProperties {
    ASMethodNode *method = [[ASMethodNode alloc] initWithSelectorParts:@[@"helper"]
                                                        parameterNames:@[]
                                                                  body:@[]
                                                         isClassMethod:NO
                                                                  line:10
                                                                column:1];
    ASCategoryDefinitionNode *node = [[ASCategoryDefinitionNode alloc] initWithClassName:@"NSString"
                                                                            categoryName:@"Utilities"
                                                                                 methods:@[method]
                                                                                    line:9
                                                                                  column:1];
    XCTAssertEqualObjects(node.className, @"NSString");
    XCTAssertEqualObjects(node.categoryName, @"Utilities");
    XCTAssertEqual(node.methods.count, 1u);
    XCTAssertEqual(node.lineNumber, 9u);
    XCTAssertEqual(node.columnNumber, 1u);
}

// ---------------------------------------------------------------------------
// ASVariableDeclarationNode

- (void)test_initWithVariableName_initializer_isWeak_isConstant_line_column_setsAllProperties {
    ASStringLiteralNode *init = [[ASStringLiteralNode alloc] initWithValue:@"hello" line:5 column:10];
    ASVariableDeclarationNode *node = [[ASVariableDeclarationNode alloc] initWithVariableName:@"greeting"
                                                                                  initializer:init
                                                                                       isWeak:NO
                                                                                   isConstant:YES
                                                                                         line:5
                                                                                       column:1];
    XCTAssertEqualObjects(node.variableName, @"greeting");
    XCTAssertEqualObjects(node.initializer, init);
    XCTAssertEqual(node.isWeak, NO);
    XCTAssertEqual(node.isConstant, YES);
    XCTAssertEqual(node.lineNumber, 5u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithVariableName_isWeak_YES_storesWeakFlag {
    ASVariableDeclarationNode *node = [[ASVariableDeclarationNode alloc] initWithVariableName:@"delegate"
                                                                                  initializer:nil
                                                                                       isWeak:YES
                                                                                   isConstant:NO
                                                                                         line:1
                                                                                       column:1];
    XCTAssertEqual(node.isWeak, YES);
    XCTAssertEqual(node.isConstant, NO);
    XCTAssertNil(node.initializer);
}

- (void)test_initWithVariableName_isConstant_YES_storesConstantFlag {
    ASVariableDeclarationNode *node = [[ASVariableDeclarationNode alloc] initWithVariableName:@"pi"
                                                                                  initializer:nil
                                                                                       isWeak:NO
                                                                                   isConstant:YES
                                                                                         line:1
                                                                                       column:1];
    XCTAssertEqual(node.isConstant, YES);
    XCTAssertEqual(node.isWeak, NO);
}

// ---------------------------------------------------------------------------
// ASAssignmentNode

- (void)test_initWithVariableName_value_line_column_setsAllProperties {
    ASNumberLiteralNode *numNode = [[ASNumberLiteralNode alloc] initWithValue:@42 line:7 column:12];
    ASAssignmentNode *node = [[ASAssignmentNode alloc] initWithVariableName:@"count"
                                                                      value:numNode
                                                                       line:7
                                                                     column:1];
    XCTAssertEqualObjects(node.variableName, @"count");
    XCTAssertEqualObjects(node.value, numNode);
    XCTAssertEqual(node.lineNumber, 7u);
    XCTAssertEqual(node.columnNumber, 1u);
}

// ---------------------------------------------------------------------------
// ASMessageSendNode — designated initializer

- (void)test_initWithReceiver_selectorParts_arguments_line_column_setsAllProperties {
    ASIdentifierNode *receiver = [[ASIdentifierNode alloc] initWithName:@"self" line:1 column:2];
    ASStringLiteralNode *arg = [[ASStringLiteralNode alloc] initWithValue:@"hello" line:1 column:15];
    ASMessageSendNode *node = [[ASMessageSendNode alloc] initWithReceiver:receiver
                                                            selectorParts:@[@"setTitle"]
                                                                arguments:@[arg]
                                                                     line:1
                                                                   column:1];
    XCTAssertEqualObjects(node.receiver, receiver);
    XCTAssertEqualObjects(node.selectorParts, @[@"setTitle"]);
    XCTAssertEqual(node.arguments.count, 1u);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

// ASMessageSendNode — selector, 0-arg

- (void)test_selector_zeroArgSend_returnsPartWithoutColon {
    ASIdentifierNode *receiver = [[ASIdentifierNode alloc] initWithName:@"obj" line:1 column:1];
    ASMessageSendNode *node = [[ASMessageSendNode alloc] initWithReceiver:receiver
                                                            selectorParts:@[@"description"]
                                                                arguments:@[]
                                                                     line:1
                                                                   column:1];
    XCTAssertEqualObjects(node.selector, @"description");
}

// ASMessageSendNode — selector, 1-arg

- (void)test_selector_oneArgSend_returnsPartWithTrailingColon {
    ASIdentifierNode *receiver = [[ASIdentifierNode alloc] initWithName:@"array" line:1 column:1];
    ASNumberLiteralNode *arg = [[ASNumberLiteralNode alloc] initWithValue:@0 line:1 column:10];
    ASMessageSendNode *node = [[ASMessageSendNode alloc] initWithReceiver:receiver
                                                            selectorParts:@[@"objectAtIndex"]
                                                                arguments:@[arg]
                                                                     line:1
                                                                   column:1];
    XCTAssertEqualObjects(node.selector, @"objectAtIndex:");
}

// ASMessageSendNode — selector, multi-arg

- (void)test_selector_multiArgSend_joinsSelectorPartsWithColons {
    ASIdentifierNode *receiver = [[ASIdentifierNode alloc] initWithName:@"dict" line:1 column:1];
    ASStringLiteralNode *val = [[ASStringLiteralNode alloc] initWithValue:@"v" line:1 column:10];
    ASStringLiteralNode *key = [[ASStringLiteralNode alloc] initWithValue:@"k" line:1 column:20];
    ASMessageSendNode *node = [[ASMessageSendNode alloc] initWithReceiver:receiver
                                                            selectorParts:@[@"setObject", @"forKey"]
                                                                arguments:@[val, key]
                                                                     line:1
                                                                   column:1];
    XCTAssertEqualObjects(node.selector, @"setObject:forKey:");
}

// ---------------------------------------------------------------------------
// ASBlockLiteralNode

- (void)test_initWithParameterNames_body_line_column_setsAllProperties {
    ASReturnNode *ret = [[ASReturnNode alloc] initWithValue:nil line:2 column:5];
    ASBlockLiteralNode *node = [[ASBlockLiteralNode alloc] initWithParameterNames:@[@"x", @"y"]
                                                                             body:@[ret]
                                                                             line:1
                                                                           column:1];
    XCTAssertEqualObjects(node.parameterNames, (@[@"x", @"y"]));
    XCTAssertEqual(node.body.count, 1u);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithParameterNames_emptyParams_setsEmptyArray {
    ASBlockLiteralNode *node = [[ASBlockLiteralNode alloc] initWithParameterNames:@[]
                                                                             body:@[]
                                                                             line:3
                                                                           column:2];
    XCTAssertEqual(node.parameterNames.count, 0u);
    XCTAssertEqual(node.body.count, 0u);
}

// ---------------------------------------------------------------------------
// ASReturnNode

- (void)test_initWithValue_nonNil_setsValue {
    ASNumberLiteralNode *num = [[ASNumberLiteralNode alloc] initWithValue:@1 line:5 column:12];
    ASReturnNode *node = [[ASReturnNode alloc] initWithValue:num line:5 column:5];
    XCTAssertEqualObjects(node.value, num);
    XCTAssertEqual(node.lineNumber, 5u);
    XCTAssertEqual(node.columnNumber, 5u);
}

- (void)test_initWithValue_nil_setsNilValue {
    ASReturnNode *node = [[ASReturnNode alloc] initWithValue:nil line:6 column:1];
    XCTAssertNil(node.value);
}

// ---------------------------------------------------------------------------
// ASIdentifierNode

- (void)test_initWithName_line_column_setsAllProperties {
    ASIdentifierNode *node = [[ASIdentifierNode alloc] initWithName:@"myVar" line:8 column:4];
    XCTAssertEqualObjects(node.name, @"myVar");
    XCTAssertEqual(node.lineNumber, 8u);
    XCTAssertEqual(node.columnNumber, 4u);
}

- (void)test_initWithName_self_storesSelf {
    ASIdentifierNode *node = [[ASIdentifierNode alloc] initWithName:@"self" line:1 column:1];
    XCTAssertEqualObjects(node.name, @"self");
}

// ---------------------------------------------------------------------------
// ASStringLiteralNode

- (void)test_initWithValue_string_line_column_setsAllProperties {
    ASStringLiteralNode *node = [[ASStringLiteralNode alloc] initWithValue:@"Hello, World!"
                                                                      line:12
                                                                    column:3];
    XCTAssertEqualObjects(node.value, @"Hello, World!");
    XCTAssertEqual(node.lineNumber, 12u);
    XCTAssertEqual(node.columnNumber, 3u);
}

- (void)test_initWithValue_emptyString_setsEmptyString {
    ASStringLiteralNode *node = [[ASStringLiteralNode alloc] initWithValue:@"" line:1 column:1];
    XCTAssertEqualObjects(node.value, @"");
}

// ---------------------------------------------------------------------------
// ASNumberLiteralNode

- (void)test_initWithValue_integer_line_column_setsAllProperties {
    ASNumberLiteralNode *node = [[ASNumberLiteralNode alloc] initWithValue:@42 line:9 column:6];
    XCTAssertEqualObjects(node.value, @42);
    XCTAssertEqual(node.lineNumber, 9u);
    XCTAssertEqual(node.columnNumber, 6u);
}

- (void)test_initWithValue_float_setsFloatValue {
    ASNumberLiteralNode *node = [[ASNumberLiteralNode alloc] initWithValue:@3.14 line:1 column:1];
    XCTAssertEqualWithAccuracy(node.value.doubleValue, 3.14, 1e-10);
}

// ---------------------------------------------------------------------------
// ASArrayLiteralNode

- (void)test_initWithElements_line_column_setsAllProperties {
    ASStringLiteralNode *elem1 = [[ASStringLiteralNode alloc] initWithValue:@"a" line:1 column:4];
    ASStringLiteralNode *elem2 = [[ASStringLiteralNode alloc] initWithValue:@"b" line:1 column:8];
    ASArrayLiteralNode *node = [[ASArrayLiteralNode alloc] initWithElements:@[elem1, elem2]
                                                                       line:1
                                                                     column:1];
    XCTAssertEqual(node.elements.count, 2u);
    XCTAssertEqualObjects(node.elements[0], elem1);
    XCTAssertEqualObjects(node.elements[1], elem2);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithElements_emptyArray_setsEmptyElements {
    ASArrayLiteralNode *node = [[ASArrayLiteralNode alloc] initWithElements:@[] line:2 column:3];
    XCTAssertEqual(node.elements.count, 0u);
}

// ---------------------------------------------------------------------------
// ASDictionaryLiteralNode

- (void)test_initWithKeys_values_line_column_setsAllProperties {
    ASStringLiteralNode *key1 = [[ASStringLiteralNode alloc] initWithValue:@"name" line:1 column:4];
    ASStringLiteralNode *val1 = [[ASStringLiteralNode alloc] initWithValue:@"Alice" line:1 column:12];
    ASStringLiteralNode *key2 = [[ASStringLiteralNode alloc] initWithValue:@"age" line:1 column:22];
    ASNumberLiteralNode *val2 = [[ASNumberLiteralNode alloc] initWithValue:@30 line:1 column:29];
    ASDictionaryLiteralNode *node = [[ASDictionaryLiteralNode alloc] initWithKeys:@[key1, key2]
                                                                           values:@[val1, val2]
                                                                             line:1
                                                                           column:1];
    XCTAssertEqual(node.keys.count, 2u);
    XCTAssertEqual(node.values.count, 2u);
    XCTAssertEqualObjects(node.keys[0], key1);
    XCTAssertEqualObjects(node.values[0], val1);
    XCTAssertEqualObjects(node.keys[1], key2);
    XCTAssertEqualObjects(node.values[1], val2);
    XCTAssertEqual(node.lineNumber, 1u);
    XCTAssertEqual(node.columnNumber, 1u);
}

- (void)test_initWithKeys_values_emptyDictionary_setsEmptyArrays {
    ASDictionaryLiteralNode *node = [[ASDictionaryLiteralNode alloc] initWithKeys:@[]
                                                                           values:@[]
                                                                             line:5
                                                                           column:1];
    XCTAssertEqual(node.keys.count, 0u);
    XCTAssertEqual(node.values.count, 0u);
}

@end
