# Clay conditions → Lean encoding

Fefferman's numbered conditions from the
[official problem statement](https://www.claymath.org/wp-content/uploads/2022/06/navierstokes.pdf),
mapped to the structures in `NavierStokes/ComparatorDefinitions.lean` (which are
byte-identical to `google-deepmind/formal-conjectures` at `8bf45ed`).

Alternative **(C)**, breakdown on ℝ³:

| Clay | Requirement | Lean | |
|---|---|---|---|
| ν, n | ν > 0, n = 3 | `(hnu : nu > 0)`, `ℝ³` | ✓ |
| — | u° smooth, divergence-free | `smooth : ContDiff ℝ ∞ u₀`, `div_free : ∀ x, ∇⬝ u₀ x = 0` | ✓ |
| (4) | \|∂^α u°(x)\| ≤ C(1+\|x\|)^−K for any α, K | `∀ m : ℕ, ∀ K : ℝ, ∃ C, ∀ x, ‖iteratedFDeriv ℝ m u₀ x‖ ≤ C / (1 + ‖x‖) ^ K` | ✓ |
| (5) | \|∂^α ∂ₜ^m f\| ≤ C(1+\|x\|+t)^−K | `iteratedFDerivWithin ℝ m (↿f) (univ ×ˢ Ici 0) (x,t) ≤ C / (1 + ‖x‖ + t) ^ K` | ✓ |
| (1) | ∂ₜu + (u·∇)u = νΔu − ∇p + f | `derivWithin (v x ·) (Ici 0) t + fderiv ℝ (v · t) x (v x t) = nu • Δ (v · t) x - gradient (p · t) x + f x t` | ✓ |
| (2) | div u = 0 for all x, t ≥ 0 | `div_free : ∀ x, ∀ t ≥ 0, ∇⬝ (v · t) x = 0` | ✓ |
| (3) | u(x,0) = u°(x) | `initial_condition : ∀ x, v x 0 = u₀ x` | ✓ |
| (6) | p, u ∈ C^∞(ℝ³ × [0,∞)) | `velocity_smooth`, `pressure_smooth : ContDiffOn ℝ ∞ … (univ ×ˢ Ici 0)` | ✓ |
| (7) | ∫\|u(x,t)\|²dx < C for all t ≥ 0 | `∃ E, ∀ t ≥ 0, (∫ x, ‖v x t‖ ^ 2) < E` | ✓ |

## Notes on individual clauses

**Equation (1).** The convective term Σⱼ uⱼ ∂uᵢ/∂xⱼ is the Jacobian applied to the
velocity, `fderiv ℝ (v · t) x (v x t)`. Signs on `νΔu`, `−∇p`, `+f` match. The time
derivative uses `derivWithin` relative to `Set.Ici 0` because Clay gives (1) on the
closed half-line t ≥ 0.

**Condition (4).** Fefferman quantifies over multi-indices α; the Lean bounds the norm
of the full `iteratedFDeriv` of order m, which controls all α with |α| = m. Equivalent
up to constants. The Lean quantifies K over ℝ rather than ℕ — strictly more general.
Since (4) is a *hypothesis the witness must satisfy*, a stronger reading makes the
theorem harder to prove, not easier.

**Condition (7), and the extra `MemLp` field.** The solution structure carries a field
beyond Fefferman's list:

```lean
integrable : ∀ t ≥ 0, MemLp (‖v · t‖) 2
```

This is a necessary repair, not a loophole. Without it, the Bochner integral of a
non-integrable function takes the junk value `0`, so `< E` would be vacuously true and
infinite-energy fields would spuriously count as solutions — making (7) toothless and
the non-existence claim *harder* than intended in a way that does not correspond to
anything Fefferman wrote. The `MemLp` field restores the intended meaning.

**Total functions, partial conditions.** In `¬ (∃ v p, …)` the fields `v : ℝ³ → ℝ → ℝ³`
and `p : ℝ³ → ℝ → ℝ` are total, defined for all t ∈ ℝ, but every condition is
restricted to t ≥ 0 and smoothness is `ContDiffOn` on `univ ×ˢ Ici 0`. Values at t < 0
are unconstrained. Faithful.

**Junk values in `divergence`.** `divergence v x = (fderiv ℝ v x).trace ℝ (ℝ^n)`, which
is `0` where `v` is not differentiable. Under the smoothness hypotheses in play the
`fderiv` is the real one.

---

Alternative **(D)**, the periodic case, adds one condition Clay does not state in (10)
or (11): `isOnePeriodic_pressure`. See the README — it weakens (D), it comes from Clay's
own errata, and it does not touch (C).
