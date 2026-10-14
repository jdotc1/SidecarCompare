# SidecarCompare

A small native macOS utility for comparing two MRI JSON sidecars. Inspect acquisition metadata, typed differences, and documented units without modifying either input.

**Version 0.1.0 — native macOS development release.** Built and exercised on macOS with Apple Swift 6. Native feature receipts cover comparison, sandboxed imports/exports, source-write protection, drag/drop, cancellation and Light/Dark presentation. The core and CLI also have portable verification. See [verification and limitations](docs/VERIFICATION.md). Distribution signing, notarization and install qualification are separate from these development checks.

## Build and run on a Mac

Requires macOS 15 or later and an Apple Swift 6 toolchain with the macOS SDK. SwiftPM is the canonical project; no Xcode project generator or third-party runtime is needed.

```sh
./script/test.sh
./script/build_and_run.sh
```

The run script stages a real development app at `dist/SidecarCompare.app`, applies an ad-hoc sandbox signature, and opens the bundle. It restarts any existing SidecarCompare process, discarding that process's in-memory session. It never edits the input files. `--verify` checks process existence only; `--debug` uses LLDB; `--logs` streams system process logs. Source builds run on the Mac's selected host architecture; universal binaries are not produced by this script.

Open the project folder in Codex and use its configured **Run** action. See [verification](docs/VERIFICATION.md) for accepted evidence and scope. Xcode can also open `Package.swift`; use the checked-in script when testing the sandboxed app bundle rather than launching a bare executable.

## Use

Choose or drop one JSON file into **A · Reference** and another into **B · Comparison**, or load the built-in synthetic example. The table shows statuses, escaped JSON Pointers, both values, and known units. Select a row for types, original values, exact `B − A` differences, and interpretation notes. The inspector bounds long previews; full exports retain the complete values.

Search covers paths and short value previews, not hidden contents of a collapsed subtree. Differences-only and category filters change the table, never the exported comparison. The seconds/milliseconds control changes display only. Swap exchanges A and B, including delta direction. Clear resets the comparison rule to exact. Closing the single window discards the session and quits.

**Exact** is the default. Numbers compare mathematically without conversion to `Double`, so `1`, `1.0`, and `1e0` are equal, while integers beyond 2^53 remain distinguishable. Optional relative tolerance applies only to curated numeric MRI quantities, not counters or unknown/nested fields. Within-tolerance values remain visibly different. The app recommends no scientific tolerance and does not establish scan equivalence. See [comparison rules](docs/COMPARISON_RULES.md).

Objects ignore member order; arrays remain positional. Missing, null, strings, booleans, and container types remain distinct. Unknown fields are preserved. Documented top-level field names determine unit annotations; the app never guesses units from magnitude or a generic `Units` field. The catalog is deliberately partial, not a BIDS validator.

## Privacy and safety

Inputs are read-only snapshots. There are no app network requests, accounts, telemetry, recent-file database, or persistent sessions. The development app is sandboxed with user-selected file access and no network entitlement. The operating system, cloud-backed/network-mounted folders, backups, screenshots, and clipboard synchronization are outside this boundary.

Exports default to **summary only**, without input keys, values, filenames, or paths. Full export/copy requires acknowledgment and preserves original metadata, including identifiers or paths already embedded in that metadata. The app does not append selected-file names or paths. Full export is not de-identification, and neither export mode is a compliance certification. The CLI's `--full` option is the explicit full-metadata opt-in.

The app's atomic writer rejects replacement of loaded source paths and their detected symlink/hardlink aliases. This protects against accidental overwrites, not a hostile concurrent filesystem actor. CLI stdout redirection is performed by your shell and cannot receive this protection: **never redirect CLI output over an input file**.

## Verification

```sh
./script/test.sh
./script/test.sh release
python3 script/repository_check.py
python3 script/oracle_check.py
python3 script/oracle_check.py --configuration release
./script/smoke.sh
```

Repository verification scripts require Python 3.11+ and only its standard library. Python is not bundled with or required by the app or CLI. [Verification results](docs/VERIFICATION.md) identify the actual commands, environment, counts, and limitations. [Review findings](docs/RED_TEAM_REVIEW.md) document reproduced failures and incorporated fixes. The macOS CI workflow is manual-only. Publication does not automatically repeat accepted test suites; run verification when relevant inputs change.

The optional CLI uses the same core:

```sh
swift run sidecar-compare --help
swift run sidecar-compare --full --relative-tolerance 0.001 \
  Fixtures/mri-baseline.json Fixtures/mri-followup.json
```

Exit status is 0 for no differences, 1 for any difference (including within tolerance), and 2 for errors. CLI tolerance is a fraction; the GUI accepts a percentage.

## Deliberate exclusions

No image reading, DICOM conversion, BIDS inheritance/dataset validation, automatic unit correction, metadata rewriting, registration, de-identification, clinical interpretation, or radiomics extraction. No custom image-viewing framework or model downloads. Resource limits reject unsupported inputs or comparisons rather than silently truncating results.

## Repository map

`Sources/SidecarCore` contains parser, exact decimal arithmetic, catalog, comparator, reports, file protection, and session state. `Sources/SidecarCompare` contains the SwiftUI app and narrow AppKit adapters. `Sources/SidecarCLI` exposes the optional command-line interface. `Tests`, `Fixtures`, `script`, `Packaging`, `docs`, and `evidence` contain regression tests, synthetic examples, build/verification tools, bundle metadata, decisions, and actual logs.

MIT license; see [LICENSE](LICENSE). All supplied fixtures are synthetic. No clinical data, third-party runtime, build cache, signing identity, or compiled application executable is included. The accepted compiled icon resources are included for reproducible app staging.

### Reviewing results

Use Status to narrow the table to a specific outcome; its counts describe the full comparison. Click any column header to sort, and click again to reverse direction. A/B columns sort raw preview text rather than numerical magnitude. Previous/Next Difference follows the visible table order and opens the inspector; use Command-Option-Up/Down from the Comparison menu. Navigation stops at either end. Search, category, status and sorting affect the table only; exports retain the full comparison.

### Refreshing changed sidecars

Click **Reload A** or **Reload B** in the file well, or use the File menu, to read that side again without a picker. The other side remains its current snapshot. Reload is disabled for empty slots, built-in examples, pending work, and open import/export panels. If refresh fails, the old snapshot and comparison are cleared; use **Choose…** to reopen the file or restore access. Reload is explicit—files are not watched automatically.
