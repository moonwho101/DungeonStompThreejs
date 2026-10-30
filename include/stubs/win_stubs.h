#pragma once

#include <cstdint>
#include <cwchar>
#include <cstring>
#include <iostream>

#include "sal.h"

#ifndef _WIN32
#include <unknwn.h>

#ifndef WINAPI
#define WINAPI
#endif

#ifndef HRESULT
typedef int32_t HRESULT;
#define S_OK ((HRESULT)0L)
#define S_FALSE ((HRESULT)1L)
#define E_FAIL ((HRESULT)0x80004005L)
#define E_POINTER ((HRESULT)0x80004003L)
#define E_INVALIDARG ((HRESULT)0x80070057L)
#define FAILED(hr) (((HRESULT)(hr)) < 0)
#define SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)
#endif

#ifndef BYTE
typedef uint8_t BYTE;
#endif

#ifndef WORD
typedef uint16_t WORD;
#endif

#ifndef FLOAT
typedef float FLOAT;
#endif

#ifndef LPCSTR
typedef const char* LPCSTR;
#endif

#ifndef LPCWSTR
typedef const wchar_t* LPCWSTR;
#endif

#ifndef LPWSTR
typedef wchar_t* LPWSTR;
#endif

#ifndef HANDLE
typedef void* HANDLE;
#endif

#endif // !_WIN32
