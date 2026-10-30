#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

coverage_path=$(swift test --show-codecov-path)
python3 - "$coverage_path" <<'PY'
import json
import sys

with open(sys.argv[1]) as coverage_file:
    report = json.load(coverage_file)

lines = [
    source["summary"]["lines"]
    for data in report["data"]
    for source in data["files"]
    if "/Sources/TwiddleCore/" in source["filename"]
]
total = sum(line["count"] for line in lines)
covered = sum(line["covered"] for line in lines)
if not total:
    sys.exit("coverage: no TwiddleCore line coverage found")
percent = covered / total * 100
print(f"TwiddleCore line coverage: {percent:.2f}% ({covered}/{total}); required: 85%")
if covered * 100 < total * 85:
    sys.exit("coverage: TwiddleCore line coverage is under 85%")
PY
