// SPDX-License-Identifier: AGPL-3.0-or-later
//
// main.m — AppScriptHarness entry point
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

#import <Cocoa/Cocoa.h>
#import <AppScript/AppScript.h>
#import <AppScript/NSBundle+AppScriptBridgeSupportLoading.h>
#include <dlfcn.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // Load Foundation's BridgeSupport companion dylib so dlsym can find
            // inline functions like NSMakeRect that are compiled into it.
            NSBundle *foundationBundle = [NSBundle bundleWithIdentifier:@"com.apple.Foundation"];
            NSURL *companionURL = [[[foundationBundle resourceURL]
                                     URLByAppendingPathComponent:@"BridgeSupport"]
                                     URLByAppendingPathComponent:@"Foundation.dylib"];
            dlopen([[companionURL path] UTF8String], RTLD_GLOBAL);

            // Install Foundation's BridgeSupport so scripts can call NSMakeRect, NSMakeSize, etc.
            [NSBundle loadBridgeSupportForFramework:@"Foundation"];

            NSError *loadError = nil;
            if (![[NSBundle mainBundle] loadScriptsWithError:&loadError]) {
                NSLog(@"Unable to load app scripts: %@", [loadError localizedDescription]);
                abort();
            }
        });
    }


    return NSApplicationMain(argc, argv);
}
