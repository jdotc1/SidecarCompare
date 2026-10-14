import Foundation
import SidecarCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

let usage = """
Usage: sidecar-compare [--full] [--text] [--relative-tolerance R] [--] A.json B.json

Local-only comparison of two explicitly selected JSON objects.
Default output: JSON summary without input keys, values, filenames, or paths.
--full includes original metadata: review for identifying information before sharing.
R is a fraction from 0 to 1, not a percentage; default 0 means exact comparison.
Tolerance applies only to curated MRI quantities. Arrays remain positional.
Exit status: 0 exact equality; 1 any difference (including within tolerance); 2 error.
No BIDS inheritance, de-identification, image inspection, or clinical validation.
"""

func run() throws -> Int32 {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--help"] || arguments == ["-h"] { print(usage); return 0 }
    var paths = [String](), detail = ReportDetail.summary, plain = false, tolerance = "0", options = true
    var index = 0
    while index < arguments.count {
        let arg = arguments[index]
        if options && arg == "--" { options = false }
        else if options && arg == "--full" { detail = .full }
        else if options && arg == "--text" { plain = true }
        else if options && arg == "--relative-tolerance" {
            index += 1
            guard index < arguments.count else { throw SidecarError("--relative-tolerance requires a numeric fraction.") }
            tolerance = arguments[index]
        } else if options && arg.hasPrefix("-") { throw SidecarError("Unknown option. Use --help; use -- before filenames beginning with a hyphen.") }
        else { paths.append(arg) }
        index += 1
    }
    guard paths.count == 2 else { throw SidecarError("Exactly two JSON files are required. Use --help for usage.") }
    let policy = try ComparisonPolicy(relativeTolerance: tolerance)
    let a = try SidecarReader.read(URL(fileURLWithPath: paths[0]))
    let b = try SidecarReader.read(URL(fileURLWithPath: paths[1]))
    let result = try Comparator.compare(a: a.value, b: b.value, policy: policy)
    let report = plain ? ReportRenderer.text(result, detail: detail) : ReportRenderer.json(result, detail: detail)
    try FileHandle.standardOutput.write(contentsOf: Data(report.utf8))
    return result.differenceCount == 0 ? 0 : 1
}

do { exit(try run()) }
catch {
    let message = (error as? SidecarError)?.message ?? "The operation failed. Check file access and output availability."
    try? FileHandle.standardError.write(contentsOf: Data(("SidecarCompare: " + message + "\n").utf8))
    exit(2)
}
