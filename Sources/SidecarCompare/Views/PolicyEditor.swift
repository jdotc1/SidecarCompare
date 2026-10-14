import SwiftUI
import SidecarCore

@MainActor
struct PolicyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var percentage: String
    @State private var error: String?
    let apply: (ComparisonPolicy) -> Void
    init(policy: ComparisonPolicy, apply: @escaping (ComparisonPolicy) -> Void) {
        _percentage = State(initialValue: policy.relativeTolerance.scaled(byPowerOfTen: 2).canonicalString)
        self.apply = apply
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Numeric comparison rule").font(.headline)
            Text("Exact comparison is the default. No scientific tolerance is recommended by this app.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Relative tolerance")
                TextField("0", text: $percentage).frame(width: 100).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Relative tolerance percentage")
                    .onSubmit(applyValue)
                Text("%")
            }
            Text("abs(B − A) ≤ r × max(abs(A), abs(B))\nUse a decimal point; 0.1 means 0.1%. Accepted range: 0–100%.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Applies only to curated numeric MRI quantities, not counters or unknown fields. Within-tolerance changes stay visible as differences.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            if let error { Label(error, systemImage: "exclamationmark.triangle").font(.caption) }
            HStack {
                Button("Reset to Exact") { apply(.exact); dismiss() }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply", action: applyValue).keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 440)
    }
    private func applyValue() {
        do {
            let number = try DecimalNumber(token: percentage.trimmingCharacters(in: .whitespacesAndNewlines))
            let policy = try ComparisonPolicy(relativeTolerance: number.scaled(byPowerOfTen: -2).canonicalString)
            apply(policy); dismiss()
        } catch { self.error = "Enter a valid decimal percentage between 0 and 100." }
    }
}
