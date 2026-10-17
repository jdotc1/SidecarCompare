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

## Comparison review feature increment

Status filtering now composes with search/category and differences-only; status counts cover the full comparison. Native header sorting is available on all five columns. A/B now sort numbers by exact decimal value and strings by decoded UTF-8 text (superseding the initial raw-preview sorting). Previous/Next Difference follows visible sort order, skips Equal, stops at either end and updates the inspector; shortcuts are Command-Option-Up/Down. Filters and sorting remain presentation-only and do not alter exports.

Accepted new receipts: `evidence/87-review-navigation-final-build.log` (staged debug app) and `evidence/89-review-navigation-release-build.log` (release compilation), both with warnings-as-errors. Focused native observations with the bundled synthetic example confirmed status counts/filter combinations, hidden-selection clearing, all-column sorting, preserved selection, inspector updates, shortcut navigation and disabled endpoints. Original raw UI captures remain local. Existing core/session/oracle/repository receipts above were reused without rerunning suites. No accessibility work or new performance/OS-matrix campaign was performed.

## Explicit sidecar reload

Reload A/B is available in file wells and the File menu. A native first attempt exposed loss of sandbox access metadata when storing a standardized URL. The reader now retains the original selected URL; write protection still normalizes paths at its existing boundary. A focused regression failed before repair and passes in debug95/release97. Final debug96 staging and release98 compilation pass with warnings-as-errors. Native synthetic observations confirmed A-only and B-only refresh without a picker, and unavailable-file failure clears the stale comparison and visibly directs Choose… recovery. Existing unchanged algorithm/session/oracle receipts were reused. No accessibility work or OS permission change. No blanket requalification of the full suite is claimed.

## Inspector refinement

Separate A/B cards identify JSON types and raw values; type changes summarize A→B. Long selectable values wrap and expand from512 to the existing8192-character preview cap, with explicit shown/total counts and full-export retention notice. Native synthetic observations confirmed number→string presentation and independent long-preview expansion/collapse (A10002/B9602 serialized characters). Debug101 staging and release102 compilation pass with warnings-as-errors. Core/serialization/report code unchanged; passing receipts reused without suites rerun. No accessibility work or expanded appearance/OS matrix.

## Exact numeric sorting and Reset View

A/B now use exact-decimal numeric ordering without floating point, tolerance or display conversion. Mixed types have a documented rank; equivalent numbers tie, strings use UTF-8 order and containers use bounded previews. Focused new sorting tests105/107 pass in debug/release (2 each), including2/10, adjacent integers beyond2^53, signs, tiny exponents, equivalent spellings, mixed types and Unicode distinctions. Debug106 staging and release108 compilation pass. Native synthetic observations confirm exact A/B order, selection preservation, and Reset View restoring path order/differences-only/seconds/cleared search and selection while retaining files. Reset leaves comparison policy intact. Existing unchanged receipts reused, no broad suites or accessibility work.

## One-file-loaded guidance

View-only targeted missing-A/B prompts identify the loaded side and supply the correct Choose action. Failed-read recovery text appears after reload failure. Debug111 staging/release112 compilation pass; native synthetic observations confirm both missing-side prompts, correct picker routing, completed comparison after adding the second side, and failed-reload recovery with the other snapshot retained. Existing receipts reused; no tests rerun or accessibility work.

## Clickable difference breakdown

An adaptive row/grid of counts applies Within tolerance, Changed, Type changed, A only or B only filters and marks the selected status with a checkmark. Counts cover the full comparison and search/category are retained. Debug115 staging/release116 compilation pass warnings-as-errors. Native bundled example confirmed counts0/6/1/1/1, each status button's matching rows, zero-count empty state and Reset View recovery. Existing receipts reused; no tests rerun or accessibility work.

## Compact filters and active-filter summary

Status/Reset View now share a row. A wrapping summary identifies active status/category/search and visible/total row counts, explaining full-comparison count buttons. Debug119 staging/release120 compilation pass warnings-as-errors. Native bundled example confirmed Changed6→Timing1 with count6 retained, Search active indication, Reset View9/22 recovery, ordinary layout and verified850-point minimum-width layout with inspector hidden. Existing receipts reused; no test reruns or accessibility work.

## Reveal sources in Finder

File-menu/well-context Reveal A/B actions locate the selected source without modifying snapshots. Native observations confirmed A selection in Finder and B routing after Swap. A moved-after-successful-reveal regression exposed cached metadata; clearing the probe cache repaired it. Final debug126 staging/release127 compilation pass warnings-as-errors. Native green confirmed unavailable-source recovery alert with snapshot retained. Context action presence observed; execution verified through the shared File-menu route. Existing receipts reused; no suites/accessibility/permission changes. Finder selection is a request, not content-identity verification or moved-file tracking.

## Fixed inspector review controls

Previous/Next and independent A/B preview toggles stay above scrolling values. Row changes reset expansion and return to the field heading. Debug130 staging/release131 compilation pass warnings-as-errors. Native synthetic long-value observation confirmed controls remain visible at bottom, collapse works there, next/previous selects expected field with endpoint disabling, heading returns to top, and A/B expansion independently retains8192-character ceiling. Existing receipts reused; no suites/accessibility work.

## Export-scope reminder

Export captures visible-row count alongside full comparison and shows Total rows/Currently visible with explicit full-comparison scope. Summary counts all rows; full reports include every row regardless of filters. Native initial layout truncated explanation; vertical wrapping repaired it. Final debug137 staging/release138 compilation pass warnings-as-errors. Native synthetic Type changed view confirmed22 total/1 visible and readable reminder in summary/full modes. Report generation unchanged; prior parity/privacy/export receipts reused, no suites/accessibility work.

## Exact row copying

Inspector Copy menu and table context actions copy JSON Pointer or complete A/B original JSON independently of preview/display units. Missing-side actions disabled; null copyable. Final debug142 staging/release143 compilation pass warnings-as-errors. Native synthetic clipboard assertions confirmed escaped pointer, original beyond2^53 numeric token with exponent spelling, complete9602-character JSON string beyond preview cap, and null. Original-metadata/device-sharing feedback observed. Context actions/missing-side disabling observed; execution verified through inspector/shared callback. Core/parser/report receipts reused; no suites/accessibility work.

## Selected difference position

View-only fixed-header indicator follows current visible difference order, excluding Equal. Debug146 staging and release147 compilation pass warnings-as-errors. Focused bundled synthetic native observations confirmed no-comparison/no-selection states, navigation positions1→2→3 of9, filtered1 of1 with disabled endpoints, zero-difference text and readable narrow-header fallback. Existing core/session/oracle/navigation/sorting receipts reused; no suites rerun or accessibility work. Equal-row and reordered-position text are source-reviewed behavior, not newly exercised native checks.

## Coordinated Reload Both

Reload Both in toolbar/File menu refreshes both original selected URLs and compares only after both loads finish successfully. Filters/sort/display state persist; visible row-ID selection restores, hidden/failed selection clears. Either failed side has Choose recovery with successful fresh snapshots retained; both failures show Sidecars unavailable. Focused new ReloadBothTests pass debug152/release153 (3 each): new-pair barrier/policy, A/B/both failures, clear rejecting late completions. Final debug155 staging/release156 compilation pass warnings-as-errors. Native synthetic acceptance157 confirms final view/selection retention, hidden-selection clearing, both-error guidance and disabled reload/export; earlier151 native confirms File-menu execution and A-failure/B-retention. Existing unchanged core/parser/oracle/report/navigation/reload receipts reused; no broad suites, oracle reruns or accessibility work.

## Removable active-filter chips

View-only removable Status/Category/Search active chips clear only their own filter and preserve other presentation/session state. Debug159 staging/release160 compilation pass warnings-as-errors. Focused bundled synthetic native acceptance161 confirmed all three chips together, independent removals, retained descending sort/Differences only/EchoTime selection and9/22 recovery after search clear. Screenshot showed readable labels/× controls. Existing core/session/oracle/filter/navigation/reload receipts reused; no suites rerun or accessibility work. Constrained vertical fallback and modal disabling source-reviewed; no new minimum-width/appearance campaign.
