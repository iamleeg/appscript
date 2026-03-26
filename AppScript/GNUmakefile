# SPDX-License-Identifier: AGPL-3.0-or-later
#
# GNUmakefile — GNUstep build file for the AppScript framework
# Copyright (C) 2026 Graham Lee
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

include $(GNUSTEP_MAKEFILES)/common.make

FRAMEWORK_NAME = AppScript
AppScript_NEEDS_GUI = no
ADDITIONAL_OBJCFLAGS = -fobjc-arc

AppScript_OBJC_FILES = \
	AppScript/ASArrayLiteralNode.m \
	AppScript/ASAssignmentNode.m \
	AppScript/ASASTNode.m \
	AppScript/ASBlockLiteralNode.m \
	AppScript/ASBoxer.m \
	AppScript/ASBridgeSupportConstant.m \
	AppScript/ASBridgeSupportDocument.m \
	AppScript/ASBridgeSupportEnumeration.m \
	AppScript/ASBridgeSupportFunction.m \
	AppScript/ASBridgeSupportInstaller.m \
	AppScript/ASBridgeSupportParser.m \
	AppScript/ASBridgeSupportStruct.m \
	AppScript/ASBridgeSupportStructField.m \
	AppScript/ASStructValue.m \
	AppScript/ASCategoryDefinitionNode.m \
	AppScript/ASClassDefinitionNode.m \
	AppScript/ASDictionaryLiteralNode.m \
	AppScript/ASIdentifierNode.m \
	AppScript/ASInterpreter.m \
	AppScript/ASLexer.m \
	AppScript/ASLoader.m \
	AppScript/ASMessageSendNode.m \
	AppScript/ASMethodNode.m \
	AppScript/ASNull.m \
	AppScript/ASNumberLiteralNode.m \
	AppScript/ASParser.m \
	AppScript/ASPropertyNode.m \
	AppScript/ASReturnNode.m \
	AppScript/ASRuntimeInstaller.m \
	AppScript/ASScope.m \
	AppScript/ASStringLiteralNode.m \
	AppScript/ASSuperNode.m \
	AppScript/ASToken.m \
	AppScript/ASUncaughtExceptionHandler.m \
	AppScript/ASVariableDeclarationNode.m \
	AppScript/NSArray+AppScriptBlocks.m \
	AppScript/NSBundle+AppScriptBridgeSupportLoading.m \
	AppScript/NSBundle+AppScriptLoading.m \
	AppScript/NSNumber+AppScriptArithmetic.m \
	AppScript/NSNumber+AppScriptBitwise.m \
	AppScript/NSNumber+AppScriptControlFlow.m \
	AppScript/NSNumber+AppScriptLogic.m \
	AppScript/NSObject+AppScriptControlFlow.m \
	AppScript/NSString+AppScriptRuntime.m \
	AppScript/NSURL+AppScriptFileReading.m

AppScript_HEADER_FILES_DIR = AppScript

AppScript_HEADER_FILES = \
	AppScript.h \
	ASArrayLiteralNode.h \
	ASAssignmentNode.h \
	ASASTNode.h \
	ASBlockLiteralNode.h \
	ASBoxer.h \
	ASBridgeSupportConstant.h \
	ASBridgeSupportDocument.h \
	ASBridgeSupportEnumeration.h \
	ASBridgeSupportFunction.h \
	ASBridgeSupportInstaller.h \
	ASBridgeSupportParser.h \
	ASBridgeSupportStruct.h \
	ASBridgeSupportStructField.h \
	ASStructValue.h \
	ASCategoryDefinitionNode.h \
	ASClassDefinitionNode.h \
	ASDictionaryLiteralNode.h \
	ASIdentifierNode.h \
	ASInterpreter.h \
	ASLexer.h \
	ASLoader.h \
	ASMessageSendNode.h \
	ASMethodNode.h \
	ASNull.h \
	ASNumberLiteralNode.h \
	ASParser.h \
	ASPropertyNode.h \
	ASReturnNode.h \
	ASRuntimeInstaller.h \
	ASScope.h \
	ASUncaughtExceptionHandler.h \
	ASStringLiteralNode.h \
	ASSuperNode.h \
	ASToken.h \
	ASVariableDeclarationNode.h \
	NSArray+AppScriptBlocks.h \
	NSBundle+AppScriptBridgeSupportLoading.h \
	NSBundle+AppScriptLoading.h \
	NSNumber+AppScriptArithmetic.h \
	NSNumber+AppScriptBitwise.h \
	NSNumber+AppScriptControlFlow.h \
	NSNumber+AppScriptLogic.h \
	NSObject+AppScriptControlFlow.h \
	NSString+AppScriptRuntime.h \
	NSURL+AppScriptFileReading.h

include $(GNUSTEP_MAKEFILES)/framework.make

# ---------------------------------------------------------------------------
# Test bundle target
# ---------------------------------------------------------------------------

BUNDLE_NAME = AppScriptTests

AppScriptTests_OBJC_FILES = \
	AppScriptTests/ASASTNodeTests.m \
	AppScriptTests/ASBoxerTests.m \
	AppScriptTests/ASBridgeSupportInstallerTests.m \
	AppScriptTests/ASBridgeSupportParserTests.m \
	AppScriptTests/ASBridgeSupportStructTests.m \
	AppScriptTests/ASStructValueTests.m \
	AppScriptTests/ASInterpreterTests.m \
	AppScriptTests/ASLexerTests.m \
	AppScriptTests/ASLoaderTests.m \
	AppScriptTests/ASParserStringEscapeTests.m \
	AppScriptTests/ASParserTests.m \
	AppScriptTests/ASRuntimeInstallerTests.m \
	AppScriptTests/ASUncaughtExceptionHandlerTests.m \
	AppScriptTests/NSBundle_AppScriptBridgeSupportLoadingTests.m \
	AppScriptTests/NSBundle_AppScriptLoadingTests.m \
	AppScriptTests/NSNumber_AppScriptArithmeticTests.m \
	AppScriptTests/NSNumber_AppScriptBitwiseTests.m \
	AppScriptTests/NSNumber_AppScriptControlFlowTests.m \
	AppScriptTests/NSNumber_AppScriptLogicTests.m \
	AppScriptTests/NSObject_AppScriptControlFlowTests.m \
	AppScriptTests/NSString_AppScriptRuntimeTests.m \
	AppScriptTests/NSURL_AppScriptFileReadingTests.m

AppScriptTests_OBJCFLAGS = -fobjc-arc

AppScriptTests_BUNDLE_LIBS = \
	-lXCTest \
	-framework AppScript

AppScriptTests_LIB_DIRS = \
	-L/usr/local/lib \
	-F$(GNUSTEP_BUILD_DIR)

ADDITIONAL_BUNDLE_LIBS = $(AppScriptTests_BUNDLE_LIBS)
ADDITIONAL_LIB_DIRS    = $(AppScriptTests_LIB_DIRS)
ADDITIONAL_INCLUDE_DIRS = -I/usr/local/include

include $(GNUSTEP_MAKEFILES)/bundle.make

# ---------------------------------------------------------------------------
# check target — build the test bundle then run xctest against it
# ---------------------------------------------------------------------------

internal-check:: $(GNUSTEP_BUILD_DIR)/AppScriptTests.bundle
	DYLD_LIBRARY_PATH=/usr/local/lib:$(DYLD_LIBRARY_PATH) \
	/usr/local/bin/xctest $(GNUSTEP_BUILD_DIR)/AppScriptTests.bundle

$(GNUSTEP_BUILD_DIR)/AppScriptTests.bundle: all

# ---------------------------------------------------------------------------
# AppScriptHarness application target
# ---------------------------------------------------------------------------

APP_NAME = AppScriptHarness
AppScriptHarness_NEEDS_GUI = yes
AppScriptHarness_MAIN_MODEL_FILE = MainMenu.nib

AppScriptHarness_OBJC_FILES = \
	AppScriptHarness/main.m

AppScriptHarness_RESOURCE_FILES_DIR = AppScriptHarness/Scripts
AppScriptHarness_RESOURCE_FILES = \
	$(notdir $(wildcard AppScriptHarness/Scripts/*.appscript)) \
	$(notdir $(wildcard AppScriptHarness/Scripts/*.expected)) \
	$(notdir $(wildcard AppScriptHarness/Scripts/*.bridgesupport))

AppScriptHarness_LDFLAGS = \
	-F$(GNUSTEP_BUILD_DIR) \
	-framework AppScript \
	-Wl,-headerpad_max_install_names

include $(GNUSTEP_MAKEFILES)/application.make

# ---------------------------------------------------------------------------
# Post-build steps for AppScriptHarness.app:
#   1. Compile MainMenu.xib → MainMenu.nib  (macOS/ibtool only; skipped on Linux)
#   2. Embed AppScript.framework in Contents/Frameworks/ and fix the binary's
#      load command so the app is self-contained and launchable from anywhere.
# ---------------------------------------------------------------------------

IBTOOL          := $(shell xcrun --find ibtool 2>/dev/null)
INSTALL_NAME_TOOL := install_name_tool
HARNESS_APP     = $(GNUSTEP_BUILD_DIR)/AppScriptHarness.app
HARNESS_BINARY  = $(HARNESS_APP)/Contents/MacOS/AppScriptHarness
HARNESS_FW_DIR  = $(HARNESS_APP)/Contents/Frameworks
EMBEDDED_FW     = $(HARNESS_FW_DIR)/AppScript.framework/AppScript
FW_RPATH_NAME   = @executable_path/../Frameworks/AppScript.framework/AppScript

after-AppScriptHarness-all::
ifneq ($(IBTOOL),)
	$(IBTOOL) --compile $(HARNESS_APP)/Contents/Resources/MainMenu.nib \
		AppScriptHarness/Base.lproj/MainMenu.xib
endif
	$(MKDIRS) $(HARNESS_FW_DIR)
	$(INSTALL) -d $(HARNESS_FW_DIR)
	cp -Rf $(GNUSTEP_BUILD_DIR)/AppScript.framework $(HARNESS_FW_DIR)/
	$(INSTALL_NAME_TOOL) -change AppScript.framework/AppScript \
		$(FW_RPATH_NAME) $(HARNESS_BINARY)
	$(INSTALL_NAME_TOOL) -change libgnustep-baseadd.1.31.dylib \
		/usr/local/lib/libgnustep-baseadd.1.31.dylib $(HARNESS_BINARY) 2>/dev/null || true
	rm -f $(HARNESS_APP)/Contents/stamp.make
	codesign --sign - --force $(HARNESS_APP)
