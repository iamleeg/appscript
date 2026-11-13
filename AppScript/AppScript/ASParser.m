// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASParser.m — Parser that converts a token stream into an array of AST nodes
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

#import "ASParser.h"
#import "ASClassDefinitionNode.h"
#import "ASCategoryDefinitionNode.h"
#import "ASPropertyNode.h"
#import "ASMethodNode.h"
#import "ASVariableDeclarationNode.h"
#import "ASAssignmentNode.h"
#import "ASReturnNode.h"
#import "ASMessageSendNode.h"
#import "ASBlockLiteralNode.h"
#import "ASIdentifierNode.h"
#import "ASStringLiteralNode.h"
#import "ASNumberLiteralNode.h"
#import "ASArrayLiteralNode.h"
#import "ASDictionaryLiteralNode.h"
#import "ASSuperNode.h"

NSString * const ASParserErrorDomain = @"ASParserErrorDomain";

// ---------------------------------------------------------------------------
// Private parse-state class
// ---------------------------------------------------------------------------

@interface ASParseState : NSObject

@property (nonatomic, readonly) NSArray<ASToken *> *tokens;
@property (nonatomic) NSUInteger position;
/// Number of block literals currently being parsed. Used to reject `super` inside blocks.
@property (nonatomic) NSUInteger blockDepth;

- (instancetype)initWithTokens:(NSArray<ASToken *> *)tokens NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The current token without advancing.
- (ASToken *)current;

/// The token at position+offset without advancing.
- (ASToken *)peekAhead:(NSUInteger)offset;

/// Advance past the current token and return it.
- (ASToken *)consume;

/// Return YES if the current token has the given type.
- (BOOL)currentIs:(ASTokenType)type;

/// Skip all consecutive newline tokens.
- (void)skipNewlines;

@end

@implementation ASParseState

- (instancetype)initWithTokens:(NSArray<ASToken *> *)tokens {
    self = [super init];
    if (self) {
        _tokens = [tokens copy];
        _position = 0;
    }
    return self;
}

- (ASToken *)current {
    if (_position < _tokens.count) {
        return _tokens[_position];
    }
    // Safety: return the last token (should be EOF).
    return _tokens.lastObject;
}

- (ASToken *)peekAhead:(NSUInteger)offset {
    NSUInteger idx = _position + offset;
    if (idx < _tokens.count) {
        return _tokens[idx];
    }
    return _tokens.lastObject;
}

- (ASToken *)consume {
    ASToken *tok = [self current];
    if (_position < _tokens.count) {
        _position++;
    }
    return tok;
}

- (BOOL)currentIs:(ASTokenType)type {
    return [self current].type == type;
}

- (void)skipNewlines {
    while ([self currentIs:ASTokenTypeNewline]) {
        [self consume];
    }
}

@end

// ---------------------------------------------------------------------------
// ASParser implementation
// ---------------------------------------------------------------------------

@implementation ASParser

- (nullable NSArray<ASASTNode *> *)parseTokens:(NSArray<ASToken *> *)tokens
                                         error:(NSError **)error {
    if (tokens.count == 0) {
        return @[];
    }

    ASParseState *state = [[ASParseState alloc] initWithTokens:tokens];
    NSMutableArray<ASASTNode *> *topLevel = [NSMutableArray array];

    [state skipNewlines];

    while (![state currentIs:ASTokenTypeEOF]) {
        ASASTNode *node = nil;

        if ([state currentIs:ASTokenTypeKwClass]) {
            node = [self parseClassDefinition:state error:error];
        } else if ([state currentIs:ASTokenTypeKwCategory]) {
            node = [self parseCategoryDefinition:state error:error];
        } else {
            ASToken *tok = [state current];
            if (error) {
                *error = [self unexpectedTokenError:tok];
            }
            return nil;
        }

        if (!node) {
            return nil;
        }
        [topLevel addObject:node];
        [state skipNewlines];
    }

    return [topLevel copy];
}

// ---------------------------------------------------------------------------
// Top-level definitions
// ---------------------------------------------------------------------------

- (nullable ASClassDefinitionNode *)parseClassDefinition:(ASParseState *)state
                                                   error:(NSError **)error {
    ASToken *kwToken = [state consume]; // @class
    NSUInteger line = kwToken.line;
    NSUInteger column = kwToken.column;

    // ClassName
    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected class name after @class"];
        }
        return nil;
    }
    NSString *className = [state consume].text;

    // : SuperclassName (optional)
    NSString *superclassName = nil;
    if ([state currentIs:ASTokenTypeColon]) {
        [state consume]; // :
        if (![state currentIs:ASTokenTypeIdentifier]) {
            if (error) {
                *error = [self errorForToken:[state current]
                                        code:([state currentIs:ASTokenTypeEOF]
                                              ? ASParserErrorUnexpectedEOF
                                              : ASParserErrorUnexpectedToken)
                                     message:@"Expected superclass name after ':'"];
            }
            return nil;
        }
        superclassName = [state consume].text;
    }

    // <Protocol1, Protocol2> (optional)
    NSMutableArray<NSString *> *protocols = [NSMutableArray array];
    if ([state currentIs:ASTokenTypeLeftAngle]) {
        [state consume]; // <
        if (![state currentIs:ASTokenTypeIdentifier]) {
            if (error) {
                *error = [self errorForToken:[state current]
                                        code:([state currentIs:ASTokenTypeEOF]
                                              ? ASParserErrorUnexpectedEOF
                                              : ASParserErrorUnexpectedToken)
                                     message:@"Expected protocol name after '<'"];
            }
            return nil;
        }
        [protocols addObject:[state consume].text];
        while ([state currentIs:ASTokenTypeComma]) {
            [state consume]; // ,
            if (![state currentIs:ASTokenTypeIdentifier]) {
                if (error) {
                    *error = [self errorForToken:[state current]
                                            code:([state currentIs:ASTokenTypeEOF]
                                                  ? ASParserErrorUnexpectedEOF
                                                  : ASParserErrorUnexpectedToken)
                                         message:@"Expected protocol name after ','"];
                }
                return nil;
            }
            [protocols addObject:[state consume].text];
        }
        if (![state currentIs:ASTokenTypeRightAngle]) {
            if (error) {
                if ([state currentIs:ASTokenTypeEOF]) {
                    *error = [self unexpectedEOFError:[state current]
                                             message:@"Unterminated protocol list"];
                } else {
                    *error = [self unexpectedTokenError:[state current]];
                }
            }
            return nil;
        }
        [state consume]; // >
    }

    // Expect newline after header
    if (![state currentIs:ASTokenTypeNewline] && ![state currentIs:ASTokenTypeEOF]) {
        if (error) {
            *error = [self unexpectedTokenError:[state current]];
        }
        return nil;
    }
    [state skipNewlines];

    // Parse body: properties and methods until @end
    NSMutableArray<ASPropertyNode *> *properties = [NSMutableArray array];
    NSMutableArray<ASMethodNode *> *methods = [NSMutableArray array];

    while (![state currentIs:ASTokenTypeKwEnd]) {
        if ([state currentIs:ASTokenTypeEOF]) {
            if (error) {
                *error = [self unexpectedEOFError:[state current]
                                         message:@"Unterminated class definition; expected @end"];
            }
            return nil;
        }

        [state skipNewlines];
        if ([state currentIs:ASTokenTypeKwEnd]) {
            break;
        }

        if ([state currentIs:ASTokenTypeKwProperty]) {
            ASPropertyNode *prop = [self parsePropertyDeclaration:state error:error];
            if (!prop) return nil;
            [properties addObject:prop];
        } else if ([state currentIs:ASTokenTypeMinus] || [state currentIs:ASTokenTypePlus]) {
            ASMethodNode *method = [self parseMethodDefinition:state error:error];
            if (!method) return nil;
            [methods addObject:method];
        } else if ([state currentIs:ASTokenTypeEOF]) {
            if (error) {
                *error = [self unexpectedEOFError:[state current]
                                         message:@"Unterminated class definition; expected @end"];
            }
            return nil;
        } else {
            if (error) {
                *error = [self unexpectedTokenError:[state current]];
            }
            return nil;
        }
    }

    [state consume]; // @end

    // Expect newline or EOF after @end
    if (![state currentIs:ASTokenTypeNewline] && ![state currentIs:ASTokenTypeEOF]) {
        if (error) {
            *error = [self unexpectedTokenError:[state current]];
        }
        return nil;
    }

    return [[ASClassDefinitionNode alloc] initWithClassName:className
                                             superclassName:superclassName
                                              protocolNames:[protocols copy]
                                                 properties:[properties copy]
                                                    methods:[methods copy]
                                                       line:line
                                                     column:column];
}

- (nullable ASCategoryDefinitionNode *)parseCategoryDefinition:(ASParseState *)state
                                                         error:(NSError **)error {
    ASToken *kwToken = [state consume]; // @category
    NSUInteger line = kwToken.line;
    NSUInteger column = kwToken.column;

    // ClassName
    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected class name after @category"];
        }
        return nil;
    }
    NSString *className = [state consume].text;

    // (CategoryName)
    if (![state currentIs:ASTokenTypeLeftParen]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected '(' after class name in @category"];
        }
        return nil;
    }
    [state consume]; // (

    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected category name inside parentheses"];
        }
        return nil;
    }
    NSString *categoryName = [state consume].text;

    if (![state currentIs:ASTokenTypeRightParen]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected ')' after category name"];
        }
        return nil;
    }
    [state consume]; // )

    // Expect newline after header
    if (![state currentIs:ASTokenTypeNewline] && ![state currentIs:ASTokenTypeEOF]) {
        if (error) {
            *error = [self unexpectedTokenError:[state current]];
        }
        return nil;
    }
    [state skipNewlines];

    // Parse methods until @end
    NSMutableArray<ASMethodNode *> *methods = [NSMutableArray array];

    while (![state currentIs:ASTokenTypeKwEnd]) {
        if ([state currentIs:ASTokenTypeEOF]) {
            if (error) {
                *error = [self unexpectedEOFError:[state current]
                                         message:@"Unterminated category definition; expected @end"];
            }
            return nil;
        }

        [state skipNewlines];
        if ([state currentIs:ASTokenTypeKwEnd]) {
            break;
        }

        if ([state currentIs:ASTokenTypeMinus] || [state currentIs:ASTokenTypePlus]) {
            ASMethodNode *method = [self parseMethodDefinition:state error:error];
            if (!method) return nil;
            [methods addObject:method];
        } else if ([state currentIs:ASTokenTypeEOF]) {
            if (error) {
                *error = [self unexpectedEOFError:[state current]
                                         message:@"Unterminated category definition; expected @end"];
            }
            return nil;
        } else {
            if (error) {
                *error = [self unexpectedTokenError:[state current]];
            }
            return nil;
        }
    }

    [state consume]; // @end

    return [[ASCategoryDefinitionNode alloc] initWithClassName:className
                                                  categoryName:categoryName
                                                       methods:[methods copy]
                                                          line:line
                                                        column:column];
}

// ---------------------------------------------------------------------------
// Property declaration
// ---------------------------------------------------------------------------

- (nullable ASPropertyNode *)parsePropertyDeclaration:(ASParseState *)state
                                                error:(NSError **)error {
    ASToken *kwToken = [state consume]; // @property
    NSUInteger line = kwToken.line;
    NSUInteger column = kwToken.column;

    NSMutableArray<NSString *> *modifiers = [NSMutableArray array];

    // Optional (modifier1, modifier2)
    if ([state currentIs:ASTokenTypeLeftParen]) {
        [state consume]; // (
        while (![state currentIs:ASTokenTypeRightParen]) {
            if ([state currentIs:ASTokenTypeEOF]) {
                if (error) {
                    *error = [self unexpectedEOFError:[state current]
                                             message:@"Unterminated property modifier list"];
                }
                return nil;
            }
            if ([state currentIs:ASTokenTypeIdentifier] ||
                [state currentIs:ASTokenTypeKwWeak]) {
                [modifiers addObject:[state consume].text];
            } else if ([state currentIs:ASTokenTypeComma]) {
                [state consume];
            } else {
                if (error) {
                    *error = [self unexpectedTokenError:[state current]];
                }
                return nil;
            }
        }
        [state consume]; // )
    }

    // propertyName
    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected property name after @property"];
        }
        return nil;
    }
    NSString *propertyName = [state consume].text;

    // Consume trailing newline
    if ([state currentIs:ASTokenTypeNewline]) {
        [state consume];
    }

    return [[ASPropertyNode alloc] initWithPropertyName:propertyName
                                              modifiers:[modifiers copy]
                                                   line:line
                                                 column:column];
}

// ---------------------------------------------------------------------------
// Method definition
// ---------------------------------------------------------------------------

- (nullable ASMethodNode *)parseMethodDefinition:(ASParseState *)state
                                           error:(NSError **)error {
    ASToken *sigToken = [state current];
    NSUInteger line = sigToken.line;
    NSUInteger column = sigToken.column;

    BOOL isClassMethod = NO;
    if ([state currentIs:ASTokenTypePlus]) {
        isClassMethod = YES;
        [state consume]; // +
    } else if ([state currentIs:ASTokenTypeMinus]) {
        [state consume]; // -
    } else {
        if (error) {
            *error = [self unexpectedTokenError:[state current]];
        }
        return nil;
    }

    // Parse selector parts and parameter names
    NSMutableArray<NSString *> *selectorParts = [NSMutableArray array];
    NSMutableArray<NSString *> *parameterNames = [NSMutableArray array];

    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected selector identifier in method definition"];
        }
        return nil;
    }

    NSString *firstSelector = [state consume].text;
    [selectorParts addObject:firstSelector];

    if ([state currentIs:ASTokenTypeLeftBrace]) {
        // Zero-argument method: - name {
        // parameterNames stays empty
    } else if ([state currentIs:ASTokenTypeColon]) {
        // Keyword method with parameters
        [state consume]; // :
        if (![state currentIs:ASTokenTypeIdentifier]) {
            if (error) {
                *error = [self errorForToken:[state current]
                                        code:([state currentIs:ASTokenTypeEOF]
                                              ? ASParserErrorUnexpectedEOF
                                              : ASParserErrorUnexpectedToken)
                                     message:@"Expected parameter name after ':'"];
            }
            return nil;
        }
        [parameterNames addObject:[state consume].text];

        // Continue reading keyword:param pairs
        while ([state currentIs:ASTokenTypeIdentifier]) {
            // Could be another keyword part or the start of the body — peek for colon
            NSString *nextSelector = [state consume].text;
            if ([state currentIs:ASTokenTypeColon]) {
                [state consume]; // :
                [selectorParts addObject:nextSelector];
                if (![state currentIs:ASTokenTypeIdentifier]) {
                    if (error) {
                        *error = [self errorForToken:[state current]
                                                code:([state currentIs:ASTokenTypeEOF]
                                                      ? ASParserErrorUnexpectedEOF
                                                      : ASParserErrorUnexpectedToken)
                                             message:@"Expected parameter name after ':'"];
                    }
                    return nil;
                }
                [parameterNames addObject:[state consume].text];
            } else {
                // It was an unexpected identifier after params without colon
                if (error) {
                    *error = [self unexpectedTokenError:[state current]];
                }
                return nil;
            }
        }
    }

    // Expect {
    if (![state currentIs:ASTokenTypeLeftBrace]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected '{' to open method body"];
        }
        return nil;
    }
    [state consume]; // {

    // Expect newline after {
    if ([state currentIs:ASTokenTypeNewline]) {
        [state consume];
    }

    // Parse body statements until } on its own line
    NSArray<ASASTNode *> *body = [self parseBody:state error:error];
    if (!body) return nil;

    // Consume trailing newline after }
    if ([state currentIs:ASTokenTypeNewline]) {
        [state consume];
    }

    return [[ASMethodNode alloc] initWithSelectorParts:[selectorParts copy]
                                        parameterNames:[parameterNames copy]
                                                  body:body
                                         isClassMethod:isClassMethod
                                                  line:line
                                                column:column];
}

// ---------------------------------------------------------------------------
// Body (shared by methods and blocks): reads statements until } on its own line
// ---------------------------------------------------------------------------

- (nullable NSArray<ASASTNode *> *)parseBody:(ASParseState *)state
                                       error:(NSError **)error {
    NSMutableArray<ASASTNode *> *statements = [NSMutableArray array];

    while (YES) {
        // Skip blank lines
        [state skipNewlines];

        if ([state currentIs:ASTokenTypeEOF]) {
            if (error) {
                *error = [self unexpectedEOFError:[state current]
                                         message:@"Unexpected end of input inside body"];
            }
            return nil;
        }

        // } closes the body
        if ([state currentIs:ASTokenTypeRightBrace]) {
            [state consume]; // }
            return [statements copy];
        }

        ASASTNode *stmt = [self parseStatement:state error:error];
        if (!stmt) return nil;
        [statements addObject:stmt];
    }
}

// ---------------------------------------------------------------------------
// Statement
// ---------------------------------------------------------------------------

- (nullable ASASTNode *)parseStatement:(ASParseState *)state
                                 error:(NSError **)error {
    // return statement
    if ([state currentIs:ASTokenTypeKwReturn]) {
        return [self parseReturnStatement:state error:error];
    }

    // Variable declaration: (weak | constant)? id name ...
    if ([state currentIs:ASTokenTypeKwWeak] || [state currentIs:ASTokenTypeKwConstant]) {
        return [self parseVariableDeclaration:state error:error];
    }

    if ([state currentIs:ASTokenTypeKwId]) {
        return [self parseVariableDeclaration:state error:error];
    }

    // self = expr — reassigning self (e.g. self = [super init])
    if ([state currentIs:ASTokenTypeKwSelf]) {
        ASToken *next = [state peekAhead:1];
        if (next.type == ASTokenTypeEquals) {
            return [self parseAssignment:state error:error];
        }
        // Otherwise fall through to expression statement (e.g. bare `self`)
    }

    // Assignment or expression statement: starts with identifier
    // Look ahead to distinguish: identifier = expr  vs  expression-statement
    if ([state currentIs:ASTokenTypeIdentifier]) {
        // Peek ahead: if next non-this token is =, it's an assignment
        ASToken *next = [state peekAhead:1];
        if (next.type == ASTokenTypeEquals) {
            return [self parseAssignment:state error:error];
        }
        // Otherwise fall through to expression statement
    }

    // Expression statement (message send, block, literal, etc.)
    ASASTNode *expr = [self parseExpression:state error:error];
    if (!expr) return nil;

    // Consume trailing newline
    if ([state currentIs:ASTokenTypeNewline]) {
        [state consume];
    }

    return expr;
}

// ---------------------------------------------------------------------------
// Return statement
// ---------------------------------------------------------------------------

- (nullable ASReturnNode *)parseReturnStatement:(ASParseState *)state
                                          error:(NSError **)error {
    ASToken *kwToken = [state consume]; // return
    NSUInteger line = kwToken.line;
    NSUInteger column = kwToken.column;

    // Bare return
    if ([state currentIs:ASTokenTypeNewline] || [state currentIs:ASTokenTypeEOF]) {
        if ([state currentIs:ASTokenTypeNewline]) [state consume];
        return [[ASReturnNode alloc] initWithValue:nil line:line column:column];
    }

    ASASTNode *value = [self parseExpression:state error:error];
    if (!value) return nil;

    if ([state currentIs:ASTokenTypeNewline]) [state consume];

    return [[ASReturnNode alloc] initWithValue:value line:line column:column];
}

// ---------------------------------------------------------------------------
// Variable declaration
// ---------------------------------------------------------------------------

- (nullable ASVariableDeclarationNode *)parseVariableDeclaration:(ASParseState *)state
                                                           error:(NSError **)error {
    ASToken *firstToken = [state current];
    NSUInteger line = firstToken.line;
    NSUInteger column = firstToken.column;

    BOOL isWeak = NO;
    BOOL isConstant = NO;

    if ([state currentIs:ASTokenTypeKwWeak]) {
        isWeak = YES;
        [state consume];
    } else if ([state currentIs:ASTokenTypeKwConstant]) {
        isConstant = YES;
        [state consume];
    }

    // id keyword
    if (![state currentIs:ASTokenTypeKwId]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected 'id' in variable declaration"];
        }
        return nil;
    }
    [state consume]; // id

    // variable name
    if (![state currentIs:ASTokenTypeIdentifier]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected variable name after 'id'"];
        }
        return nil;
    }
    NSString *varName = [state consume].text;

    ASASTNode *initializer = nil;
    if ([state currentIs:ASTokenTypeEquals]) {
        [state consume]; // =
        initializer = [self parseExpression:state error:error];
        if (!initializer) return nil;
    }

    if ([state currentIs:ASTokenTypeNewline]) [state consume];

    return [[ASVariableDeclarationNode alloc] initWithVariableName:varName
                                                       initializer:initializer
                                                            isWeak:isWeak
                                                        isConstant:isConstant
                                                              line:line
                                                            column:column];
}

// ---------------------------------------------------------------------------
// Assignment
// ---------------------------------------------------------------------------

- (nullable ASAssignmentNode *)parseAssignment:(ASParseState *)state
                                         error:(NSError **)error {
    // Accepts either a plain identifier or the 'self' keyword as the assignment target.
    ASToken *nameToken = [state consume]; // identifier or 'self'
    NSUInteger line = nameToken.line;
    NSUInteger column = nameToken.column;
    NSString *varName = nameToken.text;

    // consume =
    if (![state currentIs:ASTokenTypeEquals]) {
        if (error) {
            *error = [self unexpectedTokenError:[state current]];
        }
        return nil;
    }
    [state consume]; // =

    ASASTNode *value = [self parseExpression:state error:error];
    if (!value) return nil;

    if ([state currentIs:ASTokenTypeNewline]) [state consume];

    return [[ASAssignmentNode alloc] initWithVariableName:varName
                                                    value:value
                                                     line:line
                                                   column:column];
}

// ---------------------------------------------------------------------------
// Expression
// ---------------------------------------------------------------------------

- (nullable ASASTNode *)parseExpression:(ASParseState *)state
                                  error:(NSError **)error {
    ASToken *tok = [state current];

    // Message send: [ receiver selector ]
    if ([state currentIs:ASTokenTypeLeftBracket]) {
        return [self parseMessageSend:state error:error];
    }

    // Block literal: ^ { ... } or ^ ( params ) { ... }
    if ([state currentIs:ASTokenTypeCaret]) {
        return [self parseBlockLiteral:state error:error];
    }

    // @ prefix: @"string", @[array], @{dict}, @42 (number boxed)
    if ([state currentIs:ASTokenTypeAt]) {
        return [self parseAtExpression:state error:error];
    }

    // String literal (already combined by lexer as @"...")
    if ([state currentIs:ASTokenTypeStringLiteral]) {
        ASToken *strTok = [state consume];
        // Strip the @" prefix and " suffix to get the content
        NSString *raw = strTok.text;
        NSString *content = raw;
        if ([raw hasPrefix:@"@\""] && [raw hasSuffix:@"\""]) {
            content = [raw substringWithRange:NSMakeRange(2, raw.length - 3)];
        }
        NSError *unescapeError = nil;
        NSString *unescaped = [self unescapeString:content
                                            atLine:strTok.line
                                            column:strTok.column
                                             error:&unescapeError];
        if (!unescaped) {
            if (error) *error = unescapeError;
            return nil;
        }
        return [[ASStringLiteralNode alloc] initWithValue:unescaped
                                                     line:strTok.line
                                                   column:strTok.column];
    }

    // Number literal
    if ([state currentIs:ASTokenTypeNumberLiteral]) {
        ASToken *numTok = [state consume];
        NSNumber *value = @([numTok.text doubleValue]);
        return [[ASNumberLiteralNode alloc] initWithValue:value
                                                     line:numTok.line
                                                   column:numTok.column];
    }

    // Bool literal YES/NO
    if ([state currentIs:ASTokenTypeBoolLiteral]) {
        ASToken *boolTok = [state consume];
        return [[ASIdentifierNode alloc] initWithName:boolTok.text
                                                 line:boolTok.line
                                               column:boolTok.column];
    }

    // nil literal
    if ([state currentIs:ASTokenTypeNilLiteral]) {
        ASToken *nilTok = [state consume];
        return [[ASIdentifierNode alloc] initWithName:nilTok.text
                                                 line:nilTok.line
                                               column:nilTok.column];
    }

    // self
    if ([state currentIs:ASTokenTypeKwSelf]) {
        ASToken *selfTok = [state consume];
        return [[ASIdentifierNode alloc] initWithName:selfTok.text
                                                 line:selfTok.line
                                               column:selfTok.column];
    }

    // _cmd
    if ([state currentIs:ASTokenTypeKwCmd]) {
        ASToken *cmdTok = [state consume];
        return [[ASIdentifierNode alloc] initWithName:cmdTok.text
                                                 line:cmdTok.line
                                               column:cmdTok.column];
    }

    // super — only valid as a message receiver outside a block literal
    if ([state currentIs:ASTokenTypeKwSuper]) {
        ASToken *superTok = [state consume];
        if (state.blockDepth > 0) {
            if (error) {
                *error = [self errorForToken:superTok
                                        code:ASParserErrorUnexpectedToken
                                     message:@"'super' is not valid inside a block literal"];
            }
            return nil;
        }
        return [[ASSuperNode alloc] initWithLine:superTok.line
                                          column:superTok.column];
    }

    // Plain identifier (variable, class name)
    if ([state currentIs:ASTokenTypeIdentifier]) {
        ASToken *identTok = [state consume];
        return [[ASIdentifierNode alloc] initWithName:identTok.text
                                                 line:identTok.line
                                               column:identTok.column];
    }

    // Unrecognised
    if ([state currentIs:ASTokenTypeEOF]) {
        if (error) {
            *error = [self unexpectedEOFError:[state current]
                                     message:@"Unexpected end of input in expression"];
        }
        return nil;
    }

    if (error) {
        *error = [self unexpectedTokenError:tok];
    }
    return nil;
}

// ---------------------------------------------------------------------------
// @ expression: @"...", @[...], @{...}
// ---------------------------------------------------------------------------

- (nullable ASASTNode *)parseAtExpression:(ASParseState *)state
                                    error:(NSError **)error {
    // The lexer already produces ASTokenTypeStringLiteral for @"..." so we
    // should only get here for @[ or @{.
    ASToken *atToken = [state consume]; // @
    NSUInteger line = atToken.line;
    NSUInteger column = atToken.column;

    if ([state currentIs:ASTokenTypeLeftBracket]) {
        // Array literal @[...]
        [state consume]; // [
        NSMutableArray<ASASTNode *> *elements = [NSMutableArray array];
        while (![state currentIs:ASTokenTypeRightBracket]) {
            if ([state currentIs:ASTokenTypeEOF]) {
                if (error) {
                    *error = [self unexpectedEOFError:[state current]
                                             message:@"Unterminated array literal"];
                }
                return nil;
            }
            [state skipNewlines];
            if ([state currentIs:ASTokenTypeRightBracket]) break;
            ASASTNode *elem = [self parseExpression:state error:error];
            if (!elem) return nil;
            [elements addObject:elem];
            [state skipNewlines];
            if ([state currentIs:ASTokenTypeComma]) [state consume];
        }
        [state consume]; // ]
        return [[ASArrayLiteralNode alloc] initWithElements:[elements copy]
                                                       line:line
                                                     column:column];
    }

    if ([state currentIs:ASTokenTypeLeftBrace]) {
        // Dictionary literal @{...}
        [state consume]; // {
        NSMutableArray<ASASTNode *> *keys = [NSMutableArray array];
        NSMutableArray<ASASTNode *> *values = [NSMutableArray array];
        while (![state currentIs:ASTokenTypeRightBrace]) {
            if ([state currentIs:ASTokenTypeEOF]) {
                if (error) {
                    *error = [self unexpectedEOFError:[state current]
                                             message:@"Unterminated dictionary literal"];
                }
                return nil;
            }
            [state skipNewlines];
            if ([state currentIs:ASTokenTypeRightBrace]) break;
            ASASTNode *key = [self parseExpression:state error:error];
            if (!key) return nil;
            if (![state currentIs:ASTokenTypeColon]) {
                if (error) {
                    *error = [self errorForToken:[state current]
                                            code:([state currentIs:ASTokenTypeEOF]
                                                  ? ASParserErrorUnexpectedEOF
                                                  : ASParserErrorUnexpectedToken)
                                         message:@"Expected ':' between key and value in dictionary literal"];
                }
                return nil;
            }
            [state consume]; // :
            ASASTNode *value = [self parseExpression:state error:error];
            if (!value) return nil;
            [keys addObject:key];
            [values addObject:value];
            [state skipNewlines];
            if ([state currentIs:ASTokenTypeComma]) [state consume];
        }
        [state consume]; // }
        return [[ASDictionaryLiteralNode alloc] initWithKeys:[keys copy]
                                                      values:[values copy]
                                                        line:line
                                                      column:column];
    }

    // @42 — boxed number (rare but possible)
    if ([state currentIs:ASTokenTypeNumberLiteral]) {
        ASToken *numTok = [state consume];
        NSNumber *value = @([numTok.text doubleValue]);
        return [[ASNumberLiteralNode alloc] initWithValue:value
                                                     line:line
                                                   column:column];
    }

    if (error) {
        *error = [self unexpectedTokenError:[state current]];
    }
    return nil;
}

// ---------------------------------------------------------------------------
// Message send: [ receiver selector ]
// ---------------------------------------------------------------------------

// Returns YES for token types that can serve as a selector keyword name.
// ObjC selectors may use any identifier word, including AppScript contextual
// keywords such as `id`, `weak`, `constant`, and `return`.  Structural
// keywords (@class, @end, …) and special-receiver tokens (self, super, _cmd)
// are intentionally excluded because they carry distinct parse semantics.
static BOOL ASTokenIsKeywordPart(ASToken *tok) {
    switch (tok.type) {
        case ASTokenTypeIdentifier:
        case ASTokenTypeKwId:
        case ASTokenTypeKwWeak:
        case ASTokenTypeKwConstant:
        case ASTokenTypeKwReturn:
            return YES;
        default:
            return NO;
    }
}

- (nullable ASMessageSendNode *)parseMessageSend:(ASParseState *)state
                                           error:(NSError **)error {
    ASToken *lbToken = [state consume]; // [
    NSUInteger line = lbToken.line;
    NSUInteger column = lbToken.column;

    [state skipNewlines];

    // Parse receiver
    ASASTNode *receiver = [self parseExpression:state error:error];
    if (!receiver) return nil;

    [state skipNewlines];

    // Parse selector and arguments
    NSMutableArray<NSString *> *selectorParts = [NSMutableArray array];
    NSMutableArray<ASASTNode *> *arguments = [NSMutableArray array];

    if (ASTokenIsKeywordPart([state current])) {
        NSString *firstPart = [state consume].text;
        [state skipNewlines];

        if ([state currentIs:ASTokenTypeRightBracket]) {
            // Zero-argument message
            [selectorParts addObject:firstPart];
        } else if ([state currentIs:ASTokenTypeColon]) {
            // Keyword message
            [state consume]; // :
            [state skipNewlines];
            ASASTNode *arg = [self parseExpression:state error:error];
            if (!arg) return nil;
            [selectorParts addObject:firstPart];
            [arguments addObject:arg];

            [state skipNewlines];

            // Additional keyword:arg pairs — supports both named (key:arg) and
            // unnamed (:arg) parts, e.g. [obj NSMakeRect:x :y :w :h].
            while (ASTokenIsKeywordPart([state current]) || [state currentIs:ASTokenTypeColon]) {
                NSString *nextPart;
                if (ASTokenIsKeywordPart([state current])) {
                    nextPart = [state consume].text;
                    if (![state currentIs:ASTokenTypeColon]) {
                        if (error) {
                            *error = [self unexpectedTokenError:[state current]];
                        }
                        return nil;
                    }
                } else {
                    nextPart = @""; // unnamed keyword part
                }
                [state consume]; // :
                [state skipNewlines];
                ASASTNode *nextArg = [self parseExpression:state error:error];
                if (!nextArg) return nil;
                [selectorParts addObject:nextPart];
                [arguments addObject:nextArg];
                [state skipNewlines];
            }
        } else {
            if (error) {
                *error = [self unexpectedTokenError:[state current]];
            }
            return nil;
        }
    } else {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected selector identifier in message send"];
        }
        return nil;
    }

    [state skipNewlines];
    if (![state currentIs:ASTokenTypeRightBracket]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected ']' to close message send"];
        }
        return nil;
    }
    [state consume]; // ]

    return [[ASMessageSendNode alloc] initWithReceiver:receiver
                                         selectorParts:[selectorParts copy]
                                             arguments:[arguments copy]
                                                  line:line
                                                column:column];
}

// ---------------------------------------------------------------------------
// Block literal: ^ { ... } or ^ ( params ) { ... }
// ---------------------------------------------------------------------------

- (nullable ASBlockLiteralNode *)parseBlockLiteral:(ASParseState *)state
                                             error:(NSError **)error {
    ASToken *caretToken = [state consume]; // ^
    NSUInteger line = caretToken.line;
    NSUInteger column = caretToken.column;

    NSMutableArray<NSString *> *params = [NSMutableArray array];

    // Optional parameter list ( param1, param2 )
    if ([state currentIs:ASTokenTypeLeftParen]) {
        [state consume]; // (
        while (![state currentIs:ASTokenTypeRightParen]) {
            if ([state currentIs:ASTokenTypeEOF]) {
                if (error) {
                    *error = [self unexpectedEOFError:[state current]
                                             message:@"Unterminated block parameter list"];
                }
                return nil;
            }
            if ([state currentIs:ASTokenTypeIdentifier]) {
                [params addObject:[state consume].text];
            } else if ([state currentIs:ASTokenTypeComma]) {
                [state consume];
            } else {
                if (error) {
                    *error = [self unexpectedTokenError:[state current]];
                }
                return nil;
            }
        }
        [state consume]; // )
    }

    // Expect {
    if (![state currentIs:ASTokenTypeLeftBrace]) {
        if (error) {
            *error = [self errorForToken:[state current]
                                    code:([state currentIs:ASTokenTypeEOF]
                                          ? ASParserErrorUnexpectedEOF
                                          : ASParserErrorUnexpectedToken)
                                 message:@"Expected '{' to open block body"];
        }
        return nil;
    }
    [state consume]; // {

    // Consume newline after {
    if ([state currentIs:ASTokenTypeNewline]) {
        [state consume];
    }

    state.blockDepth++;
    NSArray<ASASTNode *> *body = [self parseBody:state error:error];
    state.blockDepth--;
    if (!body) return nil;

    return [[ASBlockLiteralNode alloc] initWithParameterNames:[params copy]
                                                         body:body
                                                         line:line
                                                       column:column];
}

// ---------------------------------------------------------------------------
// String literal unescaping
// ---------------------------------------------------------------------------

/// Translates C / Objective-C escape sequences in a raw string literal content
/// (i.e. the text after stripping the surrounding @" … " delimiters) into the
/// corresponding Unicode characters.
///
/// Supported sequences mirror those of the Objective-C language:
///   \\  \"  \n  \t  \r  \0  \a  \b  \f  \v
///   \xNN  (1–2 hex digits)
///   \uNNNN  (exactly 4 hex digits)
///   \UNNNNNNNN  (exactly 8 hex digits)
///   \NNN  (1–3 octal digits)
///
/// Any backslash followed by an unrecognised character is a parse error.
- (nullable NSString *)unescapeString:(NSString *)raw
                               atLine:(NSUInteger)line
                               column:(NSUInteger)column
                                error:(NSError **)error {
    NSUInteger len = raw.length;
    NSMutableString *result = [NSMutableString stringWithCapacity:len];
    NSUInteger i = 0;

    while (i < len) {
        unichar c = [raw characterAtIndex:i];

        if (c != '\\') {
            [result appendFormat:@"%C", c];
            i++;
            continue;
        }

        // Backslash — look at the next character.
        if (i + 1 >= len) {
            // Trailing backslash with nothing after it.
            if (error) {
                *error = [NSError errorWithDomain:ASParserErrorDomain
                                             code:ASParserErrorInvalidEscapeSequence
                                         userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:
                        @"Trailing backslash in string literal at line %lu, column %lu",
                        (unsigned long)line, (unsigned long)column],
                }];
            }
            return nil;
        }

        unichar next = [raw characterAtIndex:i + 1];

        // Simple single-character escapes.
        switch (next) {
            case '\\': [result appendString:@"\\"]; i += 2; continue;
            case '"':  [result appendString:@"\""]; i += 2; continue;
            case 'n':  [result appendString:@"\n"]; i += 2; continue;
            case 't':  [result appendString:@"\t"]; i += 2; continue;
            case 'r':  [result appendString:@"\r"]; i += 2; continue;
            case '0':  [result appendFormat:@"%C", (unichar)0x0000]; i += 2; continue;
            case 'a':  [result appendFormat:@"%C", (unichar)0x0007]; i += 2; continue;
            case 'b':  [result appendFormat:@"%C", (unichar)0x0008]; i += 2; continue;
            case 'f':  [result appendFormat:@"%C", (unichar)0x000C]; i += 2; continue;
            case 'v':  [result appendFormat:@"%C", (unichar)0x000B]; i += 2; continue;
            default: break;
        }

        // \xNN — hex escape (1–2 hex digits).
        if (next == 'x') {
            NSUInteger j = i + 2;
            NSUInteger hexStart = j;
            while (j < len && j < hexStart + 2) {
                unichar h = [raw characterAtIndex:j];
                if (!((h >= '0' && h <= '9') || (h >= 'a' && h <= 'f') || (h >= 'A' && h <= 'F'))) break;
                j++;
            }
            if (j == hexStart) {
                if (error) {
                    *error = [NSError errorWithDomain:ASParserErrorDomain
                                                 code:ASParserErrorInvalidEscapeSequence
                                             userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:
                            @"\\x escape requires at least one hex digit at line %lu, column %lu",
                            (unsigned long)line, (unsigned long)column],
                    }];
                }
                return nil;
            }
            NSString *hexStr = [raw substringWithRange:NSMakeRange(hexStart, j - hexStart)];
            unsigned int codePoint = 0;
            [[NSScanner scannerWithString:hexStr] scanHexInt:&codePoint];
            [result appendFormat:@"%C", (unichar)codePoint];
            i = j;
            continue;
        }

        // \uNNNN — 4-digit Unicode escape.
        if (next == 'u') {
            if (i + 5 >= len + 1) { // need exactly 4 digits
                if (error) {
                    *error = [NSError errorWithDomain:ASParserErrorDomain
                                                 code:ASParserErrorInvalidEscapeSequence
                                             userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:
                            @"\\u escape requires exactly 4 hex digits at line %lu, column %lu",
                            (unsigned long)line, (unsigned long)column],
                    }];
                }
                return nil;
            }
            NSString *hexStr = [raw substringWithRange:NSMakeRange(i + 2, 4)];
            for (NSUInteger k = 0; k < 4; k++) {
                unichar h = [hexStr characterAtIndex:k];
                if (!((h >= '0' && h <= '9') || (h >= 'a' && h <= 'f') || (h >= 'A' && h <= 'F'))) {
                    if (error) {
                        *error = [NSError errorWithDomain:ASParserErrorDomain
                                                     code:ASParserErrorInvalidEscapeSequence
                                                 userInfo:@{
                            NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                @"\\u escape requires exactly 4 hex digits at line %lu, column %lu",
                                (unsigned long)line, (unsigned long)column],
                        }];
                    }
                    return nil;
                }
            }
            unsigned int codePoint = 0;
            [[NSScanner scannerWithString:hexStr] scanHexInt:&codePoint];
            [result appendFormat:@"%C", (unichar)codePoint];
            i += 6;
            continue;
        }

        // \UNNNNNNNN — 8-digit Unicode escape (full code point, may be outside BMP).
        if (next == 'U') {
            if (i + 9 >= len + 1) { // need exactly 8 digits
                if (error) {
                    *error = [NSError errorWithDomain:ASParserErrorDomain
                                                 code:ASParserErrorInvalidEscapeSequence
                                             userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:
                            @"\\U escape requires exactly 8 hex digits at line %lu, column %lu",
                            (unsigned long)line, (unsigned long)column],
                    }];
                }
                return nil;
            }
            NSString *hexStr = [raw substringWithRange:NSMakeRange(i + 2, 8)];
            for (NSUInteger k = 0; k < 8; k++) {
                unichar h = [hexStr characterAtIndex:k];
                if (!((h >= '0' && h <= '9') || (h >= 'a' && h <= 'f') || (h >= 'A' && h <= 'F'))) {
                    if (error) {
                        *error = [NSError errorWithDomain:ASParserErrorDomain
                                                     code:ASParserErrorInvalidEscapeSequence
                                                 userInfo:@{
                            NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                @"\\U escape requires exactly 8 hex digits at line %lu, column %lu",
                                (unsigned long)line, (unsigned long)column],
                        }];
                    }
                    return nil;
                }
            }
            unsigned int codePoint = 0;
            [[NSScanner scannerWithString:hexStr] scanHexInt:&codePoint];
            // Append as a UTF-32 code point; NSString uses UTF-16 surrogates for non-BMP.
            if (codePoint <= 0xFFFF) {
                [result appendFormat:@"%C", (unichar)codePoint];
            } else {
                // Encode as a surrogate pair.
                codePoint -= 0x10000;
                unichar high = (unichar)(0xD800 + (codePoint >> 10));
                unichar low  = (unichar)(0xDC00 + (codePoint & 0x3FF));
                [result appendFormat:@"%C%C", high, low];
            }
            i += 10;
            continue;
        }

        // \NNN — octal escape (1–3 octal digits, first digit may be 1–7 here since \0 is handled above).
        if (next >= '1' && next <= '7') {
            NSUInteger j = i + 1;
            NSUInteger octStart = j;
            while (j < len && j < octStart + 3) {
                unichar o = [raw characterAtIndex:j];
                if (o < '0' || o > '7') break;
                j++;
            }
            NSString *octStr = [raw substringWithRange:NSMakeRange(octStart, j - octStart)];
            unsigned int codePoint = 0;
            NSScanner *scanner = [NSScanner scannerWithString:octStr];
            [scanner scanInt:(int *)&codePoint]; // decimal scan; we need octal
            // Parse octal manually.
            codePoint = 0;
            for (NSUInteger k = 0; k < octStr.length; k++) {
                codePoint = codePoint * 8 + ([octStr characterAtIndex:k] - '0');
            }
            [result appendFormat:@"%C", (unichar)codePoint];
            i = j;
            continue;
        }

        // Unrecognised escape sequence.
        if (error) {
            *error = [NSError errorWithDomain:ASParserErrorDomain
                                         code:ASParserErrorInvalidEscapeSequence
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Unrecognised escape sequence '\\%C' in string literal at line %lu, column %lu",
                    next, (unsigned long)line, (unsigned long)column],
            }];
        }
        return nil;
    }

    return [result copy];
}

// ---------------------------------------------------------------------------
// Error helpers
// ---------------------------------------------------------------------------

- (NSError *)unexpectedTokenError:(ASToken *)token {
    return [self errorForToken:token
                          code:ASParserErrorUnexpectedToken
                       message:[NSString stringWithFormat:
                                @"Unexpected token '%@' at line %lu, column %lu",
                                token.text,
                                (unsigned long)token.line,
                                (unsigned long)token.column]];
}

- (NSError *)unexpectedEOFError:(ASToken *)token message:(NSString *)message {
    return [self errorForToken:token
                          code:ASParserErrorUnexpectedEOF
                       message:[NSString stringWithFormat:
                                @"%@ (line %lu, column %lu)",
                                message,
                                (unsigned long)token.line,
                                (unsigned long)token.column]];
}

- (NSError *)errorForToken:(ASToken *)token
                      code:(ASParserErrorCode)code
                   message:(NSString *)message {
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey: [NSString stringWithFormat:
                                    @"%@ (line %lu, column %lu)",
                                    message,
                                    (unsigned long)token.line,
                                    (unsigned long)token.column],
    };
    return [NSError errorWithDomain:ASParserErrorDomain
                               code:code
                           userInfo:userInfo];
}

@end
