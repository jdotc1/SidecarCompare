# UI design specification

This document describes the implemented interface; it is not a screenshot or evidence of native rendering.

## Window and hierarchy

One macOS utility window, default 1180 × 780 points. The main workspace requests at least 850 × 580 points; the optional inspector has its own 270–500-point width range and may increase the effective window minimum. Verify actual sizing on macOS rather than assuming these requests are the final visible dimensions. Closing the window quits and discards its memory-only session.

The toolbar exposes Open A, Open B, Swap, Clear, Comparison Rule, Export, and Inspector. Below it, two equally weighted compact drop/open wells name A as reference and B as comparison. A filter strip carries Differences only, category, and time-display controls. The native table occupies the remaining central space. A native inspector at right provides raw typed values, exact delta, and interpretation. The footer reports shown/total rows, differences, tolerance, same-source warnings, and the limited scope.

The table uses five columns: status, JSON Pointer, A/reference, B/comparison, and display unit. It supports native selection, keyboard navigation, scrolling, and column resizing. Traversal ordering is deterministic; sortable headers or user-defined sort policies are not advertised. Searching covers pointer text and bounded scalar previews. Table filters are presentation-only and are explicitly independent of export.

## Styling and accessibility intent

Use system semantic typography and adaptive primary/secondary styles. JSON paths and values use system monospaced text; headings, buttons, warnings, and descriptions use normal system styles. File-well spacing is 12 points internally; workspace padding is 16 points. Avoid fixed Light-mode backgrounds, third-party UI components, custom window chrome, or decorative visualization.

Status combines a textual label and SF Symbol, not color alone. Equal rows use secondary emphasis; changes retain primary emphasis without automatically implying clinical severity. Native table selection, standard controls, focused menu commands, accessible field/control names, selectable inspector text, and resizable regions are implemented. Actual focus order, contrast, VoiceOver behavior, and large-text usability require native review.

## State design

Initial state offers two file selectors and a synthetic example. Loading uses a progress indicator and a cancellation route; individual import errors remain with their slot. Replacing a source removes stale results immediately. Empty objects receive an explicit no-fields message. A filter-induced empty view offers Show All Rows rather than implying there were no differences. Out-of-budget comparison returns an error, never a partial result.

The comparison-rule popover defaults to exact; the user may specify a relative percentage. The text explains the formula and scope and makes no scientific recommendation. The seconds/milliseconds selector affects only recognized time display, while the inspector retains raw values.

Export is a modal review step with summary as the default. Full metadata requires acknowledgment. It uses an immutable comparison/source snapshot and disables content/format changes while busy. The Save panel warns about embedded metadata paths and protects loaded inputs. Copy explicitly warns about system clipboard sharing. Long raw previews are visibly bounded; complete raw metadata remains available only through the acknowledged full report.

## Deferred visual work

A custom icon, native screenshots, final column-width tuning, and any cosmetic refinements follow native correctness/accessibility acceptance. No generated mockup is included or claimed as the actual app. Do not enlarge scope into an imaging workbench, viewer, or protocol recommendation engine.
