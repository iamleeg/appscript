// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASTestRunner.m — Discovers and executes AppScript integration tests
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

#import "ASTestRunner.h"
#import <AppScript/ASRuntimeInstaller.h>

/// Protocol mirroring the interface of the AppScript-defined ASTestResult class.
/// Used only for compile-time type checking; the actual implementation is loaded at runtime.
@protocol ASTestResultProtocol <NSObject>
- (NSString *)testName;
- (NSNumber *)isPassed;
- (NSString *)expected;
- (NSString *)actual;
- (instancetype)initWithTestName:(NSString *)testName
                          passed:(NSNumber *)passed
                        expected:(NSString *)expected
                          actual:(NSString *)actual;
@end

@implementation ASTestRunner

- (NSArray *)runAllTests {
    Class testCaseClass = NSClassFromString(@"ASTestCase");
    NSMutableArray *results = [NSMutableArray array];

    if (testCaseClass != nil) {
        for (Class cls in [ASRuntimeInstaller registeredClasses]) {
            if (cls == testCaseClass) continue;
            if (![cls isSubclassOfClass:testCaseClass]) continue;
            id result = [self runTestClass:cls];
            [results addObject:result];
            // Log to stdout so CI captures output.
            id<ASTestResultProtocol> r = result;
            fprintf(stdout, "%s: %s\n",
                    [[r isPassed] boolValue] ? "PASS" : "FAIL",
                    [[r testName] UTF8String]);
        }
    }

    return results;
}

/// Runs a single test class and returns an ASTestResult.
/// The test name is the class name with the "Test" suffix stripped.
/// The expected output is read from the "Scripts/<testName>.expected" bundle resource.
- (id)runTestClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    NSString *testName = [className hasSuffix:@"Test"]
        ? [className substringToIndex:className.length - 4]
        : className;

    NSURL *expectedURL = [[NSBundle mainBundle] URLForResource:testName
                                                 withExtension:@"expected"
                                                  subdirectory:nil];

    id instance = [cls new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id resultObj = [instance performSelector:@selector(runTests)];
#pragma clang diagnostic pop
    NSString *actual = [[resultObj description]
                        stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (expectedURL == nil) {
        NSString *msg = [NSString stringWithFormat:@"no .expected file for %@", testName];
        return [[NSClassFromString(@"ASTestResult") alloc]
                initWithTestName:testName
                          passed:@NO
                        expected:msg
                          actual:actual];
    }

    NSError *readError = nil;
    NSString *expectedRaw = [NSString stringWithContentsOfURL:expectedURL
                                                     encoding:NSUTF8StringEncoding
                                                        error:&readError];
    if (expectedRaw == nil) {
        NSString *msg = [NSString stringWithFormat:@"cannot read .expected: %@",
                         readError.localizedDescription];
        return [[NSClassFromString(@"ASTestResult") alloc]
                initWithTestName:testName
                          passed:@NO
                        expected:msg
                          actual:actual];
    }

    NSString *expected = [expectedRaw
                          stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSNumber *passed = [NSNumber numberWithBool:[actual isEqualToString:expected]];
    return [[NSClassFromString(@"ASTestResult") alloc]
            initWithTestName:testName
                      passed:passed
                    expected:expected
                      actual:actual];
}

@end
