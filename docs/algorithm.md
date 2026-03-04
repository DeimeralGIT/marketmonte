# Market Monte — Algorithm Reference

> **Last updated:** 2026-03-04  
> **Purpose:** Complete technical description of the probabilistic regime-switching trading engine. Use this document to review, audit, or discuss the algorithm with any LLM or collaborator.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)  
2. [Data Pipeline](#2-data-pipeline)  
3. [Hidden Markov Model (Student-t HMM)](#3-hidden-markov-model-student-t-hmm)  
4. [Particle Filter (Volatility Adaptation)](#4-particle-filter-volatility-adaptation)  
5. [Regime Persistence Adjustment](#5-regime-persistence-adjustment)  
6. [Monte Carlo Simulation (Path-Aware)](#6-monte-carlo-simulation-path-aware)  
7. [Forecast Distribution](#7-forecast-distribution)  
8. [Trade Direction Logic](#8-trade-direction-logic)  
9. [Trade Construction (Long / Short)](#9-trade-construction-long--short)  
10. [Barrier Probabilities](#10-barrier-probabilities)  
11. [Expected Value](#11-expected-value)  
12. [Position Sizing (Kelly Criterion)](#12-position-sizing-kelly-criterion)  
13. [Trade Acceptance Filter](#13-trade-acceptance-filter)  
14. [Cross-Asset Selection (Leaderboard)](#14-cross-asset-selection-leaderboard)  
15. [Risk Controls](#15-risk-controls)  
16. [Configuration Constants](#16-configuration-constants)  
17. [Data Models](#17-data-models)  
18. [File Map](#18-file-map)  
19. [Changelog](#19-changelog)  

---

## 1. Architecture Overview

The engine is a **four-layer probabilistic pipeline**:

```
Raw hourly candles (Binance API)
        │
        ▼
  ┌──────────────────────────────────┐
  │  Layer 1: Regime Detection       │  Student-t HMM (Baum-Welch EM)
  │  (3 latent states, fat tails)    │  Viterbi decoding, log-space fwd/bwd
  └──────────────┬───────────────────┘
                 │ learned params {μ,σ,ν} + transition matrix A
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 2: Volatility Adaptation  │  500 particles, systematic resampling
  │  (Particle Filter)               │  volScale evolution, Student-t weights
  └──────────────┬───────────────────┘
                 │ blended regime probs + volScale
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 3: Sticky Regime MC Sim   │  10,000 paths, Student-t innovations
  │  (State-Space with persistence)  │  Full path tracking: max/min/drawdown
  └──────────────┬───────────────────┘
                 │ List<PathResult> sorted by finalPrice
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 4: EV-Optimized Trades    │  Barrier pricing, Kelly sizing
  │  (Long + Short positions)        │  EV filter, entropy-penalized ranking
  └──────────────────────────────────┘
```

**Philosophy:** This engine does not predict price. It prices probabilistic opportunity under regime uncertainty. All trades must satisfy positive expected value under realistic execution assumptions.

---

## 2. Data Pipeline

### 2.1 Market Data

- **Source:** Configurable exchange via `ExchangeService` abstraction — Binance, Coinbase, or MEXC public REST APIs (no auth required)
- **Timeframe:** 1H candles
- **Rolling training window:** 168 hours minimum (1 week)
- **Fields used:** Close price
- **Assets:** Top N USDT pairs by 24h volume (configurable, default 10)

### 2.2 Return Transformation

Hourly log-returns:

```
r_t = ln(P_t / P_{t-1})
```

Fed directly into the HMM — no smoothing applied.

### 2.3 Kline Limit Scaling

```
limit = period.hours ≤ 24 ? 168 : clamp(period.hours × 2, 168, 720)
```

---

## 3. Hidden Markov Model (Student-t HMM)

**File:** `lib/services/regime_detection_service.dart`, class `StudentTHMM`

### 3.1 Structure

- **3 latent states** (sorted ascending by volatility after each EM step):
  - State 0 = Low Volatility (calm, mean-reverting)
  - State 1 = Medium Volatility (trending, normal)
  - State 2 = High Volatility (crisis, turbulent)
- **Observations:** Hourly log-returns
- **Emission model:** Student-t distribution (captures fat tails)

### 3.2 Emission Model

For state k:

```
r_t ~ StudentT(μ_k, σ_k, ν_k)
```

Where:
- `μ_k` = location (drift), shrunk toward zero: `μ = (1 - λ) × raw_mean`, with λ = 0.8
- `σ_k` = scale (> 0), clamped ≥ 1e-6
- `ν_k` = degrees of freedom (> 2), controls tail heaviness

### 3.3 Student-t Log-PDF

```
log p(x | μ, σ, ν) = logΓ((ν+1)/2) - logΓ(ν/2) - 0.5·log(νπ) - log(σ)
                      - ((ν+1)/2)·log(1 + z²/ν)
where z = (x - μ) / σ
```

Log-gamma computed via **Lanczos approximation** (g=7, 9 coefficients) with reflection formula for z < 0.5.

### 3.4 Initialisation

1. Sort all observed log-returns
2. Split into 3 equal buckets → compute empirical μ, σ per bucket
3. Estimate ν from excess kurtosis: `ν = clamp(6/ExcessKurt + 4, 2.5, 50)`
4. Initial state distribution π = uniform [1/3, 1/3, 1/3]
5. Transition matrix: sticky — 0.7 diagonal, 0.15 off-diagonal

### 3.5 Baum-Welch Training (EM with ECME for ν)

**Max iterations:** 30  
**Convergence tolerance:** |ΔlogLik| < 1e-4 after ≥ 2 iterations

**E-step (log-space):**
- Forward: `logα[t][s] = log P(o_1..o_t, q_t = s)` using Student-t emissions
- Backward: `logβ[t][s] = log P(o_{t+1}..o_T | q_t = s)`
- `γ[t][s]` = posterior state occupancy (via log-sum-exp normalisation)
- `ξ[t][i][j]` = transition counts (accumulated directly)

**M-step (Student-t ECME):**

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

### 3.6 Viterbi Decoding

Standard log-space Viterbi. Returns the most-likely state sequence over the observation window (used for historical regime visualisation).

### 3.7 Forward-Filtered Probabilities

`currentStateProbabilities()` returns filtered regime probabilities from the last forward time-step. Blended with PF probs (see §4.5).

---

## 4. Particle Filter (Volatility Adaptation)

**File:** `lib/services/regime_detection_service.dart`, class `ParticleFilter`

### 4.1 Purpose

Adapts local volatility beyond the HMM's batch structure. Provides real-time regime tracking and a `volScale` correction applied during simulation (§6).

### 4.2 Particle State

Each of **500 particles** carries:

| Field | Description | Init |
|-------|-------------|------|
| `regime` | Current discrete state (0, 1, or 2) | Round-robin |
| `volScale` | Multiplicative vol scaling factor | 1.0 |
| `weight` | Normalised importance weight | 1/N |

### 4.3 Update Step (per observation)

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

### 4.4 PF Window

Last 50 observations (or all if fewer). Focuses adaptation on recent market dynamics.

### 4.5 Outputs

- `getRegimeProbabilities()`: weighted histogram of particle regimes
- `getVolScaleMean()`: weighted average volScale → applied as multiplier in MC sim
- `getVolScaleStd()`: uncertainty in volScale estimate

### 4.6 Probability Blending

Final regime probabilities:
```
blended[s] = 0.7 × HMM_forward_prob[s] + 0.3 × PF_prob[s]
```
HMM gets majority weight (70%) since it has full-sequence context; PF (30%) adds real-time adaptation.

---

## 5. Regime Persistence Adjustment

**File:** `lib/services/regime_detection_service.dart`, `RegimeDetectionService._persistenceAdjust()`

Boosts the diagonal of the transition matrix to prevent over-switching in simulation.

### 5.1 Regime Entropy

```
RegimeEntropy = −Σ π_k · ln(π_k)
```

Max entropy (3 states) = ln(3) ≈ 1.099. Higher entropy = more uncertain regime.

### 5.2 Persistence Boost

```
normalizedEntropy = RegimeEntropy / ln(3)
persistenceBoost = 0.10 × (1 - normalizedEntropy)
```

When the regime is certain (low entropy), self-transition probability is boosted by up to 0.10. When uncertain (entropy near max), no boost.

### 5.3 Adjusted Matrix A'

```
A'[i][i] = clamp(A[i][i] + persistenceBoost, 0, 0.98)
```

Off-diagonal entries are renormalised to preserve row sums = 1. A' is used **only** for simulation (Layer 3); the original A is stored for reporting.

---

## 6. Monte Carlo Simulation (Path-Aware)

**File:** `lib/services/regime_detection_service.dart`, class `RegimeAwareSimulator`

### 6.1 Settings

- **Paths:** 10,000 (`_numSim`)
- **Horizon:** `period.hours` steps (1, 4, 24, 168, or 720)
- **Simulation space:** log-price (GBM with Student-t innovations)
- **Transition matrix:** persistence-adjusted A'
- **Seed:** 42 (deterministic)

### 6.2 Initial Regime

For each path, sample starting regime from `blended_probs`.

### 6.3 Per-Step Simulation

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

### 6.4 Path Tracking

Per-path statistics tracked during simulation:

| Statistic | Description |
|-----------|-------------|
| `finalPrice` | Price at end of horizon |
| `maxPrice` | Highest price reached during path |
| `minPrice` | Lowest price reached during path |
| `maxDrawdown` | Maximum peak-to-trough fraction |

These enable **barrier pricing** (§10) — using the full path, not just the endpoint.

### 6.5 Gamma Random Sampling (Marsaglia-Tsang)

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

### 6.6 Output

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

## 8. Trade Direction Logic

```
if P50 ≥ currentPrice → build LONG positions
if P50 < currentPrice → build SHORT positions
```

If the chosen direction produces no valid trades (negative EV), the engine falls back to `forceInclude = true` to return informational positions.

---

## 9. Trade Construction (Long / Short)

**File:** `lib/services/analysis_service.dart`, method `_buildDirectionalPositions()`

Two positions per direction: **conservative** and **aggressive**.

### 9.1 Long Entry

```
entry = currentPrice × (1 − entryDiscount)
```

Discount = `baseDiscount × periodScale`, clamped.

### 9.2 Short Entry

```
entry = currentPrice × (1 + entryPremium)
```

Premium = `baseDiscount × periodScale`, clamped.

### 9.3 Regime Base Discounts (24h calibration)

| Regime | Conservative | Aggressive |
|--------|-------------|------------|
| Low Vol (0) | 0.15% | 0.40% |
| Med Vol (1) | 0.30% | 0.70% |
| High Vol (2) | 0.50% | 1.20% |

### 9.4 Period Scaling

```
periodScale = clamp(√(hours / 24), 0.25, 3.0)
```

### 9.5 Exit — Conditional Expectation

**Long:**
```
exit = E[finalPrice | finalPrice ≥ entry]
     = mean of all paths with finalPrice ≥ entry
```

**Short:**
```
exit = E[finalPrice | finalPrice ≤ entry]
     = mean of all paths with finalPrice ≤ entry
```

Fallback (< 10 qualifying paths): `entry × (1 ± baseDiscount × 3)`.

Safety floors: long exit ≥ entry × 1.001; short exit ≤ entry × 0.999.

### 9.6 Stop Loss

```
Long:  stop = entry − k × StdDev_distribution
Short: stop = entry + k × StdDev_distribution
```

Where k = 1.5 (`_slMultiplier`).

---

## 10. Barrier Probabilities

Uses **full path max/min** — a path can hit TP even if it doesn't end there.

**Long:**
```
TP_prob = count(maxPrice ≥ exit) / N
SL_prob = count(minPrice ≤ stop) / N
```

**Short:**
```
TP_prob = count(minPrice ≤ exit) / N
SL_prob = count(maxPrice ≥ stop) / N
```

These are the true barrier-hit frequencies from 10,000 simulated paths, not endpoint statistics.

---

## 11. Expected Value

```
TP_gain = |exit − entry|
SL_loss = |entry − stop|

EV = TP_prob × TP_gain − SL_prob × SL_loss
```

Adjusted for execution costs:
```
transactionCost = 0.2% of price  (2 × 0.1% taker fee)
slippage = 0.05% of price

EV_adj = EV − price × (0.002 + 0.0005)
```

Positions are ranked by `EV_adj` descending.

---

## 12. Position Sizing (Kelly Criterion)

```
f* = (TP_prob × TP_gain − SL_prob × SL_loss) / SL_loss
```

Use half-Kelly for safety:
```
positionSize = clamp(0.5 × f*, 0%, 5%)
```

Cap at 5% of capital maximum.

---

## 13. Trade Acceptance Filter

A position is **rejected** (not shown) unless:

```
EV_adj > 0   AND   TP_prob ≥ 0.40
```

If no positions pass the filter for either direction, the engine falls back to `forceInclude = true` and shows informational positions.

---

## 14. Cross-Asset Selection (Leaderboard)

**File:** `lib/services/analysis_service.dart`, method `scanTopMarket()`

1. Fetch top 10 USDT pairs by 24h volume
2. Run full hybrid engine on each pair (168h hourly candles)
3. Take #1 position from each pair
4. **Entropy-penalized ranking:**
   ```
   score = EV_adj × (1 − RegimeEntropy / ln(3))
   ```
   Pairs with uncertain regime identification are penalized.
5. Return top 3 as `LeadPosition` objects
6. Report market-wide regime distribution

---

## 15. Risk Controls

### Implemented

- **Trade rejection:** EV ≤ 0 or TP_prob < 40% → trade not shown
- **Position cap:** Max 5% capital per trade (Kelly cap)
- **Stop loss:** Every position has an explicit SL price
- **Regime entropy awareness:** High-entropy (uncertain) regimes produce conservative signals

### Future (Not Yet Implemented)

- Disable trading if volScale_std is extreme
- Daily / weekly loss caps
- Spread and volume minimums
- Walk-forward validation (sliding window backtesting)
- Calibration monitoring (predicted vs realised TP frequency)

---

## 16. Configuration Constants

| Constant | Value | Location |
|----------|-------|----------|
| `_numSim` | 10,000 | `AnalysisService` |
| `nParticles` | 500 | `ParticleFilter` |
| `_nStates` | 3 | `RegimeDetectionService` |
| HMM max iterations | 30 | `StudentTHMM.fit()` |
| HMM convergence tol | 1e-4 | `StudentTHMM.fit()` |
| Drift shrinkage λ | 0.8 | `StudentTHMM` |
| ν grid | [2.5, 3, 4, 5, 7, 10, 15, 30] | `StudentTHMM._nuGrid` |
| PF window | last 50 obs | `RegimeDetectionService.detect()` |
| PF resampling threshold | ESS < N/2 | `ParticleFilter.update()` |
| PF volScale mean-reversion | 0.92 | `ParticleFilter.update()` |
| PF volScale clamp | [0.5, 2.5] | `ParticleFilter.update()` |
| HMM/PF blend | 70% HMM / 30% PF | `RegimeDetectionService.detect()` |
| Persistence boost max | 0.10 | `_persistenceAdjust()` |
| A' diagonal cap | 0.98 | `_persistenceAdjust()` |
| SL multiplier k | 1.5 | `AnalysisService._slMultiplier` |
| Transaction cost | 0.2% | `AnalysisService._txCost` |
| Slippage | 0.05% | `AnalysisService._slippage` |
| Kelly fraction | 0.5 (half-Kelly) | `AnalysisService._kellyFraction` |
| Max position size | 5% | `AnalysisService._maxPositionSize` |
| Min TP probability | 40% | `AnalysisService._minTpProb` |
| Random seed | 42 | Multiple locations |
| Min candles | 168 (1 week hourly) | `AnalysisService.analyzePair()` |

---

## 17. Data Models

**File:** `lib/models/analysis_models.dart`

### TimePeriod (enum)

| Value | Label | Hours |
|-------|-------|-------|
| oneHour | 1H | 1 |
| fourHours | 4H | 4 |
| oneDay | 1D | 24 |
| oneWeek | 1W | 168 |
| oneMonth | 1M | 720 |

### VolatilityRegime (enum)

| Value | Label | Description |
|-------|-------|-------------|
| low | Low Volatility | Calm / Mean-Reverting |
| medium | Medium Volatility | Trending / Normal |
| high | High Volatility | Turbulent / Crisis |

### TradeDirection (enum)

| Value | Label |
|-------|-------|
| long | Long |
| short | Short |

### RegimeInfo

| Field | Type | Description |
|-------|------|-------------|
| currentRegime | VolatilityRegime | Most likely regime |
| regimeProbs | List\<double\> | Probability per regime [low, med, high] |
| regimeAnnualisedVols | List\<double\> | Annualised vol per regime (%) |
| regimeDrifts | List\<double\> | Hourly drift per regime |
| regimeNus | List\<double\> | Student-t ν per regime |
| transitionFromCurrent | List\<double\> | Transition probs from current regime |
| stabilityScore | int | Self-transition prob × 100 (0–100) |
| regimeEntropy | double | −Σ π_k ln(π_k), higher = more uncertain |

### DistributionStats

| Field | Type | Description |
|-------|------|-------------|
| mean | double | Mean simulated price |
| stdDev | double | Std dev of simulated prices |
| skewness | double | Third standardised moment |
| kurtosis | double | Fourth standardised moment |
| p5..p95 | double | Distribution percentiles |

### TradingPosition

| Field | Type | Description |
|-------|------|-------------|
| direction | TradeDirection | Long or Short |
| entryPrice | double | Limit entry price |
| exitPrice | double | Take profit target |
| stopLoss | double | Stop loss price |
| predictedROI | double | (exit-entry)/entry × 100 |
| confidenceScore | int | TP barrier probability as % (5–95) |
| tpProbability | double | Fraction of paths hitting TP (barrier) |
| slProbability | double | Fraction of paths hitting SL (barrier) |
| expectedValue | double | EV_adj in $ terms |
| positionSizePct | double | Half-Kelly position as % of capital |
| strategyDescription | String | Human-readable strategy summary |

### CryptoAnalysisResult

| Field | Type | Description |
|-------|------|-------------|
| positions | List\<TradingPosition\> | Ranked trading positions |
| regimeInfo | RegimeInfo? | Regime detection metadata |
| distributionStats | DistributionStats? | Full simulation distribution stats |
| analysisSummary | String | Text summary |

### LeadPosition

| Field | Type | Description |
|-------|------|-------------|
| symbol | String | Trading pair |
| direction | TradeDirection | Long or Short |
| entryPrice | double | Entry price |
| exitPrice | double | TP target |
| stopLoss | double | SL price |
| predictedROI | double | ROI % |
| confidenceScore | int | TP prob as % |
| expectedValue | double | EV_adj |
| reasoning | String | Selection reasoning |

---

## 18. File Map

| File | Purpose |
|------|---------|
| `lib/services/regime_detection_service.dart` | Student-t HMM (Baum-Welch + ECME), Particle Filter, MC Simulator with path tracking, persistence adjustment, `RegimeDetectionService` orchestrator |
| `lib/services/analysis_service.dart` | Pipeline orchestration, long/short position building, barrier pricing, EV calculation, Kelly sizing, trade filtering, leaderboard scanner |
| `lib/services/binance_service.dart` | Legacy Binance API client |
| `lib/services/exchange_service.dart` | Abstract ExchangeService interface |
| `lib/services/exchanges/binance_exchange_service.dart` | Binance implementation of ExchangeService |
| `lib/services/exchanges/coinbase_exchange_service.dart` | Coinbase implementation of ExchangeService |
| `lib/services/exchanges/mexc_exchange_service.dart` | MEXC implementation of ExchangeService |
| `lib/models/analysis_models.dart` | Data models: `TimePeriod`, `VolatilityRegime`, `TradeDirection`, `RegimeInfo`, `DistributionStats`, `TradingPosition`, etc. |
| `lib/models/binance_models.dart` | `KlineData`, `BinancePair` models (shared across exchanges) |
| `lib/models/exchange_models.dart` | `Exchange` enum (binance, coinbase, mexc) |
| `lib/providers/market_providers.dart` | Riverpod state management providers |
| `lib/providers/exchange_provider.dart` | Exchange selection provider (persisted to SharedPreferences) |
| `lib/widgets/analysis_section.dart` | UI: analysis results + regime detection card |
| `lib/widgets/position_card.dart` | UI: position card with direction badge, entry/exit/SL, EV, barrier probs |
| `lib/widgets/leaderboard_section.dart` | UI: market leaderboard display |

---

## 19. Changelog

### 2026-03-04 — Full Probabilistic Regime-Switching Engine (v2)

Complete rewrite implementing the production algorithm specification.

**HMM → Student-t emissions:**
- Replaced Gaussian emission model with Student-t (fat tails)
- Added per-state degrees of freedom ν_k, estimated via grid search in M-step
- Added auxiliary weights (ũ) in M-step for proper Student-t ECME
- Added drift shrinkage (80% toward zero) for regime means
- Added log-gamma via Lanczos approximation for Student-t PDF

**Particle Filter → simplified, Student-t weights:**
- Removed `driftOffset` from particles (only `volScale` + `regime`)
- Changed evolution: `0.92 × old + 0.08 × 1 + 0.03 × N(0,1)`, clamped [0.5, 2.5]
- Weight update uses Student-t log-PDF instead of Gaussian
- Changed blend to 70% HMM / 30% PF (was 40/60)

**Regime persistence:**
- Added regime entropy calculation: −Σ π_k ln(π_k)
- Build persistence-adjusted matrix A': boost diagonal by up to 0.10 based on 1−entropy
- A' used only for simulation; original A stored for reporting

**MC Simulation → path-aware, Student-t innovations:**
- Student-t random sampling via Marsaglia-Tsang gamma + Box-Muller normal
- Full path tracking: maxPrice, minPrice, maxDrawdown per path
- Uses persistence-adjusted A' for regime transitions
- Returns `List<PathResult>` instead of `List<double>`

**Position building → long + short, barrier pricing, EV, Kelly:**
- Added SHORT position support (entry above market, exit below)
- Stop loss on every position: entry ± 1.5 × distribution stddev
- Barrier TP probability: fraction of paths where maxPrice hits exit (long) or minPrice hits exit (short)
- Barrier SL probability: fraction of paths where minPrice hits stop (long) or maxPrice hits stop (short)
- Expected value: EV = TP_prob × gain − SL_prob × loss − costs
- Kelly position sizing: half-Kelly, capped at 5%
- Trade acceptance filter: reject if EV ≤ 0 or TP_prob < 40%
- Exit calculated as conditional expectation (mean of qualifying paths), not percentile

**Leaderboard → entropy-penalized ranking:**
- Score = EV × (1 − normalizedEntropy)
- Penalizes pairs with uncertain regime identification

**Models:**
- `TradingPosition`: added direction, stopLoss, tpProbability, slProbability, expectedValue, positionSizePct
- `RegimeInfo`: added regimeEntropy, regimeNus
- Added `TradeDirection` enum and `DistributionStats` class
- `LeadPosition`: added direction, stopLoss, expectedValue

**UI:**
- Position card: direction badge (LONG/SHORT), stop loss display, EV, TP/SL barrier probabilities
- Regime card: updated engine label to "Student-t HMM"

### 2026-03-04 (earlier) — Initial HMM + PF + MC Engine (v1)

Previous implementation with Gaussian emissions, no path tracking, no short positions, no barrier pricing, no EV/Kelly. See git history for details.
