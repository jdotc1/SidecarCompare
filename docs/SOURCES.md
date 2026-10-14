# Primary sources and interpretation boundaries

Reviewed 2026-10-14. Links to `stable`/`master` are moving references; the implemented catalog snapshot is `FieldCatalog.revision`, not an assertion of complete conformance to a specific BIDS edition. No third-party source implementation, complete standard, or downloaded dataset is bundled.

| Source | Used for |
|---|---|
| [BIDS MRI metadata specification](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html) | Names, documented units, and supported scalar/array interpretations for selected MRI fields. In particular RepetitionTimePreparation, EchoTime, and PostLabelingDelay can be numeric arrays; this is why they are not all scalar-only. |
| [BIDS glossary](https://bids-specification.readthedocs.io/en/stable/glossary.html) | Cross-checking selected metadata definitions; no required-field, range, inheritance, or dataset validation is implemented. |
| [dcm2niix BIDS JSON documentation](https://github.com/rordenlab/dcm2niix/blob/master/BIDS/README.md) | Converter-specific metadata/unit annotations, including SliceThickness, SpacingBetweenSlices, ImagingFrequency, PixelBandwidth, and derived timing metadata. Also reinforces that a JSON sidecar is not automatically free of identifying fields. |
| [RFC 8259 — JSON](https://www.rfc-editor.org/rfc/rfc8259) | JSON grammar, values, Unicode escapes, and interoperability boundaries. This app intentionally imposes tighter resource and duplicate/canonical-name constraints. |
| [RFC 6901 — JSON Pointer](https://www.rfc-editor.org/rfc/rfc6901) | Escaped path representation. Object-member traversal order is an application decision, not an ordering guarantee from this RFC. |
| [Apple SwiftUI Table](https://developer.apple.com/documentation/swiftui/table) | Native table surface; macOS SDK build and actual UI behavior still require native verification. |
| [Apple security-scoped URL access](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource()) | Scope-lifetime boundaries for user-selected file access. Actual sandbox read/write behavior is a native acceptance gate. |
| [Swift 6 announcement](https://www.swift.org/blog/announcing-swift-6/) | Language/concurrency baseline. The tested toolchain in this handoff is recorded separately in evidence. |
| [actions/checkout pinned commit](https://github.com/actions/checkout/commit/3d3c42e5aac5ba805825da76410c181273ba90b1) | Immutable checkout action reference used by the configured workflow. The workflow itself was not executed remotely during this handoff. |

Unit annotation is deliberately narrower than validation. Valid but unlisted fields remain raw; physical plausibility, requiredness, deprecated-field migration, image consistency, acquisition equivalence, and clinical suitability are not inferred. Unit tests and the independent Decimal oracle test implemented behavior, not full BIDS conformance or clinical validity.
