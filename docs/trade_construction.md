# Trade Construction, Pricing & Sizing

> **Layer 4 — EV-Optimized Trade Building**  
> **File:** `lib/services/analysis_service.dart`, method `_buildDirectionalPositions()`  
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Trade Direction Logic

```
if P50 ≥ currentPrice → build LONG positions
if P50 < currentPrice → build SHORT positions
```

If the chosen direction produces no valid trades (negative EV), the engine falls back to `forceInclude = true` to return informational positions.

---

## 2. Position Construction (Long / Short)

Two positions per direction: **conservative** and **aggressive**.

### 2.1 Long Entry

```
entry = currentPrice × (1 − entryDiscount)
```

Discount = `baseDiscount × periodScale`, clamped.

### 2.2 Short Entry

```
entry = currentPrice × (1 + entryPremium)
```

Premium = `baseDiscount × periodScale`, clamped.

### 2.3 Regime Base Discounts (24h calibration)

| Regime | Conservative | Aggressive |
|--------|-------------|------------|
| Low Vol (0) | 0.15% | 0.40% |
| Med Vol (1) | 0.30% | 0.70% |
| High Vol (2) | 0.50% | 1.20% |

### 2.4 Period Scaling

```
periodScale = clamp(√(hours / 24), 0.25, 3.0)
```

### 2.5 Exit — Conditional Expectation

Uses simulation paths from [monte_carlo.md](monte_carlo.md).

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

### 2.6 Stop Loss

```
Long:  stop = entry − k × StdDev_distribution
Short: stop = entry + k × StdDev_distribution
```

Where k = 1.5 (`_slMultiplier`).

---

## 3. Barrier Probabilities

Uses **full path max/min** from [monte_carlo.md](monte_carlo.md#4-path-tracking) — a path can hit TP even if it doesn't end there.

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

## 4. Expected Value

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

## 5. Position Sizing (Kelly Criterion)

```
f* = (TP_prob × TP_gain − SL_prob × SL_loss) / SL_loss
```

Use half-Kelly for safety:
```
positionSize = clamp(0.5 × f*, 0%, 5%)
```

Cap at 5% of capital maximum.

---

## 6. Trade Acceptance Filter

A position is **rejected** (not shown) unless:

```
EV_adj > 0   AND   TP_prob ≥ 0.40
```

If no positions pass the filter for either direction, the engine falls back to `forceInclude = true` and shows informational positions.

---

## Configuration Constants

| Constant | Value | Location |
|----------|-------|----------|
| SL multiplier k | 1.5 | `AnalysisService._slMultiplier` |
| Transaction cost | 0.2% | `AnalysisService._txCost` |
| Slippage | 0.05% | `AnalysisService._slippage` |
| Kelly fraction | 0.5 (half-Kelly) | `AnalysisService._kellyFraction` |
| Max position size | 5% | `AnalysisService._maxPositionSize` |
| Min TP probability | 40% | `AnalysisService._minTpProb` |
