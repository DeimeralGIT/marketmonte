# Algorithm Configuration & Tunable Parameters

> **AlgorithmConfig — Centralized Engine Tuning**
> **File:** `lib/models/analysis_models.dart` (class `AlgorithmConfig`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Overview

The `AlgorithmConfig` class centralizes all tunable parameters for the 4-layer analysis pipeline. It provides compile-time defaults that can be overridden at runtime via `AnalysisService.updateAlgoConfig()`. Every parameter is a named field with a documented default, range, and purpose.

Market Monte is an **analytical presentation tool**, not a headless trading bot. There is no automated position opening, closing, or Telegram integration. The configuration affects the analysis output shown to the user.

---

## 2. Full Parameter Reference (17 tunable)

### 2.1 Transaction Costs

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `txCost` | 0.001 (0.1%) | > 0 | Layer 4: EV calculation (deducted from raw EV) |
| `slippage` | 0.0002 (0.02%) | > 0 | Layer 4: EV calculation (deducted from raw EV) |

### 2.2 Stop Loss

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `stopMultiplier` | 1.2 | [0.8, 3.0] | Layer 4: SL distance = stopMultiplier * distStats.stdDev |

### 2.3 Volatility Scaling

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `volScaleMin` | 0.5 | > 0 | Layer 2: PF volScale lower clamp |
| `volScaleMax` | 2.5 | > volScaleMin | Layer 2: PF volScale upper clamp |

### 2.4 Period Scaling

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `periodScaleMin` | 0.5 | > 0 | Layer 4: Entry discount duration scaling lower bound |
| `periodScaleMax` | 2.5 | > periodScaleMin | Layer 4: Entry discount duration scaling upper bound |

### 2.5 Regime Detection Thresholds

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `regimeLowThreshold` | 0.9 | [0.5, 1.0] | Layer 1: vol < meanVol * threshold --> LOW regime |
| `regimeHighThreshold` | 1.3 | [1.1, 2.0] | Layer 1: vol > meanVol * threshold --> HIGH regime |

**Note:** These thresholds are defined in `AlgorithmConfig` for potential future use. The current Flutter implementation uses the Student-t HMM for regime detection instead of threshold comparison. They are retained for compatibility and possible fallback logic.

### 2.6 Persistence

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `persistenceMultiplier` | 0.10 | [0.03, 0.20] | Layer 2: persistenceBoost = multiplier * (1 - normalizedEntropy) |

### 2.7 Entry Discounts

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `discountLow` | 0.0010 (0.10%) | [0.0005, 0.01] | Layer 4: Conservative entry discount for LOW regime |
| `discountMedium` | 0.0020 (0.20%) | [0.0005, 0.01] | Layer 4: Conservative entry discount for MEDIUM regime |
| `discountHigh` | 0.0040 (0.40%) | [0.0005, 0.01] | Layer 4: Conservative entry discount for HIGH regime |

### 2.8 Directional Probability

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `driftMultiplier` | 50.0 | [20.0, 200.0] | Available in config; not used in current barrier-pricing pipeline |

### 2.9 Position Sizing

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `kellyMax` | 0.05 (5%) | [0.01, 0.20] | Layer 4: Maximum half-Kelly position size |
| `basePositionPct` | 0.001 (0.1%) | [0.0002, 0.005] | Available for dynamic position sizing |

### 2.10 Leverage

| Parameter | Default | Range | Used By |
|-----------|---------|-------|---------|
| `maxLeverage` | 75 | [1, 125] | Layer 4: Leverage cap for all positions |

---

## 3. How Parameters Flow Through the Pipeline

```
AlgorithmConfig
  |
  |-- Layer 1 (HMM regime detection)
  |     regimeLowThreshold, regimeHighThreshold    (reserved for future use)
  |
  |-- Layer 2 (Particle Filter)
  |     volScaleMin, volScaleMax                   (PF volScale clamp)
  |     persistenceMultiplier                       (entropy-gated persistence boost)
  |
  |-- Layer 3 (MC simulation)
  |     (no direct config; uses PF output and HMM params)
  |
  |-- Layer 4 (Trade construction)
  |     txCost, slippage                           (EV cost deduction)
  |     stopMultiplier                              (SL distance)
  |     periodScaleMin, periodScaleMax             (duration discount scaling)
  |     discountLow, discountMedium, discountHigh  (regime-based entry discounts)
  |     kellyMax                                    (position sizing cap)
  |     maxLeverage                                 (leverage cap)
  |     driftMultiplier                             (reserved)
  |     basePositionPct                             (reserved)
```

---

## 4. Volatility Scaling Mechanics

The volScale system adapts positions to recent market conditions through the Particle Filter:

```
Each particle: volScale = 0.92 * volScale + 0.08 + 0.03 * N(0,1)
Weighted mean: volScale = sum(w_i * volScale_i)

When volScale > 1.0:
  - Recent volatility exceeds HMM's learned regime sigma
  - MC simulation produces wider price distributions
  - SL distances naturally widen (via distStats.stdDev)
  - Exit targets adjust (via conditional expectations from wider paths)

When volScale < 1.0:
  - Recent volatility is below regime sigma
  - Tighter distributions, tighter exits and stops
```

---

## 5. Regime Persistence Adjustment

Quantifies regime certainty using Shannon entropy of blended regime probabilities:

```
H = -sum(p_s * ln(p_s))     for s in {LOW, MEDIUM, HIGH}
normalizedEntropy = H / ln(3)
persistenceBoost = persistenceMultiplier * (1 - normalizedEntropy)
```

- **Certain regime** (low entropy): persistenceBoost approaches `persistenceMultiplier` (0.10)
- **Uncertain regime** (high entropy): persistenceBoost approaches 0.00

The boost is added to the diagonal of the HMM transition matrix to create A' (sticky matrix), making regime transitions more persistent when the model is confident. See [hmm.md section 8](hmm.md#8-entropy-and-persistence-adjustment).

`persistenceBoost` and `volScale` are stored in `CryptoAnalysisResult` and displayed as metric chips in the analysis UI.

---

## 6. Leverage Calculation Detail

The leverage formula targets a bounded loss at stop-loss:

```
slDistancePct = |entry - stop| / entry
confScale = max(0.3, tpProbability)
regimeScale = { LOW: 1.3, MEDIUM: 1.0, HIGH: 0.5 }

targetSlLoss = 0.35 * confScale * regimeScale[regime]
leverage = clamp(round(targetSlLoss / slDistancePct), 1, maxLeverage)
```

**Parameter effects:**
- Increasing `maxLeverage` allows higher leverage in calm markets
- Decreasing it caps exposure in all conditions
- The 0.35 base factor is fixed (not in AlgorithmConfig)

---

## 7. Default Configuration (Dart)

```dart
const AlgorithmConfig({
  this.txCost = 0.001,
  this.slippage = 0.0002,
  this.stopMultiplier = 1.2,
  this.volScaleMin = 0.5,
  this.volScaleMax = 2.5,
  this.periodScaleMin = 0.5,
  this.periodScaleMax = 2.5,
  this.regimeLowThreshold = 0.9,
  this.regimeHighThreshold = 1.3,
  this.persistenceMultiplier = 0.10,
  this.discountLow = 0.0010,
  this.discountMedium = 0.0020,
  this.discountHigh = 0.0040,
  this.driftMultiplier = 50.0,
  this.kellyMax = 0.05,
  this.basePositionPct = 0.001,
  this.maxLeverage = 75,
});
```

---

## 8. Runtime Updates

The configuration can be updated at runtime:

```dart
analysisService.updateAlgoConfig(AlgorithmConfig(
  maxLeverage: 50,
  stopMultiplier: 1.5,
  // ... other overrides
));
```

This takes effect on the next `analyzePair()` or `scanTopMarket()` call. No persistence layer is currently implemented in the Flutter app — config resets to defaults on app restart.

---

## 9. Fixed Constants (Not in AlgorithmConfig)

These values are hardcoded in the engine and not exposed for tuning:

| Constant | Value | Location | Purpose |
|----------|-------|----------|---------|
| HMM states | 3 | `StudentTHMM` | Number of regimes |
| Drift shrinkage | 0.8 | `StudentTHMM` | Shrink learned drift toward zero |
| nu grid | {2.5, 3, 4, 5, 7, 10, 15, 30} | `StudentTHMM._nuGrid` | Profile LL search |
| Particles | 500 | `ParticleFilter` | SMC particle count |
| PF mean reversion | 0.92v + 0.08 | `ParticleFilter` | VolScale AR(1) |
| PF noise | 0.03 | `ParticleFilter` | VolScale innovation |
| ESS threshold | N/2 | `ParticleFilter` | Resampling trigger |
| Blending | 70% HMM / 30% PF | `RegimeDetectionService` | Regime probability blend |
| MC paths | 10,000 | `AnalysisService._numSim` | Simulation count |
| Half-Kelly fraction | 0.5 | `AnalysisService._kellyFraction` | Position sizing safety |
| Min TP probability | 0.40 | `AnalysisService._minTpProb` | Trade acceptance filter |
| Leverage base factor | 0.35 | `AnalysisService._leverageBaseFactor` | Target SL loss base |
| Ludomania SL mult | 2.5 | `AnalysisService._ludoSlMultiplier` | Wider stops for YOLO |
| Max A' diagonal | 0.98 | `RegimeDetectionService` | Persistence cap |
| Seed | 42 | Multiple | Deterministic reproducibility |
