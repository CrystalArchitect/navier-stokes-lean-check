# Checking the Navier–Stokes Lean proof

An independent check of the Lean formalization OpenAI published on 8 September 2026
alongside its [claimed resolution](https://openai.com/index/navier-stokes-solution/)
of the Navier–Stokes Millennium Prize Problem.

Two questions decide whether the formalization means anything:

1. **Does the theorem say what Clay asks?**
2. **Does it actually prove?**

Both hold.

- The proved statement is Google DeepMind's pre-existing encoding of Clay
  alternative **(C)**, unmodified.
- The build kernel-checks with exit 0 and no `sorryAx`.

Target: [`openai/NavierStokesAndEuler`](https://github.com/openai/NavierStokesAndEuler).

---

## The claim under test

Fefferman's [problem statement](https://www.claymath.org/wp-content/uploads/2022/06/navierstokes.pdf)
offers four alternatives; proving any one resolves the problem. OpenAI targets **(C)**,
the breakdown case on ℝ³:

> Take ν > 0 and n = 3. Then there exist a smooth, divergence-free vector field u°(x)
> on ℝ³ and a smooth f(x,t) on ℝ³×[0,∞), satisfying (4), (5), for which there exist
> no solutions (p,u) of (1), (2), (3), (6), (7) on ℝ³×[0,∞).

Note the shape: an *existence* claim whose witness must satisfy the decay conditions,
wrapped around a *non-existence* claim about solutions. The two halves fail in opposite
directions — a too-weak decay condition on the witness makes the theorem easier, and so
does a too-strong requirement on the solutions being ruled out.

## Check one — statement fidelity

This is where a formalized proof usually goes wrong: the Lean theorem is internally
valid but states something weaker than the prose claims. Here the architecture
forecloses it, because **the definitions are not OpenAI's**.

They are copied from Google DeepMind's
[formal-conjectures](https://github.com/google-deepmind/formal-conjectures), pinned at
commit `8bf45ed` — written as an open challenge before any proof existed.

`evidence/definitions.diff` is the complete diff of OpenAI's
`NavierStokes/ComparatorDefinitions.lean` against that upstream file:

```
import FormalConjecturesUtil        →  import Mathlib
namespace NavierStokes             →  namespace NavierStokes.Comparator
notation "∇⬝"                      →  local notation "∇⬝"
@[category API, AMS 35]            →  (stripped)
theorems (A)–(D) with `sorry`      →  (removed)
module docstring                   →  rewritten
```

Zero mathematical edits. Every structure — `InitialVelocityConditionDecay`,
`ForceConditionDecay`, `NavierStokesExistenceAndSmoothness`, `…Rn`, `…Periodic` — is
byte-identical to upstream.

The proved theorem statement is character-identical to upstream's stubbed (C) apart
from the dropped attribute:

```lean
theorem navier_stokes_breakdown_R3 (nu : ℝ) (hnu : nu > 0) :
    ∃ (u₀ : ℝ³ → ℝ³) (f : ℝ³ → ℝ → ℝ³),
    InitialVelocityConditionDecay u₀ ∧ ForceConditionDecay f ∧
    ¬ (∃ v p, NavierStokesExistenceAndSmoothnessRn nu u₀ f v p)
```

The definitions the *proof* imports are byte-identical (one trailing newline apart) to
those in the *challenge reference* file, so the adapter cannot be satisfying a lookalike
structure.

Clause-by-clause mapping of Fefferman's conditions to their Lean encodings:
[`evidence/clay-conditions.md`](evidence/clay-conditions.md).

## Check two — kernel validity

Statement fidelity is worthless if the proof does not compile, and a compiling proof is
worthless if a `sorry` hides in its dependency graph. Lean reports both.

Built from source on macOS, 10 cores. Full non-progress output in
`evidence/build-summary.log`:

```
info: NavierStokes/ComparatorSolution.lean:31:0:
  'NavierStokes.Comparator.navier_stokes_breakdown_R3'
  depends on axioms: [propext, Classical.choice, Quot.sound]

info: NavierStokes/ComparatorSolution.lean:32:0:
  'NavierStokes.Comparator.navier_stokes_breakdown_periodic'
  depends on axioms: [propext, Classical.choice, Quot.sound]

Build completed successfully (11251 jobs).
```

Those three are the standard axioms of Lean's classical foundation: propositional
extensionality, choice, and soundness of quotients. The absence that matters is
**`sorryAx`** — the axiom Lean inserts wherever a `sorry` stands, which propagates to
every theorem downstream. It is not there. The Euler theorems report the same three.

### The four sorry warnings

The build emitted exactly four warnings, all `declaration uses 'sorry'`, all inside
`ComparatorChallenges/`. Those are the stubbed reference statements — Comparator's
method is to compare a proved theorem's type against a statement that deliberately
carries no proof. Nothing outside those two files uses `sorry`, and
`ComparatorSolution.lean` never imports the challenge module, which is why the axiom
lists above come back clean.

Across 11,251 jobs, those four warnings and four info lines were the entire
non-progress output.

## One judgment call, in (D) rather than (C)

The periodic solution structure requires **pressure** periodicity
(`isOnePeriodic_pressure`), which Clay's conditions (10) and (11) do not state. It comes
from the errata appended to the problem PDF:

> The further condition p(x + eⱼ, t) = p(x, t) should be made explicit in Eqn (8).

Direction matters. For a *breakdown* claim, adding a requirement to the solution
**weakens** the result — you rule out a smaller class. And the class genuinely shrinks:
periodic-velocity flows driven by a constant pressure gradient have non-periodic
pressure. So (D) as formalized is slightly weaker than a hyper-literal reading of
Clay (D).

Two things defuse it. The choice is DeepMind's, not OpenAI's, and it follows Clay's own
errata. More decisively: proving any one of (A)–(D) resolves the problem, and **(C) on
ℝ³ carries no analogous condition**. The headline claim rests on (C).

## What this establishes, and what it doesn't

| | |
|---|---|
| **Settled** | The theorem states Clay alternative (C). Byte-level diff against formal-conjectures at `8bf45ed`, authored before the proof existed. |
| **Settled** | Lean's kernel accepts the proof. 11,251 jobs, exit 0, no `sorryAx`, only the three standard classical axioms. |
| **Not run** | Independent kernel replay through nanoda. Comparator needs `landrun`, which wraps the Landlock LSM and is Linux-only. It hedges against a bug in Lean's own kernel — a far more exotic failure than the two above. |
| **Out of scope** | Whether the prose paper's argument is correct. A separate question from whether the Lean development proves the Lean statement. |

The two failure modes people actually worry about with machine-generated proofs are a
`sorry` hiding in a dependency and a theorem statement that quietly says less than the
announcement. Both are ruled out. The Lean development proves Clay alternative (C) for
every ν > 0, with initial velocity identically zero and a smooth, compactly-supported
forcing — a fluid that starts at rest and is driven to blow up in finite time.

Note that `formalization.yaml` in the OpenAI repo records its own review status as
`self-assessed`.

## Reproducing

```sh
./repro.sh
```

Or by hand — see [`repro.sh`](repro.sh) for the full sequence.

## Sources

- [OpenAI announcement](https://openai.com/index/navier-stokes-solution/)
- [openai/NavierStokesAndEuler](https://github.com/openai/NavierStokesAndEuler) — the Lean formalization
- [Fefferman, official Clay problem statement](https://www.claymath.org/wp-content/uploads/2022/06/navierstokes.pdf)
- [google-deepmind/formal-conjectures](https://github.com/google-deepmind/formal-conjectures) — the independent statement encoding

## License

The write-up and evidence files here are MIT. The upstream Lean sources they quote are
Apache-2.0 (Formal Conjectures Authors / OpenAI); `evidence/definitions.diff` contains
excerpts of both and is redistributed under Apache-2.0.
