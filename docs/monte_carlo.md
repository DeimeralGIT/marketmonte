# Monte Carlo Simulation (Layer 3)

> **Layer 3 — 10,000-Path Regime-Switching Monte Carlo with Student-t Innovations**
> **File:** `lib/services/regime_detection_service.dart` (class `RegimeAwareSimulator`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Purpose

Generates **10,000 regime-switching price paths** with Student-t heavy-tailed innovations to produce a full probability distribution of future prices. Each path tracks `maxPrice`, `minPrice`, and `maxDrawdown` for **barrier pricing** — the foundation of TP/SL probability estimation in Layer 4.

---

## 2. Architecture

The simulator (`RegimeAwareSimulator`) receives learned parameters from the HMM (Layer 1) and the persistence-adjusted transition matrix A' from the Particle Filter pipeline (Layer 2). It does not learn any parameters itself — it is purely a forward simulation engine.

```
Inputs:
  - startPrice       (current market price)
  - steps            (simulation horizon in hours, from TimePeriod)
  - regimeProbs      (blended regime probabilities for start regime sampling)
  - volScale         (weighted mean from PF)
  - regimeParams     (mu, sigma, nu per regime from HMM)
  - transitionMatrix (persistence-adjusted A')

Output:
  - List<PathResult> sorted by finalPrice (ascending)
```

---

## 3. Path Generation

### 3.1 Starting Regime

Each path samples a starting regime from the blended regime probabilities:

```
u ~ Uniform(0, 1)
cumulative = 0
for j in 0..2:
    cumulative += regimeProbs[j]
    if u <= cumulative:
        startRegime = j
        break
```

### 3.2 Per-Step Dynamics

For each time step t = 1..steps:

**Regime transition** from persistence-adjusted A':

```
u ~ Uniform(0, 1)
cumProb = 0
for j in 0..2:
    cumProb += A'[current_regime][j]
    if u <= cumProb:
        regime = j
        break
```

**Student-t innovation:**

```
mu     = regimeParams[regime].mean
sigma  = clamp(regimeParams[regime].std * volScale, 1e-8, inf)
nu     = regimeParams[regime].nu

innovation = StudentT(nu)       // see section 4
logReturn  = (mu - 0.5 * sigma^2) + sigma * innovation
price      = price * exp(logReturn)
```

The drift correction term `-0.5 * sigma^2` ensures the geometric process is unbiased (Ito correction).

### 3.3 Barrier Tracking

Each path maintains running statistics:

```
if price > maxPrice:  maxPrice = price
if price < minPrice:  minPrice = price
if price > peak:      peak = price
drawdown = (peak - price) / peak
if drawdown > maxDrawdown:  maxDrawdown = drawdown
```

These per-path extremes are used by Layer 4 for barrier probability estimation.

---

## 4. Student-t Variate Generation

Student-t random variates are generated via the **Marsaglia-Tsang gamma method** combined with **Box-Muller normal generation**:

### 4.1 Box-Muller Normal

```
u1 ~ Uniform(0, 1),  clamped to [1e-15, 1.0]
u2 ~ Uniform(0, 1)
z = sqrt(-2 * ln(u1)) * cos(2 * pi * u2)
```

### 4.2 Marsaglia-Tsang Gamma

For Gamma(shape, 1) where shape >= 1:

```
d = shape - 1/3
c = 1 / sqrt(9d)

repeat:
    repeat:
        x = Normal(0,1)
        v = 1 + c*x
    until v > 0
    v = v^3
    u ~ Uniform(0,1)

    if u < 1 - 0.0331 * x^4:
        return d * v
    if ln(u) < 0.5 * x^2 + d * (1 - v + ln(v)):
        return d * v
```

For shape < 1: `Gamma(shape) = Gamma(shape+1) * U^(1/shape)` where U ~ Uniform.

### 4.3 Student-t from Gamma

```
z   = Normal(0, 1)
chi2 = 2 * Gamma(nu/2)
T   = z * sqrt(nu / chi2)
```

This produces a standard Student-t variate with `nu` degrees of freedom. The heavier tails (compared to Normal) better capture the fat-tailed nature of crypto returns.

---

## 5. Distribution Statistics

After all 10,000 paths complete, the sorted final prices are used to compute:

| Statistic | Formula |
|-----------|---------|
| Mean | `sum(finalPrices) / N` |
| StdDev | `sqrt(sum((p - mean)^2) / N)` |
| Skewness | `sum(((p - mean)/stdDev)^3) / N` |
| Kurtosis | `sum(((p - mean)/stdDev)^4) / N` |
| Percentiles | `P_q = finalPrices[floor(N * q)]` for q in {0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95} |

These statistics are packaged into a `DistributionStats` object consumed by Layer 4 and displayed in the analysis UI.

---

## 6. PathResult Structure

Each of the 10,000 paths produces:

| Field | Type | Description |
|-------|------|-------------|
| `finalPrice` | double | Price at end of horizon |
| `maxPrice` | double | Highest price reached on path |
| `minPrice` | double | Lowest price reached on path |
| `maxDrawdown` | double | Max peak-to-trough as fraction |

The `maxPrice` and `minPrice` fields are critical for barrier pricing in Layer 4:
- **Long TP:** count paths where `maxPrice >= exitTarget`
- **Long SL:** count paths where `minPrice <= stopLoss`
- **Short TP:** count paths where `minPrice <= exitTarget`
- **Short SL:** count paths where `maxPrice >= stopLoss`

---

## 7. Outputs

| Output | Type | Consumed By |
|--------|------|-------------|
| `pathResults` | `List<PathResult>` (sorted by finalPrice) | Layer 4 (barrier pricing, conditional expectations) |
| `DistributionStats` | mean, stdDev, skew, kurt, P5-P95 | Layer 4 (stop loss calculation), UI display |

---

## 8. Why Student-t Instead of Normal

Normal (Gaussian) innovations underestimate the probability of extreme moves. Cryptocurrency returns exhibit significant excess kurtosis (fat tails). The Student-t distribution with learned nu per regime captures:

- **Low nu (e.g., 2.5-5):** Very heavy tails, more frequent extreme moves
- **High nu (e.g., 15-30):** Near-Gaussian, thin tails

The HMM M-step learns the optimal nu for each regime via grid search, allowing the simulator to match the empirical tail behavior of each volatility state.

---

## Configuration Constants

| Constant | Default | Tunable | Description |
|----------|---------|---------|-------------|
| Simulation paths | 10,000 | No | `AnalysisService._numSim` |
| Seed | 42 | No | Deterministic reproducibility |
| Innovation type | Student-t | No | Marsaglia-Tsang + Box-Muller |
| Transition matrix | A' (persistence-adjusted) | Indirectly | Via `persistenceMultiplier` |
| volScale | PF weighted mean | Indirectly | Via PF output |
| Drift correction | -0.5 * sigma^2 | No | Ito correction for unbiased GBM |
