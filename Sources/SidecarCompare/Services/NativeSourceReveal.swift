import AppKit
import Foundation
import SidecarCore

@MainActor
enum NativeSourceReveal {
    static func reveal(_ url: URL) async throws {
        let worker = Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                var probe = url
                probe.removeAllCachedResourceValues()
                guard url.isFileURL, try probe.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                    throw SidecarError("The source is no longer a regular file at its selected location. Choose it again if it was moved or replaced.")
                }
            } catch let error as SidecarError { throw error }
            catch {
                throw SidecarError("The source is unavailable at its selected location. It may have moved or access may have expired. Choose it again to locate it or restore access.")
            }
        }
        try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
        try Task.checkCancellation()
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
