import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct FileIdentity: Sendable, Equatable, Hashable {
    let device: UInt64
    let inode: UInt64
    init(_ info: stat) {
        device = UInt64(truncatingIfNeeded: info.st_dev)
        inode = UInt64(truncatingIfNeeded: info.st_ino)
    }
    static func at(_ url: URL) -> FileIdentity? {
        var info = stat()
        let result = url.withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else { return Int32(-1) }
            return stat(pointer, &info)
        }
        return result == 0 ? FileIdentity(info) : nil
    }
}

public struct SidecarDocument: Sendable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let value: JSONValue
    public let sourceURL: URL?
    public let sourceIdentity: FileIdentity?
    public init(value: JSONValue, displayName: String = "Synthetic example", sourceURL: URL? = nil, sourceIdentity: FileIdentity? = nil) {
        self.id = UUID(); self.value = value; self.displayName = displayName
        self.sourceURL = sourceURL; self.sourceIdentity = sourceIdentity
    }
}

public enum SidecarReader {
    public static func read(_ url: URL) throws -> SidecarDocument {
        guard url.isFileURL else { throw SidecarError("Only local files can be opened.") }
        try Task.checkCancellation()
        // Open nonblocking, then inspect the opened descriptor, not just a racy pathname preflight.
        let descriptor = url.withUnsafeFileSystemRepresentation { pointer -> Int32 in
            guard let pointer else { return -1 }
            return open(pointer, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        }
        guard descriptor >= 0 else { throw SidecarError("Unable to open the selected file. Check its availability and read permission.") }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG) else {
            throw SidecarError("Select a regular file, not a folder, device, or pipe.")
        }
        guard info.st_size >= 0, info.st_size <= JSONLimits.maxBytes else { throw SidecarError("JSON exceeds the 2 MiB input limit.") }
        var data = Data()
        do {
            while true {
                try Task.checkCancellation()
                let remaining = JSONLimits.maxBytes + 1 - data.count
                let chunk = try handle.read(upToCount: min(65_536, remaining)) ?? Data()
                if chunk.isEmpty { break }
                data.append(chunk)
                guard data.count <= JSONLimits.maxBytes else { throw SidecarError("JSON exceeds the 2 MiB input limit.") }
            }
        } catch is CancellationError { throw CancellationError() }
        catch let error as SidecarError { throw error }
        catch { throw SidecarError("Unable to read the selected file. It may have changed or become unavailable.") }
        let value = try JSONParser.parse(data)
        return SidecarDocument(value: value, displayName: url.lastPathComponent,
                               sourceURL: url.standardizedFileURL, sourceIdentity: FileIdentity(info))
    }

    /// A scope is needed only while the immutable in-memory snapshot is being loaded.
    public static func load(_ url: URL) async throws -> SidecarDocument {
        let task = Task.detached(priority: .userInitiated) {
            #if os(macOS)
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            #endif
            return try read(url)
        }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
}
