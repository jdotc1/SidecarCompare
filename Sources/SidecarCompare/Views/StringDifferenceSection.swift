import Foundation
import SwiftUI
import SidecarCore

struct StringDifferenceIdentity: Hashable {
    let rowID: String
    let revision: [UUID?]

}

@MainActor
struct StringDifferenceSection: View {
    let a: String
    let b: String
    let identity: StringDifferenceIdentity
    @Binding var collapsed: Bool
    let canReveal: Bool
    let reveal: (String, ChangedSpanExcerpt) -> Void
    @State private var aLocation: ChangedSpanExcerpt?
    @State private var bLocation: ChangedSpanExcerpt?
    @State private var summary: StringDifferenceSummary?
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { !collapsed }, set: { collapsed = !$0 })) {
        VStack(alignment: .leading, spacing: 8) {
            if let summary {
                Text(summary.kind).font(.subheadline)
                Text("Shared prefix: \(summary.sharedPrefixScalars) · suffix: \(summary.sharedSuffixScalars) Unicode scalars")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                StringDifferenceExcerpt(title: "A · Reference", excerpt: summary.a)
                if let aLocation {
                    Button("Show A Change") { reveal("A", aLocation) }.disabled(!canReveal)
                }
                StringDifferenceExcerpt(title: "B · Comparison", excerpt: summary.b)
                if let bLocation {
                    Button("Show B Change") { reveal("B", bLocation) }.disabled(!canReveal)
                }
                Text("One differing span, not a minimal edit-by-edit diff. Escaped decoded text: non-ASCII and control characters use JSON Unicode escapes. Underlined text is the differing span; ellipses mark bounded context or truncation. Raw JSON below is unchanged.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(loading ? "Comparing text…" : failed ? "Text summary unavailable. Review the raw values below." : "Identical Unicode scalar sequences.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Text difference").font(.headline)
                if collapsed {
                    Text(compactSummary).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task(id: identity) {
            summary = nil; aLocation = nil; bLocation = nil; loading = true; failed = false
            let a = a, b = b
            let worker = Task.detached(priority: .userInitiated) { () throws -> (StringDifferenceSummary?, ChangedSpanExcerpt?, ChangedSpanExcerpt?) in
                guard let result = try StringDifferenceSummary.compare(a: a, b: b) else { return (nil, nil, nil) }
                return (result,
                        try ChangedSpanExcerpt.make(value: a, prefix: result.sharedPrefixScalars, suffix: result.sharedSuffixScalars),
                        try ChangedSpanExcerpt.make(value: b, prefix: result.sharedPrefixScalars, suffix: result.sharedSuffixScalars))
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                guard !Task.isCancelled else { return }
                summary = result.0; aLocation = result.1; bLocation = result.2; loading = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; failed = true; loading = false }
        }
    }
    private var compactSummary: String {
        guard let summary else {
            return loading ? "Comparing text…" : failed ? "Summary unavailable" : "Identical Unicode scalar sequences"
        }
        return "\(summary.kind) · A: \(summary.a.changedScalarCount) / B: \(summary.b.changedScalarCount) scalars"
            + (summary.a.truncated || summary.b.truncated ? " · Preview truncated" : "")
    }

}

@MainActor
private struct StringDifferenceExcerpt: View {
    let title: String
    let excerpt: StringDifferenceSummary.Excerpt
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text("\(excerpt.changedScalarCount) Unicode scalars in differing span" + (excerpt.valueIsEmpty ? " · Empty string" : ""))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            (Text(verbatim: excerpt.before)
             + Text(verbatim: excerpt.changed.isEmpty ? "[empty span]" : excerpt.changed).bold().underline()
             + Text(verbatim: (excerpt.truncated ? "…" : "") + excerpt.after))
                .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if excerpt.truncated {
                Text("Differing span preview limited to 80 Unicode scalars.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
