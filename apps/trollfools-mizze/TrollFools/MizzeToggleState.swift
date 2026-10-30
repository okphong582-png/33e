import Foundation

enum MizzeLiveLinks {
    /// Follow current on-disk images. An existing payload file by itself is
    /// insufficient; it must be reachable from the live executable graph.
    static func contains(from root: URL, target: URL,
                         linkedFiles: (URL) throws -> [URL]) throws -> Bool {
        let wanted = target.standardizedFileURL
        var pending = [root.standardizedFileURL], visited = Set<URL>()
        while let file = pending.popLast() {
            if !visited.insert(file).inserted { continue }
            if file == wanted { return true }
            if visited.count > 1024 { throw CocoaError(.fileReadTooLarge) }
            pending.append(contentsOf: try linkedFiles(file).map { $0.standardizedFileURL })
        }
        return false
    }
}

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
