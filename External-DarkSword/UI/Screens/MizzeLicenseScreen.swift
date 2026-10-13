import Combine
import SwiftUI

final class MizzeLicenseModel: ObservableObject {
    @Published private(set) var authorized = false
    @Published private(set) var busy = false
    @Published var key = ""
    @Published private(set) var message = "Nhập key iOSViet để tiếp tục."

    init() {
        // Each app launch starts at the key screen; retain only device identity.
        LicenseSession.shared().logout()
    }

    func login() {
        guard !busy else { return }
        busy = true
        message = "Đang xác thực…"
        LicenseSession.shared().login(withKey: key) { [weak self] ok, message in
            guard let self else { return }
            self.busy = false
            self.message = message ?? "Không xác thực được key."
            self.authorized = ok && LicenseSession.shared().authorized
            if self.authorized {
                self.key = ""
                LicenseSession.shared().monitor()
            }
        }
    }

    func synchronize() {
        authorized = LicenseSession.shared().authorized
        if !authorized { message = LicenseSession.shared().lastMessage ?? "Vui lòng nhập key." }
    }

    func foreground() {
        guard authorized else { return }
        LicenseSession.shared().refresh { [weak self] _, _ in self?.synchronize() }
    }
}

struct MizzeRootView: View {
    @ObservedObject var manager: DarkSwordManager
    @StateObject private var license = MizzeLicenseModel()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if license.authorized { ContentView(manager: manager) }
            else { MizzeLicenseScreen(license: license) }
        }
        .preferredColorScheme(.light)
        .onReceive(timer) { _ in
            if license.authorized && !LicenseSession.shared().authorized { license.synchronize() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LicenseSessionDidBecomeUnauthorizedNotification")).receive(on: DispatchQueue.main)) { _ in
            license.synchronize()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            license.foreground()
        }
        .onChange(of: license.authorized) { _, authorized in
            if authorized { manager.restoreLicensedSession() }
            else { manager.lockForLicenseExpiry() }
        }
    }
}

struct MizzeLicenseScreen: View {
    @ObservedObject var license: MizzeLicenseModel

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Image("MizzeLogo")
                        .resizable().scaledToFit()
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
                    Text("Mizze").font(.system(size: 38, weight: .bold, design: .rounded))
                    Text("Một key. Bắt đầu.")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    SecureField("Nhập key iOSViet", text: $license.key)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(18)
                        .background(Color(white: 0.965), in: RoundedRectangle(cornerRadius: 16))
                        .onSubmit { license.login() }
                        .disabled(license.busy)
                    Button(action: license.login) {
                        Group {
                            if license.busy { ProgressView().tint(.white) }
                            else { Text("Tiếp tục").font(.system(size: 17, weight: .semibold)) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(license.busy || license.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(license.busy ? 0.7 : 1)
                    Text(license.message)
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("license-message")
                }
                .padding(28).frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
                .padding(.top, 70)
            }
        }
    }
}
