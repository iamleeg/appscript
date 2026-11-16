// SPDX-License-Identifier: AGPL-3.0-or-later
//
// AppScript.h — Umbrella header for the AppScript framework
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

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double AppScriptVersionNumber;
FOUNDATION_EXPORT const unsigned char AppScriptVersionString[];

#import <AppScript/NSBundle+AppScriptLoading.h>
#import <AppScript/NSURL+AppScriptFileReading.h>
#import <AppScript/NSString+AppScriptRuntime.h>
#import <AppScript/NSNumber+AppScriptBitwise.h>
#import <AppScript/NSNumber+AppScriptControlFlow.h>
#import <AppScript/NSObject+AppScriptControlFlow.h>
#import <AppScript/ASLoader.h>
#import <AppScript/ASUncaughtExceptionHandler.h>
#import <AppScript/ASBridgeSupportStructField.h>
#import <AppScript/ASBridgeSupportStruct.h>
#import <AppScript/ASStructValue.h>
#import <AppScript/ASOutObject.h>
#import <AppScript/ASBridgeSupportBlockSignature.h>
#import <AppScript/ASBlockRegistry.h>
#import <AppScript/ASBlockTrampoline.h>
