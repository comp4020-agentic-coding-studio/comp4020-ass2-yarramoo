#!/usr/bin/env bash
# week-11.md asks for "a differential-testing harness that runs the same
# programs through this interpreter and a real CSNOBOL4, and reports where
# they disagree." This script is that harness, run for real -- but this
# environment has no CSNOBOL4 binary installed, and installing 1970s C
# SNOBOL4 from source is out of scope for this assignment build. Rather
# than fabricate a "CSNOBOL4 disagreed here" transcript (which CLAUDE.md's
# "a missing citation beats a fabricated one" rule extends to: a missing
# binary beats a fabricated diff), this script honestly detects whether a
# CSNOBOL4 binary is available and degrades to single-interpreter mode
# when it isn't, saying so plainly rather than pretending a comparison
# happened.
#
# Usage:
#   ./scripts/diff_test.sh                    # this interpreter only
#   CSNOBOL4_BIN=/path/to/snobol4 ./scripts/diff_test.sh   # real diff mode
#
# Every *.sno file under examples/ (never error_examples/ -- those are
# deliberately malformed and are not "normal operation" programs; see
# error_examples/recovery.sno's own header comment) is run through this
# interpreter, and -- only if CSNOBOL4_BIN names an existing, executable
# file -- through that binary too, diffing the two outputs.

set -euo pipefail

cd "$(dirname "$0")/.."

echo "== building interpreter =="
dune build

exe="_build/default/bin/main.exe"
examples_dir="examples"

have_csnobol4=0
if [[ -n "${CSNOBOL4_BIN:-}" && -x "${CSNOBOL4_BIN}" ]]; then
  have_csnobol4=1
  echo "== CSNOBOL4_BIN=${CSNOBOL4_BIN} -- running in real differential mode =="
else
  echo "== CSNOBOL4_BIN is unset or not executable =="
  echo "== no real CSNOBOL4 binary is available in this environment, so this run only"
  echo "== exercises this repo's own interpreter (and still catches its own crashes)."
  echo "== set CSNOBOL4_BIN=/path/to/csnobol4 to get a genuine differential comparison."
fi

fail_count=0
example_count=0

for f in "${examples_dir}"/*.sno; do
  example_count=$((example_count + 1))
  name="$(basename "$f")"

  ours_out="$("${exe}" "$f" 2>&1)" || {
    echo "FAIL (this interpreter crashed): ${name}"
    echo "${ours_out}" | sed 's/^/    /'
    fail_count=$((fail_count + 1))
    continue
  }

  if [[ "${have_csnobol4}" -eq 1 ]]; then
    theirs_out="$("${CSNOBOL4_BIN}" "$f" 2>&1)" || {
      echo "FAIL (CSNOBOL4 crashed): ${name}"
      fail_count=$((fail_count + 1))
      continue
    }
    if [[ "${ours_out}" != "${theirs_out}" ]]; then
      echo "DISAGREEMENT: ${name}"
      diff <(echo "${ours_out}") <(echo "${theirs_out}") | sed 's/^/    /' || true
      fail_count=$((fail_count + 1))
    else
      echo "OK (agrees with CSNOBOL4): ${name}"
    fi
  else
    echo "OK (ran without crashing): ${name}"
  fi
done

echo "== ${example_count} example(s), ${fail_count} failure(s) =="
if [[ "${have_csnobol4}" -eq 0 ]]; then
  echo "== reminder: this was NOT a real differential comparison -- see above. =="
fi

exit $((fail_count > 0 ? 1 : 0))
