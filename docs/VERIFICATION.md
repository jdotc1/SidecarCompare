# Verification and development-release scope

SidecarCompare 0.1.0 targets macOS 15+ and Swift 6. Native development acceptance was performed on macOS 27.2, arm64, Xcode 27.2 / Apple Swift 6.4, using a staged sandboxed app and synthetic inputs. This is a source publication; it does not include an application executable, Developer ID signature or notarization.

## Accepted checks

| Evidence | Result |
|---|---|
| `evidence/40-native-debug-tests.log` | 49 XCTest cases, zero failures; warnings-as-errors |
| `evidence/41-native-release-tests.log` | 49 XCTest cases, zero failures; warnings-as-errors |
| `evidence/67-checkpoint-session-tests.log` | Seven affected session tests passed after DEBUG worker instrumentation |
| `evidence/33-final-debug-oracle.log`, `34-final-release-oracle.log` | 12,135 independent numeric/structural/privacy/error checks per configuration on the portable toolchain |
| `evidence/42-native-repository-check.log` | Repository/configuration checks and Observation-enabled typechecking passed |
| `evidence/82-stale-drop-error-debug-build.log`, `83-stale-drop-error-release-build.log` | Final file-well UI repair compiled in native debug/release |

Logs are redacted copies of accepted receipts; original machine paths and local history are excluded. The source publication does not repeat these suites. CI is manual-only.

Native feature observations include example counts and inspector values; tolerance and display-only units; sandbox file panels and Finder drops; distinct multi-file/folder/text/UTF-8/malformed-input refusal; source-path/hardlink/symlink and moved-source write protections; GUI/CLI export parity; clipboard-sharing feedback; bounded input/row/pointer errors; deliberate reread; minimum width and long-preview behavior; close/relaunch; pending import/comparison/policy/replacement races; disabled controls during confirmed pending summary/full export; modal Return/Escape; actual Light/Dark views and Dock icon.

The final independent source review found stale drop-error feedback surviving Clear and masking later import errors. A native pre-repair reproduction preceded the fix. Resetting well-local state on Clear and clearing old drop feedback on new loading/error transitions addresses it. The changed-source native Clear regression passed, and independent follow-up source review found no further actionable patch issue. Earlier writer-symlink and rule-text wrapping defects were also repaired and verified.

DEBUG-only opt-in acceptance controls can hold import/comparison/export completion and select local Light/Dark appearance. Release excludes this instrumentation. Normal launch has no acceptance controls, no retained session and no networking.

## Limits

Evidence is bounded development acceptance, not exhaustive races, a performance benchmark, an OS/architecture install matrix, clinical validation, BIDS validation or scan-equivalence validation. Accessibility work was explicitly deferred. Release installation/Gatekeeper qualification, Developer ID signing and notarization are not claimed. Full reports retain original metadata; repository sanitization is not de-identification.

All fixtures are synthetic. There is no third-party runtime dependency or app networking. Compiled icon resources are included to reproduce app staging; build caches, local credentials, disposable UI inputs, original archive checksums and raw local history are excluded.
