import Foundation

public enum ReportWriter {
    /// Protect loaded source paths and identities, even when the selected target is an alias.
    /// This is accidental-overwrite protection, not a defense against a hostile concurrent filesystem actor.
    public static func write(_ data: Data, to url: URL, protecting documents: [SidecarDocument]) throws {
        guard url.isFileURL else { throw SidecarError("Reports must be saved to a local file.") }
        if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.standardizedFileURL.path)) != nil {
            throw SidecarError("A report cannot replace a symbolic link. Choose a different destination.")
        }
        let target = url.standardizedFileURL.resolvingSymlinksInPath()
        let targetIdentity = FileIdentity.at(target)
        for document in documents {
            if let source = document.sourceURL {
                let canonicalSource = source.standardizedFileURL.resolvingSymlinksInPath()
                if target == canonicalSource || url.standardizedFileURL == source.standardizedFileURL {
                    throw SidecarError("A report cannot replace a loaded source file. Choose a different destination.")
                }
                if let targetIdentity, targetIdentity == FileIdentity.at(canonicalSource) {
                    throw SidecarError("The report destination refers to a loaded source file.")
                }
            }
            if let targetIdentity, let original = document.sourceIdentity, targetIdentity == original {
                throw SidecarError("The report destination refers to a loaded source file.")
            }
        }
        do { try data.write(to: target, options: .atomic) }
        catch { throw SidecarError("The report could not be saved. Check the destination and its permissions.") }
    }
}
