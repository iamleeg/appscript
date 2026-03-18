// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASLoaderTests.m — Unit tests for ASLoader
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
#import <AppScript/ASLoader.h>

// ---------------------------------------------------------------------------
// Helper: Create a temporary directory with test files
// ---------------------------------------------------------------------------

static NSString *createTempDirectory(void) {
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *dir = [tmpDir stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"ASLoaderTest-%@", [NSUUID UUID].UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

static void writeFile(NSString *dir, NSString *filename, NSString *content) {
    NSString *path = [dir stringByAppendingPathComponent:filename];
    [content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// ---------------------------------------------------------------------------
// Test class
// ---------------------------------------------------------------------------

@interface ASLoaderTests : XCTestCase
@end

@implementation ASLoaderTests

// ---------------------------------------------------------------------------
// 1. Load script from file path
// ---------------------------------------------------------------------------

- (void)test_loadScriptFromFileAtPath_success {
    NSString *tmpDir = createTempDirectory();
    @autoreleasepool {
        NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        writeFile(tmpDir, @"test.appscript",
                  [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className]);
        
        ASLoader *loader = [[ASLoader alloc] init];
        NSError *error = nil;
        BOOL result = [loader loadScriptFromFileAtPath:[tmpDir stringByAppendingPathComponent:@"test.appscript"]
                                                 error:&error];
        
        XCTAssertTrue(result, @"Loading script from file path should succeed");
        XCTAssertNil(error, @"No error should be set on success");
    }
}

- (void)test_loadScriptFromFileAtPath_fileNotFound {
    ASLoader *loader = [[ASLoader alloc] init];
    NSError *error = nil;
    BOOL result = [loader loadScriptFromFileAtPath:@"/nonexistent/path/appscript.appscript"
                                             error:&error];

    XCTAssertFalse(result, @"Loading from nonexistent file should fail");
    XCTAssertNotNil(error, @"Error should be set on failure");
    XCTAssertEqualObjects(error.domain, ASLoaderErrorDomain,
                          @"Error domain should be ASLoaderErrorDomain");
    XCTAssertEqual(error.code, ASLoaderErrorFileNotFound,
                   @"Error code should be ASLoaderErrorFileNotFound");
}

- (void)test_loadScriptFromFileAtPath_duplicateLoad {
    NSString *tmpDir = createTempDirectory();
    @autoreleasepool {
        NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        writeFile(tmpDir, @"test.appscript",
                  [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className]);
        
        ASLoader *loader = [[ASLoader alloc] init];
        NSString *filePath = [tmpDir stringByAppendingPathComponent:@"test.appscript"];
        
        // First load should succeed
        NSError *error1 = nil;
        BOOL result1 = [loader loadScriptFromFileAtPath:filePath error:&error1];
        XCTAssertTrue(result1, @"First load should succeed");
        
        // Second load should fail with duplicate error
        NSError *error2 = nil;
        BOOL result2 = [loader loadScriptFromFileAtPath:filePath error:&error2];
        XCTAssertFalse(result2, @"Second load should fail");
        XCTAssertEqualObjects(error2.domain, ASLoaderErrorDomain,
                              @"Error domain should be ASLoaderErrorDomain");
        XCTAssertEqual(error2.code, ASLoaderErrorDuplicateLoad,
                       @"Error code should be ASLoaderErrorDuplicateLoad");
    }
}

// ---------------------------------------------------------------------------
// 2. Load script from string
// ---------------------------------------------------------------------------

- (void)test_loadScriptFromString_success {
    ASLoader *loader = [[ASLoader alloc] init];
    NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    NSString *source = [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className];
    
    NSError *error = nil;
    BOOL result = [loader loadScriptFromString:source error:&error];
    
    XCTAssertTrue(result, @"Loading script from string should succeed");
    XCTAssertNil(error, @"No error should be set on success");
}

- (void)test_loadScriptFromString_duplicateLoad {
    ASLoader *loader = [[ASLoader alloc] init];
    NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    NSString *source = [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className];
    
    // First load should succeed
    NSError *error1 = nil;
    BOOL result1 = [loader loadScriptFromString:source error:&error1];
    XCTAssertTrue(result1, @"First load should succeed");
    
    // Second load with same source should fail
    NSError *error2 = nil;
    BOOL result2 = [loader loadScriptFromString:source error:&error2];
    XCTAssertFalse(result2, @"Second load should fail");
    XCTAssertEqualObjects(error2.domain, ASLoaderErrorDomain,
                          @"Error domain should be ASLoaderErrorDomain");
    XCTAssertEqual(error2.code, ASLoaderErrorDuplicateLoad,
                   @"Error code should be ASLoaderErrorDuplicateLoad");
}

// ---------------------------------------------------------------------------
// 3. Load script with custom name
// ---------------------------------------------------------------------------

- (void)test_loadScriptFromFileAtPath_withScriptName {
    NSString *tmpDir = createTempDirectory();
    @autoreleasepool {
        NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        writeFile(tmpDir, @"test.appscript",
                  [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className]);
        
        ASLoader *loader = [[ASLoader alloc] init];
        NSString *filePath = [tmpDir stringByAppendingPathComponent:@"test.appscript"];
        
        NSError *error = nil;
        BOOL result = [loader loadScriptFromFileAtPath:filePath
                                              scriptName:@"Custom Name"
                                                   error:&error];
        
        XCTAssertTrue(result, @"Loading with custom name should succeed");
        XCTAssertNil(error, @"No error should be set on success");
    }
}

- (void)test_loadScriptFromString_withScriptName {
    ASLoader *loader = [[ASLoader alloc] init];
    NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
    NSString *source = [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className];
    
    NSError *error = nil;
    BOOL result = [loader loadScriptFromString:source
                                    scriptName:@"Custom Name"
                                         error:&error];
    
    XCTAssertTrue(result, @"Loading with custom name should succeed");
    XCTAssertNil(error, @"No error should be set on success");
}

// ---------------------------------------------------------------------------
// 4. Load multiple scripts from files
// ---------------------------------------------------------------------------

- (void)test_loadScriptsFromFilesAtPaths_success {
    NSString *tmpDir = createTempDirectory();
    @autoreleasepool {
        writeFile(tmpDir, @"base.appscript",
                  @"@class BaseClass : NSObject\n- baseMethod {\nreturn @\"base\"\n}\n@end");
        writeFile(tmpDir, @"derived.appscript",
                  @"@class DerivedClass : BaseClass\n- derivedMethod {\nreturn @\"derived\"\n}\n@end");
        
        ASLoader *loader = [[ASLoader alloc] init];
        NSArray<NSString *> *paths = @[
            [tmpDir stringByAppendingPathComponent:@"base.appscript"],
            [tmpDir stringByAppendingPathComponent:@"derived.appscript"]
        ];
        
        NSError *error = nil;
        BOOL result = [loader loadScriptsFromFilesAtPaths:paths error:&error];
        
        XCTAssertTrue(result, @"Loading multiple scripts should succeed");
        XCTAssertNil(error, @"No error should be set on success");
    }
}

// ---------------------------------------------------------------------------
// 5. Load multiple scripts from strings
// ---------------------------------------------------------------------------

- (void)test_loadScriptsFromStrings_success {
    ASLoader *loader = [[ASLoader alloc] init];
    NSArray<NSString *> *sources = @[
        @"@class Class1 : NSObject\n- method1 {\nreturn @\"1\"\n}\n@end",
        @"@class Class2 : NSObject\n- method2 {\nreturn @\"2\"\n}\n@end"
    ];
    
    NSError *error = nil;
    BOOL result = [loader loadScriptsFromStrings:sources error:&error];
    
    XCTAssertTrue(result, @"Loading multiple scripts from strings should succeed");
    XCTAssertNil(error, @"No error should be set on success");
}

// ---------------------------------------------------------------------------
// 6. Error handling
// ---------------------------------------------------------------------------

- (void)test_loadScriptFromFileAtPath_lexerError {
    ASLoader *loader = [[ASLoader alloc] init];
    
    // Invalid syntax that should cause a lexer error
    NSString *invalidSource = @"class {";
    
    NSError *error = nil;
    BOOL result = [loader loadScriptFromString:invalidSource error:&error];
    
    XCTAssertFalse(result, @"Loading invalid source should fail");
    XCTAssertNotNil(error, @"Error should be set on failure");
}

- (void)test_loadScriptFromFileAtPath_parserError {
    ASLoader *loader = [[ASLoader alloc] init];
    
    // Valid tokens but invalid syntax
    NSString *invalidSource = @"class MyClass method broken() {}";
    
    NSError *error = nil;
    BOOL result = [loader loadScriptFromString:invalidSource error:&error];
    
    XCTAssertFalse(result, @"Loading invalid syntax should fail");
    XCTAssertNotNil(error, @"Error should be set on failure");
}

// ---------------------------------------------------------------------------
// 7. Thread safety
// ---------------------------------------------------------------------------

- (void)test_loadScriptFromFileAtPath_concurrent {
    NSString *tmpDir = createTempDirectory();
    @autoreleasepool {
        NSString *className = [NSString stringWithFormat:@"TestClass_%@", [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""]];
        writeFile(tmpDir, @"test.appscript",
                  [NSString stringWithFormat:@"@class %@ : NSObject\n- hello {\nreturn @\"Hello\"\n}\n@end", className]);
        
        ASLoader *loader = [[ASLoader alloc] init];
        NSString *filePath = [tmpDir stringByAppendingPathComponent:@"test.appscript"];
        
        __block BOOL success1 = NO;
        __block BOOL success2 = NO;
        __block NSError *error1 = nil;
        __block NSError *error2 = nil;
        
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_async(group, queue, ^{
            success1 = [loader loadScriptFromFileAtPath:filePath error:&error1];
        });
        
        dispatch_group_async(group, queue, ^{
            success2 = [loader loadScriptFromFileAtPath:filePath error:&error2];
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

        // Exactly one load must succeed and one must fail with DuplicateLoad
        XCTAssertTrue(success1 != success2, @"Exactly one load should succeed");

        NSError *failingError = success1 ? error2 : error1;
        XCTAssertEqualObjects(failingError.domain, ASLoaderErrorDomain,
                              @"Failing error domain should be ASLoaderErrorDomain");
        XCTAssertEqual(failingError.code, ASLoaderErrorDuplicateLoad,
                       @"Failing error code should be ASLoaderErrorDuplicateLoad");
    }
}

@end
