# Adversarial review and incorporated fixes

Date: 2026-10-14. Scope: design, plan, source, session concurrency, parser/number behavior, unit catalog, reports, file I/O, GUI wiring, and handoff/release claims.

## Method and independence

This was an implementation self-review, not an independent review. The numerical/structural oracle is an independently implemented Python JSON/Decimal reference exercising the compiled Swift CLI; that is algorithmic cross-checking, not an independent review of the implementation. `INDEPENDENT_REVIEW_PROMPT.md` supplies criteria for a further independent review.

The review sought counterexamples and reproduced failures before repairs where executable. It also inspected platform-conditional code and attempted an Observation-enabled Swift 6 typecheck, rather than treating a Linux-only build as sufficient. No native macOS SDK build, GUI run, screenshot audit, or accessibility evaluation was performed.

## Findings

| ID | Priority | Finding and evidence | Incorporated resolution | Verification |
|---|---|---|---|---|
| RT-01 | P1 | macOS-conditional `@ObservationIgnored` attributes inside per-attribute `#if` blocks interacted incorrectly with `@Observable`: macro expansion generated conflicting accessors and isolation errors. `evidence/13-observation-typecheck.log` records the failure. | `ComparisonSession.swift` now keeps cancellation/task generations in an immutable `SessionWork` reference, which Observation naturally ignores. The helper owns task cancellation on deinitialization; observable UI state remains in the session. | Macro-enabled core typecheck passes in `script/repository_check.py`; session regression suite passes. Native runtime observation remains an open gate. |
| RT-02 | P1 | Per-file size limits did not bound expanded result size. Two individually valid inputs could produce more than 20,000 rows; repeated long prefixes could expand small JSON into a large path table/report. Three adversarial regressions initially failed in `evidence/19-comparison-budget-red.log`. | Added independent row, per-pointer, and aggregate-pointer budgets in `ComparisonLimits` and `Comparator`. Exceeding any budget rejects the entire result rather than silently truncating it. | `ResourceBudgetTests` verifies all three rejections plus supported boundary cases and parser byte/string/key/value/depth/number limits. |
| RT-03 | P2 | `RepetitionTimePreparation` was treated as scalar-only, although the BIDS field allows a number or an array of numbers in seconds. This suppressed unit annotation/tolerance for a supported MRI representation. `evidence/15-preparation-time-red.log` reproduces the unit/status failure. | Moved the field to the catalog's scalar-or-array group; retained raw preservation and per-element array comparison. | `ComparisonTests.testPreparationRepetitionTimeAllowsArrayAndScalar` passes for both forms. Source: BIDS MRI specification, linked in `SOURCES.md`. |
| RT-04 | P1 | A save-panel/design statement claimed reports never contain filenames/paths. Full reports intentionally preserve original metadata, which can embed paths. The inaccurate reassurance could prompt inappropriate sharing. | Corrected save-panel, shared privacy warning, design, README, and export description. Full reports still preserve data; the app does not add selected-file names/paths. Summary remains value-free by default. | `ReportTests.testEmbeddedPathsRemainInFullReportButNotSummary` tests retained embedded paths, absent summary contents, and explicit warning text. Earlier wording failure is in `evidence/16-privacy-wording-red.log`. |
| RT-05 | P2 | Selecting the same file on both sides gave an unqualified equal result with no identity warning. | Added `ComparisonSession.sameSource` using stored device/inode identity or standardized selected paths and a visible footer warning. Identical copies and same display names alone do not trigger it. | `SessionTests.testSameSourceIncludesHardlinksButNotEqualContent` covers repeated paths, hardlinks, independent copies, synthetic documents, and Clear. `evidence/17-same-source-red.log` records the initial failure. |
| RT-06 | P2 | Export content/format controls could change while an already-captured export task was running, making the visible selection disagree with the in-flight report. | Disabled content/format/acknowledgment controls while busy. Export still uses one immutable comparison/source snapshot; acknowledgment resets whenever detail changes. | Source inspection plus Swift syntax check. Exercise interactively on macOS; no GUI test result is claimed. |
| RT-07 | P2 | Text reports omitted the catalog revision and explicit tolerance formula/scope that JSON reports already included, weakening reproducibility outside the app. | Both formats now use the shared tolerance-rule constant. Text adds catalog revision, schema, and raw tolerance fraction. | `ReportTests.testTextReportIncludesVersionedComparisonRule`; initial failure in `evidence/29-text-report-provenance-red.log`, final suite passes. |
| RT-08 | P2 | The initial design implied per-window sessions, but the code intentionally used one `Window`. Extra windows would also complicate loaded-source protection across sessions. | Reconciled the design and acceptance contract to one workspace, close-to-quit, no restoration. No unimplemented multiwindow capability is advertised. | Design/source cross-check; native lifecycle remains a manual acceptance item. |
| RT-09 | P3 | Literal filenames could display line breaks/directional control characters in a file well. | File-well display names now use the same escaped-string presentation as JSON values. No input-path logging was added. | Syntax check and source inspection; native typography/VoiceOver check remains pending. |

P1 means a build/safety/resource or consequential correctness problem to address before acceptance; P2 means a meaningful functional/interpretation defect; P3 is presentation hardening. These priorities are judgments about this utility, not a clinical risk classification.

## Additional challenges exercised

Tests and the independent oracle cover large integers past binary64's exact-integer range, tiny/large exponents, signed arithmetic, tolerance boundaries, original numeric tokens, bool/number separation, missing/null distinctions, array order, type changes, Unicode-distinct keys, duplicate/escaped keys, malformed inputs, and parser limits. The session tests force out-of-order loaders that ignore cancellation, rapid policy changes, failure during replacement, clear/cancel races, and swap guarding. File tests challenge directories, oversize files, FIFOs, symlinks, hardlinks, and unsafe error disclosure.

Historical red logs include compilation failures for not-yet-implemented APIs, the Linux Observation runtime-linker issue, and an initially incorrect path-order test. They are not all assertion-level red tests, and they are not the final build status. The unit-array regression initially also expected no notes; that assertion was narrowed to the actual contract (no unsupported-shape warning), because valid annotations deliberately retain interpretation notes.

## Remaining acceptance gates / limitations

**Native build and behavior are unverified.** The highest-priority remaining work is a genuine macOS SDK compile, sandboxed app launch, file/drop permissions, native Save-panel behavior, observation-driven redraw, keyboard/VoiceOver, and Light/Dark/resize checks. Passing portable tests or syntax checks cannot close these gates. The macOS CI workflow is configured but has not executed in this session.

**No independently isolated reviewer has assessed this snapshot.** The next review prompt is included. This report does not claim independent approval.

**Filesystem and environmental limits remain explicit.** Input reads do not lock files or guarantee a coherent snapshot during concurrent modification. Source-overwrite checks are not a defense against a malicious actor racing filesystem operations. Cloud/network storage and clipboard synchronization can move data outside the application. A full report remains original metadata, not de-identified data. No OS-level memory-residency, crash-report, clinical, or compliance audit was performed.

**No release identity or distribution validation.** The generic app icon is intentional. Developer ID signing, notarization, universal binaries, Gatekeeper installation, and public publication are not included or tested. These are release tasks, not evidence of a completed distributable app.

## Disposition

The confirmed portable and macro-typechecking findings above were repaired, and the final executable checks are recorded in `VERIFICATION.md`. Deliver this as a tested-core source handoff with explicit native and independent-review gates—not as a fully validated macOS release.

## Independent native continuation review — 2026-10-14

A separate read-only in-thread reviewer inspected baseline commit 52fab5e, full source/design/tests and existing evidence. It ran no checks or tests. One P2 finding: ReportWriter resolved unrelated destination symlinks and overwrote their referents, contrary to DESIGN. Parent added a failing regression (39), then rejected existing/dangling final-component symlinks before resolution. Debug/release suites pass 49 cases (40/41). No further concrete source defect was established; this is not approval of unexercised native gates. Review covered the baseline; repair evidence comes from parent execution.

## Native feature feedback repair — 2026-10-14

Native Copy Summary feedback lacked the device-sharing warning specified by acceptance, although Export sheet Copy already included it. Added that warning only; native pre/post regression recorded in 49/51 and real debug build in 50. Report content/core unchanged; existing passing tests reused. No new independent review claimed for this wording change. Accessibility work was explicitly deferred by owner during this continuation.

## Native continuation and final independent source review

The original self-review above predates native continuation. A separate read-only in-thread reviewer subsequently identified the destination-symlink writer defect; it was reproduced, repaired and included in the 49 passing native debug/release tests. Final read-only review identified stale file-well drop feedback surviving Clear and masking later import errors. A native failure receipt preceded the view-state repair, and its native Clear regression passed. Independent source follow-up found no additional actionable patch issue. These reviews do not claim exhaustive proof, accessibility conformance or clinical validation. The current verification record distinguishes portable checks, native observations and distribution limits.
