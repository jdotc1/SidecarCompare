import AppKit
import Foundation
import UniformTypeIdentifiers
import SidecarCore

@MainActor
enum NativeReportSave {
    static func save(_ data: Data, json: Bool, protecting documents: [SidecarDocument]) async throws -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Comparison"
        panel.message = "Loaded source files are protected from replacement. Full reports retain original metadata, including any embedded filenames and paths."
        panel.allowedContentTypes = json ? [.json] : [.plainText]
        panel.nameFieldStringValue = json ? "sidecar-comparison.json" : "sidecar-comparison.txt"
        panel.canCreateDirectories = true
        let response = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        guard response == .OK, let url = panel.url else { return false }
        let worker = Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try ReportWriter.write(data, to: url, protecting: documents)
        }
        try await worker.value
        return true
    }
}
