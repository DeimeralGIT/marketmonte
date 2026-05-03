# Market Monte — Algorithm Reference

> **Last updated:** 2026-03-05  
> **Purpose:** High-level description of the four-layer probabilistic pipeline and how the individual algorithms combine. Each layer has its own detailed reference document.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Pipeline](#2-data-pipeline)
3. [Layer 1 — Regime Detection (HMM)](#3-layer-1--regime-detection-hmm)
4. [Layer 2 — Volatility Adaptation (Particle Filter)](#4-layer-2--volatility-adaptation-particle-filter)
5. [Layer 3 — Monte Carlo Simulation](#5-layer-3--monte-carlo-simulation)
6. [Layer 4 — Trade Construction & Sizing](#6-layer-4--trade-construction--sizing)
7. [Cross-Asset Leaderboard](#7-cross-asset-leaderboard)
8. [Inter-Layer Data Flow](#8-inter-layer-data-flow)
9. [Configuration Constants](#9-configuration-constants)
10. [Data Models](#10-data-models)
11. [File Map](#11-file-map)
12. [Changelog](#12-changelog)

### Algorithm Detail Documents

| Document | Covers |
|----------|--------|
| [hmm.md](hmm.md) | Student-t HMM — Baum-Welch EM, ECME ν estimation, Viterbi, forward filtering |
| [particle_filter.md](particle_filter.md) | 500-particle filter, volScale evolution, HMM/PF probability blending, regime persistence adjustment |
| [monte_carlo.md](monte_carlo.md) | 10,000-path regime-switching simulation, Student-t innovations, path tracking, forecast distribution |
| [trade_construction.md](trade_construction.md) | Long/short position building, barrier pricing, expected value, Kelly sizing, acceptance filter |
| [leaderboard.md](leaderboard.md) | Cross-asset scanning, entropy-penalized ranking, risk controls |

---

## 1. Architecture Overview

The engine is a **four-layer probabilistic pipeline**:

```
Raw hourly candles (Exchange API)
        │
        ▼
  ┌──────────────────────────────────┐
  │  Layer 1: Regime Detection       │  Student-t HMM (Baum-Welch EM)
  │  (3 latent states, fat tails)    │  → hmm.md
  └──────────────┬───────────────────┘
                 │ learned params {μ,σ,ν} + transition matrix A
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 2: Volatility Adaptation  │  500 particles, systematic resampling
  │  (Particle Filter)               │  → particle_filter.md
  └──────────────┬───────────────────┘
                 │ blended regime probs + volScale + adjusted A'
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 3: Sticky Regime MC Sim   │  10,000 paths, Student-t innovations
  │  (State-Space with persistence)  │  → monte_carlo.md
  └──────────────┬───────────────────┘
                 │ List<PathResult> (finalPrice, maxPrice, minPrice, drawdown)
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 4: EV-Optimized Trades    │  Barrier pricing, Kelly sizing
  │  (Long + Short positions)        │  → trade_construction.md
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

## 3. Layer 1 — Regime Detection (HMM)

**Full reference:** [hmm.md](hmm.md)

A 3-state Student-t HMM trained via Baum-Welch EM with ECME ν estimation. Each state represents a volatility regime (Low / Medium / High) with fat-tailed emission distributions.

**Inputs:** Hourly log-returns  
**Outputs consumed by downstream layers:**
- Per-state parameters: `{μ_k, σ_k, ν_k}` for k ∈ {0, 1, 2}
- Transition matrix `A` (3×3)
- Forward-filtered state probabilities at the last time step

---

## 4. Layer 2 — Volatility Adaptation (Particle Filter)

**Full reference:** [particle_filter.md](particle_filter.md)

A 500-particle sequential filter that adapts local volatility in real time and blends its regime estimates with the HMM's batch probabilities.

**Inputs:** HMM parameters `{μ, σ, ν, A}`, last 50 log-returns  
**Outputs consumed by downstream layers:**
- **Blended regime probabilities:** `0.7 × HMM + 0.3 × PF` → used to sample initial regime in MC
- **volScale mean:** multiplicative correction applied to σ during simulation
- **Persistence-adjusted transition matrix A':** boosted diagonal to prevent over-switching (entropy-gated, up to +0.10)

---

## 5. Layer 3 — Monte Carlo Simulation

**Full reference:** [monte_carlo.md](monte_carlo.md)

10,000 paths of regime-switching GBM with Student-t innovations, full path tracking.

**Inputs:** HMM params `{μ, σ, ν}`, adjusted `A'`, `volScale`, `blended_probs`, current price, horizon steps  
**Outputs consumed by downstream layers:**
- `List<PathResult>` sorted by `finalPrice` — each containing `finalPrice`, `maxPrice`, `minPrice`, `maxDrawdown`
- `DistributionStats`: percentiles (P5–P95), mean, stdDev, skewness, kurtosis

---

## 6. Layer 4 — Trade Construction & Sizing

**Full reference:** [trade_construction.md](trade_construction.md)

Builds long/short positions using conditional expectations from the simulation paths, prices barrier TP/SL probabilities against full path extremes, computes EV net of costs, and sizes via half-Kelly.

**Inputs:** `List<PathResult>`, `DistributionStats`, current price, regime info  
**Outputs:**
- Ranked `List<TradingPosition>` (direction, entry, exit, SL, ROI, EV, TP/SL probs, Kelly size)

### Combined EV Calculation

The final expected value that determines trade ranking ties all four layers together:

```
1. HMM detects regime → determines base discount (entry distance)
2. PF adapts volScale → σ_eff used in simulation
3. MC paths → conditional exit price, barrier TP/SL probabilities
4. EV = TP_prob × |exit − entry| − SL_prob × |entry − stop| − costs
5. Kelly size = clamp(0.5 × EV / SL_loss, 0%, 5%)
6. Accept if EV > 0 AND TP_prob ≥ 40%
```

---

## 7. Cross-Asset Leaderboard

**Full reference:** [leaderboard.md](leaderboard.md)

Runs the full four-layer pipeline on the top 10 USDT pairs by volume and ranks them using an entropy-penalized EV score:

```
score = EV_adj × (1 − RegimeEntropy / ln(3))
```

Returns the top 3 opportunities as `LeadPosition` objects.

---

## 8. Inter-Layer Data Flow

```
                     ┌─────────────┐
  log-returns ──────▶│  StudentTHMM │
                     │  (Layer 1)   │
                     └──────┬──────┘
                            │  {μ, σ, ν, A, forward_probs}
                            ▼
                     ┌──────────────────┐
  last 50 returns ──▶│  ParticleFilter   │
                     │  (Layer 2)        │
                     └──────┬───────────┘
                            │  blended_probs, volScale, A'
                            ▼
                     ┌──────────────────┐
  current price ────▶│  RegimeAwareSim   │
  horizon steps ────▶│  (Layer 3)        │
                     └──────┬───────────┘
                            │  List<PathResult>, DistributionStats
                            ▼
                     ┌──────────────────┐
  regime info ──────▶│  Trade Builder    │
  current price ────▶│  (Layer 4)        │
                     └──────┬───────────┘
                            │  List<TradingPosition>
                            ▼
                       Final Output
```

---

## 9. Configuration Constants

All constants consolidated across layers:

| Constant | Value | Location | Layer |
|----------|-------|----------|-------|
| `_nStates` | 3 | `RegimeDetectionService` | 1 |
| HMM max iterations | 30 | `StudentTHMM.fit()` | 1 |
| HMM convergence tol | 1e-4 | `StudentTHMM.fit()` | 1 |
| Drift shrinkage λ | 0.8 | `StudentTHMM` | 1 |
| ν grid | [2.5, 3, 4, 5, 7, 10, 15, 30] | `StudentTHMM._nuGrid` | 1 |
| `nParticles` | 500 | `ParticleFilter` | 2 |
| PF window | last 50 obs | `RegimeDetectionService.detect()` | 2 |
| PF resampling threshold | ESS < N/2 | `ParticleFilter.update()` | 2 |
| PF volScale mean-reversion | 0.92 | `ParticleFilter.update()` | 2 |
| PF volScale clamp | [0.5, 2.5] | `ParticleFilter.update()` | 2 |
| HMM/PF blend | 70% HMM / 30% PF | `RegimeDetectionService.detect()` | 2 |
| Persistence boost max | 0.10 | `_persistenceAdjust()` | 2 |
| A' diagonal cap | 0.98 | `_persistenceAdjust()` | 2 |
| `_numSim` | 10,000 | `AnalysisService` | 3 |
| Random seed | 42 | Multiple locations | 3 |
| SL multiplier k | 1.5 | `AnalysisService._slMultiplier` | 4 |
| Transaction cost | 0.2% | `AnalysisService._txCost` | 4 |
| Slippage | 0.05% | `AnalysisService._slippage` | 4 |
| Kelly fraction | 0.5 (half-Kelly) | `AnalysisService._kellyFraction` | 4 |
| Max position size | 5% | `AnalysisService._maxPositionSize` | 4 |
| Min TP probability | 40% | `AnalysisService._minTpProb` | 4 |
| Min candles | 168 (1 week hourly) | `AnalysisService.analyzePair()` | — |

---

## 10. Data Models

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

## 11. File Map

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

## 12. Changelog

### 2026-03-05 — Documentation Split

Split monolithic algorithm.md into focused per-layer documents:
- [hmm.md](hmm.md) — Student-t HMM details
- [particle_filter.md](particle_filter.md) — Particle filter & regime persistence
- [monte_carlo.md](monte_carlo.md) — MC simulation & forecast distribution
- [trade_construction.md](trade_construction.md) — Trade building, barrier pricing, EV, Kelly
- [leaderboard.md](leaderboard.md) — Cross-asset scanning & risk controls

This file now serves as the pipeline overview and inter-layer data flow reference.

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
