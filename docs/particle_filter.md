# Volatility Adaptation (Layer 2)

> **Layer 2 — 500-Particle Sequential Monte Carlo Filter**
> **File:** `lib/services/regime_detection_service.dart` (class `ParticleFilter`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Purpose

Tracks real-time volatility evolution using a **500-particle Sequential Monte Carlo** (SMC) filter. Each particle carries a regime state and a mean-reverting volatility scale factor (volScale). The filter produces a weighted volScale estimate and refined regime probabilities that are blended with HMM output for the final regime decision.

---

## 2. Particle State

Each of the 500 particles maintains:

| Field | Type | Description |
|-------|------|-------------|
| `regime` | int (0/1/2) | Current regime assignment |
| `volScale` | double [0.5, 2.5] | Local volatility scaling factor |
| `weight` | double | Importance weight (sums to 1.0 across all particles) |

All particles are initialized with `regime = i % 3` (round-robin), `volScale = 1.0`, and `weight = 1/N`.

---

## 3. Update Cycle

For each new observation (log-return), every particle undergoes three steps:

### 3.1 Propagation

**Regime transition:** Sample a new regime from the HMM transition matrix row:

```
u ~ Uniform(0, 1)
cumProb = 0
for j in 0..2:
    cumProb += A[current_regime][j]
    if u <= cumProb:
        regime = j
        break
```

**VolScale evolution (mean-reverting random walk):**

```
volScale = clamp(0.92 * volScale + 0.08 * 1.0 + 0.03 * N(0,1),  0.5,  2.5)
```

Where:
- `0.92` = autoregressive decay toward the mean
- `0.08` = mean-reversion pull toward 1.0
- `0.03 * N(0,1)` = stochastic innovation

This ensures volScale slowly reverts toward 1.0 (neutral) while allowing it to drift with market conditions.

### 3.2 Weighting

Each particle's weight is updated using the **Student-t log-likelihood** of the observation under the particle's current regime and volScale:

```
mu = regimeMeans[regime]
sigma = clamp(regimeStds[regime] * volScale, 1e-8, inf)
nu = regimeNus[regime]

logW = log(old_weight) + logStudentT(observation, mu, sigma, nu)
```

Log-weights are shifted by max(logW) before exponentiation (log-sum-exp trick for numerical stability), then normalized to sum to 1.0.

### 3.3 Systematic Resampling

Triggered when the **Effective Sample Size** (ESS) drops below N/2 = 250:

```
ESS = 1 / sum(w_i^2)
```

When ESS < 250, systematic resampling is performed:

```
step = 1/N
u = Uniform(0, step)    // single random offset
for i in 0..N-1:
    find particle j such that CDF[j] >= u
    copy particle j with weight = 1/N
    u += step
```

This prevents particle degeneracy while maintaining diversity in the population.

---

## 4. Outputs

### 4.1 Weighted Mean VolScale

```
volScale = sum(w_i * volScale_i)     for all particles
```

Consumed by Layer 3 (MC simulation scaling) and Layer 4 (exit target adaptation). Typical range [0.5, 2.5]:

- **volScale > 1.0:** Recent volatility exceeds the HMM's learned regime sigma — wider exits and stops
- **volScale < 1.0:** Recent volatility is below regime sigma — tighter exits and stops
- **volScale ~ 1.0:** Neutral, no adaptation needed

### 4.2 Regime Probabilities

```
pfProbs[s] = sum(w_i)     for particles where regime == s
```

These are blended with HMM forward-filtered probabilities (70/30) in `RegimeDetectionService.detect()` to produce the final regime decision.

### 4.3 VolScale Standard Deviation

```
volScaleStd = sqrt(sum(w_i * (volScale_i - meanVolScale)^2))
```

Available as a diagnostic measure of volScale uncertainty across the particle population.

---

## 5. Persistence Boost

Computed from the blended regime probabilities (not directly by the Particle Filter, but in the `RegimeDetectionService`):

```
H = -sum(p_s * ln(p_s))    for s in {0, 1, 2}
normalizedEntropy = H / ln(3)
persistenceBoost = persistenceMultiplier * (1 - normalizedEntropy)
```

Where `persistenceMultiplier` defaults to **0.10** (tunable via `AlgorithmConfig.persistenceMultiplier`).

- **Certain regime** (low entropy): `persistenceBoost` approaches 0.10
- **Uncertain regime** (high entropy, near-uniform): `persistenceBoost` approaches 0.00

The persistence boost modifies the HMM transition matrix diagonal to create the sticky matrix A' consumed by the MC simulator (see [hmm.md section 8](hmm.md#8-entropy-and-persistence-adjustment)).

---

## 6. Particle Filter Window

The filter processes the **last 50 log-returns** (or all returns if fewer than 50 are available). This sliding window keeps the filter responsive to recent market conditions without being overwhelmed by older data.

The PF is run twice in the pipeline:
1. Inside `RegimeDetectionService.detect()` — for blended regime probabilities and persistence
2. Inside `AnalysisService._runHybridEngine()` — for the volScale estimate consumed by MC and trade construction

Both use seed 42 for reproducibility.

---

## 7. Interaction with HMM

The Particle Filter receives its regime parameters (means, stds, nus) and transition matrix from the Student-t HMM (Layer 1). It does **not** learn its own emission parameters — it uses the HMM's learned values and adds the volScale adaptation layer on top.

```
HMM learns: mu_s, sigma_s, nu_s, A    (from full data via Baum-Welch)
PF uses:    A for regime transitions
            mu_s, sigma_s * volScale_i, nu_s    for Student-t weighting
```

---

## Configuration Constants

| Constant | Default | Tunable | Description |
|----------|---------|---------|-------------|
| Particles (N) | 500 | No | Particle count |
| Mean reversion decay | 0.92 | No | AR(1) coefficient for volScale |
| Mean reversion target | 1.0 | No | Long-run volScale mean |
| Innovation noise | 0.03 | No | Stochastic volScale perturbation |
| volScale clamp | [0.5, 2.5] | Yes | `AlgorithmConfig.volScaleMin/Max` |
| Resampling threshold | ESS < N/2 | No | Systematic resampling trigger |
| Persistence multiplier | 0.10 | Yes | `AlgorithmConfig.persistenceMultiplier` |
| Window size | last 50 returns | No | Sliding window for PF input |
| Blending ratio | 70% HMM / 30% PF | No | Regime probability blending |
| Seed | 42 | No | Deterministic reproducibility |
