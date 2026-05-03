# Particle Filter & Regime Persistence

> **Layer 2 — Volatility Adaptation**  
> **File:** `lib/services/regime_detection_service.dart`, class `ParticleFilter`  
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Purpose

Adapts local volatility beyond the HMM's batch structure. Provides real-time regime tracking and a `volScale` correction applied during Monte Carlo simulation (see [monte_carlo.md](monte_carlo.md)).

---

## 2. Particle State

Each of **500 particles** carries:

| Field | Description | Init |
|-------|-------------|------|
| `regime` | Current discrete state (0, 1, or 2) | Round-robin |
| `volScale` | Multiplicative vol scaling factor | 1.0 |
| `weight` | Normalised importance weight | 1/N |

---

## 3. Update Step (per observation)

For each new log-return:

**1. Propagate:**
- Regime transition via A[old_regime][·]
- Vol evolution (mean-reverting to 1.0):
  ```
  volScale ← 0.92 × volScale + 0.08 × 1.0 + 0.03 × N(0,1)
  clamp to [0.5, 2.5]
  ```

**2. Weight (Student-t likelihood):**
```
σ_eff = σ_regime × volScale
logW = log(old_weight) + log_StudentT(r_t | μ_regime, σ_eff, ν_regime)
```
Normalise weights to sum to 1 (log-space max-subtraction for stability).

**3. Resample:**
- ESS = 1 / Σ w_i²
- If ESS < N/2 → systematic resampling, weights reset to 1/N

---

## 4. PF Window

Last 50 observations (or all if fewer). Focuses adaptation on recent market dynamics.

---

## 5. Probability Blending

Final regime probabilities combine the HMM's full-sequence view with the PF's real-time adaptation:

```
blended[s] = 0.7 × HMM_forward_prob[s] + 0.3 × PF_prob[s]
```

HMM gets majority weight (70%) since it has full-sequence context; PF (30%) adds real-time adaptation.

### Outputs

- `getRegimeProbabilities()`: weighted histogram of particle regimes
- `getVolScaleMean()`: weighted average volScale → applied as multiplier in MC sim
- `getVolScaleStd()`: uncertainty in volScale estimate

---

## 6. Regime Persistence Adjustment

**Method:** `RegimeDetectionService._persistenceAdjust()`

Boosts the diagonal of the transition matrix to prevent over-switching in simulation.

### 6.1 Regime Entropy

```
RegimeEntropy = −Σ π_k · ln(π_k)
```

Max entropy (3 states) = ln(3) ≈ 1.099. Higher entropy = more uncertain regime.

### 6.2 Persistence Boost

```
normalizedEntropy = RegimeEntropy / ln(3)
persistenceBoost = 0.10 × (1 - normalizedEntropy)
```

When the regime is certain (low entropy), self-transition probability is boosted by up to 0.10. When uncertain (entropy near max), no boost.

### 6.3 Adjusted Matrix A'

```
A'[i][i] = clamp(A[i][i] + persistenceBoost, 0, 0.98)
```

Off-diagonal entries are renormalised to preserve row sums = 1. A' is used **only** for simulation (Layer 3); the original A is stored for reporting.

---

## Configuration Constants

| Constant | Value | Location |
|----------|-------|----------|
| `nParticles` | 500 | `ParticleFilter` |
| PF window | last 50 obs | `RegimeDetectionService.detect()` |
| Resampling threshold | ESS < N/2 | `ParticleFilter.update()` |
| volScale mean-reversion | 0.92 | `ParticleFilter.update()` |
| volScale clamp | [0.5, 2.5] | `ParticleFilter.update()` |
| HMM/PF blend | 70% HMM / 30% PF | `RegimeDetectionService.detect()` |
| Persistence boost max | 0.10 | `_persistenceAdjust()` |
| A' diagonal cap | 0.98 | `_persistenceAdjust()` |
