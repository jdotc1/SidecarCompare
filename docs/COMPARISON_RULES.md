# Comparison rules and limits

## Representation

Inputs must be UTF-8 JSON objects. An initial UTF-8 BOM is accepted; invalid UTF-8, malformed JSON, comments, nonfinite literals, duplicate keys, and non-object roots are rejected. The parser is deliberately stricter than interoperable JSON in rejecting canonically equivalent names within one object. Escaped and literal spellings of the same name are duplicates. Across two objects, names with different decoded UTF-8 sequences remain distinct. Numeric spelling is retained, but exact numeric equality is mathematical rather than lexical.

Object order does not affect results. Traversal sorts raw decoded UTF-8 object keys, not the escaped path text. Array indices retain their original order. Paths use JSON Pointer escaping (`~` to `~0`, `/` to `~1`). Display additionally escapes control/directional characters; the JSON report encodes the actual pointer as a JSON string. This is not JSONPath.

Scalar or empty-container differences appear at their own paths. If an entire subtree is missing from one side, it appears as one row at the subtree root with its full value retained for export. A container-type replacement is also one row. This prevents a type replacement from masquerading as many unrelated child additions/deletions. Nonempty arrays present on both sides expand positionally. Counts refer to these comparison rows, not the number of original header fields or MRI acquisitions.

## Status and numeric rule

`Equal` means the typed values match; equal decimal numbers may have different original numeric tokens. `Changed` means unequal values of the same JSON type. `Type changed`, `A only`, and `B only` distinguish replacements and absence. `Within tolerance` means unequal numbers that satisfy the chosen rule in an eligible field; these rows remain in the difference count and differences-only view.

Exact comparison is default. Optional relative tolerance `r` is in [0,1]. The GUI accepts percentages [0,100]; the CLI accepts a fraction. Both classify with exact decimal arithmetic:

```text
abs(B - A) <= r * max(abs(A), abs(B))
```

There is no absolute tolerance floor. Zero versus nonzero is outside tolerance for `r < 1`; at `r = 1` it meets the documented boundary. Exact equality is classified before tolerance. No tolerance is recommended for research or clinical use.

Tolerance applies only to recognized top-level physical quantities with supported numeric shapes. Immediate numeric array elements are eligible only when the field permits an array. Counters, generic numbers, and nested vendor fields remain exact. Unknown fields have no inferred unit. Known fields with unsupported shapes remain raw with a note. Negative or otherwise physiologically implausible numeric values are not automatically rejected: this is not a BIDS range/required-field validator.

`EchoTime`, `PostLabelingDelay`, and `RepetitionTimePreparation` permit a scalar or numeric array. `SliceTiming` and `VolumeTiming` use numeric arrays. Scalar timing fields and the supported scanner/geometry quantities are enumerated in `Sources/SidecarCore/FieldCatalog.swift`. That file is the exact versioned catalog. Deprecated or converter-specific fields are not silently renamed or converted. Unlisted valid BIDS fields remain fully comparable as raw JSON.

The milliseconds selector multiplies recognized second-valued display values by 1,000; it never changes raw values, status, delta calculations, or exported units. A generic `Units` field does not override the catalog. The inspector shows raw JSON; exact deltas use the canonical annotated unit when known.

## Resource boundaries

| Boundary | Limit |
|---|---:|
| Bytes per input | 2 MiB (2,097,152 bytes) |
| JSON values per input, including root/containers | 20,000 |
| Nesting, with top-level object at depth 0 | 32 |
| Decoded UTF-8 bytes per string | 65,536 |
| Decoded UTF-8 bytes per key | 512 |
| Bytes per numeric token | 256 |
| Magnitude of explicit numeric exponent | 400 |
| Result rows across both inputs | 20,000 |
| UTF-8 bytes per expanded JSON Pointer | 2,048 |
| Aggregate UTF-8 bytes of result pointers | 2 MiB |

Comparison budgets are separate from parser limits because repeated long prefixes can expand small inputs into large tables/reports. Any exceeded budget rejects the whole comparison with an error; no successful partial table/report is returned. Limits describe this utility's supported inputs, not the limits of JSON or BIDS.

## Reports and reproducibility

Reports record app version, catalog revision, scope, tolerance, and counts. JSON uses report schema version 1 and typed presence markers; full output includes both values and raw deltas. Text records the versioned rule and raw typed values. Neither format depends on filters, selected rows, display milliseconds, current time, or source filenames. Full output may still contain filenames or paths embedded in original metadata. Numeric output tokens and deterministic traversal are preserved; object whitespace/ordering is not a source-byte snapshot. Numeric values in a report can exceed another application's floating-point range, so consumers must use a suitable decimal parser.

Sources are immutable in-memory snapshots, not monitored files. A same-source warning uses known file identity or standardized selected paths; identical contents in different files are not treated as the same source. It is a warning, not an identity/provenance certification. See `SOURCES.md` for normative JSON/BIDS and converter references.
