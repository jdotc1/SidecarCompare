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

## Find within inspector values

Full selected-value A/B search uses literal case-sensitive non-overlapping UTF-8 matching over complete raw JSON, with cancellable linear worker search and row/query/document-revision result guards. Fixed-header counts/navigation and underlined bounded excerpts preserve previews/copy/export. New focused JSONValueSearchTests pass debug163/release165 (4 each), covering beyond8192, Unicode/case/non-overlap, escaped/container/null/missing/exact-number content, bounded excerpts and cancellation. Debug164 staging/release166 compilation pass warnings-as-errors. Native167 confirms long-value A2/B3 matches beyond preview cap, cross-side navigation and endpoints, field-change zero-match reset, null A1/B2 and Clear Find preserving selection. Existing unchanged receipts reused; no broad suites/oracle/accessibility work.

## Adjustable inspector width

Resizable inspector now uses a session-local bound SwiftUI divider (270–640/default315), preserves850-point table space and provides explicit Reset Inspector Width. Native preferred-width/reset attempts171/174/177/180 did not establish reset; bound-width container repaired that boundary. Final debug181 staging/release182 compilation pass warnings-as-errors. Native183 confirms315→640 drag, reset315 retaining field/Find Match3of5/A expansion, further500 drag, width retained after hide/show and1128-window clamp270→1600-window restoration500, readable controls and final1180×780/default315. Core/search engines unchanged; previous receipts reused, no test suites/oracle/accessibility work.

## Refresh completion feedback

Workspace-only refresh feedback reports requested A/B outcomes separately from clipboard notices, is dismissible, and confirms retained selection or neutral no-longer-visible text. Single-side reload now shares existing visible-selection restoration. Final debug188 staging/release189 compilation pass warnings-as-errors. Focused synthetic native190 confirmed Reload Both success/selection, Dismiss, Reload A success/selection, selected row becoming Equal/hidden, A-failure/B-success with cleared selection and readable guidance, and A-success/B-failure. Existing core/session/reload/search/export receipts reused; no suites/oracle/accessibility work. Cancellation/comparison-failure/superseding-import feedback guards source-reviewed, not newly exercised native races.

## Inspector review state while hidden

Workspace-owned review state preserves Find, completed results/current match and independent A/B expansion across inspector hide/show on unchanged inputs. Field changes and reloads retain query but invalidate results/match/expansion; replacement inputs, Clear, example and Reset View clear query too. Debug192 staging/release193 compilation pass warnings-as-errors. Focused synthetic native194 confirms hide/show preserves needle/A2/B3/Match3of5 B/both expanded; hidden field change yields A1/B2/Match1of3 A; returning long field collapses both; hidden Reload Both yields fresh A0/B1/Match1of1 B/compact previews; Clear plus example starts Find empty. Existing core/session/search/oracle/export receipts reused; no suites, oracle reruns or accessibility work. Source-reviewed cancellation guards and explicit replacement/Reset View resets; no new race/appearance/width campaign.

## Show selected field in table

Compact fixed inspector Show in Table requests centered table scrolling to the current visible selection without assigning selection or changing filters/sort/Find/expansion. Debug196 staging/release197 compilation pass warnings-as-errors. Focused synthetic native198 confirms disabled without selection; Changed plus Search active100of160 rows, descending JSON Pointer order, Field080 selected/both expanded/needle Match3of5 B. Scroll table to visible indices61–100, selected row offscreen; Show in Table returns indices0–39 with Field080 selected, descending order/filter summary and complete inspector review state retained. Existing core/session/oracle/search/filter/navigation/export receipts reused; no suites/oracle reruns/accessibility work. Modal/busy guards and hidden-selection behavior source-reviewed; no new width/appearance/race campaign.

## Empty-filter recovery

Empty-filter overlay now explains No fields match this view, full comparison row count and Clear Filters scope. Clears search/category/status/Differences only, preserving sort/time display/policy/snapshots. Debug200 staging/release201 compilation pass warnings-as-errors. Focused bundled synthetic native202 confirms Changed+Timing+unmatched search0of22 explanation; Clear Filters restores22of22, all category/status/empty search/Differences only off, descending pointers and milliseconds retained, Exact comparison unchanged. Existing core/session/oracle/filter/reset/reload receipts reused; no suites/oracle reruns/accessibility work. Modal guard and distinct truly-empty-object path source-reviewed; no new race/appearance/width campaign.

## Copy Match Context

Find adds Copy Match Context for the current identity-validated bounded excerpt, A/B side and byte position, explicitly labeled not a complete JSON value with long-match truncation notice. Final debug206 staging/release207 compilation pass warnings-as-errors; initial204/205 failed mechanical callback placement repaired. Native208 synthetic Field080 A2/B3 confirms copied Match3of5 B at byte9002 beyond preview cap, exact179-character clipboard payload with40-byte context each side, feedback and unchanged query/match/both expanded. No-match query disables action. Existing search163/165/167, clipboard144, review194 and core/session/oracle/export receipts reused; no suites/oracle reruns/accessibility work. Searching/modal/failure/truncation branches source-reviewed, not separately exercised; no new race/width/appearance campaign.

## Selected field across Swap

Toolbar/menu Swap now use workspace selection restoration after reversed comparison. Filters/sort/display/query retained; Find results/match and expansion reset for changed sides. Debug210 staging/release211 compilation pass warnings-as-errors. Focused synthetic native212 confirms toolbar Field080 retained with Changed+Field08 search/descending pointers/Milliseconds, query needle A2/B3→A3/B2 and Match3of5 B→Match1of5 A, both previews collapsed. Menu Swap under A-only filter moves selected OptionalValue to B, clears selection with no-longer-visible explanation, retaining A-only/Milliseconds. Existing session/core/oracle/reload/search/filter receipts reused; no suites/oracle reruns/accessibility work. Superseding actions/cancellation/comparison-failure guards source-reviewed; no new race/width/appearance campaign.

## Comparison-rule summary and Edit Rule

Existing exact-decimal policy label and Edit Rule above breakdown with curated-numeric scope. Shared policy wrapper restores visible selection after recomparison, preserves settings/Find query and resets field review. Debug214 staging/release215 compilation pass warnings-as-errors. Native216 bundled synthetic confirms Exact summary/editor, applying0.1%→Relative tolerance0.1% with EchoTime selected/Within tolerance, descending pointers/Milliseconds/query0.085 retained and selection feedback. Within-tolerance filter then Reset to Exact gives0of22, hidden selection cleared with explanation and same filter/Milliseconds. Existing core/tolerance/session/search/filter/reload/Swap receipts reused; no suites/oracle reruns/accessibility work. Modal/busy/same-rule/supersession/failure paths source-reviewed; no width/appearance/race campaign.

## Go to JSON Pointer

Comparison-menu exact UTF-8 pointer lookup sheet distinguishes absent and hidden rows. Explicit Clear Filters and Go reveals hidden target preserving sort/display/policy/Find. Debug218 staging/release219 compilation pass warnings-as-errors. Native220 synthetic escaped-key pair confirms absent pointer disabled, /a~1b~0c visible Go selects correct row, query0.0/Milliseconds/order retained; table search hides target, sheet offers hidden recovery, action clears search/Differences only and selects target with settings/query retained. Existing pointer/core/filter/navigation/search receipts reused; no suites/oracle reruns/accessibility work. Unicode distinctions/whitespace/modal/busy/inspector reopening and long-table scrolling source-reviewed or reuse prior scroll receipt198; no width/appearance/race campaign.

## Numeric difference summary

Inspector adds exact magnitude in current supported display unit and relative change from A with explicit formula/6-place ties-away rounding and zero-reference text, retaining exact raw signed delta. Decimal long division worker uses no floating point; reports/classification unchanged. New focused tests222/223 each passed sign/repeating/zero and rounding/large-integer methods; extreme test initially expected expanded notation instead of existing canonical scientific format. Corrected extreme alone passes226/227; accepted methods not rerun. Final worker-backed builds228/229 pass warnings-as-errors, superseding224/225. Native230 synthetic0.08→0.09 confirms12.5%, absolute0.01s→10ms and raw0.01 retained;0→1 shows zero-reference unavailable and unspecified unit. Existing comparison/tolerance/oracle/session/export receipts reused; no broad suites/oracle reruns/accessibility. Native extreme-performance/cancellation/race/width/appearance not expanded.

## Inspector Back/Forward history

Bounded100-entry session history adds independent fixed-header Back/Forward, records field selections/pointer jumps, branches on new visits and prunes valid full-comparison IDs after restoration. Hidden-target alert offers explicit Clear Filters and Go preserving settings/query; replacement/Clear/example reset. Model234 checks endpoints/traversal/dedup/branch/prune/bound/empty; reproducible script contains same accepted harness, not rerun. Final debug235 staging/release236 pass warnings-as-errors, superseding232/233 before modal-guard refinement. Native237 confirms EchoTime→ProtocolName→Back→Forward endpoint/selection/query/Milliseconds/order retention; hidden-by-search Back recovery yields EchoTime/all22/empty search/query retained/Forward available; Clear disables both. Existing comparison/navigation/pointer/filter/reload/search receipts reused; no suites/oracles/accessibility. Reload/Swap/rule integration and pointer-jump recording source-reviewed, no new race/width/appearance campaign.

## Copy Field Comparison

Shared Copy menu adds single-field original-metadata text: quoted pointer/status/rule, complete raw A/B JSON, explicit missing marker, optional exact raw signed delta/unit. Worker captures comparison policy; existing pasteboard feedback/state path reused. Debug239 staging/release240 pass warnings-as-errors. Native241 synthetic escaped-pointer/type-change exact clipboard9267chars confirms complete9008char A JSON beyond cap and B token9007199254740993e+0, status/rule and selected/query/match/A-expansion retained. Missing row clipboard exactly distinguishes A null/B absent and retains selection/query/Back history. Existing core/serialization/clipboard/numeric/search/history receipts reused; no suites/oracle reruns/accessibility. Numeric-delta formatting/context execution/modal/failure branches source-reviewed; no new race/appearance/width campaign.

## Fixed inspector field context

Existing selected escaped pointer/status now appear above fixed review controls, two-line middle-truncated/full help; nil row says No field selected. Debug243 staging/release244 pass warnings-as-errors. Native245 synthetic long escaped pointer/long A-B values confirms empty header, full help text/status, screenshot two-line truncation, bottom scroll1 with header visible and Findneedle/Match3of4 B/both Show less retained. Existing navigation/history/search/copy receipts reused; no suites/oracle reruns/accessibility. Actual tooltip activation and navigation/reload/Swap matrix source-reviewed/reused; no width/appearance campaign.

## Collapsible inspector Find

Workspace review-owned Show/Hide Find hides search content, retains outer task/cache and shows compact match/side or empty/pending/failed/no-match summary. Debug247 staging/release248 pass warnings-as-errors. Native249 existing synthetic long values A2/B2 beyond cap: Match3of4 B collapsed summary with both expanded, reopened needle/counts/same match/expansions; unmatched query collapsed No matches with expansion retained. Existing search/review/navigation/header receipts reused; no suites/oracle reruns/accessibility. Pending/failure/no-query/reset/hide-entire-inspector branches source-reviewed; no width/appearance/race campaign.

## Table-search scope

Search in offers Paths & previews/default, JSON Pointers only and Value previews only, selecting existing matching clauses. Scoped chip/summary/empty explanation, Clear Filters retains scope/Reset View restores default. New focused tests255 debug/252 release pass2 each: scope routing/either-side/case/default/empty query and preview cap. Initial251 compile fixture case names corrected; no accepted tests rerun. GUI builds253/254 warnings-as-errors pass; final source whitespace-only cleanup reused builds. Native256 synthetic needle in one path/other value confirms pointer-only/preview-only rows, chip, retained inspector query, scoped empty explanation, Clear Filters retention and Reset View default. Existing core/session/oracle/filter/search/export receipts reused; no broad suites/oracles/accessibility. Other view settings/modal/empty category combinations source-reviewed; no width/appearance/race campaign.

## Clear Filters in nonempty views

Filter-row Clear Filters beside Reset View reuses existing callback and disables without active filters/modal permission. Debug259 staging/release260 warnings-as-errors pass. Native261 bundled synthetic confirms1of22 matching EchoTime query→all22, selected EchoTime/Find0.085/descending pointers/Milliseconds/JSON Pointers only retained and button disabled after clear. Existing empty-recovery202/scope256/filter/navigation/search receipts reused; no tests/oracles/accessibility. Modal/no-comparison/category/status variants source-reviewed, no width/appearance/race campaign.

## Scope-aware search prompts

Searchable prompt now follows combined/pointer/preview scope, with matching Search in help and full-value inspector Find guidance. Debug263 staging/release264 warnings-as-errors pass. Native265 empty workspace confirms default prompt/help, active queryneedle retained through pointer→preview changes with Search JSON Pointers/Search value previews placeholders and correct help. Existing scope252/255/256/filter261/Find receipts reused; no tests/oracles/accessibility. Hover activation/comparison-state/width/appearance variants source-reviewed or reused. Owner authorized publishing this plus prepared Clear Filters c6d792f; no repeat verification of pending increment.

## Back/Forward review restoration

History bookmarks save only query/revision identity, expansions and ordinal; workspace owns selection reset/restore. Fresh guarded search applies saved match only for unchanged current query/snapshots. Debug267 staging/release268 warnings-as-errors pass. Updated small history harness269 passes save/branch-eviction/invalidation plus traversal/bounds. Native270 synthetic FieldOne Aexpanded/Bcompact/Match3of5 B and FieldTwo Acompact/Bexpanded/Match3of3 B restored respectively by Back/Forward with needle unchanged; changed-query Back retains new query, both compact/no matches. Existing search/history/core/session receipts reused; no suites/oracles/accessibility. Reload/Swap/rule invalidation, hidden recovery, pending/cancellation/clamping guards source-reviewed; no new race/width/appearance campaign.

## Compact A/B value summaries

Cards add parsed-value string character/container count/scalar/missing captions. New focused272debug/273release tests pass2 each: decoded Unicode/escaped/empty strings/scalars and immediate singular/plural/empty container counts. Builds274/275 warnings-as-errors pass. Native276 synthetic type changes confirm Empty string vs0items, long A9006decodedcharacters vs B3items with Aexpanded/Findneedle/Match1of1 A/Back retained. Existing parser/serialization/type-change/preview/history receipts reused; no broad suites/oracles/accessibility. Missing fallback/scalar/card rendering and remaining state/width variants source-reviewed; no new appearance/race campaign.

## Pin fields and Pinned only

Session stable-ID pins with inspector/context actions, count-bearing Pinned only toggle/chip/summary, combined filtering and lifecycle pruning. Model278 passes empty/toggle/membership/prune/reset; builds279/280 warnings-as-errors pass. Native281 existing synthetic long field confirms pin/count1 and Pinned only1of2 preserve selection/Findneedle/Match3of5 B/both expanded. Swap retains pin/filter/selection. Unpin under filter→count0/empty/no selection; removing chip restores2rows. Context Pin Field present; execution verified via inspector/shared callback. Existing core/filter/search/history/reload/export receipts reused; no suites/oracles/accessibility. Reload/rule/replacement/Reset View/hidden-recovery integration source-reviewed, no width/appearance/race campaign.


## Table pin markers

Existing stable-ID pins now render a pin symbol beside table JSON Pointers with Pinned field help. Debug283 staging/release284 warnings-as-errors pass. Native285 existing synthetic Review-A/B confirms pin marker appears on FieldOne while FieldTwo remains unmarked; unpin removes marker. Selected FieldOne, Findneedle/Match3of5 B and both expanded values remain unchanged. Screenshot confirms marker placement; tooltip text source-reviewed, hover activation not exercised. Existing model278/pin281/search/history/filter/core/export receipts reused; no repeated tests, suites, oracles or accessibility work. No width/appearance/race campaign.


## Clear Pins

Count-bearing button beside Pinned only clears all pins and disables that filter in one guarded main-actor action; no other view/review state mutation. Debug287 staging/release288 warnings-as-errors pass. Native289 existing synthetic Review-A/B: selected FieldOne/descending pointers/table searchField/Differences only/Milliseconds/Findneedle Match3of5 B/both expanded; pin1 and enable Pinned only1of2, then Clear Pins restores2of2, count0/filteroff/chipremoved/buttondisabled/markerremoved while selected field and all configured settings/review remain. Default zero-pin disabled state and control placement observed. Existing model278/pin281/marker285/search/history/core/export receipts reused; no repeated tests/suites/oracles/accessibility. Status/category/scope/modal/busy branches source-reviewed; no broad width/appearance/race campaign.


## Pin All Visible

Additive stable-ID union of currently visible rows, newly pinnable count/zero-busy-modal disabled; compact shared pin action row below filters. Model291 checks retained hidden pins/dedup/idempotence/empty; debug292 staging/release293 warnings-as-errors pass. Native294 Review-A/B FieldTwo pinned then hidden by FieldOne search, selected FieldOne/Findneedle Match3of5 B/both expanded/Milliseconds/descending pointers/Differences only: Pin All Visible1→0 disabled and total pins1→2, selected marker appears while query/settings/review retained. Widening search to Field reveals previously pinned FieldTwo marker and descending order. Existing filter/pin/Clear Pins/search/history/core/export receipts reused; no unchanged tests/suites/oracles/accessibility. Pinned-only/no-match/category/status/scope/modal/busy branches source-reviewed; no broad width/appearance/race campaign.


## Copy Pinned JSON Pointers

Full-comparison/pinned-ID snapshot worker formats original pointers in UTF-8 order, newline-delimited/no trailing newline. Copy action count/full-pin help/empty-busy-modal-copy guard; shared clipboard success/failure feedback. Model296 checks membership/stale IDs/escaped and empty keys/Unicode-distinct exact bytes/order/empty. Builds297/298 warnings-as-errors pass. Native299 Review-A/B both pinned, FieldOne search hides FieldTwo; copy exact clipboard /FieldOne newline /FieldTwo and Copied2 feedback. Selected FieldOne/queryFieldOne/Milliseconds/Findneedle Match3of5 B/both expanded retained. Existing pin/filter/clipboard/history/search/core/export receipts reused; no unchanged tests/suites/oracles/accessibility. Failure/busy/modal/snapshot race and remaining filter/sort variants source-reviewed; no width/appearance/race campaign.


## Pinned field navigation and hidden recovery

Pure ordered-ID navigation with endpoint disables/position and explicit all-hidden recovery. Model301 passes order/endpoints/unpinned/absent selection/hidden/empty/counts. Builds302/303 warnings-as-errors pass. Native304 bundled synthetic9pins descending: Next selects SpacingBetweenSlices position1of9/Previous disabled; Next SliceThickness2of9 then Previous returns1of9 with Find0.0 retained. Search hides all pins, disabled nav/explanation/Show Pinned Fields. Recovery clears row filters, enables Pinned only9of22, selects first descending pin and retains Milliseconds/search scope/Find0.0. Screenshot controls/order/selection observed. Existing pin/filter/Find/history/table-reveal/core/export receipts reused, no unchanged tests/suites/oracles/accessibility. Last endpoint and unpinned-selection algorithm model-tested; busy/modal/remaining filters/inspector-hidden branches source-reviewed; no broad width/appearance/race campaign.


## Go to Pinned Field

Searchable full pin-list sheet, pointer/status/visibility rows, local case-insensitive search, selection-gated Go/explicit hidden recovery; workspace pin/current-row/nonbusy guards and modal gating. Builds306/307 warnings-as-errors pass. Native308 bundled9pins: no-match0of9/Go disabled; cancel retains SpacingBetweenSlices/Milliseconds/Find0.0. Searchecho→1of9 EchoTime visible; Go retains Differences only and Find/display. Table searchEchoTime hides ProtocolName; picker labels hidden/searchprotocol1of9, selection offers Clear Filters and Go; action yields ProtocolName/all22/searchcleared/pins9 retained/Milliseconds/Find0.0. Existing exact pointer/pin/history/filter/table-reveal/search/core/export receipts reused; no unchanged tests/suites/oracles/accessibility. Sorting/modal/busy/stale-selection/remaining filter variants source-reviewed; no width/appearance/race campaign.


## Copy Pinned Comparisons

Full-pin snapshot worker composes existing exact single-field text in UTF8 pointer order; 4 MiB UTF8 header/separator-inclusive limit rejects whole output before clipboard access. Builds310/312 warnings-as-errors pass. Initial model311 harness import path failed before running; corrected local module/library path, new313 passes exact composition/membership/order/long Unicode/raw numeric/missing-null/exact byte boundary/one-byte oversize rejection/empty. Native314 bundled9pins with EchoTime-only table: clipboard2808bytes contains9 complete ordered field blocks, hiddenpins/rawvalues/missing-null/delta; Copied9 metadata warning feedback; selection/queryEchoTime/Milliseconds/Find0.0 Match2of2 B retained. Oversize clipboard preservation source-reviewed (writer only on successful content); limit boundary model-tested. Existing exact-value/pin/filter/clipboard/Find/history/expansion/core/export receipts reused, no unchanged tests/suites/oracles/accessibility. No native oversize fixture, width/appearance/race campaign.


## Compact pin-review toolbar

Presentation-only grouping into Pins(count) menu and direct Go to Pin/Previous/Next/position; all-hidden recovery on contextual row. Builds316/317 warnings-as-errors pass. Native318 empty menu all4disabled; synthetic9rows Pin All Visible9 menu execution produces Pins9/directnav; populated menu new0disabled/copies9/Clear9enabled/4MiB help retained. Open/dismiss keeps selectedEchoTime/Find0.0 Match1of2 A. Background window-control frame readback confirms1128width inspectorvisible and850hidden; screenshots toolbar fits both, hidden recovery text/button fit850. Existing pin/copy/limit/navigation/recovery/Find/history/expansion/core/export receipts reused; no unchanged tests/suites/oracles/accessibility. Scalar native review; expansion retention source-reviewed/reused. No broader appearance/race campaign.


## Undo Clear Pins

Bounded one-shot cleared-ID snapshot with edit/add/prune/refresh/reset invalidation; toolbar cleared-count/Undo. Model320 restoration incl hidden IDs, one-shot and invalidation passes. Builds321/322 warnings-as-errors pass. Native323 bundled9pins, EchoTime-only search hides8, Pinned onlyon, Milliseconds/Find0.0 Match2of2 B: Clear→count0/filteroff/Cleared9Undo; Undo→pins9/filteroff/marker/selection/query/match/display retained and messagegone. Clear again then inspector Pin Field→pins1/Undo removed, proving pin-edit invalidation. Reload/Swap/rule/import/drop/Clear/example lifecycle wiring source-reviewed/model-tested; no native refresh matrix. Existing pin/filter/Find/history/expansion/core/export receipts reused, no unchanged suites/oracles/accessibility/width/appearance/race campaign.


## Collapsible inspector A/B sections

Independent review-owned collapse flags/fixed controls/card body hiding retain A/B header/type/summary and preview-expansion state. Bookmarks include collapse under existing query/revision guard. Debug325/release327 warnings-as-errors pass; final indentation-only cleanup reuses these builds. Standalone model326 initially inherited current-OS target and failed existing Text-concatenation deprecation warnings before execution; explicit macOS15 target corrected,328 passes collapse/expansion/query independence, history bookmark/pending-match roundtrip, reset defaults and query/revision guards. Native329 existing long Review-A/B: FieldOne both expanded/needle Match3of5 B; collapse B then A hides both bodies retaining headers/counts/Find; reopen A retains expanded preview. FieldTwo fresh open, A collapsed/B expanded; Back restores FieldOne Aopen/Bcollapsed/both expanded/Match3of5 B; Forward restores FieldTwo Acollapsed/Bopen/Acompact/Bexpanded/Match1of3 A. Inspector hide/reopen retains FieldTwo state. Existing full-value search/copy/core/pins/filter receipts reused; no unchanged suites/oracles/accessibility/width/appearance/race campaign.

## Show Match in Value — 2026-10-17

Find now offers Show Match in Value. It opens only the matching A/B section and scrolls its bounded, highlighted raw JSON context into view, including beyond the 8,192-character preview cap. Query/current match, other-side collapse/expansion, and table settings remain intact. Query/index/field/revision guards prevent stale context. Complete-value copy actions are unchanged.

Accepted debug staged build336, release warnings-as-errors build337 and review-state harness338 are included. Focused native observation used synthetic Review-A/B FieldOne: A expanded then both sections collapsed; Find needle advanced to Match3of5/B/byte9002. Show Match opened B, retained A collapsed with Show less retained, preserved query/match/table state, and scrolled B context into view. A later screenshot capture followed an application reset and is not used as reveal evidence. Existing search, history and section receipts were reused; no unchanged suites or oracles were rerun. No accessibility work.

## Inspector Find scope — 2026-10-17

Debug staged build341 and release warnings-as-errors build342 pass. Focused model343 exercises actual scope ranges, occurrence retention/recovery, independent collapse/expansion/query preservation, scope/match bookmarks, empty-side reveal guard and full reset. Native344 uses existing synthetic Review-A/B: FieldOne needle5matches, Match4of5/B/byte9108 -> B only retains occurrence as Match2of3; visit FieldTwo, choose A only, then Back restores FieldOne B only/Match2of3 and A collapsed/Show less. Query xxxx in B only gives No matches in B, scoped0 with A2275/B0, and disables Previous/Next/Show/Copy. Table remains same selection/filter/order/display. Query needle restored afterward. Scope changes do not change search identity or restart the search worker.

Reused complete-value search163/165/167, hidden review194, history270, collapse328/329 and Show Match336–339. No unchanged suites/oracles/signatures rerun; no accessibility work.

## Compact inspector Find — 2026-10-17

Debug staged build346 and release warnings-as-errors build347 pass. Focused native348 used existing synthetic Review-A/B FieldOne, needle/B only/Match1of3 at byte9002, with A expanded then collapsed and B context revealed. At315-point inspector width, navigation/position and reveal/copy each fit one row. At270, position and actions stack with full Find labels; query/scope/match/A collapse and expansion/revealed B context remain unchanged. Hide Find shows B only / B / Match1of3; Show Find and Reset Inspector Width retain review state. Native driver foreground gesture used under prior explicit authorization after standard UI drag did not move the divider. No OS permissions/settings changed.

Reused scoped search/history343/344, Show Match338/339 and older complete-value search/collapse receipts. Model, worker, bookmark, matching, copy and report semantics unchanged; no unchanged model tests, suites, oracles or signatures rerun. No accessibility implementation.

## Follow Match in Value — 2026-10-17

Debug staged350 and release warnings-as-errors351 builds pass. Focused actual-state harness352 covers default-off manual behavior, enabling reveal, A-to-B navigation at byte9002, other-side collapse/expansion/query retention, stale-revision and unavailable-reveal guards, scope follow, no-match retention and full reset. Native353 used existing synthetic Review-A/B FieldOne: expand A then collapse both, Find needle; Next while off retains manual behavior. Enable at second A occurrence reveals A byte9108. Collapse A again; Next crosses to B Match3of5 byte9002, opens/scrolls B context, retains A collapsed/Show less and B Show more; query/table view unchanged. Hide/Show Find preserves enabled toggle/query/Match3of5.

Reused complete-value search, history343/344, reveal338/339 and compact-width348 receipts; no unchanged suites/oracles/signatures repeated. No accessibility work or permissions/settings changes.

## Export Pinned Comparisons — 2026-10-17

Debug staged355 and release warnings-as-errors356 pass. Initial focused harness357 linked an old helper archive and failed to resolve the new scope API; no product failure. Corrected harness358 links the current built core object and passes hidden-pin selection, summary privacy/counts, canonical pointer order, exact numeric lexemes/null/missing/full JSON/text, exact UTF8 byte limit and complete-output rejection, and ordinary-export parity. No unchanged app tests were rerun.

Native359 used bundled synthetic example: pin9 differences, filter EchoTime leaves1 visible pin, select it, collapse A, set Find0. Pinned sheet shows9pins/1visible, summary default. Native summary save succeeds; parsed saved JSON rowCount9/pinned-selection marker/no rows or values. Filter/selection/pins/Find/A collapse retained. Full option disables Copy/Save until acknowledgment; acknowledged Save opens existing protected panel. Cancelling panel returns to full/acknowledged sheet; Cancel sheet preserves review/view state. Full output serialization verified in focused358; existing save protections and atomic writer receipts reused. No accessibility, OS permissions/settings changes, unchanged suites/oracles/signatures or unrelated packaging checks.

## Unpin All Visible and Undo — 2026-10-17

Initial debug361/release362 passed; native observation prompted a feedback wording refinement for singular counts. Final debug365/release366 compile that wording. Focused model363 passes intersection/deduplication, hidden-pin preservation, exact one-shot restore, no-op preservation, edit/add/prune/refresh invalidation, replacement by Clear Pins and legacy clear restoration. Model receipt reused after the wording-only refinement.

Native364 used bundled synthetic example, pin9 differences, filter EchoTime (1visible/8hidden), selected EchoTime with Find0 and A collapsed. Unpin All Visible1 leaves8hidden pins and retains filter/selection/Find/A collapse; Undo restores9. Pinned only on: same removal leavesfilteron/pins8/emptyview/no selection; Undo restores9 and1visible withfilteron, without selecting a row. Existing hidden-selection semantics retained. UI menu dispatch needed the previously authorized native driver after primary tool guards; no permissions/settings changed. Prior search/history/filter/review/export checks reused; no unchanged suites/oracles/signatures or accessibility work.

## Pinned export review list — 2026-10-17

Debug staged368/release warnings-as-errors369 pass. Focused actual-snapshot370 passes exact membership, stable escaped-pointer order, statuses, visible/hidden labels, ordinary export exclusion and immutable snapshot state. Existing serialization/size-limit/protection/export tests358/359 reused without rerun.

Native371: bundled synthetic example9pins, EchoTime filter1visible/8hidden, selectedEchoTime/Find0/Aclosed. Pinned review starts collapsed; open shows pointer/status only, EchoTime unlabelled and hidden pins labelled Hidden in current view. Scroll admits remainingProtocolName/SliceThickness/SpacingBetweenSlices. ChooseFull/acknowledge/PlainText; collapse/reopen retains all choices. Save opens txt panel; Cancel retains expanded review/full/ack/plaintext. Cancel sheet retains pins9/filterEchoTime/selectedrow/Find0/Aclosed. Screenshot371 local. No accessibility or permissions/settings changes, no unchanged suites/oracles/signatures repeated.

## Pinned export review search — 2026-10-17

Debug staged373/release warnings-as-errors374 pass. Focused375 covers case-insensitive escaped-pointer matching, hidden/visible label retention, status/value/unpinned exclusion, no-match/clear behavior, stable order and unchanged snapshot membership/counts. Existing renderer/limit/writer/export checks358359370371 reused, not rerun.

Native376: syntheticexample9pins/EchoTimefilter1visible/selectedEchoTime/Find0/Aclosed. Reviewsearch vendor shows3of9, allhidden, while reminder saysall9exported. Full+ack+PlainText choices and vendor query survive disclosurecollapse/reopen. no-such-field shows0of9 and explicitNo included fields match, while all9export reminder remains and fullack/plaintext remainselected. ClearSearch returns9of9. Cancel returns workspacepins9/filterEchoTime/selectedfield/Find0/Aclosed. No accessibility/permissions/settings changes or unchanged suites/oracles/signatures repeated.

## Review in Inspector from pinned export — 2026-10-17

Debug staged378/release warnings-as-errors379 pass. Focused snapshot380 passes visible direct/hidden recovery request classification, unpinned/stale rejection, review-search independence, immutable pins/visibility. Existing search/serialization/limit/writer/history receipts reused without rerun.

Native381 syntheticexample: pin9, EchoTime Find0/Aclosed; visitNewFlag and collapseB, Back restoresEchoTime. FilterEchoTime then export reviewEchoTime directly: sheetcloses/filterretained/EchoTime selected/Find0/Aclosed/pins9. Reopen summarydefault; searchNewFlag hidden, Review prompts Clear Filters and Review/Cancel. Cancel retains sheet/query/disclosure; retryConfirm closesexport/clearsfilters/revealsNewFlag, pins9/Find0 and savedBclosed restored. No report saved. Native screenshot381 local. No accessibility/permissions/settings changes or repeatedunchanged suites/oracles/signatures.

## Pinned export status breakdown — 2026-10-17

Debug staged383/release warnings-as-errors384 pass. Focused385 passes counts over complete pin set including hidden fields, unpinned exclusion, combined query/status intersection, independent clearing, stable order/labels and unchanged membership/counts. Existing search/navigation/export/serialization/limit/writer receipts reused without rerun.

Native386 synthetic9pins/EchoTimefilter1visible/selectedEchoTime/Find0/Aclosed. SheetcountsChanged6/TypeChanged1/Aonly1/Bonly1 while8pinshidden. TypeChangedclick openslist1of9 hiddenRevision. vendor+TypeChanged1, Full+ack+PlainText andquery/status retaineddisclosurecollapse/reopen. Changed+vendor0of9, fullcounts/all9exportreminder retained withclearrecovery. ClearStatus=>vendor3of9; reapplyChanged thenClearSearch=>Changed6of9; ClearStatus=>9of9. Cancel retains pins9/EchoTimefilter/selection/Find0/Aclosed. Screenshot386 local. No accessibility/permissions/settings changes or repeatedunchanged suites/oracles/signatures.
