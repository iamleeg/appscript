// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppDelegate.m — AppScriptHarness application delegate implementation
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

#import "AppDelegate.h"
#import "ASHarnessWindowController.h"

@interface AppDelegate ()
@property (nonatomic, strong) ASHarnessWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.windowController = [[ASHarnessWindowController alloc] init];
    [self.windowController showWindow:nil];
    [self.windowController.window center];
    [self.windowController runTests:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
