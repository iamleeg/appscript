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

static NSString * const kColumnStatus   = @"status";
static NSString * const kColumnTest     = @"test";
static NSString * const kColumnExpected = @"expected";
static NSString * const kColumnActual   = @"actual";

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
    // Subclasses (e.g. the AppScript implementation) override this to run the tests.
}

@end
