# Monte Carlo Simulation & Forecast Distribution

> **Layer 3 — Sticky Regime Path Simulation**  
> **File:** `lib/services/regime_detection_service.dart`, class `RegimeAwareSimulator`  
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Settings

- **Paths:** 10,000 (`_numSim`)
- **Horizon:** `period.hours` steps (1, 4, 24, 168, or 720)
- **Simulation space:** log-price (GBM with Student-t innovations)
- **Transition matrix:** persistence-adjusted A' (see [particle_filter.md](particle_filter.md#6-regime-persistence-adjustment))
- **Seed:** 42 (deterministic)

---

## 2. Initial Regime

For each path, sample starting regime from `blended_probs` (see [particle_filter.md](particle_filter.md#5-probability-blending)).

---

## 3. Per-Step Simulation

```
For each path, for t = 1 to steps:
    1. Sample next regime from A'[current_regime][·]
    2. σ_eff = σ_regime × volScale (PF correction)
    3. z ~ StudentT(ν_regime) via:
       z_normal ~ N(0,1) via Box-Muller
       chi2 ~ 2 × Gamma(ν/2, 1) via Marsaglia-Tsang
       z = z_normal × √(ν / chi2)
    4. logReturn = (μ_regime - 0.5·σ_eff²) + σ_eff · z  (Itô-corrected)
    5. price *= exp(logReturn)
```

---

## 4. Path Tracking

Per-path statistics tracked during simulation:

| Statistic | Description |
|-----------|-------------|
| `finalPrice` | Price at end of horizon |
| `maxPrice` | Highest price reached during path |
| `minPrice` | Lowest price reached during path |
| `maxDrawdown` | Maximum peak-to-trough fraction |

These enable **barrier pricing** — using the full path, not just the endpoint (see [trade_construction.md](trade_construction.md#3-barrier-probabilities)).

---

## 5. Gamma Random Sampling (Marsaglia-Tsang)

For shape ≥ 1:
```
d = shape - 1/3
c = 1 / √(9d)
repeat:
  x ~ N(0,1)
  v = (1 + cx)³
  if v > 0 and log(U) < 0.5x² + d(1 - v + log(v)):
    return d × v
```

For shape < 1: `Gamma(α) = Gamma(α+1) × U^(1/α)`.

---

## 6. Output

`List<PathResult>` sorted by `finalPrice` ascending (for efficient percentile extraction).

---

## 7. Forecast Distribution

From the 10,000 `finalPrice` values, compute:

| Statistic | Description |
|-----------|-------------|
| P5, P10, P25, P50, P75, P90, P95 | Percentiles |
| Mean | Average simulated price |
| StdDev | Standard deviation |
| Skewness | Third standardised moment |
| Kurtosis | Fourth standardised moment (raw, not excess) |

All stored in `DistributionStats` and attached to `CryptoAnalysisResult`.

---

## Configuration Constants

| Constant | Value | Location |
|----------|-------|----------|
| `_numSim` | 10,000 | `AnalysisService` |
| Random seed | 42 | Multiple locations |
