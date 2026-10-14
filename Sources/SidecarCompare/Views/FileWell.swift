import SwiftUI
import SidecarCore

@MainActor
struct FileWell: View {
    let slot: FileSlot
    let document: SidecarDocument?
    let loading: Bool
    let error: String?
    let open: () -> Void
    let receive: (URL) -> Void
    let cancel: () -> Void
    @State private var targeted = false
    @State private var dropError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(slot == .a ? "A · Reference" : "B · Comparison", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                Button(loading ? "Cancel" : "Choose…", action: loading ? cancel : open)
                    .accessibilityLabel(loading ? "Cancel loading \(slot.rawValue)" : "Choose sidecar \(slot.rawValue)")
            }
            Text(document.map { String(JSONValue.quote($0.displayName).dropFirst().dropLast()) } ?? (loading ? "Reading local snapshot…" : "Drop one JSON file here"))
                .lineLimit(1).truncationMode(.middle)
                .foregroundStyle(document == nil ? .secondary : .primary)
            if let message = dropError ?? error {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Import error: \(message)")
            } else {
                Text("Read-only input · JSON object · up to 2 MiB")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(targeted ? 0.8 : 0.35)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(targeted ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: targeted ? 2 : 1))
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1, let url = urls.first, url.isFileURL else {
                dropError = "Drop exactly one local JSON file into this side."
                return false
            }
            dropError = nil
            receive(url)
            return true
        } isTargeted: { targeted = $0 }
        .onChange(of: loading) { _, loading in if loading { dropError = nil } }
        .onChange(of: error) { _, error in if error != nil { dropError = nil } }
        .onChange(of: document?.id) { _, _ in dropError = nil }
    }
}
