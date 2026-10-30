import Foundation

final class FakeBackend: MizzeToggleBackend {
    var state = MizzeInjectionSnapshot(mizzeLoaded: false, injectedCount: 0, persistedCount: 0)
    var failInspect = false, failEnable = false, incompleteEnable = false, incompleteRemove = false
    var events: [String] = []
    func inspect() throws -> MizzeInjectionSnapshot {
        events.append("inspect")
        if failInspect { throw MizzeToggleError.missingGame }
        return state
    }
    func enable() throws {
        events.append("enable")
        if failEnable { throw MizzeToggleError.invalidPayload }
        if !incompleteEnable { state = MizzeInjectionSnapshot(mizzeLoaded: true, injectedCount: 1, persistedCount: 0) }
    }
    func disableAll() throws {
        events.append("disableAll")
        state = MizzeInjectionSnapshot(mizzeLoaded: false, injectedCount: 0, persistedCount: incompleteRemove ? 1 : 0)
    }
}

@main struct MizzeToggleTests {
    static func main() throws {
        var checks = 0
        func check(_ value: @autoclosure () -> Bool, _ text: String) {
            precondition(value(), text); checks += 1
        }
        let backend = FakeBackend(), coordinator = MizzeToggleCoordinator(backend: FakeBackend())
        _ = coordinator
        let control = MizzeToggleCoordinator(backend: backend)
        let on = try control.toggle()
        check(on.mizzeLoaded, "enable must be observed")
        check(backend.events == ["inspect", "enable", "inspect"], "inspect before and after changes")
        let off = try control.toggle()
        check(!off.canRemove, "off clears injected and persisted state")
        check(backend.events.suffix(3) == ["inspect", "disableAll", "inspect"], "off calls eject all")
        for _ in 0..<5 { _ = try control.toggle(); _ = try control.toggle() }
        check(!backend.state.canRemove, "repeated toggles stay balanced")

        let missing = FakeBackend(); missing.failInspect = true
        do { _ = try MizzeToggleCoordinator(backend: missing).toggle(); fatalError("missing game accepted") }
        catch { check(missing.events == ["inspect"], "missing game never modifies a target") }
        let bad = FakeBackend(); bad.failEnable = true
        do { _ = try MizzeToggleCoordinator(backend: bad).toggle(); fatalError("bad payload accepted") }
        catch { check(!bad.state.mizzeLoaded, "payload failure does not set a UI preference to ON") }
        let unlinked = FakeBackend(); unlinked.incompleteEnable = true
        do { _ = try MizzeToggleCoordinator(backend: unlinked).toggle(); fatalError("unlinked payload accepted") }
        catch { check(unlinked.events.last == "inspect", "post-injection inspection is mandatory") }
        let remaining = FakeBackend(); remaining.state = on; remaining.incompleteRemove = true
        do { _ = try MizzeToggleCoordinator(backend: remaining).toggle(); fatalError("incomplete removal accepted") }
        catch { check(remaining.state.persistedCount == 1, "persistent leftovers cannot be reported as OFF") }
        let other = FakeBackend(); other.state = MizzeInjectionSnapshot(mizzeLoaded: false, injectedCount: 3, persistedCount: 0)
        _ = try MizzeToggleCoordinator(backend: other).toggle()
        check(other.events.contains("disableAll") && !other.events.contains("enable"), "existing plugins are cleaned before enabling Mizze")
        let persisted = FakeBackend(); persisted.state = MizzeInjectionSnapshot(mizzeLoaded: false, injectedCount: 0, persistedCount: 2)
        _ = try MizzeToggleCoordinator(backend: persisted).toggle()
        check(!persisted.state.canRemove, "OFF also clears saved plugins")
        let root = URL(fileURLWithPath: "/game/Game"),
            framework = URL(fileURLWithPath: "/game/Frameworks/Unity.framework/Unity"),
            payload = URL(fileURLWithPath: "/game/Frameworks/Mizze.dylib")
        var live: [URL: [URL]] = [root: [framework], framework: [payload], payload: []]
        let linked = try MizzeLiveLinks.contains(from: root, target: payload) { live[$0] ?? [] }
        check(linked, "live framework injection is detected even when the original executable backup has no link")
        live[framework] = []
        let unlinkedFile = try MizzeLiveLinks.contains(from: root, target: payload) { live[$0] ?? [] }
        check(!unlinkedFile, "a leftover payload file must not be reported as linked")
        live[framework] = [root]
        let cycle = try MizzeLiveLinks.contains(from: root, target: payload) { live[$0] ?? [] }
        check(!cycle, "dependency cycles terminate")
        live[framework] = [root, payload]
        let cycleWithPayload = try MizzeLiveLinks.contains(from: root, target: payload) { live[$0] ?? [] }
        check(cycleWithPayload, "a cycle does not hide a reachable live payload")
        print("PASS: \(checks) Swift coordinator/live-graph assertions; no device injection during tests")
    }
}
