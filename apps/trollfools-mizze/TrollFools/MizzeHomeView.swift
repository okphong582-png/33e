import CryptoKit
import SwiftUI
import UIKit

final class MizzeGameBackend: MizzeToggleBackend {
    static let targetID = "com.dts.freefireth"
    static let payloadHash = "f53124a0e6a3f282d04220c14d3511ab755efb21ef1acd4a0a27efbe4f0e5188"

    private func checkedInjector() throws -> InjectorV3 {
        guard let proxy = LSApplicationProxy(forIdentifier: Self.targetID),
              proxy.applicationIdentifier() == Self.targetID,
              let url = proxy.bundleURL(), FileManager.default.fileExists(atPath: url.path)
        else { throw MizzeToggleError.missingGame }
        let injector = try InjectorV3(url)
        guard injector.appID == Self.targetID else { throw MizzeToggleError.wrongGame }
        if injector.teamID.isEmpty { injector.teamID = proxy.teamID() ?? "0000000000" }
        injector.useWeakReference = true
        return injector
    }

    func inspect() throws -> MizzeInjectionSnapshot {
        let injector = try checkedInjector()
        let injected = injector.injectedAssetURLsInBundle(injector.bundleURL)
        let persisted = injector.persistedAssetURLs(bid: Self.targetID)
        let file = injector.bundleURL.appendingPathComponent("Frameworks/Mizze.dylib")
        var linked = false
        if FileManager.default.fileExists(atPath: file.path) {
            linked = try injector.linkedDylibsRecursivelyOfMachO(injector.executableURL)
                .contains { $0.standardizedFileURL == file.standardizedFileURL }
        }
        return MizzeInjectionSnapshot(mizzeLoaded: linked, injectedCount: injected.count, persistedCount: persisted.count)
    }

    func enable() throws {
        // Inspect the bundled resource before any target-game modification.
        guard let payload = Bundle.main.url(forResource: "MizzePayload", withExtension: "zip")
        else { throw MizzeToggleError.missingPayload }
        let bytes = try Data(contentsOf: payload)
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        guard hash == Self.payloadHash else { throw MizzeToggleError.invalidPayload }
        let injector = try checkedInjector()
        try injector.inject([payload], shouldPersist: false)
    }

    func disableAll() throws {
        let injector = try checkedInjector()
        // Existing TrollFools restoration path; never blanket-delete Frameworks.
        try injector.ejectAll(shouldDesist: true)
    }
}

final class MizzeHomeModel: ObservableObject {
    @Published private(set) var snapshot: MizzeInjectionSnapshot?
    @Published private(set) var busy = false
    @Published private(set) var available = false
    @Published private(set) var message = "Đang kiểm tra Free Fire TH…"
    @Published var failure: String?
    private let backend = MizzeGameBackend()
    private let work = DispatchQueue(label: "mizze.freefire.toggle", qos: .userInitiated)

    var removesPlugins: Bool { snapshot?.canRemove == true }
    var title: String { removesPlugins ? "Tắt" : "Bật" }

    func refresh() {
        guard !busy else { return }
        perform(change: false)
    }
    func toggle() {
        guard !busy && available else { return }
        perform(change: true)
    }
    private func perform(change: Bool) {
        busy = true
        if change { message = removesPlugins ? "Đang gỡ plugin…" : "Đang tiêm Mizze…" }
        work.async { [self] in
            do {
                let next: MizzeInjectionSnapshot
                if change { next = try MizzeToggleCoordinator(backend: backend).toggle() }
                else { next = try backend.inspect() }
                DispatchQueue.main.async { [self] in
                    snapshot = next; available = true; busy = false
                    if next.mizzeLoaded { message = "Mizze đã bật · Mở lại game để sử dụng" }
                    else if next.canRemove { message = "Phát hiện plugin · Bấm Tắt để gỡ" }
                    else { message = change ? "Đã tắt · Đã gỡ các plugin được quản lý" : "Sẵn sàng" }
                }
            } catch {
                let observed = try? backend.inspect()
                let text = error.localizedDescription
                DispatchQueue.main.async { [self] in
                    snapshot = observed; available = observed != nil; busy = false; message = text
                    if change { failure = text }
                }
            }
        }
    }
}

struct MizzeHomeView: View {
    @StateObject private var model = MizzeHomeModel()
    private let mint = Color(red: 0.30, green: 0.88, blue: 0.70)
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.055, green: 0.11, blue: 0.14), Color(red: 0.025, green: 0.045, blue: 0.065)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                logo
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(mint.opacity(0.45), lineWidth: 1))
                    .shadow(color: mint.opacity(0.12), radius: 25)
                Text("MIZZE").font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(6).padding(.top, 22)
                Text("FREE FIRE TH").font(.system(size: 12, weight: .medium))
                    .tracking(3).foregroundColor(mint).padding(.top, 8)
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        Circle().fill(model.snapshot?.mizzeLoaded == true ? mint : Color.gray).frame(width: 7, height: 7)
                        Text(model.message).font(.system(size: 14)).multilineTextAlignment(.center)
                    }.foregroundColor(Color.white.opacity(0.8)).frame(minHeight: 44)
                    Button(action: model.toggle) {
                        HStack(spacing: 12) {
                            if model.busy { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            else { Image(systemName: "power").font(.system(size: 23, weight: .semibold)) }
                            Text(model.busy ? "Đang xử lý…" : model.title).font(.system(size: 22, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).frame(height: 72)
                        .background(RoundedRectangle(cornerRadius: 22).fill(model.removesPlugins ? Color(red: 0.60, green: 0.21, blue: 0.25) : Color(red: 0.08, green: 0.44, blue: 0.36)))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .opacity(model.available || model.busy ? 1 : 0.45)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(model.busy || !model.available)
                    .accessibilityLabel(model.title + " Mizze")
                }
                .padding(24).background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .padding(.top, 38)
                Spacer(minLength: 24)
                Text("com.dts.freefireth").font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.35)).padding(.bottom, 24)
            }
            .padding(.horizontal, 26).frame(maxWidth: 440)
        }
        .foregroundColor(.white).preferredColorScheme(.dark)
        .onAppear(perform: model.refresh)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in model.refresh() }
        .alert(isPresented: Binding(get: { model.failure != nil }, set: { if !$0 { model.failure = nil } })) {
            Alert(title: Text("Chưa hoàn tất"), message: Text(model.failure ?? ""), dismissButton: .default(Text("Đóng")))
        }
    }
    @ViewBuilder private var logo: some View {
        if let path = Bundle.main.path(forResource: "MizzeLogo", ofType: "jpg"), let image = UIImage(contentsOfFile: path) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack { Color.black; Text("M").font(.system(size: 64, weight: .black, design: .rounded)) }
        }
    }
}
