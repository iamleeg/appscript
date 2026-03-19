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
NEEDS_GUI = no
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
