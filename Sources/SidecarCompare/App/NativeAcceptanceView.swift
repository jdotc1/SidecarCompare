#if DEBUG
import Foundation
import Observation
import SwiftUI
import SidecarCore

/// Opt-in local developer route, absent from release and normal launch.
/// Uses the actual workspace, drop destinations, source reader and session.
@MainActor
struct NativeAcceptanceView: View {
    @State private var controller = NativeAcceptanceController()
    @State private var darkAppearance = false

    var body: some View {
        @Bindable var gate = controller.gate
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Native acceptance · synthetic sources only").font(.headline)
                    Spacer()
                    Toggle("Hold imports until released", isOn: $gate.holdImports)
                    Button("Release held imports") { gate.releaseAll() }
                        .disabled(gate.heldCount == 0)
                }
                HStack {
                    Button("Hold next comparison") { controller.comparisonGate.arm() }
                    Button("Release comparison") { controller.comparisonGate.release() }
                    Text(controller.comparisonGate.status).font(.caption)
                }
                .task {
                    while !Task.isCancelled {
                        controller.comparisonGate.refresh()
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
                HStack {
                    Button("Hold next export") { controller.exportGate.arm() }
                    Button("Release export") { controller.exportGate.release() }
                    Text("Export held: \(controller.exportGate.held ? "yes" : "no")").font(.caption)
                    Spacer()
                    Toggle("Dark acceptance appearance", isOn: $darkAppearance)
                }
                Text("Drag one synthetic URL below into a real file well.")
                    .font(.caption)
                HStack(spacing: 24) {
                    ForEach(controller.sources, id: \.self) { url in
                        Label(url.lastPathComponent, systemImage: url.hasDirectoryPath ? "folder" : "doc")
                            .frame(width: 150, height: 60)
                            .background(.quaternary)
                            .onDrag {
                                gate.providerRequests += 1
                                return NSItemProvider(object: url as NSURL)
                            }
                    }
                }.frame(height: 100)
                Text("Drag providers requested: \(gate.providerRequests) · Held imports: \(gate.heldCount) · Released completions: \(gate.releasedCount) · Late completion was cancelled: \(gate.lastCompletionWasCancelled ? "yes" : "no")")
                    .font(.caption)
            }.frame(height: 280).padding(12)
            Divider()
            WorkspaceView(session: controller.session)
        }.frame(minHeight: 940)
            .environment(\.nativeAcceptanceExportGate, controller.exportGate)
            .preferredColorScheme(darkAppearance ? .dark : .light)
    }
}

@MainActor
private final class NativeAcceptanceController {
    let gate: HeldImportGate
    let session: ComparisonSession
    let sources: [URL]
    let comparisonGate = ComparisonGate()
    let exportGate = NativeAcceptanceExportGate()

    init() {
        let gate = HeldImportGate()
        self.gate = gate
        self.session = ComparisonSession(loader: { try await gate.load($0) })
        let comparisonGate = self.comparisonGate
        session.acceptanceComparisonCheckpoint = { comparisonGate.checkpoint() }
        let root = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/NativeAcceptance", isDirectory: true)
        sources = [root.appendingPathComponent("A.json"), root.appendingPathComponent("B.json"),
                   root.appendingPathComponent("Folder", isDirectory: true)]
    }
}

/// Deliberately ignores cancellation at the barrier, like ControlledLoader in
/// SessionTests, so releasing it tests the production generation/cancel guards.
@Observable @MainActor
private final class HeldImportGate {
    var holdImports = false
    var providerRequests = 0
    private(set) var heldCount = 0
    private(set) var releasedCount = 0
    private(set) var lastCompletionWasCancelled = false
    @ObservationIgnored private var pending: [CheckedContinuation<Void, Never>] = []

    func load(_ url: URL) async throws -> SidecarDocument {
        let document = try await SidecarReader.load(url)
        if holdImports {
            await withCheckedContinuation { continuation in
                pending.append(continuation)
                heldCount = pending.count
            }
            releasedCount += 1
            lastCompletionWasCancelled = Task.isCancelled
        }
        return document
    }

    func releaseAll() {
        let continuations = pending
        pending.removeAll()
        heldCount = 0
        for continuation in continuations { continuation.resume() }
    }
}
#endif

#if DEBUG
/// One bounded worker checkpoint inside Comparator.visit, before its real
/// cancellation check. NSCondition protects the cross-thread gate state.
@Observable @MainActor
private final class ComparisonGate: Sendable {
    var status = "Comparison checkpoint idle"
    private let state = ComparisonGateState()
    func arm() { state.arm(); refresh() }
    func release() { state.release(); refresh() }
    func refresh() { status = state.description }
    nonisolated func checkpoint() { state.checkpoint() }
}
private final class ComparisonGateState: @unchecked Sendable {
    private let condition = NSCondition()
    private var armed = false
    private var held = false
    private var cancelled = false
    private var completed = false
    var description: String {
        condition.lock(); defer { condition.unlock() }
        return "Comparison checkpoint: armed=\(armed), held=\(held), released=\(completed), cancelled=\(cancelled)"
    }
    func arm() {
        condition.lock(); defer { condition.unlock() }
        armed = true; completed = false; cancelled = false
    }
    func release() {
        condition.lock(); defer { condition.unlock() }
        held = false; condition.broadcast()
    }
    func checkpoint() {
        condition.lock(); defer { condition.unlock() }
        guard armed else { return }
        armed = false; held = true
        // Timeout prevents an abandoned developer check retaining a worker forever.
        let deadline = Date().addingTimeInterval(120)
        while held {
            if !condition.wait(until: deadline) { held = false }
        }
        cancelled = Task.isCancelled; completed = true
    }
}
#endif

#if DEBUG
/// A stable, opt-in environment reference; normal sessions use nil.
private struct NativeAcceptanceExportGateKey: EnvironmentKey {
    static let defaultValue: NativeAcceptanceExportGate? = nil
}
extension EnvironmentValues {
    var nativeAcceptanceExportGate: NativeAcceptanceExportGate? {
        get { self[NativeAcceptanceExportGateKey.self] }
        set { self[NativeAcceptanceExportGateKey.self] = newValue }
    }
}
@Observable @MainActor
final class NativeAcceptanceExportGate {
    private var armed = false
    private(set) var held = false
    @ObservationIgnored private var pending: CheckedContinuation<Void, Never>?
    func arm() { armed = true }
    func holdIfArmed() async {
        guard armed else { return }
        armed = false
        held = true
        await withCheckedContinuation { pending = $0 }
        held = false
    }
    func release() {
        pending?.resume()
        pending = nil
    }
}
#endif
