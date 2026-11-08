#pragma once

#if !defined(__arm64e__)
#error Hoangha RemoteCall must be compiled for arm64e.
#endif

#if !__has_feature(ptrauth_calls)
#error Hoangha requires the Apple arm64e pointer-authentication ABI.
#endif
