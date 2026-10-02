#include "../obfuscation/VDataStore.h"
uint64_t fixture_encoded() { return _vdata_::vd_encrypt_u64(0x123456789ABCDEF0ULL, 77); }
uint64_t fixture_seed() { return _obf_::BuildSeed; }
