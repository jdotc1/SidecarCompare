import AppKit
import SwiftUI
import SidecarCore

struct PinnedExportField: Identifiable {
    let id: String
    let pointer: String
    let status: DifferenceStatus
    let hidden: Bool
}

struct ExportInspectorRequest {
    let id: String
    let clearFilters: Bool
    let requiresPin: Bool
    let sourceIDs: [UUID]

    func isValid(currentSourceIDs: [UUID], currentRowIDs: Set<String>, pins: Set<String>) -> Bool {
        sourceIDs == currentSourceIDs && currentRowIDs.contains(id)
            && (requiresPin ? pins.contains(id) : !clearFilters)
    }
}

struct ExportSnapshot: Identifiable {
    let id = UUID()
    let comparison: Comparison
    let documents: [SidecarDocument]
    let visibleRowCount: Int
    var pinnedIDs: Set<String>? = nil
    var visibleIDs: Set<String>? = nil
    var isScoped: Bool { pinnedIDs != nil || visibleIDs != nil }
    var title: String { visibleIDs != nil ? "Export visible comparisons" : pinnedIDs != nil ? "Export pinned comparisons" : "Export comparison" }
    var visiblePinnedIDs: Set<String> = []
    var reviewFields: [PinnedExportField] {
        guard let ids = visibleIDs ?? pinnedIDs else { return [] }
        return comparison.rows.filter { ids.contains($0.id) }
            .sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
            .map { PinnedExportField(id: $0.id, pointer: $0.visiblePath, status: $0.status,
                                    hidden: visibleIDs == nil && !visiblePinnedIDs.contains($0.id)) }
    }
    var reviewCounts: [DifferenceStatus: Int] {
        Dictionary(grouping: reviewFields, by: \.status).mapValues(\.count)
    }
    func reviewFields(matching query: String, status: DifferenceStatus? = nil) -> [PinnedExportField] {
        let fields = reviewFields
        return fields.filter { (status == nil || $0.status == status) && (query.isEmpty || $0.pointer.localizedCaseInsensitiveContains(query)) }
    }
    func inspectorRequest(for id: String) -> ExportInspectorRequest? {
        guard isScoped, pinnedIDs == nil || visibleIDs == nil,
              let field = reviewFields.first(where: { $0.id == id }) else { return nil }
        return ExportInspectorRequest(id: field.id, clearFilters: field.hidden,
                                      requiresPin: visibleIDs == nil, sourceIDs: documents.map(\.id))
    }
    var reviewReminder: String {
        visibleIDs != nil
            ? "Review filters affect this list only; all \(selectedCount) captured fields will be exported. Summary excludes field names."
            : "Review filters affect this list only; all \(selectedCount) pins will be exported. Summary excludes field names."
    }
    var selectedCount: Int { comparison.rows.filter { (visibleIDs ?? pinnedIDs)?.contains($0.id) ?? true }.count }
    func includedPointers(limit: Int = PinnedPointerCopy.includedByteLimit) throws -> (text: String, count: Int) {
        guard let ids = visibleIDs ?? pinnedIDs, pinnedIDs == nil || visibleIDs == nil else {
            throw SidecarError("Choose one captured export scope. Clipboard unchanged.")
        }
        return try PinnedPointerCopy.includedContent(fields: comparison.rows.map { (id: $0.id, pointer: $0.path) },
                                                     includedIDs: ids, limit: limit)
    }
    static let pinnedByteLimit = 16 * 1024 * 1024

    func render(detail: ReportDetail, json: Bool, limit: Int = pinnedByteLimit) throws -> String {
        guard pinnedIDs == nil || visibleIDs == nil else { throw SidecarError("Choose one export scope. Nothing was saved or copied.") }
        let scope: ReportScope = visibleIDs.map { .visible($0) } ?? pinnedIDs.map { .pinned($0) } ?? .all
        let text = json ? ReportRenderer.json(comparison, detail: detail, scope: scope) : ReportRenderer.text(comparison, detail: detail, scope: scope)
        guard !isScoped || text.utf8.count <= limit else {
            throw SidecarError(visibleIDs != nil ? "Visible report exceeds the 16 MiB export limit. Nothing was saved or copied. Narrow the table filters and try again." : "Pinned report exceeds the 16 MiB export limit. Nothing was saved or copied. Unpin some fields and try again.")
        }
        return text
    }
}

@MainActor
struct ExportSheet: View {
    let snapshot: ExportSnapshot
    var reviewField: (ExportInspectorRequest) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @Environment(\.nativeAcceptanceExportGate) private var acceptanceExportGate
    #endif
    @State private var pendingReview: ExportInspectorRequest?
    @State private var reviewIncluded = false
    @State private var reviewSearch = ""
    @State private var reviewStatus: DifferenceStatus?
    @State private var detail = ReportDetail.summary
    @State private var json = true
    @State private var acknowledged = false
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snapshot.title).font(.title2.weight(.semibold))
            if snapshot.isScoped {
                ScrollView {
                    exportContent.padding(.trailing, 4)
                }.frame(maxHeight: .infinity)
            } else {
                exportContent
            }
            if let message { Text(message).font(.callout).textSelection(.enabled) }
            Divider()
            exportActions
        }
        .padding(20).frame(width: 520)
        .frame(height: snapshot.isScoped ? 540 : nil)
        .interactiveDismissDisabled(busy)
        .onChange(of: detail) { _, _ in acknowledged = false; message = nil }
        .alert("Field hidden by current filters", isPresented: Binding(get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } })) {
            Button("Cancel", role: .cancel) { pendingReview = nil }
            if let request = pendingReview {
                Button("Clear Filters and Review") { pendingReview = nil; reviewField(request) }
            }
        } message: {
            Text("Leave export and clear table filters to review this field. Pins, sort order, display settings and the Find query stay unchanged. No report will be saved.")
        }
    }
    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if snapshot.visibleIDs != nil {
                    Text("Export scope · visible fields only").font(.headline)
                    Text("\(snapshot.selectedCount) of \(snapshot.comparison.rows.count) total fields")
                        .monospacedDigit()
                    Text("Membership is fixed to the table rows visible when this sheet opened. Summaries count only these fields; full reports include their original values in canonical units. Limit: 16 MiB; no partial output.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(snapshot.pinnedIDs == nil ? "Export scope · full comparison" : "Export scope · pinned fields, including hidden pins").font(.headline)
                    HStack(spacing: 24) {
                        Text(snapshot.pinnedIDs == nil ? "Total rows: \(snapshot.comparison.rows.count)" : "Pinned fields: \(snapshot.selectedCount)")
                        Text(snapshot.pinnedIDs == nil ? "Currently visible: \(snapshot.visibleRowCount)" : "Visible pins: \(snapshot.visibleRowCount)")
                    }.monospacedDigit()
                    Text(snapshot.pinnedIDs == nil ? "Table filters do not limit export. Summaries count all rows; full reports include every row in canonical sidecar units." : "All pins are included regardless of table filters. Full reports use canonical sidecar units. Limit: 16 MiB; no partial output.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            if snapshot.isScoped {
                statusBreakdown
                includedFields
            }
            Picker("Contents", selection: $detail) {
                Text("Summary only").tag(ReportDetail.summary)
                Text("Full metadata comparison").tag(ReportDetail.full)
            }.pickerStyle(.segmented).disabled(busy)
            if detail == .summary {
                Text("Counts and comparison policy only. No input field names, values, filenames, or paths.")
                    .font(.callout)
            } else {
                Label(ReportRenderer.privacyNote, systemImage: "exclamationmark.shield")
                    .font(.callout)
                Toggle("I understand this includes original metadata and is not de-identification.", isOn: $acknowledged).disabled(busy)
            }
            Picker("Format", selection: $json) {
                Text("JSON").tag(true)
                Text("Plain text").tag(false)
            }.pickerStyle(.segmented).disabled(busy)
            #if DEBUG
            if let acceptanceExportGate, acceptanceExportGate.held {
                Button("Release acceptance export") { acceptanceExportGate.release() }
            }
            #endif
        }
    }
    private var exportActions: some View {
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Button("Copy") { perform(copy: true) }.disabled(!canExport)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy)
                Button("Save…") { perform(copy: false) }.keyboardShortcut(.defaultAction).disabled(!canExport)
            }
    }

    private var statusBreakdown: some View {
        let counts = snapshot.reviewCounts
        return VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.visibleIDs != nil ? "All captured fields · status counts" : "All pinned fields · status counts").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(DifferenceStatus.allCases.filter { (counts[$0] ?? 0) > 0 }, id: \.self) { status in
                    Button {
                        reviewStatus = status
                        reviewIncluded = true
                    } label: {
                        Text((reviewStatus == status ? "✓ " : "") + "\(status.rawValue) · \(counts[status] ?? 0)")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }.controlSize(.small)
                }
            }

        }.disabled(busy)
    }

    private var includedFields: some View {
        let fields = snapshot.reviewFields(matching: reviewSearch, status: reviewStatus)
        return DisclosureGroup("Review included fields (\(snapshot.selectedCount))", isExpanded: $reviewIncluded) {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        reviewSearchField
                        reviewClearActions
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        reviewSearchField
                        HStack(spacing: 6) { reviewClearActions }
                    }
                }
                Button("Copy Included JSON Pointers (\(snapshot.selectedCount))", action: copyIncludedPointers)
                    .controlSize(.small).disabled(busy || snapshot.selectedCount == 0)
                HStack(alignment: .firstTextBaseline) {
                    Text("Showing \(fields.count) of \(snapshot.selectedCount)")
                    Spacer(minLength: 8)
                    Text(reviewStatus?.rawValue ?? "All statuses")
                }.font(.caption).monospacedDigit()
                Text(snapshot.reviewReminder)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if snapshot.visibleIDs != nil {
                    Text("Review in Inspector leaves export without saving. Reopening export starts at Summary.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if fields.isEmpty {
                            Text("No included fields match these review filters. Clear Search or Clear Status to broaden the list.")
                                .font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(fields) { field in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: field.pointer).font(.system(.caption, design: .monospaced))
                                    .lineLimit(2).truncationMode(.middle).help(field.pointer)
                                    .textSelection(.enabled)
                                HStack {
                                    Text(field.status.rawValue).font(.caption)
                                    Spacer(minLength: 8)
                                    Button("Review in Inspector") {
                                        guard let request = snapshot.inspectorRequest(for: field.id) else { return }
                                        if request.clearFilters { pendingReview = request }
                                        else { reviewField(request) }
                                    }.controlSize(.small)
                                }
                                if field.hidden {
                                    Text("Hidden in current view").font(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.trailing, 8)
                }.frame(height: 120)
            }.padding(.top, 6)
        }.disabled(busy)
    }

    private var reviewSearchField: some View {
        TextField("Find included field…", text: $reviewSearch)
            .textFieldStyle(.roundedBorder).frame(minWidth: 120)
    }
    @ViewBuilder private var reviewClearActions: some View {
        if !reviewSearch.isEmpty {
            Button("Clear Search") { reviewSearch = "" }.controlSize(.small).fixedSize()
        }
        if reviewStatus != nil {
            Button("Clear Status") { reviewStatus = nil }.controlSize(.small).fixedSize()
        }
    }

    private func copyIncludedPointers() {
        guard !busy, snapshot.selectedCount > 0 else { return }
        busy = true; message = nil
        let snapshot = snapshot
        Task { @MainActor in
            defer { busy = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) { try snapshot.includedPointers() }.value
                NSPasteboard.general.clearContents()
                let success = NSPasteboard.general.setString(result.text, forType: .string)
                message = success
                    ? "Copied all \(result.count) included pointers; review filters do not limit this action. Field names may identify people. The system clipboard may be shared with your other devices."
                    : "The clipboard could not be updated."
            } catch {
                message = (error as? SidecarError)?.message ?? "Included pointers could not be prepared. Clipboard unchanged."
            }
        }
    }

    private var canExport: Bool { !busy && (detail == .summary || acknowledged) }
    private func perform(copy: Bool) {
        guard canExport else { return }
        busy = true; message = nil
        let snapshot = snapshot, detail = detail, json = json
        Task {
            do {
            let text = try await Task.detached(priority: .userInitiated) {
                try snapshot.render(detail: detail, json: json)
            }.value
            #if DEBUG
            await acceptanceExportGate?.holdIfArmed()
            #endif
                if copy {
                    NSPasteboard.general.clearContents()
                    let success = NSPasteboard.general.setString(text, forType: .string)
                    message = success ? "Copied. The system clipboard may be shared with your other devices." : "The clipboard could not be updated."
                } else {
                    let saved = try await NativeReportSave.save(Data(text.utf8), json: json, protecting: snapshot.documents)
                    if saved { dismiss() }
                }
            } catch {
                message = (error as? SidecarError)?.message ?? "The report could not be saved."
            }
            busy = false
        }
    }
}
