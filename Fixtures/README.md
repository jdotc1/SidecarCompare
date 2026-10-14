# Synthetic fixtures

All values are fabricated for software tests/demonstration. No clinical record or real subject data is included.

`mri-baseline.json` and `mri-followup.json` mirror the built-in example. Under exact comparison they produce 22 rows: 13 Equal, 6 Changed, 1 Type changed, 1 A only, and 1 B only (9 total differences). The differences include EchoTime, phase-encoding direction, bandwidth, descriptive protocol text, slice geometry metadata, and deliberately typed/missing vendor fields. The numbers are illustrative, not a recommended acquisition protocol or tolerance.

`multi-echo.json` exercises scalar-or-array timing annotations, including RepetitionTimePreparation. `types-and-nesting.json` exercises raw nesting, escaped pointer names, and type preservation. `empty.json` is an empty object, not a complete MRI sidecar. None of these files is asserted to be a complete valid BIDS dataset.

Malformed inputs, limit boundaries, large exact numbers, aliases, and cancellation races are generated synthetically inside XCTest/Python tests rather than stored as bulk fixtures.
