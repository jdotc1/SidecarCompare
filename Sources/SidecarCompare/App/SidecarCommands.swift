import SwiftUI

struct WorkspaceActions {
    var canGoToPointer: Bool
    var goToPointer: @MainActor () -> Void
    var canRevealA: Bool
    var canRevealB: Bool
    var revealA: @MainActor () -> Void
    var revealB: @MainActor () -> Void
    var resetView: @MainActor () -> Void
    var canReloadA: Bool
    var canReloadB: Bool
    var canReloadBoth: Bool
    var reloadBoth: @MainActor () -> Void
    var reloadA: @MainActor () -> Void
    var reloadB: @MainActor () -> Void
    var canPreviousDifference: Bool
    var canNextDifference: Bool
    var previousDifference: @MainActor () -> Void
    var nextDifference: @MainActor () -> Void
    var canOpen: Bool
    var canSwap: Bool
    var canExport: Bool
    var openA: @MainActor () -> Void
    var openB: @MainActor () -> Void
    var swap: @MainActor () -> Void
    var clear: @MainActor () -> Void
    var example: @MainActor () -> Void
    var export: @MainActor () -> Void
    var copySummary: @MainActor () -> Void
}
struct WorkspaceActionsKey: FocusedValueKey { typealias Value = WorkspaceActions }
extension FocusedValues {
    var workspaceActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

@MainActor
struct SidecarCommands: Commands {
    @FocusedValue(\.workspaceActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Reference Sidecar…") { actions?.openA() }
                .keyboardShortcut("o").disabled(actions?.canOpen != true)
            Button("Open Comparison Sidecar…") { actions?.openB() }
                .keyboardShortcut("o", modifiers: [.command, .shift]).disabled(actions?.canOpen != true)
            Divider()
            Button("Reload A") { actions?.reloadA() }.disabled(actions?.canReloadA != true)
            Button("Reload B") { actions?.reloadB() }.disabled(actions?.canReloadB != true)
            Button("Reload Both") { actions?.reloadBoth() }.disabled(actions?.canReloadBoth != true)
            Button("Reveal A in Finder") { actions?.revealA() }.disabled(actions?.canRevealA != true)
            Button("Reveal B in Finder") { actions?.revealB() }.disabled(actions?.canRevealB != true)
            Divider()
            Button("Load Synthetic Example") { actions?.example() }.disabled(actions?.canOpen != true)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Export Comparison…") { actions?.export() }
                .keyboardShortcut("e").disabled(actions?.canExport != true)
        }
        CommandMenu("Comparison") {
            Button("Go to JSON Pointer…") { actions?.goToPointer() }
                .disabled(actions?.canGoToPointer != true)
            Divider()
            Button("Previous Difference") { actions?.previousDifference() }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(actions?.canPreviousDifference != true)
            Button("Next Difference") { actions?.nextDifference() }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(actions?.canNextDifference != true)
            Divider()
            Button("Swap A and B") { actions?.swap() }
                .keyboardShortcut("s", modifiers: [.command, .option]).disabled(actions?.canSwap != true)
            Button("Reset View") { actions?.resetView() }.disabled(actions?.canOpen != true)
            Button("Clear Comparison") { actions?.clear() }
                .keyboardShortcut("k").disabled(actions?.canOpen != true)
            Divider()
            Button("Copy Summary") { actions?.copySummary() }
                .keyboardShortcut("c", modifiers: [.command, .shift]).disabled(actions?.canExport != true)
        }
    }
}
