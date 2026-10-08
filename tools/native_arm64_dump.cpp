#include <windows.h>
#include <capstone/capstone.h>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

// Read-only disassembly helper. Load the supplied Capstone DLL without adding
// a build dependency to the menu or requiring a working Python installation.
int main(int argc, char **argv) {
    if (argc != 4) return 2; // DLL, hex code, starting RVA
    HMODULE dll = LoadLibraryA(argv[1]);
    if (!dll) return 3;
    auto open = reinterpret_cast<decltype(&cs_open)>(GetProcAddress(dll, "cs_open"));
    auto disasm = reinterpret_cast<decltype(&cs_disasm)>(GetProcAddress(dll, "cs_disasm"));
    auto release = reinterpret_cast<decltype(&cs_free)>(GetProcAddress(dll, "cs_free"));
    auto close = reinterpret_cast<decltype(&cs_close)>(GetProcAddress(dll, "cs_close"));
    if (!open || !disasm || !release || !close) return 4;
    std::vector<uint8_t> code;
    const std::string hex(argv[2]);
    if (hex.size() % 2) return 5;
    for (size_t i = 0; i < hex.size(); i += 2) {
        const std::string byte = hex.substr(i, 2);
        char *end = nullptr;
        const unsigned long parsed = std::strtoul(byte.c_str(), &end, 16);
        if (!end || *end) return 5;
        code.push_back(static_cast<uint8_t>(parsed));
    }
    csh handle = 0;
    if (open(CS_ARCH_ARM64, CS_MODE_ARM, &handle) != CS_ERR_OK) return 6;
    cs_insn *instructions = nullptr;
    const size_t count = disasm(handle, code.data(), code.size(), std::strtoull(argv[3], nullptr, 0), 0, &instructions);
    for (size_t i = 0; i < count; ++i) {
        const cs_insn &in = instructions[i];
        std::cout << std::hex << in.address << '\t' << in.mnemonic << '\t' << in.op_str << '\n';
    }
    release(instructions, count);
    close(&handle);
    FreeLibrary(dll);
    return count * 4 == code.size() ? 0 : 7;
}
