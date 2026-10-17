import SwiftUI

/// A session-local width binding keeps reset and dragging consistent without
/// rebuilding the inspector or writing window/preferences state.
@MainActor
struct InspectorDivider: View {
    @Binding var width: CGFloat
    let displayedWidth: CGFloat
    let maximum: CGFloat
    @State private var dragStart: CGFloat?

    var body: some View {
        Rectangle().fill(.quaternary.opacity(0.4))
            .frame(width: 8)
            .overlay {
                RoundedRectangle(cornerRadius: 1).fill(.secondary)
                    .frame(width: 2, height: 24)
            }
            .contentShape(Rectangle())
            .help("Drag to resize inspector")
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    let start = dragStart ?? displayedWidth
                    dragStart = start
                    width = min(maximum, max(270, start - value.translation.width))
                }
                .onEnded { _ in dragStart = nil })
    }
}
