import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SidecarCore

@MainActor
struct WorkspaceView: View {
    @State private var session: ComparisonSession
    @State private var fileWellReset = UUID()
    @State private var importSlot = FileSlot.a
    @State private var showImporter = false
    @State private var showPolicy = false
    @State private var showInspector = true
    @State private var exportSnapshot: ExportSnapshot?
    @State private var search = ""
    @State private var differencesOnly = true
    @State private var status: DifferenceStatus?
    @State private var sortOrder = [KeyPathComparator(\ComparisonRow.path)]
    @State private var category: FieldCategory?
    @State private var milliseconds = false
    @State private var selection: String?
    @State private var actionError: String?
    @State private var notification: String?

    init(session: ComparisonSession = ComparisonSession()) {
        _session = State(initialValue: session)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                fileWell(.a)
                fileWell(.b)
            }.padding(16)
            filterBar
            Divider()
            comparisonContent
            Divider()
            footer
        }
        .frame(minWidth: 850, minHeight: 580)
        .searchable(text: $search, prompt: "Search paths and value previews")
        .toolbar { toolbar }
        .inspector(isPresented: $showInspector) { RowInspector(row: selectedRow) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { session.load(url, into: importSlot) }
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { actionError = "The selected file could not be opened." }
            }
        }
        .sheet(item: $exportSnapshot) { ExportSheet(snapshot: $0) }
        .alert("Action could not be completed", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK") { actionError = nil }
        } message: { Text(actionError ?? "") }
        .focusedSceneValue(\.workspaceActions, actions)
        .onChange(of: status) { _, status in
            if status == .equal { differencesOnly = false }
        }
        .onChange(of: differencesOnly) { _, enabled in
            if enabled && status == .equal { status = nil }
        }
        .onChange(of: visibleRows.map(\.id)) { _, ids in
            if let selection, !ids.contains(selection) { self.selection = nil }
        }
        .onChange(of: session.a?.id) { _, _ in selection = nil; notification = nil }
        .onChange(of: session.b?.id) { _, _ in selection = nil; notification = nil }
    }

    private var visibleRows: [ComparisonRow] {
        (session.comparison?.filtered(search: search, differencesOnly: differencesOnly, category: category) ?? [])
            .filter { status == nil || $0.status == status }
            .sorted(using: sortOrder + [KeyPathComparator(\ComparisonRow.id)])
    }
    private var selectedRow: ComparisonRow? {
        guard let selection else { return nil }
        return visibleRows.first { $0.id == selection }
    }
    private func fileWell(_ slot: FileSlot) -> some View {
        FileWell(slot: slot, document: session.document(for: slot), loading: session.isLoading(slot), error: session.error(for: slot),
                 open: { choose(slot) }, receive: { url in if canModify { session.load(url, into: slot) } }, cancel: { session.cancel(slot) })
            .id(fileWellReset)
    }
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 14) {
            Toggle("Differences only", isOn: $differencesOnly).toggleStyle(.checkbox)
            Picker("Category", selection: $category) {
                Text("All categories").tag(Optional<FieldCategory>.none)
                ForEach(FieldCategory.allCases) { Text($0.rawValue).tag(Optional($0)) }
            }.labelsHidden().frame(width: 180).accessibilityLabel("Metadata category")
            Spacer()
            Picker("Time display", selection: $milliseconds) {
                Text("Seconds").tag(false)
                Text("Milliseconds").tag(true)
            }.pickerStyle(.menu).frame(width: 185)
        }
            Picker("Status", selection: $status) {
                Text("All statuses").tag(Optional<DifferenceStatus>.none)
                ForEach(DifferenceStatus.allCases, id: \.self) { item in
                    Text("\(item.rawValue) (\(session.comparison?.counts[item] ?? 0))").tag(Optional(item))
                }
            }.frame(width: 200)
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
    @ViewBuilder private var comparisonContent: some View {
        if session.isBusy {
            VStack(spacing: 12) {
                ProgressView()
                Text(session.isComparing ? "Comparing metadata…" : "Reading sidecar…").foregroundStyle(.secondary)
                Button("Cancel and Clear") { clear() }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = session.comparisonError {
            ContentUnavailableView("Comparison unavailable", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let result = session.comparison {
            if result.rows.isEmpty {
                ContentUnavailableView("Both objects are empty", systemImage: "doc", description: Text("There are no fields to compare. This does not establish metadata completeness."))
            } else {
                ComparisonTable(rows: visibleRows, milliseconds: milliseconds, selection: $selection, sortOrder: $sortOrder)
                    .overlay {
                        if visibleRows.isEmpty {
                            VStack(spacing: 10) {
                                Text("No rows match the current filters.").foregroundStyle(.secondary)
                                Button("Show All Rows") { search = ""; category = nil; status = nil; differencesOnly = false }
                            }
                        }
                    }
            }
        } else {
            VStack(spacing: 14) {
                ContentUnavailableView("Compare two MRI sidecars", systemImage: "doc.text.magnifyingglass", description: Text("Choose a reference and comparison JSON file. Inspect typed differences without modifying either input."))
                Button("Load Synthetic Example", action: example)
                    .buttonStyle(.borderedProminent)
                Text("No image processing, accounts, uploads, or third-party runtime dependencies.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let result = session.comparison {
                    Text("\(visibleRows.count) shown / \(result.rows.count) rows · \(result.differenceCount) differences")
                    if let count = result.counts[.withinTolerance], count > 0 { Text("· \(count) within tolerance") }
                } else { Text("Local, in-memory snapshots") }
                Spacer()
                Text(session.policy.label)
            }
            if session.sameSource {
                Label("A and B were loaded from the same source file; snapshots may have been taken at different times.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }
            Text(notification ?? "Assumes documented BIDS/dcm2niix units. No inherited metadata, image checks, de-identification, or clinical validation.")
                .foregroundStyle(.secondary)
        }.font(.caption).padding(.horizontal, 16).padding(.vertical, 10)
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: { choose(.a) }) { Label("Open A", systemImage: "folder") }.disabled(!canModify)
            Button(action: { choose(.b) }) { Label("Open B", systemImage: "folder.badge.plus") }.disabled(!canModify)
            Button(action: { session.swap() }) { Label("Swap", systemImage: "arrow.left.arrow.right") }.disabled(!session.canSwap || !canModify)
            Button(action: clear) { Label("Clear", systemImage: "xmark.circle") }.disabled(!canModify)
        }
        ToolbarItemGroup {
            Button { navigateDifference(forward: false) } label: { Label("Previous Difference", systemImage: "chevron.up") }
                .disabled(differenceTarget(forward: false) == nil)
            Button { navigateDifference(forward: true) } label: { Label("Next Difference", systemImage: "chevron.down") }
                .disabled(differenceTarget(forward: true) == nil)
            Button { showPolicy = true } label: { Label("Comparison Rule", systemImage: "slider.horizontal.3") }
                .disabled(!canModify)
                .popover(isPresented: $showPolicy) { PolicyEditor(policy: session.policy, apply: { session.setPolicy($0) }) }
            Button(action: export) { Label("Export", systemImage: "square.and.arrow.up") }.disabled(session.comparison == nil || !canModify)
            Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
        }
    }
    private var canModify: Bool { !showImporter && exportSnapshot == nil }
    private var actions: WorkspaceActions {
        WorkspaceActions(canPreviousDifference: differenceTarget(forward: false) != nil,
                         canNextDifference: differenceTarget(forward: true) != nil,
                         previousDifference: { navigateDifference(forward: false) },
                         nextDifference: { navigateDifference(forward: true) }, canOpen: canModify, canSwap: session.canSwap && canModify, canExport: session.comparison != nil && canModify,
                         openA: { choose(.a) }, openB: { choose(.b) }, swap: { session.swap() }, clear: clear,
                         example: example, export: export, copySummary: copySummary)
    }
    private func differenceTarget(forward: Bool) -> String? {
        guard !session.isBusy, canModify else { return nil }
        let rows = visibleRows
        let index = rows.firstIndex { $0.id == selection }
        let candidates = forward ? Array(rows.dropFirst(index.map { $0 + 1 } ?? 0))
            : Array(rows.prefix(index ?? rows.count).reversed())
        return candidates.first { $0.status != .equal }?.id
    }
    private func navigateDifference(forward: Bool) {
        guard let target = differenceTarget(forward: forward) else { return }
        selection = target
        showInspector = true
    }
    private func choose(_ slot: FileSlot) {
        guard canModify else { return }
        importSlot = slot; showImporter = true
    }
    private func clear() {
        guard canModify else { return }
        session.clear(); fileWellReset = UUID(); selection = nil; notification = nil
    }
    private func example() {
        guard canModify else { return }
        do {
            let pair = try ExampleSidecars.documents()
            session.replace(a: pair.0, b: pair.1)
            search = ""; category = nil; status = nil; differencesOnly = true
        } catch { actionError = "The bundled synthetic example could not be loaded." }
    }
    private func export() {
        guard canModify, let result = session.comparison else { return }
        exportSnapshot = ExportSnapshot(comparison: result, documents: session.sourceDocuments)
    }
    private func copySummary() {
        guard canModify, let result = session.comparison else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(ReportRenderer.text(result, detail: .summary), forType: .string) {
            notification = "Summary copied; no input keys, values, filenames, or paths were included. The system clipboard may be shared with your other devices."
        } else { actionError = "The summary could not be copied." }
    }
}
