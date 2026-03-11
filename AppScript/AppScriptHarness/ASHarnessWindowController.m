// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASHarnessWindowController.m — Window controller for the AppScriptHarness test runner UI
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

#import "ASHarnessWindowController.h"
#import "ASTestResult.h"
#import <AppScript/NSBundle+AppScriptLoading.h>

static NSString * const kColumnStatus   = @"status";
static NSString * const kColumnTest     = @"test";
static NSString * const kColumnExpected = @"expected";
static NSString * const kColumnActual   = @"actual";

@interface ASHarnessWindowController () <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) NSButton    *runButton;

/// Ordered test results from the most recent run.
@property (nonatomic, copy) NSArray<ASTestResult *> *results;

/// YES after the bundle's AppScripts have been loaded once.
@property (nonatomic) BOOL scriptsLoaded;

@end

@implementation ASHarnessWindowController

- (instancetype)init {
    // Build the window programmatically — no XIB required.
    NSWindow *window = [[NSWindow alloc]
                        initWithContentRect:NSMakeRect(0, 0, 900, 600)
                                  styleMask:(NSWindowStyleMaskTitled |
                                             NSWindowStyleMaskClosable |
                                             NSWindowStyleMaskResizable |
                                             NSWindowStyleMaskMiniaturizable)
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
    window.title = @"AppScript Integration Tests";
    window.minSize = NSMakeSize(600, 300);

    self = [super initWithWindow:window];
    if (self) {
        _results = @[];
        [self buildUI];
    }
    return self;
}

#pragma mark - UI construction

- (void)buildUI {
    NSView *content = self.window.contentView;

    // --- Run button ---
    NSButton *runBtn = [NSButton buttonWithTitle:@"Run Tests"
                                          target:self
                                          action:@selector(runTests:)];
    runBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:runBtn];
    self.runButton = runBtn;

    // --- Summary label ---
    NSTextField *summary = [NSTextField labelWithString:@"Press \"Run Tests\" to begin."];
    summary.translatesAutoresizingMaskIntoConstraints = NO;
    summary.lineBreakMode = NSLineBreakByTruncatingTail;
    [content addSubview:summary];
    self.summaryLabel = summary;

    // --- Table view ---
    NSTableView *table = [[NSTableView alloc] initWithFrame:NSZeroRect];
    table.usesAlternatingRowBackgroundColors = YES;
    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    table.dataSource = self;
    table.delegate   = self;

    NSTableColumn *statusCol = [[NSTableColumn alloc] initWithIdentifier:kColumnStatus];
    statusCol.title = @"";
    statusCol.width = 28;
    statusCol.minWidth = 28;
    statusCol.maxWidth = 28;
    [table addTableColumn:statusCol];

    NSTableColumn *testCol = [[NSTableColumn alloc] initWithIdentifier:kColumnTest];
    testCol.title = @"Test";
    testCol.width = 200;
    testCol.minWidth = 100;
    [table addTableColumn:testCol];

    NSTableColumn *expectedCol = [[NSTableColumn alloc] initWithIdentifier:kColumnExpected];
    expectedCol.title = @"Expected";
    expectedCol.width = 300;
    expectedCol.minWidth = 100;
    [table addTableColumn:expectedCol];

    NSTableColumn *actualCol = [[NSTableColumn alloc] initWithIdentifier:kColumnActual];
    actualCol.title = @"Actual";
    actualCol.width = 300;
    actualCol.minWidth = 100;
    [table addTableColumn:actualCol];

    self.tableView = table;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.documentView = table;
    [content addSubview:scroll];

    // --- Auto-layout ---
    NSDictionary *views = @{ @"run": runBtn, @"summary": summary, @"scroll": scroll };
    NSDictionary *metrics = @{ @"pad": @12, @"btnPad": @8 };

    [content addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(pad)-[scroll]-(pad)-|"
                                             options:0 metrics:metrics views:views]];
    [content addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(pad)-[summary]-(>=pad)-[run]-(pad)-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:metrics views:views]];
    [content addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(pad)-[scroll]-(btnPad)-[run]-(pad)-|"
                                             options:0 metrics:metrics views:views]];

    [summary setContentHuggingPriority:NSLayoutPriorityDefaultLow
                        forOrientation:NSLayoutConstraintOrientationHorizontal];
}

#pragma mark - Test execution

- (IBAction)runTests:(nullable id)sender {
    self.runButton.enabled = NO;
    self.summaryLabel.stringValue = @"Running…";

    if (!self.scriptsLoaded) {
        NSError *loadError = nil;
        if (![[NSBundle mainBundle] loadAppScriptsInBundle:&loadError]) {
            self.summaryLabel.stringValue =
                [NSString stringWithFormat:@"Failed to load scripts: %@",
                 loadError.localizedDescription];
            self.runButton.enabled = YES;
            return;
        }
        self.scriptsLoaded = YES;
    }

    NSArray<NSURL *> *scriptURLs =
        [[NSBundle mainBundle] URLsForResourcesWithExtension:@"appscript"
                                                subdirectory:@"Scripts"];

    NSMutableArray<ASTestResult *> *results = [NSMutableArray array];

    for (NSURL *scriptURL in scriptURLs) {
        ASTestResult *result = [self runTestAtURL:scriptURL];
        [results addObject:result];
        // Log to stdout so CI captures output.
        fprintf(stdout, "%s: %s\n",
                result.isPassed ? "PASS" : "FAIL",
                result.testName.UTF8String);
    }

    // Sort: failures first, then alphabetically.
    [results sortUsingComparator:^NSComparisonResult(ASTestResult *a, ASTestResult *b) {
        if (a.isPassed != b.isPassed) {
            return a.isPassed ? NSOrderedDescending : NSOrderedAscending;
        }
        return [a.testName compare:b.testName];
    }];

    self.results = results;
    [self.tableView reloadData];

    NSInteger passed = 0;
    for (ASTestResult *r in results) {
        if (r.isPassed) passed++;
    }
    NSInteger failed = (NSInteger)results.count - passed;
    self.summaryLabel.stringValue =
        [NSString stringWithFormat:@"%ld passed, %ld failed", (long)passed, (long)failed];

    self.runButton.enabled = YES;
}

/// Runs a single test script and returns its result.
- (ASTestResult *)runTestAtURL:(NSURL *)scriptURL {
    NSString *baseName = scriptURL.lastPathComponent.stringByDeletingPathExtension;
    NSString *className = [baseName stringByAppendingString:@"Test"];
    NSURL *expectedURL = [[scriptURL URLByDeletingPathExtension]
                          URLByAppendingPathExtension:@"expected"];

    Class cls = NSClassFromString(className);
    if (cls == nil) {
        NSString *msg = [NSString stringWithFormat:@"class %@ not found", className];
        return [[ASTestResult alloc] initWithTestName:baseName
                                               passed:NO
                                             expected:@"(unknown)"
                                               actual:msg];
    }

    id instance = [cls new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id resultObj = [instance performSelector:@selector(runTests)];
#pragma clang diagnostic pop
    NSString *actual = [[resultObj description]
                        stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    NSError *readError = nil;
    NSString *expectedRaw = [NSString stringWithContentsOfURL:expectedURL
                                                     encoding:NSUTF8StringEncoding
                                                        error:&readError];
    if (expectedRaw == nil) {
        NSString *msg = [NSString stringWithFormat:@"cannot read .expected: %@",
                         readError.localizedDescription];
        return [[ASTestResult alloc] initWithTestName:baseName
                                               passed:NO
                                             expected:msg
                                               actual:actual];
    }

    NSString *expected = [expectedRaw
                          stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL passed = [actual isEqualToString:expected];
    return [[ASTestResult alloc] initWithTestName:baseName
                                           passed:passed
                                         expected:expected
                                           actual:actual];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)self.results.count;
}

#pragma mark - NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    ASTestResult *result = self.results[(NSUInteger)row];
    NSString *identifier = tableColumn.identifier;

    NSTextField *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    if (cell == nil) {
        cell = [NSTextField labelWithString:@""];
        cell.identifier = identifier;
        cell.lineBreakMode = NSLineBreakByTruncatingTail;
    }

    if ([identifier isEqualToString:kColumnStatus]) {
        cell.stringValue = result.isPassed ? @"✓" : @"✗";
        cell.textColor = result.isPassed
            ? [NSColor systemGreenColor]
            : [NSColor systemRedColor];
        cell.alignment = NSTextAlignmentCenter;
    } else if ([identifier isEqualToString:kColumnTest]) {
        cell.stringValue = result.testName;
        cell.textColor = [NSColor labelColor];
    } else if ([identifier isEqualToString:kColumnExpected]) {
        cell.stringValue = [result.expected stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        cell.textColor = [NSColor labelColor];
    } else if ([identifier isEqualToString:kColumnActual]) {
        cell.stringValue = [result.actual stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        cell.textColor = result.isPassed
            ? [NSColor labelColor]
            : [NSColor systemRedColor];
    }

    return cell;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return 20.0;
}

@end
