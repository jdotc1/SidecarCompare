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
    @State private var inspectorWidth: CGFloat = 315
    @State private var inspectorReview = InspectorReviewState()
    @State private var tableRevealRequest = UUID()
    @State private var exportSnapshot: ExportSnapshot?
    @State private var search = ""
    @State private var differencesOnly = true
    @State private var status: DifferenceStatus?
    @State private var sortOrder = [KeyPathComparator(\ComparisonRow.path)]
    @State private var category: FieldCategory?
    @State private var milliseconds = false
    @State private var selection: String?
    @State private var restoringReloadSelection = false
    @State private var reloadSelection: String?
    @State private var reloadSlots: [FileSlot] = []
    @State private var refreshFeedback: String?
    @State private var actionError: String?
    @State private var notification: String?
    @State private var isCopyingRow = false
    @State private var rowCopyMessage: String?
    @State private var isRevealing = false

    init(session: ComparisonSession = ComparisonSession()) {
        _session = State(initialValue: session)
    }

    var body: some View {
        GeometryReader { geometry in
            let maximum = min(640, max(270, geometry.size.width - 858))
            let width = min(inspectorWidth, maximum)
            HStack(spacing: 0) {
                workspaceContent.frame(minWidth: 850, maxWidth: .infinity, maxHeight: .infinity)
                if showInspector {
                    InspectorDivider(width: $inspectorWidth, displayedWidth: width, maximum: maximum)
                    inspector.frame(width: width).frame(maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: showInspector ? 1128 : 850, minHeight: 580)
        .searchable(text: $search, prompt: "Search paths and value previews")
        .toolbar { toolbar }
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
            if !restoringReloadSelection, let selection, !ids.contains(selection) { self.selection = nil }
        }
        .onChange(of: selection) { _, _ in rowCopyMessage = nil; inspectorReview.resetField() }
        .onChange(of: session.a?.id) { _, _ in if !restoringReloadSelection { selection = nil; refreshFeedback = nil; inspectorReview.resetAll() } else { inspectorReview.resetField() }; notification = nil }
        .onChange(of: session.b?.id) { _, _ in if !restoringReloadSelection { selection = nil; refreshFeedback = nil; inspectorReview.resetAll() } else { inspectorReview.resetField() }; notification = nil }
        .onChange(of: session.isBusy || !restoringReloadSelection) { _, waiting in
            guard !waiting else { return }
            finishReload()
        }
    }

    private var workspaceContent: some View {
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
    }
    private var inspector: some View {
        RowInspector(canResetWidth: abs(inspectorWidth - 315) >= 1,
                     resetWidth: { inspectorWidth = 315 },
                     row: selectedRow, revision: [session.a?.id, session.b?.id], position: differencePosition,
                     canPrevious: differenceTarget(forward: false) != nil,
                     canNext: differenceTarget(forward: true) != nil,
                     previous: { navigateDifference(forward: false) },
                     next: { navigateDifference(forward: true) },
                     canShowInTable: selectedRow != nil && canModify && !session.isBusy,
                     showInTable: { tableRevealRequest = UUID() },
                     canCopy: canCopyRow, copyMessage: rowCopyMessage, copy: copyRow, review: inspectorReview)
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
                 open: { choose(slot) }, receive: { receive($0, into: slot) }, cancel: { session.cancel(slot) }, canReload: canReload(slot), reload: { reload(slot) })
            .id(fileWellReset)
            .contextMenu {
                Button("Reveal \(slot.rawValue) in Finder") { reveal(slot) }
                    .disabled(!canReveal(slot))
            }
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
            HStack(spacing: 12) {
            Picker("Status", selection: $status) {
                Text("All statuses").tag(Optional<DifferenceStatus>.none)
                ForEach(DifferenceStatus.allCases, id: \.self) { item in
                    Text("\(item.rawValue) (\(session.comparison?.counts[item] ?? 0))").tag(Optional(item))
                }
            }.frame(width: 200)
            Button("Reset View", action: resetView).disabled(!canModify)
            Spacer(minLength: 0)
            }
            if status != nil || category != nil || !search.isEmpty {
                activeFilterChips
            }
            if let result = session.comparison {
                differenceBreakdown(result)
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
    private var activeFilterChips: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { filterChipButtons }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) { filterChipButtons }
        }
        .buttonStyle(.bordered).controlSize(.small).disabled(!canModify)
    }
    @ViewBuilder private var filterChipButtons: some View {
        if let status {
            filterChip("Status: \(status.rawValue)", help: "Clear status filter") { self.status = nil }
        }
        if let category {
            filterChip("Category: \(category.rawValue)", help: "Clear category filter") { self.category = nil }
        }
        if !search.isEmpty {
            filterChip("Search active", help: "Clear search") { search = "" }
        }
    }
    private func filterChip(_ title: String, help: String, clear: @escaping () -> Void) -> some View {
        Button(action: clear) {
            HStack(spacing: 5) {
                Text(title)
                Image(systemName: "xmark")
            }
        }.help(help)
    }
    private var activeFilterSummary: String {
        var filters = [status?.rawValue ?? (differencesOnly ? "Differences only" : "All rows")]
        if let category { filters.append(category.rawValue) }
        if !search.isEmpty { filters.append("Search active") }
        return filters.joined(separator: " · ")
    }
    private func differenceBreakdown(_ result: Comparison) -> some View {
        let counts = result.counts
        return VStack(alignment: .leading, spacing: 5) {
            Text("View: \(activeFilterSummary) · \(visibleRows.count) of \(result.rows.count) rows shown. Counts below cover the full comparison.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(DifferenceStatus.allCases.filter { $0 != .equal }, id: \.self) { item in
                    Button {
                        status = item
                        differencesOnly = true
                    } label: {
                        HStack(spacing: 4) {
                            if status == item { Image(systemName: "checkmark") }
                            Text("\(item.rawValue) · \(counts[item] ?? 0)")
                                .monospacedDigit()
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.small).disabled(!canModify)
                }
            }
        }
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
                ComparisonTable(rows: visibleRows, revealRequest: tableRevealRequest, milliseconds: milliseconds, canCopy: canCopyRow, copy: copyRow, selection: $selection, sortOrder: $sortOrder)
                    .overlay {
                        if visibleRows.isEmpty {
                            VStack(spacing: 10) {
                                Text("No fields match this view").font(.headline)
                                Text("The comparison contains \(result.rows.count) rows. Clear filters to show them all.")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Clear Filters", action: clearFilters)
                                    .buttonStyle(.borderedProminent).disabled(!canModify)
                                Text("Sort order, time display and comparison rule stay unchanged.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.padding(24).frame(maxWidth: 480)
                        }
                    }
            }
        } else if (session.a == nil) != (session.b == nil) {
            let missing: FileSlot = session.a == nil ? .a : .b
            let missingName = missing == .a ? "reference sidecar A" : "comparison sidecar B"
            let loadedName = missing == .a ? "B · Comparison" : "A · Reference"
            VStack(spacing: 14) {
                ContentUnavailableView("Choose the \(missingName)", systemImage: "doc.badge.plus", description: Text("\(loadedName) is loaded. Add the missing sidecar to compare metadata without modifying either input."))
                if session.error(for: missing) != nil {
                    Text("The last read on this side failed. Choose the file again to restore access or select another JSON sidecar.")
                        .font(.callout).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(missing == .a ? "Choose Reference A…" : "Choose Comparison B…") { choose(missing) }
                    .buttonStyle(.borderedProminent).disabled(!canModify)
                Text("The loaded side remains an in-memory snapshot until you explicitly reload or replace it.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if session.error(for: .a) != nil || session.error(for: .b) != nil {
            ContentUnavailableView("Sidecars unavailable", systemImage: "exclamationmark.triangle",
                                   description: Text("Review the A/B read errors above. Choose each unavailable sidecar again to restore access and compare."))
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
            if let refreshFeedback {
                HStack(alignment: .top, spacing: 8) {
                    Text(refreshFeedback).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Dismiss") { self.refreshFeedback = nil }.buttonStyle(.borderless)
                }
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
            Text(notification ?? "Assumes documented BIDS/dcm2niix units. No inherited metadata, image checks, de-identification, or clinical validation.")
                .foregroundStyle(.secondary)
        }.font(.caption).padding(.horizontal, 16).padding(.vertical, 10)
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button(action: { choose(.a) }) { Label("Open A", systemImage: "folder") }.disabled(!canModify)
            Button(action: { choose(.b) }) { Label("Open B", systemImage: "folder.badge.plus") }.disabled(!canModify)
            Button(action: reloadBoth) { Label("Reload Both", systemImage: "arrow.clockwise") }.disabled(!canReloadBoth)
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
        WorkspaceActions(canRevealA: canReveal(.a), canRevealB: canReveal(.b),
                         revealA: { reveal(.a) }, revealB: { reveal(.b) }, resetView: resetView, canReloadA: canReload(.a), canReloadB: canReload(.b),
                         canReloadBoth: canReloadBoth, reloadBoth: reloadBoth, reloadA: { reload(.a) }, reloadB: { reload(.b) }, canPreviousDifference: differenceTarget(forward: false) != nil,
                         canNextDifference: differenceTarget(forward: true) != nil,
                         previousDifference: { navigateDifference(forward: false) },
                         nextDifference: { navigateDifference(forward: true) }, canOpen: canModify, canSwap: session.canSwap && canModify, canExport: session.comparison != nil && canModify,
                         openA: { choose(.a) }, openB: { choose(.b) }, swap: { session.swap() }, clear: clear,
                         example: example, export: export, copySummary: copySummary)
    }
    private var differencePosition: String {
        guard !session.isBusy, session.comparison != nil else { return "No comparison ready" }
        let differences = visibleRows.filter { $0.status != .equal }
        guard !differences.isEmpty else { return "No differences in this view" }
        if let index = differences.firstIndex(where: { $0.id == selection }) {
            return "Difference \(index + 1) of \(differences.count) in this view"
        }
        if selectedRow?.status == .equal { return "Equal row · \(differences.count) differences in this view" }
        return "\(differences.count) differences in this view · select a row"
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
    private func canReveal(_ slot: FileSlot) -> Bool {
        canModify && !session.isBusy && !isRevealing && session.document(for: slot)?.sourceURL != nil
    }
    private func reveal(_ slot: FileSlot) {
        guard canReveal(slot), let url = session.document(for: slot)?.sourceURL else { return }
        isRevealing = true
        Task { @MainActor in
            defer { isRevealing = false }
            do { try await NativeSourceReveal.reveal(url) }
            catch is CancellationError { }
            catch { actionError = (error as? SidecarError)?.message ?? "The source could not be revealed. Choose it again to restore access." }
        }
    }
    private func canReload(_ slot: FileSlot) -> Bool {
        canModify && !session.isBusy && session.document(for: slot)?.sourceURL != nil
    }
    private var canReloadBoth: Bool { canReload(.a) && canReload(.b) }
    private func reloadBoth() {
        guard canReloadBoth else { return }
        beginReload([.a, .b])
        session.reloadBoth()
    }
    private func reload(_ slot: FileSlot) {
        guard canReload(slot), let url = session.document(for: slot)?.sourceURL else { return }
        beginReload([slot])
        session.load(url, into: slot)
    }
    private func beginReload(_ slots: [FileSlot]) {
        reloadSlots = slots
        reloadSelection = selection
        restoringReloadSelection = true
        refreshFeedback = nil
        notification = nil
        rowCopyMessage = nil
    }
    private func finishReload() {
        let hadSelection = reloadSelection != nil
        selection = visibleRows.first(where: { $0.id == reloadSelection })?.id
        var messages: [String] = []
        if reloadSlots.count == 2 && reloadSlots.allSatisfy({ session.document(for: $0) != nil }) {
            messages.append("Both sidecars refreshed.")
        } else {
            for slot in reloadSlots {
                if session.error(for: slot) != nil {
                    messages.append("\(slot.rawValue) refresh failed.")
                } else if session.document(for: slot) != nil {
                    messages.append("\(slot.rawValue) refreshed.")
                } else {
                    messages.append("\(slot.rawValue) refresh cancelled.")
                }
            }
        }
        if session.comparisonError != nil { messages.append("Comparison could not be completed.") }
        if reloadSlots.contains(where: { session.error(for: $0) != nil }) {
            messages.append("Use Choose on each unavailable side to retry or select another file.")
        }
        if hadSelection {
            if session.comparison != nil {
                messages.append(selection != nil ? "Selected field retained." : "Previously selected field is no longer visible in this view.")
            } else {
                messages.append("Selection cleared; no comparison is available.")
            }
        }
        refreshFeedback = messages.isEmpty ? nil : messages.joined(separator: " ")
        reloadSelection = nil
        reloadSlots = []
        restoringReloadSelection = false
    }
    private func receive(_ url: URL, into slot: FileSlot) {
        guard canModify else { return }
        restoringReloadSelection = false; reloadSelection = nil; reloadSlots = []; refreshFeedback = nil
        session.load(url, into: slot)
    }
    private func choose(_ slot: FileSlot) {
        guard canModify else { return }
        restoringReloadSelection = false; reloadSelection = nil; reloadSlots = []; refreshFeedback = nil
        importSlot = slot; showImporter = true
    }
    private func clearFilters() {
        guard canModify else { return }
        search = ""; category = nil; status = nil; differencesOnly = false
    }
    private func resetView() {
        guard canModify else { return }
        inspectorReview.resetAll()
        reloadSelection = nil
        search = ""; category = nil; status = nil; differencesOnly = true
        milliseconds = false; sortOrder = [KeyPathComparator(\ComparisonRow.path)]
        selection = nil; notification = nil; refreshFeedback = nil
    }
    private func clear() {
        guard canModify else { return }
        inspectorReview.resetAll()
        restoringReloadSelection = false; reloadSelection = nil; reloadSlots = []; refreshFeedback = nil
        session.clear(); fileWellReset = UUID(); selection = nil; notification = nil
    }
    private func example() {
        guard canModify else { return }
        inspectorReview.resetAll()
        restoringReloadSelection = false; reloadSelection = nil; reloadSlots = []; refreshFeedback = nil
        do {
            let pair = try ExampleSidecars.documents()
            session.replace(a: pair.0, b: pair.1)
            search = ""; category = nil; status = nil; differencesOnly = true
        } catch { actionError = "The bundled synthetic example could not be loaded." }
    }
    private func export() {
        guard canModify, let result = session.comparison else { return }
        exportSnapshot = ExportSnapshot(comparison: result, documents: session.sourceDocuments, visibleRowCount: visibleRows.count)
    }
    private var canCopyRow: Bool { canModify && !session.isBusy && !isCopyingRow }
    private func copyRow(_ row: ComparisonRow, _ target: RowCopyTarget) {
        guard canCopyRow else { return }
        if target == .a && row.a == nil || target == .b && row.b == nil { return }
        isCopyingRow = true
        rowCopyMessage = nil
        Task { @MainActor in
            defer { isCopyingRow = false }
            let text = await Task.detached(priority: .userInitiated) { () -> String? in
                switch target {
                case .pointer: return row.path
                case .a: return row.a?.serialized()
                case .b: return row.b?.serialized()
                }
            }.value
            guard let text else { return }
            NSPasteboard.general.clearContents()
            let success = NSPasteboard.general.setString(text, forType: .string)
            let subject = target == .pointer ? "JSON Pointer copied." : "Complete original JSON value copied; it may identify people."
            let feedback = success ? subject + " The system clipboard may be shared with your other devices." : "The clipboard could not be updated."
            rowCopyMessage = feedback
            notification = feedback
        }
    }
    private func copySummary() {
        guard canModify, let result = session.comparison else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(ReportRenderer.text(result, detail: .summary), forType: .string) {
            notification = "Summary copied; no input keys, values, filenames, or paths were included. The system clipboard may be shared with your other devices."
        } else { actionError = "The summary could not be copied." }
    }
}
