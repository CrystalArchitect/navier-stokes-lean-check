#!/usr/bin/env bash
# Reproduce the two checks in this repo against openai/NavierStokesAndEuler.
#
#   ./repro.sh            # both checks
#   ./repro.sh diff       # statement fidelity only (fast, no Lean needed)
#   ./repro.sh build      # kernel validity only (slow, needs elan)
#
# Check one takes seconds. Check two compiles ~616k lines of Lean on top of a
# cached Mathlib; budget an hour or two and ~10 GB of disk.

set -euo pipefail

UPSTREAM_COMMIT=8bf45ed70d48b2b2a501de9c00b26bfa38c573ee
WORK=${WORK:-$(pwd)/work}
MODE=${1:-all}

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d NavierStokesAndEuler ]; then
  git clone --depth 1 https://github.com/openai/NavierStokesAndEuler.git
fi

# ---------------------------------------------------------------- check one
if [ "$MODE" = all ] || [ "$MODE" = diff ]; then
  echo "=== Check one: statement fidelity ==="

  curl -fsSL \
    "https://raw.githubusercontent.com/google-deepmind/formal-conjectures/${UPSTREAM_COMMIT}/FormalConjectures/Millenium/NavierStokes.lean" \
    -o upstream_ns.lean

  # Expect: only import/namespace/attribute/notation changes and the removal of
  # the four sorry-stubbed challenge theorems. No mathematical edits.
  diff -u upstream_ns.lean \
    NavierStokesAndEuler/NavierStokes/ComparatorDefinitions.lean \
    > definitions.diff || true
  echo "wrote definitions.diff ($(grep -c '' definitions.diff) lines)"

  # The definitions the proof imports must match the challenge reference exactly,
  # or the adapter could be satisfying a lookalike structure.
  python3 - <<'PY'
import pathlib
def body(p):
    s = pathlib.Path(p).read_text(encoding="utf-8")
    i = s.index("namespace NavierStokes.Comparator")
    j = s.index("/-- (C) Breakdown")
    return s[i:j].rstrip()
a = body("NavierStokesAndEuler/NavierStokes/ComparatorDefinitions.lean")
b = body("NavierStokesAndEuler/ComparatorChallenges/NavierStokes.lean")
print("proof-side definitions == challenge reference:", a == b)
PY

  echo "--- sorry outside the challenge reference files (expect none) ---"
  grep -rn --include='*.lean' '\bsorry\b' NavierStokesAndEuler \
    | grep -v ComparatorChallenges || echo "none"
fi

# ---------------------------------------------------------------- check two
if [ "$MODE" = all ] || [ "$MODE" = build ]; then
  echo "=== Check two: kernel validity ==="

  command -v elan >/dev/null || {
    echo "elan not found — install from https://github.com/leanprover/elan" >&2
    exit 1
  }

  cd NavierStokesAndEuler
  elan toolchain install "$(cat lean-toolchain)"
  lake exe cache get                       # ~8,747 Mathlib artifacts
  lake build 2>&1 | tee ../build.log

  echo "--- non-progress output ---"
  grep -v '^✔' ../build.log

  # ComparatorSolution.lean already ends with #print axioms on both theorems.
  # Expect exactly [propext, Classical.choice, Quot.sound] and no sorryAx.
  echo "--- sorryAx (expect none) ---"
  grep -i sorryAx ../build.log || echo "none"
fi

# ------------------------------------------------------------- not runnable
# Comparator's independent kernel replay needs landrun, lean4export and
# nanoda_bin on PATH. landrun wraps the Landlock LSM and is Linux-only, so this
# step does not run on macOS:
#
#   lake exe comparator ComparatorChallenges/NavierStokes.json
#   lake exe comparator ComparatorChallenges/Euler.json
