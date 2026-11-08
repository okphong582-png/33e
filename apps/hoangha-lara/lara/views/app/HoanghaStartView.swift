import SwiftUI

final class HoanghaOverlayModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var visible = false
    @Published private(set) var message = "Nhấn Start để hiện chữ giữa màn hình."

    func start(using manager: laramgr) {
        guard !busy else { return }
        guard !isunsupported(), !isdebugged() else {
            message = "Thiết bị hoặc cách mở app chưa đáp ứng điều kiện của Lara."
            return
        }
        #if DISABLE_REMOTECALL
        message = "Bản build này đã tắt RemoteCall."
        #else
        guard !manager.dsrunning, !manager.rcrunning else { return }
        busy = true
        message = "Đang chuẩn bị Lara…"
        if manager.dsready {
            prepareOffsets(using: manager)
        } else {
            init_offsets()
            offsets_init()
            manager.run { success in
                if success {
                    self.prepareOffsets(using: manager)
                } else {
                    self.fail("Lara chưa khởi tạo thành công. Xem Logs để biết chi tiết.")
                }
            }
        }
        #endif
    }

    #if !DISABLE_REMOTECALL
    private func prepareOffsets(using manager: laramgr) {
        if manager.hasOffsets {
            prepareSession(using: manager, showing: true)
            return
        }
        message = "Đang chuẩn bị dữ liệu thiết bị…"
        DispatchQueue.global(qos: .userInitiated).async {
            var ready = emergencyfixfunctiontobereplacedlateronquestionmark() || dlkcache()
            if !ready && fetchkcache() {
                ready = dlkcache()
            }
            DispatchQueue.main.async {
                manager.hasOffsets = ready
                if ready {
                    self.prepareSession(using: manager, showing: true)
                } else {
                    self.fail("Chưa lấy được kernelcache. Mở công cụ Lara để kiểm tra rồi thử lại.")
                }
            }
        }
    }

    private func prepareSession(using manager: laramgr, showing: Bool) {
        message = showing ? "Đang kết nối SpringBoard…" : "Đang ẩn chữ…"
        if manager.rcready, let session = manager.sbProc {
            apply(to: session, showing: showing, manager: manager)
            return
        }
        manager.rcinit(process: "SpringBoard", migbypass: false) { success in
            guard success, let session = manager.sbProc else {
                self.fail(manager.rcLastError ?? "Không mở được phiên SpringBoard của Lara.")
                return
            }
            self.apply(to: session, showing: showing, manager: manager)
        }
    }

    private func apply(to session: RemoteCall, showing: Bool, manager: laramgr) {
        DispatchQueue.global(qos: .userInitiated).async {
            let success = showing ? hoangha_overlay_show(session) : hoangha_overlay_hide(session)
            let error = hoangha_overlay_last_error()
            DispatchQueue.main.async {
                self.busy = false
                if success {
                    self.visible = showing
                    self.message = showing ? "Đã hiện hoangha. Bạn có thể về màn hình chính." : "Đã ẩn chữ hoangha."
                    manager.logmsg(showing ? "(hoangha) SpringBoard overlay shown" : "(hoangha) SpringBoard overlay hidden")
                } else {
                    self.message = error.isEmpty ? "SpringBoard chưa hoàn tất yêu cầu." : error
                    manager.logmsg("(hoangha) \(self.message)")
                }
            }
        }
    }
    #endif

    func stop(using manager: laramgr) {
        guard !busy else { return }
        #if !DISABLE_REMOTECALL
        guard manager.dsready, !manager.dsrunning, !manager.rcrunning else {
            message = "Nhấn Start để kết nối lại Lara trước khi ẩn chữ."
            return
        }
        busy = true
        prepareSession(using: manager, showing: false)
        #endif
    }

    private func fail(_ reason: String) {
        busy = false
        message = reason
    }
}

struct HoanghaStartView: View {
    @EnvironmentObject private var manager: laramgr
    @StateObject private var overlay = HoanghaOverlayModel()
    @State private var showTools = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text("hoangha")
                    .font(.system(size: 76, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)

                Text(overlay.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("hoangha.status")

                if overlay.busy {
                    ProgressView()
                        .accessibilityLabel("Đang xử lý")
                }

                Button("Start") {
                    overlay.start(using: manager)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(overlay.busy || manager.dsrunning)
                .accessibilityIdentifier("hoangha.start")

                Button("Stop") {
                    overlay.stop(using: manager)
                }
                .buttonStyle(.bordered)
                .disabled(overlay.busy || !manager.dsready)
                .accessibilityIdentifier("hoangha.stop")
                Spacer()
                Text("Dựa trên Lara")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .navigationTitle("Hoangha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        manager.showLogs = true
                    } label: {
                        Image(systemName: "terminal")
                    }
                    .accessibilityLabel("Logs")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showTools = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .disabled(overlay.busy)
                    .accessibilityLabel("Công cụ Lara")
                }
            }
            .sheet(isPresented: $showTools) {
                ContentView()
                    .environmentObject(manager)
            }
        }
    }
}
