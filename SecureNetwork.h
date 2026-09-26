#ifndef SECURE_NETWORK_H
#define SECURE_NETWORK_H

#include <string>
#include "KabraxHide.h"
#include <vector>
#include <algorithm>
#include "XorString.h"

namespace AntiCrack {

    // Khóa mã hóa dữ liệu động, thay đổi ngẫu nhiên theo từng phiên bản để gây khó khăn cho việc viết script tự động
    inline std::string GetDynamicSecret() {
        std::string part1 = SECURE_STR(KH_STR("KTIEN"));
        std::string part2 = SECURE_STR(KH_STR("XIOS"));
        std::string part3 = SECURE_STR(KH_STR("2026"));
        return part1 + part2 + part3;
    }

    // Hàm xáo trộn chuỗi (Obfuscation) đa tầng trực tiếp trên bộ nhớ RAM
    // Khiến việc "dump memory" hay "hooking" các hàm string thông thường trả về kết quả sai lệch
    inline std::string ObfuscateData(const std::string& input) {
        std::string output = input;
        std::string secret = GetDynamicSecret();
        size_t secretLen = secret.length();
        
        // Vòng 1: XOR tuần tiến với khóa động
        for (size_t i = 0; i < output.length(); ++i) {
            output[i] ^= secret[i % secretLen];
        }
        
        // Vòng 2: Đảo ngược chuỗi bit để phá vỡ cấu trúc ký tự text tiêu chuẩn
        std::reverse(output.begin(), output.end());
        
        return output;
    }

    // Hàm giải mã dữ liệu thu về từ Server
    inline std::string DeobfuscateData(const std::string& input) {
        std::string output = input;
        // Đảo ngược lại vòng 2
        std::reverse(output.begin(), output.end());
        
        // Khử vòng 1
        std::string secret = GetDynamicSecret();
        size_t secretLen = secret.length();
        for (size_t i = 0; i < output.length(); ++i) {
            output[i] ^= secret[i % secretLen];
        }
        return output;
    }
}

#endif // SECURE_NETWORK_H
