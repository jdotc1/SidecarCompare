#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
swift build --product sidecar-compare -Xswiftc -warnings-as-errors
BIN="$(swift build --show-bin-path)/sidecar-compare"
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
"$BIN" --help > "$TEMP/help.txt"
"$BIN" Fixtures/mri-baseline.json Fixtures/mri-baseline.json > "$TEMP/equal.json"
set +e
"$BIN" --full Fixtures/mri-baseline.json Fixtures/mri-followup.json > "$TEMP/different.json"
STATUS=$?
set -e
[[ "$STATUS" == 1 ]] || { echo "Expected comparison exit 1, got $STATUS" >&2; exit 1; }
python3 - "$TEMP" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
equal = json.loads((p / 'equal.json').read_text())
different = json.loads((p / 'different.json').read_text())
assert equal['differenceCount'] == 0 and 'rows' not in equal
assert different['differenceCount'] > 0 and len(different['rows']) > 0
assert not any(str(p) in json.dumps(x) for x in (equal, different))
print('PASS: help, equal-summary, detailed-difference, JSON validity, exit codes.')
PY
