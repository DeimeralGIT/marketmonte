# Trade Construction & Sizing (Layer 4)

> **Layer 4 — Barrier-Priced Positions with Leverage**
> **File:** `lib/services/analysis_service.dart` (class `AnalysisService`, methods `_buildPositions`, `_buildDirectionalPositions`, `_calculateLeverage`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Overview

Builds **both long (BUY) and short (SELL) positions** for every analysis. Each direction produces up to 2 positions (conservative and aggressive), for a maximum of 4 standard positions per analysis. An optional ludomania position (high risk/reward YOLO) can be added when enabled.

Positions use:
- **Barrier pricing** from 10,000 MC paths for TP/SL probabilities
- **Conditional expectations** from MC paths for exit targets
- **Leverage calculation** based on stop-loss distance, confidence, and regime
- **Half-Kelly** position sizing

---

## 2. Duration (TimePeriod)

Available timeframes:

| Key | Label | Hours |
|-----|-------|-------|
| 1H | 1 Hour | 1 |
| 4H | 4 Hours | 4 |
| 12H | 12 Hours | 12 |
| 1D | 1 Day | 24 |
| 2D | 2 Days | 48 |
| 1W | 1 Week | 168 |
| 1M | 1 Month | 720 |

The user selects a single timeframe via the controls panel. The MC simulation runs for the corresponding number of hourly steps.

---

## 3. Period Scaling

```
periodScale = clamp(sqrt(hours / 24), periodScaleMin, periodScaleMax)
```

Where defaults are `periodScaleMin = 0.5` and `periodScaleMax = 2.5` (tunable via `AlgorithmConfig`).

Scales entry discounts by duration — longer horizons get wider entries.

---

## 4. Entry Price Calculation

### 4.1 Regime Base Discounts

Each regime defines a conservative base discount. The aggressive discount is derived as a multiple:

| Regime | Conservative Base | Aggressive Base |
|--------|------------------|-----------------|
| LOW (0) | `discountLow` (0.0010) | `discountLow * 3.0` |
| MEDIUM (1) | `discountMedium` (0.0020) | `discountMedium * 2.5` |
| HIGH (2) | `discountHigh` (0.0040) | `discountHigh * 2.5` |

All discount values are tunable via `AlgorithmConfig`.

### 4.2 Long (BUY) Entry

```
discount = clamp(baseDiscount * periodScale, 0.0005, 0.025)    // conservative
discount = clamp(baseDiscount * periodScale, 0.001, 0.04)      // aggressive

entry = currentPrice * (1 - discount)
```

Entry is below market — a limit buy order.

### 4.3 Short (SELL) Entry

```
premium = clamp(baseDiscount * periodScale, 0.0005, 0.025)     // conservative
premium = clamp(baseDiscount * periodScale, 0.001, 0.04)       // aggressive

entry = currentPrice * (1 + premium)
```

Entry is above market — a limit sell order.

---

## 5. Exit Price (Take Profit) — Conditional Expectation

Exit targets are computed as **conditional expectations from the MC paths**, not from fixed ROI targets:

### 5.1 Long Exit

```
abovePaths = pathResults.where(finalPrice >= entry)

if abovePaths.length >= 10:
    exit = mean(abovePaths.finalPrice)
else:
    exit = entry * (1 + baseDiscount * 3)    // fallback

exit = max(exit, entry * 1.001)    // conservative floor
exit = max(exit, entry * 1.002)    // aggressive floor
```

The conditional expectation `E[finalPrice | finalPrice >= entry]` answers: "Given the price ends above our entry, what's the expected final price?" This naturally adapts to the shape of the simulated distribution.

### 5.2 Short Exit

```
belowPaths = pathResults.where(finalPrice <= entry)

if belowPaths.length >= 10:
    exit = mean(belowPaths.finalPrice)
else:
    exit = entry * (1 - baseDiscount * 3)    // fallback

exit = min(exit, entry * 0.999)    // conservative floor
exit = min(exit, entry * 0.998)    // aggressive floor
```

---

## 6. Stop Loss

Stop loss uses the **MC distribution standard deviation** as the distance measure:

### 6.1 Long Stop

```
stop = entry - stopMultiplier * distStats.stdDev
```

### 6.2 Short Stop

```
stop = entry + stopMultiplier * distStats.stdDev
```

Where `stopMultiplier` defaults to **1.2** (tunable via `AlgorithmConfig.stopMultiplier`). Note that `distStats.stdDev` is the standard deviation of the 10,000 simulated final prices, not the historical return volatility. This makes the stop naturally scale with the simulation horizon and regime.

---

## 7. Barrier Probabilities (TP/SL from Path Counting)

TP and SL probabilities are estimated by **counting how many of the 10,000 paths hit each barrier** using the per-path `maxPrice` and `minPrice`:

### 7.1 Long Positions

```
tpProb = count(maxPrice >= exitTarget) / 10000
slProb = count(minPrice <= stopLoss)   / 10000
```

### 7.2 Short Positions

```
tpProb = count(minPrice <= exitTarget) / 10000
slProb = count(maxPrice >= stopLoss)   / 10000
```

This approach captures the probability that a barrier is **ever touched during the path**, not just at expiry. It correctly handles the first-passage problem that analytical formulas typically approximate.

---

## 8. Expected Value (EV)

```
tpGain = |exit - entry|
slLoss = |entry - stop|
cost   = currentPrice * (txCost + slippage)

rawEV  = tpProb * tpGain - slProb * slLoss
EV     = (rawEV - cost) * leverage
```

Where:
- `txCost` defaults to 0.001 (0.1%) — tunable via `AlgorithmConfig.txCost`
- `slippage` defaults to 0.0002 (0.02%) — tunable via `AlgorithmConfig.slippage`

EV is multiplied by leverage (see section 10). Positions are sorted by **descending EV** (best expected value first).

---

## 9. Position Sizing (Kelly Criterion)

```
f* = (tpProb * tpGain - slProb * slLoss) / slLoss
kellySize = clamp(0.5 * f*, 0%, kellyMax)
```

Returns a percentage. The 0.5 (half-Kelly) provides a safety margin. `kellyMax` defaults to 0.05 (5%) and is tunable via `AlgorithmConfig.kellyMax`.

---

## 10. Leverage System

Each position includes a calculated leverage multiplier that amplifies both EV and expectedROI.

### 10.1 Formula

```
slDistancePct = |entry - stop| / entry
confScale     = max(0.3, tpProbability)
regimeScale   = { LOW: 1.3, MEDIUM: 1.0, HIGH: 0.5 }

targetSlLoss  = 0.35 * confScale * regimeScale[regime]
leverage      = clamp(round(targetSlLoss / slDistancePct), 1, maxLeverage)
```

Where `maxLeverage` defaults to **75** (tunable via `AlgorithmConfig.maxLeverage`).

### 10.2 Intuition

The leverage targets a bounded loss at stop-loss hit. The base factor of **0.35** (35%) means the leveraged loss at SL is approximately 35% of the position margin, scaled by confidence and regime:

- **Higher confidence (tpProb)** --> more leverage (scales from 0.3x at low confidence to 1x at 100%)
- **LOW regime** --> more leverage (1.3x scale; calmer market, tighter stops = safer for higher leverage)
- **HIGH regime** --> less leverage (0.5x scale; reduces exposure in volatile conditions)

### 10.3 Application

Leverage multiplies:
- **EV:** `ev = rawEV * leverage`
- **ROI:** `expectedROI = rawROI * leverage`

---

## 11. ROI Calculation

```
Long:  rawROI = (exit - entry) / entry * 100
Short: rawROI = (entry - exit) / entry * 100

expectedROI = rawROI * leverage
```

---

## 12. Confidence Score

```
confidence = clamp(round(tpProbability * 100), 5, 95)
```

TP probability as an integer percentage, clamped to [5, 95] to avoid extreme confidence.

---

## 13. Trade Acceptance Filter

A position is included in the final output if:

```
EV_adjusted > 0  AND  tpProbability >= 0.40
```

The minimum TP probability threshold (`_minTpProb = 0.40`) ensures only positions with at least 40% barrier-hit probability are shown to the user. When no positions pass the filter (both directions rejected), the engine force-includes the best direction (bullish = long, bearish = short based on median price vs current).

---

## 14. Trade Output

Each position (`TradingPosition`) contains:

| Field | Type | Description |
|-------|------|-------------|
| `direction` | `TradeDirection` | LONG or SHORT |
| `entryPrice` | double | Limit entry price (rounded to 4 decimals) |
| `exitPrice` | double | Take profit target (conditional expectation from MC) |
| `stopLoss` | double | Stop loss price |
| `expectedValue` | double | Expected value in $ (leveraged) |
| `predictedROI` | double | Expected ROI % (leveraged) |
| `confidenceScore` | int | TP barrier probability as integer % (5-95) |
| `tpProbability` | double | TP barrier hit probability (0-1) |
| `slProbability` | double | SL barrier hit probability (0-1) |
| `positionSizePct` | double | Half-Kelly position size % |
| `strategyDescription` | String | Formatted strategy narrative |
| `leverage` | int | Calculated leverage multiplier (1-maxLeverage) |
| `durationHours` | int | Timeframe in hours |

---

## 15. Ludomania Mode

When enabled, an additional high-risk/high-reward position is built:

| Parameter | Standard | Ludomania |
|-----------|----------|-----------|
| Direction | Both long + short | Best direction only (based on median) |
| Entry discount | Conservative/aggressive | 0.3x of ludomania base (1.8x aggressive) |
| Exit target | Conditional expectation | Extreme percentile (P90 long / P10 short) |
| Stop loss multiplier | 1.2 | 2.5 (wider) |
| Kelly fraction | 0.5 (half) | 1.0 (full), capped at 10% |
| Leverage | Standard formula | Standard formula (same) |

The ludomania position is appended to the positions list (not sorted) and flagged with `isLudomania: true`.

---

## Configuration Constants

All parameters below are tunable via `AlgorithmConfig` unless marked as fixed:

| Constant | Default | Tunable | Description |
|----------|---------|---------|-------------|
| txCost | 0.001 (0.1%) | Yes | Transaction cost per trade |
| slippage | 0.0002 (0.02%) | Yes | Slippage estimate |
| stopMultiplier | 1.2 | Yes | SL buffer (x distribution stdDev) |
| Kelly fraction | 0.5 | No | Half-Kelly for safety |
| kellyMax | 0.05 (5%) | Yes | Position size cap |
| Min TP probability | 0.40 | No | Trade acceptance threshold |
| periodScaleMin | 0.5 | Yes | Duration scaling lower bound |
| periodScaleMax | 2.5 | Yes | Duration scaling upper bound |
| discountLow | 0.0010 | Yes | Entry discount for LOW regime |
| discountMedium | 0.0020 | Yes | Entry discount for MEDIUM regime |
| discountHigh | 0.0040 | Yes | Entry discount for HIGH regime |
| Leverage base factor | 0.35 | No | Target SL loss base |
| maxLeverage | 75 | Yes | Leverage cap |
| Ludomania SL multiplier | 2.5 | No | Wider stops for YOLO |
| Ludomania max Kelly | 10% | No | Higher position size cap |
| driftMultiplier | 50.0 | Yes | (Available in config, not used in barrier pricing) |
