// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppDelegate.m — Minimal ObjC stub for AppScriptHarness application delegate.
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

// The application startup logic lives in Scripts/AppDelegate.appscript.
// This stub retains only applicationShouldTerminateAfterLastWindowClosed: in
// Objective-C because NSApplicationDelegate declares it as returning BOOL, a
// primitive type that AppScript cannot guarantee to return with the correct
// type encoding.

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, strong) id windowController;
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
