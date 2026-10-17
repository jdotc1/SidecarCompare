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

Use Status to narrow the table to a specific outcome; its counts describe the full comparison. Click any column header to sort, and click again to reverse direction. A/B columns sort numbers by exact decimal value and strings by decoded UTF-8 text. Previous/Next Difference follows the visible table order and opens the inspector; use Command-Option-Up/Down from the Comparison menu. Navigation stops at either end. Search, category, status and sorting affect the table only; exports retain the full comparison.

### Refreshing changed sidecars

Click **Reload A** or **Reload B** in the file well, or use the File menu, to read that side again without a picker. The other side remains its current snapshot. Reload is disabled for empty slots, built-in examples, pending work, and open import/export panels. If refresh fails, the old snapshot and comparison are cleared; use **Choose…** to reopen the file or restore access. Reload is explicit—files are not watched automatically.

### Inspecting values

The inspector separates A/reference and B/comparison into cards with explicit JSON types and raw values. Type changes show an A → B transition. Long values wrap and initially show 512 characters; **Show more** expands that side to at most 8,192 characters, with shown/total counts and **Show less**. Detailed export retains complete values. Original numeric tokens and JSON escaping are preserved.

**Reset View** restores ascending JSON Pointer order, Differences only, seconds display, clears search/category/status filters and selection, and leaves both loaded snapshots and the comparison rule intact. It is also available in the Comparison menu. Ascending mixed-type A/B sorting uses missing, null, boolean, number, string, array, object; numbers retain exact decimal ordering, equivalent spellings tie, and containers use bounded previews. Descending reverses this order. Stable row IDs break ties.

When only one sidecar is loaded, the workspace identifies the missing reference A or comparison B and offers a direct Choose action for that side. After a failed reload, the prompt explains how to reopen or replace the missing file while keeping the other snapshot loaded.

The **Differences by status** buttons show full-comparison counts for Within tolerance, Changed, Type changed, A only and B only. Click a count to apply that status and enable Differences only while retaining search/category filters. A checkmark marks the active status. Zero-count buttons show the normal no-matching-rows state; Reset View restores the default review view. Counts and filters do not change exports.

Status and Reset View share a compact row. The view summary lists the selected status (or Differences only/All rows), category and whether search is active, followed by visible/total row counts. This explains why combined filters may show fewer rows than the full-comparison count buttons. Search text itself is not repeated in the summary.

### Locating selected sources

Use **File → Reveal A in Finder / Reveal B in Finder**, or the corresponding file well’s context menu, to select that source in Finder. Reveal uses the original selected location and leaves the in-memory snapshot unchanged. If the file moved or access expired, an alert directs you to choose it again. Empty slots and built-in examples have no source to reveal. Reveal does not search for moved files or certify that a file currently at the pathname still matches the loaded snapshot.

Inspector **Previous/Next** and side-specific **A/B · Show more / Show less** stay in a fixed header while values scroll. You can collapse a long preview or move to the next visible difference without scrolling back. Moving to another field resets expanded previews and brings its heading into view.

The export sheet shows **Total rows** and **Currently visible** rows when opened, with an explicit full-comparison scope reminder. Filters do not limit export: summaries count all rows, and full reports include every row in canonical sidecar units. The visible count is informational and does not change report contents.

### Copying a finding

The inspector’s fixed **Copy** menu and a row’s context menu provide **Copy JSON Pointer**, **Copy A Value · Original JSON**, and **Copy B Value · Original JSON**. Pointer escaping and original numeric tokens are preserved. Value copy includes the complete raw JSON, even when the inspector preview is truncated; it can contain identifying metadata. Missing-side value actions are disabled, while JSON `null` copies as `null`. Feedback reports success/failure and reminds you that the system clipboard may be shared across devices.

The inspector shows the selected difference’s position in the current filtered, sorted view, such as **Difference 3 of 9 in this view**. The count excludes Equal rows and updates with filters. The indicator sits beside Previous/Next when space permits and wraps beneath them in a narrow inspector.

**Reload Both** in the toolbar or File menu refreshes both selected files before comparing the new pair. It preserves filters, sorting, time display and the selected row when that row remains visible. A failed side shows its read error and Choose recovery; a successfully refreshed side stays loaded. No refreshed-versus-stale comparison is presented. Reload Both is unavailable for built-in examples, missing sources, busy work or import/export panels.

Active **Status**, **Category**, and **Search active** chips each have an × to clear only that filter. Removing a chip preserves the other filters, Differences only, sorting, time display, loaded sources and any still-visible selection. Reset View remains available to restore all presentation defaults.

**Find in values…** in the inspector searches the selected field’s complete A/B raw JSON, including content beyond the preview limit. Search is literal, case-sensitive and non-overlapping; JSON escapes and original numeric tokens are searched as displayed in raw JSON. Separate A/B counts and **Previous Match / Next Match** navigate A first, then B, stopping at either end. An underlined bounded excerpt identifies the current match and its one-based byte position within that side’s serialized value. Long matches have an explicit excerpt-truncation notice. Changing fields restarts match navigation using the current query; **Clear Find** removes only inspector search. Table filtering, raw previews, exact copying and exports are unaffected.

The inspector can be resized by dragging its visible left divider, from270 up to640 points when window space permits (default315). **Reset Inspector Width** returns it to the default without clearing the selected field, Find query/current match or expanded A/B previews. Resizing keeps the table’s existing minimum width; widen the window to make more room for the inspector. The toolbar’s Inspector button still hides/shows the pane. No application preference or source data is written for this feature.

After Reload A, Reload B or Reload Both, a dismissible inline message reports which sidecars refreshed or failed. It confirms a retained selection or explains when the previously selected field is no longer visible in the current view. Single-side reloads now preserve a still-visible selected row too. Failures retain the successful fresh snapshot and direct Choose recovery; comparison failure and cancellation are not reported as successful comparison completion. Clipboard notices remain separate.

Hiding and reopening the inspector on the same field and snapshots preserves **Find**, its current match and independent A/B expansion. Changing fields or reloading snapshots keeps the query but resets match navigation and expansion. Clear, replacement inputs, loading the example and Reset View clear the saved review state. This state is session-local.

Use **Show in Table** in the inspector to bring the selected field back into view after scrolling the table. It preserves filters, sort order, Find/current match and A/B expansion. The action is disabled without a selected field or while session work or import/export panels are active.

When filters hide every row, **No fields match this view** shows the total comparison row count. **Clear Filters** clears search, category and status and turns off Differences only, revealing all rows while preserving sort order, time display, comparison rule and loaded snapshots. **Reset View** remains the broader presentation reset.

**Copy Match Context** in Find copies the current bounded excerpt with its A/B side and one-based byte position. The text is explicitly labeled as an excerpt, not a complete JSON value; long-match truncation is identified. It preserves Find/current match and A/B expansion. Copy is disabled while results are unavailable or there are no matches. Use **Copy A/B Value · Original JSON** for the complete value. Clipboard feedback reminds you that metadata may identify people and may be shared across devices.
