#pragma once

// SDK 16.5 omits this header. This target only needs the opaque object type
// returned by the supplied libxpf; it does not implement or replace XPC.
@class NSObject;
typedef NSObject *xpc_object_t;
typedef const struct _xpc_type_s *xpc_type_t;
