#!/usr/bin/env python3
"""Independent black-box oracle: Python JSON/Decimal vs the compiled Swift CLI.
Synthetic data only. Python is a development dependency, never an app dependency.
"""
from __future__ import annotations
import argparse
import decimal
import json
import random
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = decimal.Decimal
decimal.getcontext().prec = 2200

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--configuration", choices=("debug", "release"), default="debug")
    args = parser.parse_args()
    subprocess.run(["swift", "build", "-c", args.configuration, "--product", "sidecar-compare", "-Xswiftc", "-warnings-as-errors"], cwd=ROOT, check=True)
    bindir = subprocess.check_output(["swift", "build", "-c", args.configuration, "--show-bin-path"], cwd=ROOT, text=True).strip()
    binary = str(Path(bindir) / "sidecar-compare")
    rng = random.Random(20261014)
    edges = [("0", "-0"), ("1", "1.000e0"), ("9", "10"), ("8.999999999999999999999999999999999", "10"),
             ("9007199254740992", "9007199254740993"), ("0", "1e-400"), ("1e400", "1e-400"),
             ("-1e400", "1e400"), ("-9", "-10"), ("-1", "1"), ("1e-400", "2e-400"), ("1.2e3", "1200")]
    def token() -> str:
        digits = str(rng.randint(1, 9)) + "".join(str(rng.randrange(10)) for _ in range(rng.randrange(1, 100)))
        sign = "-" if rng.random() < .4 else ""
        exponent = rng.randint(-400, 400)
        return sign + digits[0] + "." + digits[1:] + "e" + str(exponent)
    cases = edges + [(token(), token()) for _ in range(1200)]
    # Near equality/tolerance boundaries, rather than only far-apart random exponents.
    for _ in range(300):
        value = D(str(rng.randint(1, 100_000))) / D(1000)
        cases.append((str(value), str(value * D("1.000001"))))
    checks = 0
    with tempfile.TemporaryDirectory(prefix="sidecar-oracle-") as tmp:
        directory = Path(tmp)
        a, b = directory / "SYNTHETIC_A.json", directory / "SYNTHETIC_B.json"
        def run(left: str, right: str, *options: str) -> subprocess.CompletedProcess[str]:
            a.write_text(left, encoding="utf-8")
            b.write_text(right, encoding="utf-8")
            return subprocess.run([binary, *options, str(a), str(b)], capture_output=True, text=True, timeout=30)
        left = '{"EchoTime":[' + ",".join(x for x, _ in cases) + '],"UnknownNumbers":[' + ",".join(x for x, _ in cases) + "]}"
        right = '{"EchoTime":[' + ",".join(y for _, y in cases) + '],"UnknownNumbers":[' + ",".join(y for _, y in cases) + "]}"
        for tolerance in ("0", "0.000001", "0.1", "1"):
            output = run(left, right, "--full", "--relative-tolerance", tolerance)
            assert output.returncode == 1, output.stderr
            report = json.loads(output.stdout, parse_float=D, parse_int=D)
            rows = {row["path"]: row for row in report["rows"]}
            assert len(rows) == 2 * len(cases)
            for index, (x, y) in enumerate(cases):
                x, y = D(x), D(y)
                within = abs(y - x) <= D(tolerance) * max(abs(x), abs(y))
                expected = "Equal" if x == y else "Within tolerance" if within else "Changed"
                row = rows[f"/EchoTime/{index}"]
                assert row["status"] == expected, (tolerance, index, x, y, expected, row)
                assert row["deltaBMinusA"] == y - x, (index, "delta", row)
                assert row["a"]["value"] == x and row["b"]["value"] == y
                unknown = rows[f"/UnknownNumbers/{index}"]
                assert unknown["status"] == ("Equal" if x == y else "Changed")
                assert "unit" not in unknown
                checks += 2
        valid_pairs = [
            ('{"a":true,"b":null}', '{"a":1}'),
            ('{"a":[1,2]}', '{"a":[2,1,3]}'),
            ('{"a/b":{"~":[]},"empty":{}}', '{"a/b":{"~":{}},"empty":[]}'),
            ('{"é":1}', '{"e\\u0301":1}'),
            ('{"x":"é"}', '{"x":"e\\u0301"}'),
            ('{"x":"\\ud83d\\ude00"}', '{"x":"😀"}'),
            ('{"x":{}}', '{}'), ('{"x":[]}', '{}'),
            ('{"x":"true"}', '{"x":true}'), ('{}', '{}')
        ]
        def json_type(value: object) -> str:
            if value is None: return "null"
            if type(value) is bool: return "boolean"
            if isinstance(value, D): return "number"
            if type(value) is str: return "string"
            if type(value) is list: return "array"
            return "object"
        missing = object()
        def expected_rows(x: object, y: object, path: str = "") -> dict[str, str]:
            if isinstance(x, dict) and isinstance(y, dict) and (x or y or path == ""):
                out: dict[str, str] = {}
                for key in sorted(x.keys() | y.keys(), key=lambda k: k.encode("utf-8")):
                    escaped = key.replace("~", "~0").replace("/", "~1")
                    out.update(expected_rows(x.get(key, missing), y.get(key, missing), path + "/" + escaped))
                return out
            if isinstance(x, list) and isinstance(y, list) and (x or y):
                out = {}
                for i in range(max(len(x), len(y))):
                    out.update(expected_rows(x[i] if i < len(x) else missing, y[i] if i < len(y) else missing, path + "/" + str(i)))
                return out
            if x is missing: status = "B only"
            elif y is missing: status = "A only"
            elif json_type(x) != json_type(y): status = "Type changed"
            else: status = "Equal" if x == y else "Changed"
            return {path: status}
        for left, right in valid_pairs:
            output = run(left, right, "--full")
            assert output.returncode in (0, 1), output.stderr
            expected = expected_rows(json.loads(left, parse_int=D, parse_float=D), json.loads(right, parse_int=D, parse_float=D))
            actual = {r["path"]: r["status"] for r in json.loads(output.stdout)["rows"]}
            assert expected == actual, (left, right, expected, actual)
            checks += len(actual)
        invalid = ['[]', 'null', '{}{}', '{"x":NaN}', '{"x":Infinity}', '{"x":01}', '{"x":+1}', '{"x":1.}', '{"x":.1}', '{"x":1e}', '{"x":1e401}',
                   '{"x":1,}', '{"x":[1,]}', '{"x":"\\ud800"}', '{"x":"\\udc00"}', '{"x":"\\q"}', '{"x":1,"\\u0078":2}',
                   '{"é":1,"e\\u0301":2}', '{"x":"\n"}', '{/*comment*/}', '{"x":' + '[' * 40 + '0' + ']' * 40 + '}']
        for bad in invalid:
            output = run(bad, '{}', "--full")
            assert output.returncode == 2 and not output.stdout, (bad, output)
            assert "SYNTHETIC_A" not in output.stderr
            checks += 1
        output = run('{"PrivateKey":"SYNTHETIC_SECRET"}', '{}')
        assert output.returncode == 1
        assert not any(s in output.stdout for s in ("PrivateKey", "SYNTHETIC", str(directory)))
        for argv in (["--unknown"], ["--relative-tolerance"], ["--relative-tolerance", "nan"], []):
            output = subprocess.run([binary, *argv], capture_output=True, text=True, timeout=10)
            assert output.returncode == 2 and not output.stdout
            checks += 1
    print(f"PASS: {checks} independent numeric/structural/privacy/error checks; {len(cases)} decimal pairs × 4 policies; seed 20261014.")

if __name__ == "__main__":
    main()
