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
}

struct ExportSnapshot: Identifiable {
    let id = UUID()
    let comparison: Comparison
    let documents: [SidecarDocument]
    let visibleRowCount: Int
    var pinnedIDs: Set<String>? = nil
    var visiblePinnedIDs: Set<String> = []
    var reviewFields: [PinnedExportField] {
        guard let pinnedIDs else { return [] }
        return comparison.rows.filter { pinnedIDs.contains($0.id) }
            .sorted { $0.path.utf8.lexicographicallyPrecedes($1.path.utf8) }
            .map { PinnedExportField(id: $0.id, pointer: $0.visiblePath, status: $0.status,
                                    hidden: !visiblePinnedIDs.contains($0.id)) }
    }
    var reviewCounts: [DifferenceStatus: Int] {
        Dictionary(grouping: reviewFields, by: \.status).mapValues(\.count)
    }
    func reviewFields(matching query: String, status: DifferenceStatus? = nil) -> [PinnedExportField] {
        let fields = reviewFields
        return fields.filter { (status == nil || $0.status == status) && (query.isEmpty || $0.pointer.localizedCaseInsensitiveContains(query)) }
    }
    func inspectorRequest(for id: String) -> ExportInspectorRequest? {
        guard let field = reviewFields.first(where: { $0.id == id }) else { return nil }
        return ExportInspectorRequest(id: field.id, clearFilters: field.hidden)
    }
    var selectedCount: Int { comparison.rows.filter { pinnedIDs?.contains($0.id) ?? true }.count }
    static let pinnedByteLimit = 16 * 1024 * 1024

    func render(detail: ReportDetail, json: Bool, limit: Int = pinnedByteLimit) throws -> String {
        let scope: ReportScope = pinnedIDs.map { .pinned($0) } ?? .all
        let text = json ? ReportRenderer.json(comparison, detail: detail, scope: scope) : ReportRenderer.text(comparison, detail: detail, scope: scope)
        guard pinnedIDs == nil || text.utf8.count <= limit else {
            throw SidecarError("Pinned report exceeds the 16 MiB export limit. Nothing was saved or copied. Unpin some fields and try again.")
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
            Text(snapshot.pinnedIDs == nil ? "Export comparison" : "Export pinned comparisons").font(.title2.weight(.semibold))
            if snapshot.pinnedIDs != nil {
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
        .frame(height: snapshot.pinnedIDs == nil ? nil : 540)
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
                Text(snapshot.pinnedIDs == nil ? "Export scope · full comparison" : "Export scope · pinned fields, including hidden pins").font(.headline)
                HStack(spacing: 24) {
                    Text(snapshot.pinnedIDs == nil ? "Total rows: \(snapshot.comparison.rows.count)" : "Pinned fields: \(snapshot.selectedCount)")
                    Text(snapshot.pinnedIDs == nil ? "Currently visible: \(snapshot.visibleRowCount)" : "Visible pins: \(snapshot.visibleRowCount)")
                }.monospacedDigit()
                Text(snapshot.pinnedIDs == nil ? "Table filters do not limit export. Summaries count all rows; full reports include every row in canonical sidecar units." : "All pins are included regardless of table filters. Full reports use canonical sidecar units. Limit: 16 MiB; no partial output.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            if snapshot.pinnedIDs != nil {
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
            Text("All pinned fields · status counts").font(.caption).foregroundStyle(.secondary)
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
                HStack(alignment: .firstTextBaseline) {
                    Text("Showing \(fields.count) of \(snapshot.selectedCount)")
                    Spacer(minLength: 8)
                    Text(reviewStatus?.rawValue ?? "All statuses")
                }.font(.caption).monospacedDigit()
                Text("Review filters affect this list only; all \(snapshot.selectedCount) pins will be exported. Summary excludes field names.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
