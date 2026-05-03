# Student-t Hidden Markov Model (HMM)

> **Layer 1 — Regime Detection**  
> **File:** `lib/services/regime_detection_service.dart`, class `StudentTHMM`  
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Structure

- **3 latent states** (sorted ascending by volatility after each EM step):
  - State 0 = Low Volatility (calm, mean-reverting)
  - State 1 = Medium Volatility (trending, normal)
  - State 2 = High Volatility (crisis, turbulent)
- **Observations:** Hourly log-returns
- **Emission model:** Student-t distribution (captures fat tails)

---

## 2. Emission Model

For state k:

```
r_t ~ StudentT(μ_k, σ_k, ν_k)
```

Where:
- `μ_k` = location (drift), shrunk toward zero: `μ = (1 - λ) × raw_mean`, with λ = 0.8
- `σ_k` = scale (> 0), clamped ≥ 1e-6
- `ν_k` = degrees of freedom (> 2), controls tail heaviness

---

## 3. Student-t Log-PDF

```
log p(x | μ, σ, ν) = logΓ((ν+1)/2) - logΓ(ν/2) - 0.5·log(νπ) - log(σ)
                      - ((ν+1)/2)·log(1 + z²/ν)
where z = (x - μ) / σ
```

Log-gamma computed via **Lanczos approximation** (g=7, 9 coefficients) with reflection formula for z < 0.5.

---

## 4. Initialisation

1. Sort all observed log-returns
2. Split into 3 equal buckets → compute empirical μ, σ per bucket
3. Estimate ν from excess kurtosis: `ν = clamp(6/ExcessKurt + 4, 2.5, 50)`
4. Initial state distribution π = uniform [1/3, 1/3, 1/3]
5. Transition matrix: sticky — 0.7 diagonal, 0.15 off-diagonal

---

## 5. Baum-Welch Training (EM with ECME for ν)

**Max iterations:** 30  
**Convergence tolerance:** |ΔlogLik| < 1e-4 after ≥ 2 iterations

### E-step (log-space)

- Forward: `logα[t][s] = log P(o_1..o_t, q_t = s)` using Student-t emissions
- Backward: `logβ[t][s] = log P(o_{t+1}..o_T | q_t = s)`
- `γ[t][s]` = posterior state occupancy (via log-sum-exp normalisation)
- `ξ[t][i][j]` = transition counts (accumulated directly)

### M-step (Student-t ECME)

1. **Auxiliary weights** (from Student-t scale-mixture interpretation):
   ```
   ũ_tk = (ν_k + 1) / (ν_k + z_tk²)
   where z_tk = (r_t - μ_k) / σ_k
   ```

2. **Update μ** (with drift shrinkage):
   ```
   raw_μ_k = Σ_t γ_tk · ũ_tk · r_t / Σ_t γ_tk · ũ_tk
   μ_k = (1 - 0.8) × raw_μ_k = 0.2 × raw_μ_k
   ```

3. **Update σ**:
   ```
   σ_k² = Σ_t γ_tk · ũ_tk · (r_t - μ_k)² / Σ_t γ_tk
   σ_k = √(σ_k²), clamped ≥ 1e-6
   ```

4. **Update ν** (grid search, profile log-likelihood):
   ```
   Grid: [2.5, 3, 4, 5, 7, 10, 15, 30]
   For each ν_candidate:
     LL_k(ν) = Σ_t γ_tk · log StudentT(r_t | μ_k, σ_k, ν)
   Pick ν that maximizes LL_k
   ```

5. **State re-ordering:** After each M-step, states are sorted by ascending σ for consistent labelling.

---

## 6. Viterbi Decoding

Standard log-space Viterbi. Returns the most-likely state sequence over the observation window (used for historical regime visualisation).

---

## 7. Forward-Filtered Probabilities

`currentStateProbabilities()` returns filtered regime probabilities from the last forward time-step. Blended with Particle Filter probabilities — see [particle_filter.md](particle_filter.md#5-probability-blending).

---

## Configuration Constants

| Constant | Value | Location |
|----------|-------|----------|
| `_nStates` | 3 | `RegimeDetectionService` |
| Max iterations | 30 | `StudentTHMM.fit()` |
| Convergence tol | 1e-4 | `StudentTHMM.fit()` |
| Drift shrinkage λ | 0.8 | `StudentTHMM` |
| ν grid | [2.5, 3, 4, 5, 7, 10, 15, 30] | `StudentTHMM._nuGrid` |
