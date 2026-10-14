import AppKit
import SwiftUI
import SidecarCore

struct ExportSnapshot: Identifiable {
    let id = UUID()
    let comparison: Comparison
    let documents: [SidecarDocument]
}

@MainActor
struct ExportSheet: View {
    let snapshot: ExportSnapshot
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @Environment(\.nativeAcceptanceExportGate) private var acceptanceExportGate
    #endif
    @State private var detail = ReportDetail.summary
    @State private var json = true
    @State private var acknowledged = false
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export comparison").font(.title2.weight(.semibold))
            Text("Summaries count all \(snapshot.comparison.rows.count) rows. Full reports include every row, regardless of table filters, in canonical sidecar units.")
                .foregroundStyle(.secondary)
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
    private var canExport: Bool { !busy && (detail == .summary || acknowledged) }
    private func perform(copy: Bool) {
        guard canExport else { return }
        busy = true; message = nil
        let comparison = snapshot.comparison, detail = detail, json = json
        Task {
            let text = await Task.detached(priority: .userInitiated) {
                json ? ReportRenderer.json(comparison, detail: detail) : ReportRenderer.text(comparison, detail: detail)
            }.value
            #if DEBUG
            await acceptanceExportGate?.holdIfArmed()
            #endif
            do {
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
