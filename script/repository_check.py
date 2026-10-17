#!/usr/bin/env python3
"""Repository structure, Swift syntax, and Observation-macro typecheck.
This does NOT substitute for a macOS SDK build, GUI run, or accessibility review.
Requires Python 3.11+ and a Swift 6 toolchain; no third-party Python packages.
"""
from pathlib import Path
import os
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(*arguments: str) -> None:
    subprocess.run(arguments, cwd=ROOT, check=True)

for file in sorted((ROOT / "script").glob("*.sh")):
    run("bash", "-n", str(file))
    assert os.access(file, os.X_OK), f"Not executable: {file.name}"
print("PASS: shell syntax and executable modes.", flush=True)

with (ROOT / "Packaging/Info.plist").open("rb") as file:
    info = plistlib.load(file)
assert info["CFBundleExecutable"] == "SidecarCompare"
assert info["CFBundlePackageType"] == "APPL" and info["LSMinimumSystemVersion"] == "15.0"
with (ROOT / "Packaging/SidecarCompare.entitlements").open("rb") as file:
    entitlements = plistlib.load(file)
assert entitlements == {"com.apple.security.app-sandbox": True,
                        "com.apple.security.files.user-selected.read-write": True}
print("PASS: bundle metadata and sandbox/no-network entitlements.", flush=True)

views = sorted((ROOT / "Sources/SidecarCompare").rglob("*.swift"))
run("swiftc", "-frontend", "-parse", *(str(file) for file in views))
print(f"PASS: Swift syntax parsing for {len(views)} GUI source files (not SDK typechecking).", flush=True)

# Exercise Observation macro expansion, which is otherwise macOS-conditional.
# Linux links the non-observable session to avoid a broken Observation runtime in
# the supplied toolchain. This check only typechecks; it never links that runtime.
core = ROOT / "Sources/SidecarCore"
with tempfile.TemporaryDirectory(prefix="sidecar-observation-") as temporary:
    observed = Path(temporary) / "ComparisonSession.swift"
    observed.write_text((core / "ComparisonSession.swift").read_text().replace("#if os(macOS)", "#if true"))
    sources = sorted(p for p in core.glob("*.swift") if p.name != "ComparisonSession.swift")
    run("swiftc", "-typecheck", "-swift-version", "6", "-warnings-as-errors", *(str(p) for p in sources), str(observed))
print("PASS: Observation-enabled core Swift 6 typecheck; no macOS UI runtime claim.", flush=True)
