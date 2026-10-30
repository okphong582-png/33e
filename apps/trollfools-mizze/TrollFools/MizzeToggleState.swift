import Foundation

struct MizzeInjectionSnapshot {
    let mizzeLoaded: Bool
    let injectedCount: Int
    let persistedCount: Int
    var canRemove: Bool { mizzeLoaded || injectedCount > 0 || persistedCount > 0 }
}

protocol MizzeToggleBackend {
    func inspect() throws -> MizzeInjectionSnapshot
    func enable() throws
    func disableAll() throws
}

enum MizzeToggleError: LocalizedError {
    case missingGame, wrongGame, missingPayload, invalidPayload, notEnabled, notRemoved
    var errorDescription: String? {
        switch self {
        case .missingGame: return "Chưa tìm thấy Free Fire TH trên máy."
        case .wrongGame: return "Ứng dụng đích không đúng com.dts.freefireth."
        case .missingPayload: return "Thiếu Mizze.dylib trong gói ứng dụng."
        case .invalidPayload: return "File Mizze.dylib không khớp bản đã đóng gói."
        case .notEnabled: return "Chưa xác nhận được lệnh nạp Mizze trong game."
        case .notRemoved: return "Vẫn còn plugin hoặc cấu hình lưu; chưa thể báo đã tắt."
        }
    }
}

/// No optimistic preference flag: every transition starts and ends with a disk inspection.
struct MizzeToggleCoordinator {
    let backend: MizzeToggleBackend
    func toggle() throws -> MizzeInjectionSnapshot {
        let initial = try backend.inspect()
        if initial.canRemove {
            try backend.disableAll()
            let final = try backend.inspect()
            guard !final.canRemove else { throw MizzeToggleError.notRemoved }
            return final
        }
        try backend.enable()
        let final = try backend.inspect()
        guard final.mizzeLoaded else { throw MizzeToggleError.notEnabled }
        return final
    }
}
