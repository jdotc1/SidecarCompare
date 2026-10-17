import AppKit
import SwiftUI
import SidecarCore

struct PinnedExportField: Identifiable {
    let id: String
    let pointer: String
    let status: DifferenceStatus
    let hidden: Bool
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
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @Environment(\.nativeAcceptanceExportGate) private var acceptanceExportGate
    #endif
    @State private var reviewIncluded = false
    @State private var detail = ReportDetail.summary
    @State private var json = true
    @State private var acknowledged = false
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(snapshot.pinnedIDs == nil ? "Export comparison" : "Export pinned comparisons").font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 8) {
                Text(snapshot.pinnedIDs == nil ? "Export scope · full comparison" : "Export scope · pinned fields, including hidden pins").font(.headline)
                HStack(spacing: 24) {
                    Text(snapshot.pinnedIDs == nil ? "Total rows: \(snapshot.comparison.rows.count)" : "Pinned fields: \(snapshot.selectedCount)")
                    Text(snapshot.pinnedIDs == nil ? "Currently visible: \(snapshot.visibleRowCount)" : "Visible pins: \(snapshot.visibleRowCount)")
                }.monospacedDigit()
                Text(snapshot.pinnedIDs == nil ? "Table filters do not limit export. Summaries count all rows; full reports include every row in canonical sidecar units." : "Table filters do not exclude pins. Summary counts cover all pinned fields; full reports contain only pinned rows in JSON Pointer order and canonical sidecar units. Limit: 16 MiB; no partial output.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            if snapshot.pinnedIDs != nil { includedFields }
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
            if let message { Text(message).font(.callout).textSelection(.enabled) }
            HStack {
                if busy { ProgressView().controlSize(.small) }
                Button("Copy") { perform(copy: true) }.disabled(!canExport)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(busy)
                Button("Save…") { perform(copy: false) }.keyboardShortcut(.defaultAction).disabled(!canExport)
            }
        }
        .padding(24).frame(width: 520)
        .interactiveDismissDisabled(busy)
        .onChange(of: detail) { _, _ in acknowledged = false; message = nil }
    }
    private var includedFields: some View {
        DisclosureGroup("Review included fields (\(snapshot.selectedCount))", isExpanded: $reviewIncluded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Field names are shown here for review only. Summary output excludes them.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(snapshot.reviewFields) { field in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: field.pointer).font(.system(.caption, design: .monospaced))
                                    .lineLimit(2).truncationMode(.middle).help(field.pointer)
                                    .textSelection(.enabled)
                                Text(field.status.rawValue).font(.caption)
                                if field.hidden {
                                    Text("Hidden in current view").font(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.trailing, 8)
                }.frame(height: 150)
            }.padding(.top, 6)
        }.disabled(busy)
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
