# Market Monte — Algorithm Reference

> **Last updated:** 2026-03-24
> **Purpose:** High-level description of the four-layer probabilistic pipeline as implemented in the Flutter/Dart mobile analytics app. Each layer has its own detailed reference document.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Pipeline](#2-data-pipeline)
3. [Layer 1 — Regime Detection](#3-layer-1--regime-detection)
4. [Layer 2 — Volatility Adaptation](#4-layer-2--volatility-adaptation)
5. [Layer 3 — Monte Carlo Simulation](#5-layer-3--monte-carlo-simulation)
6. [Layer 4 — Trade Construction & Sizing](#6-layer-4--trade-construction--sizing)
7. [Market Leaders Scan](#7-market-leaders-scan)
8. [Inter-Layer Data Flow](#8-inter-layer-data-flow)
9. [Configuration Constants](#9-configuration-constants)
10. [Data Models](#10-data-models)
11. [File Map](#11-file-map)
12. [Changelog](#12-changelog)

### Algorithm Detail Documents

| Document | Covers |
|----------|--------|
| [hmm.md](hmm.md) | Student-t HMM with Baum-Welch EM — 3-state regime detection with ECME M-step |
| [particle_filter.md](particle_filter.md) | 500-particle Sequential Monte Carlo — real-time volScale tracking and regime blending |
| [monte_carlo.md](monte_carlo.md) | 10,000-path regime-switching Monte Carlo — Student-t innovations with barrier tracking |
| [trade_construction.md](trade_construction.md) | Long/short position building, barrier-priced TP/SL, leverage, EV calculation, Kelly sizing |
| [leaderboard.md](leaderboard.md) | Market leaders scan — top 10 pairs ranked by entropy-penalized EV with leveraged returns |
| [dynamic-adjustments.md](dynamic-adjustments.md) | AlgorithmConfig tunable parameters and adaptation rules |

---

## 1. Architecture Overview

The engine is a **four-layer probabilistic pipeline** implemented in Dart/Flutter:

```
Raw hourly candles (Exchange API)
        │
        ▼
  ┌──────────────────────────────────┐
  │  Layer 1: Regime Detection       │  Student-t HMM (Baum-Welch EM)
  │  (3 discrete regimes)            │  → hmm.md
  └──────────────┬───────────────────┘
                 │ regime label + blended probabilities
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 2: Volatility Adaptation  │  500-particle Sequential Monte Carlo
  │  (Particle filter)               │  → particle_filter.md
  └──────────────┬───────────────────┘
                 │ volScale, persistenceBoost, persistence-adjusted A'
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 3: Monte Carlo Simulation │  10,000 regime-switching paths
  │  (Student-t innovations)         │  → monte_carlo.md
  └──────────────┬───────────────────┘
                 │ price distribution, barrier stats
                 ▼
  ┌──────────────────────────────────┐
  │  Layer 4: Trade Construction     │  Barrier pricing, leverage, EV, Kelly
  │  (Long + Short positions)        │  → trade_construction.md
  └──────────────────────────────────┘
```

**Philosophy:** The engine prices probabilistic opportunity under regime uncertainty using full Monte Carlo simulation with Student-t heavy-tailed innovations. All positions include barrier-priced TP/SL probabilities, calculated leverage, and expected value. Both long and short positions are always produced for maximum analytical coverage.

---

## 2. Data Pipeline

### 2.1 Market Data

- **Sources:** Binance, Coinbase, MEXC (via abstract `ExchangeService` interface)
- **Timeframe:** 1H candles
- **Rolling window:** 168 hours (1 week)
- **Fields used:** Close price from kline data
- **Assets:** Top USDT pairs by 24h volume (exchange-specific)

### 2.2 Return Transformation

Hourly log-returns:

```
r_t = ln(P_t / P_{t-1})
```

Fed directly into regime detection — no smoothing applied.

### 2.3 Minimum Data Requirement

The engine requires at least **50 log-returns** (51 candles) to produce positions. If fewer are available, it returns an empty result with a default MEDIUM regime.

---

## 3. Layer 1 — Regime Detection

**Full reference:** [hmm.md](hmm.md)

A **Student-t Hidden Markov Model** (3 states) fitted via **Baum-Welch Expectation-Maximization** with an ECME M-step. Student-t emissions provide robustness to fat-tailed returns. The M-step uses auxiliary weights `ũ = (ν+1)/(ν+z²)` for weighted mean/variance estimation, plus a profile log-likelihood grid search over ν ∈ {2.5, 3, 4, 5, 7, 10, 15, 30}. States are re-sorted by σ after each iteration.

**Inputs:** Hourly log-returns
**Outputs consumed by downstream layers:**
- Regime label: `LOW` (index 0), `MEDIUM` (index 1), or `HIGH` (index 2)
- Blended regime probabilities: **70% HMM forward-filtered + 30% Particle Filter** weighted average

---

## 4. Layer 2 — Volatility Adaptation

**Full reference:** [particle_filter.md](particle_filter.md)

A **500-particle Sequential Monte Carlo** filter tracking real-time volatility evolution. Each particle carries a regime state and a mean-reverting volScale (`0.92v + 0.08 + 0.03·N(0,1)`, clamped [0.5, 2.5]). Weights are computed via Student-t log-likelihood. Systematic resampling triggers at ESS < N/2.

**Inputs:** Last 50 log-returns, HMM parameters
**Outputs consumed by downstream layers:**
- **volScale:** Weighted mean of particle volScales, clamped `[volScaleMin, volScaleMax]` (defaults `[0.5, 2.5]`)
- **persistenceBoost:** `persistenceMultiplier × (1 - normalizedEntropy)` (default multiplier 0.10)
- **A':** Persistence-adjusted transition matrix (diagonal boosted, off-diagonal renormalized)

---

## 5. Layer 3 — Monte Carlo Simulation

**Full reference:** [monte_carlo.md](monte_carlo.md)

**10,000 regime-switching paths** with Student-t innovations. Each step samples a regime transition from the persistence-adjusted matrix A', then generates:

```
logReturn = (μ - 0.5σ²) + σ × T(ν)
```

Student-t variates are generated via Marsaglia-Tsang gamma + Box-Muller. Full path tracking records `maxPrice`, `minPrice`, and `maxDrawdown` (peak-to-trough) for **barrier pricing**.

**Inputs:** Current price, HMM parameters, persistence-adjusted A', simulation horizon
**Outputs consumed by downstream layers:**
- Price distribution statistics (mean, stdDev, skewness, kurtosis, percentiles P5–P95)
- Per-path barrier data (maxPrice, minPrice, maxDrawdown)

---

## 6. Layer 4 — Trade Construction & Sizing

**Full reference:** [trade_construction.md](trade_construction.md)

Builds **both long (BUY) and short (SELL)** positions for each analysis. Each direction produces up to 2 positions: conservative (small entry discount) and aggressive (larger discount). Computes entries with regime-based discounts, exits via conditional expectation from MC paths (barrier pricing), stops with volatility-scaled buffers, leverage, and expected value net of transaction costs.

**Inputs:** MC path results, `currentPrice`, `regime`, `volScale`
**Outputs:**
- `List<TradingPosition>` — each containing side, entry, exit, stop, EV (leveraged), leverage, Kelly size, confidence %, expected ROI % (leveraged), duration

### Combined Pipeline

```
1. HMM → regime detection with Student-t emissions
2. Particle filter → volScale, persistenceBoost, A'
3. MC simulation → 10k paths with barrier tracking
4. TP price → E[finalPrice | finalPrice ≥ entry]  (conditional expectation from MC paths)
5. SL price → entry ∓ stopMultiplier × σ_distribution
6. Barrier probs → path counting: tpProb = count(maxPrice ≥ exit) / 10000
7. Leverage → (0.35 × confScale × regimeScale) / slDistancePct
8. EV = tpProb × gain − slProb × loss − costs, then × leverage
9. Kelly size = 0.5 × (tpProb × gain − slProb × loss) / loss, clamped [0%, kellyMax]
```

---

## 7. Market Leaders Scan

**Full reference:** [leaderboard.md](leaderboard.md)

The app scans the top 10 USDT pairs on the selected exchange, running the full 4-layer pipeline for each and ranking results by **entropy-penalized expected value** with leveraged returns.

---

## 8. Inter-Layer Data Flow

```
                     ┌─────────────────────┐
  log-returns ──────▶│  Student-t HMM       │
                     │  (Layer 1)           │
                     └──────┬──────────────┘
                            │  regime, blended probs, HMM params
                            ▼
                     ┌─────────────────────┐
  last 50 returns ──▶│  Particle Filter     │
                     │  (Layer 2, 500 ptcl) │
                     └──────┬──────────────┘
                            │  volScale, persistenceBoost, A'
                            ▼
                     ┌─────────────────────┐
  current price ────▶│  MC Simulation       │
  HMM params, A' ──▶│  (Layer 3, 10k paths)│
                     └──────┬──────────────┘
                            │  price distribution, barrier stats
                            ▼
                     ┌─────────────────────┐
  regime + params ──▶│  Trade Builder       │
  MC results ───────▶│  (Layer 4)           │
                     └──────┬──────────────┘
                            │  List<TradingPosition>
                            ▼
                     ┌─────────────────────┐
  top 10 pairs ────▶│  Market Leaders Scan  │
  7 timeframes ────▶│  (Leaderboard)        │
                     └──────┬──────────────┘
                            │  Ranked picks by EV
                            ▼
                       Presentation Layer
```

---

## 9. Configuration Constants

All constants consolidated across layers:

| Constant | Value | Location | Layer |
|----------|-------|----------|-------|
| HMM states | 3 (LOW, MEDIUM, HIGH) | `StudentTHMM` | 1 |
| HMM emission | Student-t (ECME M-step) | `StudentTHMM` | 1 |
| Drift shrinkage | 0.8 | `StudentTHMM` | 1 |
| ν grid search | {2.5, 3, 4, 5, 7, 10, 15, 30} | `StudentTHMM` | 1 |
| Blending ratio | 70% HMM / 30% PF | `RegimeDetectionService` | 1–2 |
| Particles | 500 | `ParticleFilter` | 2 |
| volScale mean reversion | 0.92v + 0.08 | `ParticleFilter` | 2 |
| volScale clamp | [0.5, 2.5] (tunable) | `AlgorithmConfig` | 2 |
| Persistence multiplier | 0.10 (tunable) | `AlgorithmConfig` | 2 |
| Resampling threshold | ESS < N/2 | `ParticleFilter` | 2 |
| MC paths | 10,000 | `AnalysisService._numSim` | 3 |
| Student-t innovations | Marsaglia-Tsang + Box-Muller | `RegimeAwareSimulator` | 3 |
| Transaction cost | 0.1% (0.001, tunable) | `AlgorithmConfig.txCost` | 4 |
| Slippage | 0.02% (0.0002, tunable) | `AlgorithmConfig.slippage` | 4 |
| SL multiplier | 1.2 (tunable) | `AlgorithmConfig.stopMultiplier` | 4 |
| Drift multiplier | 50.0 (tunable) | `AlgorithmConfig.driftMultiplier` | 4 |
| Kelly fraction | 0.5 (half-Kelly) | `AnalysisService` | 4 |
| Max Kelly size | 5% (tunable) | `AlgorithmConfig.kellyMax` | 4 |
| Period scale clamp | [0.5, 2.5] (tunable) | `AlgorithmConfig` | 4 |
| Leverage base factor | 0.35 | `AnalysisService` | 4 |
| Max leverage | 75 (tunable) | `AlgorithmConfig.maxLeverage` | 4 |
| Base position pct | 0.001 (tunable) | `AlgorithmConfig.basePositionPct` | — |
| TP filter threshold | 0.40 (40%) | `AnalysisService` | 4 |
| Min returns for analysis | 50 | `AnalysisService` | — |
| Klines fetched | 168 (1H interval) | `AnalysisService` | — |

---

## 10. Data Models

### Dart (Flutter)

**File:** `lib/models/analysis_models.dart`

#### CryptoAnalysisResult

| Field | Type | Description |
|-------|------|-------------|
| regime | `int` | Detected regime index (0=LOW, 1=MEDIUM, 2=HIGH) |
| regimeProbs | `List<double>` | Blended probability per regime |
| stability | `int` | Regime stability score (0–100) |
| entropy | `double` | Regime entropy |
| annualisedVol | `double` | Annualised volatility |
| volScale | `double` | Volatility scaling factor from particle filter |
| persistenceBoost | `double` | Entropy-gated persistence boost |
| positions | `Map<String, TradingPosition>` | Named positions (conservative/aggressive × long/short) |
| distributionStats | `DistributionStats` | MC price distribution statistics |
| summary | `String` | Formatted analysis summary |

#### TradingPosition

| Field | Type | Description |
|-------|------|-------------|
| direction | `String` | "LONG" or "SHORT" |
| entry | `double` | Entry price |
| exit | `double` | Take profit target (conditional expectation from MC) |
| stop | `double` | Stop loss price |
| ev | `double` | Expected value in $ (leveraged) |
| roi | `double` | Expected ROI % (leveraged) |
| confidence | `double` | TP barrier probability (0–1) |
| kellySize | `double` | Half-Kelly position size % |
| positionSize | `double` | Position size in $ |
| tpProbability | `double` | TP barrier hit probability |
| slProbability | `double` | SL barrier hit probability |
| leverage | `int` | Calculated leverage multiplier (1–maxLeverage) |
| durationHours | `int` | Expected duration in hours |
| strategy | `String` | Formatted strategy description |

#### AlgorithmConfig

17 tunable parameters — see [dynamic-adjustments.md §1](dynamic-adjustments.md) for full listing.

#### TimePeriod

| Key | Label | Hours |
|-----|-------|-------|
| 1H | 1 Hour | 1 |
| 4H | 4 Hours | 4 |
| 12H | 12 Hours | 12 |
| 1D | 1 Day | 24 |
| 2D | 2 Days | 48 |
| 1W | 1 Week | 168 |
| 1M | 1 Month | 720 |

---

## 11. File Map

### Flutter/Dart

| File | Purpose |
|------|---------|
| `lib/services/regime_detection_service.dart` | Student-t HMM (Baum-Welch EM), 500-particle filter, regime-switching MC simulator |
| `lib/services/analysis_service.dart` | 4-layer analysis pipeline: orchestrates HMM → PF → MC → trade construction |
| `lib/services/binance_service.dart` | Binance REST API client |
| `lib/services/exchange_service.dart` | Abstract exchange service interface |
| `lib/models/analysis_models.dart` | Data models: CryptoAnalysisResult, TradingPosition, AlgorithmConfig, TimePeriod, etc. |
| `lib/models/exchange_models.dart` | Exchange-specific models |
| `lib/providers/market_providers.dart` | Riverpod state management for market data and analysis |
| `lib/providers/exchange_provider.dart` | Exchange selection state |
| `lib/providers/ludomania_provider.dart` | Ludomania mode (high-risk YOLO positions) |
| `lib/providers/theme_provider.dart` | Theme state |
| `lib/widgets/position_card.dart` | Position card with trade details, leverage badge, exchange deep link |
| `lib/widgets/analysis_section.dart` | Regime detection card, outlook, position cards grid |
| `lib/widgets/leaderboard_section.dart` | Market leaders scan results |
| `lib/widgets/controls_card.dart` | Symbol search, investment amount, time period selector |
| `lib/theme/app_theme.dart` | Material theme configuration |
| `lib/main.dart` | App entry point |

---

## 12. Changelog

### 2026-03-24 — Flutter App Documentation Update

Complete rewrite of all algorithm docs to accurately reflect the Flutter/Dart analytics app codebase.

**Key updates:**
- Docs now reference Dart/Flutter file paths and class names
- Regime detection: Student-t HMM with Baum-Welch EM (not threshold-based classification)
- Adaptation: 500-particle Sequential Monte Carlo filter (not simple volScale ratio)
- Simulation: 10,000-path regime-switching Monte Carlo with Student-t innovations (not analytical formulas)
- Trade construction: Barrier pricing via MC path counting, conditional expectations (not formula-based)
- Leverage system: Documented with regime-scale and confidence-scale calculation
- AlgorithmConfig: 17 tunable parameters documented
- New timeframes: 12H and 2D added
- Both BUY and SELL positions always produced
- Multi-exchange support (Binance, Coinbase, MEXC)
- Presentation focus: analytical tool, not headless trading bot

### 2026-03-23 — Previous Documentation (TypeScript/Kotlin)

Docs described a simpler engine (threshold-based regime detection, analytical formulas) for a Next.js web app and Android headless trading bot. See git history for those docs.

### 2026-03-05 — Documentation Split

Split monolithic algorithm.md into focused per-layer documents.
