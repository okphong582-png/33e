#pragma once
#include <mach/machine.h>

// CPU-family identifiers missing from SDK 16.5, as declared by Apple XNU
// and LLVM's SDK compatibility table. These do not change Lara's offsets.
// https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/machine.h
// https://github.com/llvm/llvm-project/blob/main/llvm/lib/TargetParser/Host.cpp
#ifndef CPUFAMILY_ARM_COLL
#define CPUFAMILY_ARM_COLL 0x2876f5b5
#endif
#ifndef CPUFAMILY_ARM_IBIZA
#define CPUFAMILY_ARM_IBIZA 0xfa33415e
#endif
#ifndef CPUFAMILY_ARM_DONAN
#define CPUFAMILY_ARM_DONAN 0x6f5129ac
#endif
#ifndef CPUFAMILY_ARM_TAHITI
#define CPUFAMILY_ARM_TAHITI 0x75d4acb9
#endif
#ifndef CPUFAMILY_ARM_TUPAI
#define CPUFAMILY_ARM_TUPAI 0x204526d0
#endif
