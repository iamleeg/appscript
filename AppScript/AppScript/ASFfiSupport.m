// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ASFfiSupport.m — libffi type mapping shared by C function calls and block wrappers
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
#import "ASFfiSupport.h"

const char *ASFfiSkipQualifiers(const char *p) {
    while (p && (*p == 'r' || *p == 'n' || *p == 'N' || *p == 'o' ||
                 *p == 'O' || *p == 'R' || *p == 'V')) {
        p++;
    }
    return p;
}

ffi_type * _Nullable ASFfiTypeForEncodingCursor(const char **pPtr,
                                                       NSMutableArray<NSValue *> *allocatedStructs) {
    const char *p = ASFfiSkipQualifiers(*pPtr);
    if (!p || *p == '\0') {
        return NULL;
    }

    char c = *p;
    p++;
    *pPtr = p;

    switch (c) {
        case 'v': return &ffi_type_void;
        case 'c': return &ffi_type_schar;
        case 'C': return &ffi_type_uchar;
        case 'B': return &ffi_type_uint8;
        case 's': return &ffi_type_sshort;
        case 'S': return &ffi_type_ushort;
        case 'i': return &ffi_type_sint32;
        case 'I': return &ffi_type_uint32;
        case 'l': return (sizeof(long) == 8) ? &ffi_type_sint64 : &ffi_type_sint32;
        case 'L': return (sizeof(unsigned long) == 8) ? &ffi_type_uint64 : &ffi_type_uint32;
        case 'q': return &ffi_type_sint64;
        case 'Q': return &ffi_type_uint64;
        case 'f': return &ffi_type_float;
        case 'd': return &ffi_type_double;
        case '@':
        case '#':
        case ':':
        case '*': return &ffi_type_pointer;
        case '^': {
            // Advance past the pointed-to type encoding.
            const char *sub = ASFfiSkipQualifiers(*pPtr);
            while (sub && *sub == '^') {
                sub = ASFfiSkipQualifiers(sub + 1);
            }
            if (sub && *sub == '{') {
                int depth = 0;
                while (*sub) {
                    if (*sub == '{') depth++;
                    else if (*sub == '}') {
                        depth--;
                        if (depth == 0) { sub++; break; }
                    }
                    sub++;
                }
            } else if (sub && *sub != '\0' && *sub != '}') {
                sub++;
            }
            *pPtr = sub;
            return &ffi_type_pointer;
        }
        case '{': {
            // Skip struct tag name up to '=' or '}'
            while (**pPtr && **pPtr != '=' && **pPtr != '}') {
                (*pPtr)++;
            }
            if (**pPtr != '=') {
                return NULL;
            }
            (*pPtr)++; // skip '='

            NSMutableArray<NSValue *> *elements = [NSMutableArray array];
            while (**pPtr && **pPtr != '}') {
                // Skip optional quoted field name: "fieldName"
                if (**pPtr == '"') {
                    (*pPtr)++;
                    while (**pPtr && **pPtr != '"') {
                        (*pPtr)++;
                    }
                    if (**pPtr == '"') {
                        (*pPtr)++;
                    }
                }
                if (**pPtr == '}' || **pPtr == '\0') {
                    break;
                }
                ffi_type *fieldType = ASFfiTypeForEncodingCursor(pPtr, allocatedStructs);
                if (!fieldType) {
                    return NULL;
                }
                [elements addObject:[NSValue valueWithPointer:fieldType]];
            }
            if (**pPtr != '}' || elements.count == 0) {
                return NULL;
            }
            (*pPtr)++; // skip '}'

            ffi_type *structType = calloc(1, sizeof(ffi_type));
            ffi_type **elemsArray = calloc(elements.count + 1, sizeof(ffi_type *));
            if (!structType || !elemsArray) {
                free(structType);
                free(elemsArray);
                return NULL;
            }
            for (NSUInteger i = 0; i < elements.count; i++) {
                elemsArray[i] = (ffi_type *)[elements[i] pointerValue];
            }
            elemsArray[elements.count] = NULL;

            structType->size = 0;
            structType->alignment = 0;
            structType->type = FFI_TYPE_STRUCT;
            structType->elements = elemsArray;

            [allocatedStructs addObject:[NSValue valueWithPointer:structType]];
            return structType;
        }
        default:
            return NULL;
    }
}
