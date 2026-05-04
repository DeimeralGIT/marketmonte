# Market Leaders Scan (Leaderboard)

> **Cross-Asset Scanning**
> **File:** `lib/services/analysis_service.dart` (method `scanTopMarket`)
> **Parent doc:** [algorithm.md](algorithm.md)

---

## 1. Overview

The Market Leaders scan fetches the top 10 USDT pairs by 24h quote volume from the selected exchange, runs the full 4-layer analysis pipeline (Student-t HMM + Particle Filter + Monte Carlo + Trade Construction) on each pair, and ranks results by **entropy-penalized expected value** with leveraged returns. The top 3 opportunities are presented as LeadPosition picks.

---

## 2. Scan Flow

```
1. Fetch top 10 USDT pairs by 24h volume from selected exchange
   - Exchange is configurable: Binance, Coinbase, or MEXC
   - Stablecoins are filtered by each exchange service
2. For each symbol:
   a. Fetch 168 x 1H klines
   b. Skip symbol if no klines returned
   c. Run _runHybridEngine(symbol, klines, period)
      - Full pipeline: HMM → PF → MC (10k paths) → Trade Construction
   d. If positions are produced, store:
      - symbol
      - topPosition (highest EV position)
      - regimeInfo (regime, stability, entropy)
   e. Skip silently on any exception
3. Rank all analyzed pairs by entropy-penalized EV
4. Return top 3 as LeadPosition picks
```

---

## 3. Ranking — Entropy-Penalized Expected Value

The ranking formula ensures that high-EV positions in **certain regimes** are preferred over those in ambiguous market states:

```
maxEntropy = ln(3)    // ~1.099
normalizedEntropy = regimeEntropy / maxEntropy
penalty = 1 - clamp(normalizedEntropy, 0, 1)

score = topPosition.expectedValue * penalty
```

Sorted by **descending score**.

**Intuition:**
- When regime is certain (entropy near 0), `penalty` approaches 1.0 — full EV is used
- When regime is uncertain (entropy near ln(3)), `penalty` approaches 0.0 — EV is discounted
- This prevents the scan from recommending positions where the regime detection is unreliable

---

## 4. LeadPosition Output

Each of the top 3 picks produces a `LeadPosition`:

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | String | Trading pair (e.g., "BTCUSDT") |
| `direction` | TradeDirection | LONG or SHORT |
| `entryPrice` | double | Limit entry price |
| `exitPrice` | double | Take profit target |
| `stopLoss` | double | Stop loss price |
| `predictedROI` | double | Expected ROI % (leveraged) |
| `confidenceScore` | int | TP barrier probability (5-95%) |
| `expectedValue` | double | Expected value in $ (leveraged) |
| `leverage` | int | Calculated leverage multiplier |
| `reasoning` | String | Formatted explanation of the pick |

The reasoning string is generated from the `leaderboard.reasoningTemplate` translation key and includes: regime label, stability score, entropy %, direction, paths count, horizon, EV, and leverage.

---

## 5. Global Outlook

A summary string is generated from `leaderboard.globalOutlookTemplate` containing:

- Horizon label (e.g., "1 Day")
- Number of pairs successfully analyzed
- Regime distribution: count of LOW, MEDIUM, HIGH regime detections

---

## 6. Multi-Exchange Support

The scan uses whichever exchange service is currently configured:

| Exchange | Volume Pairs Source | Kline Source |
|----------|-------------------|--------------|
| Binance | `fetchTopUSDTByVolume(limit: 10)` | `fetchHistoricalKlines(symbol, limit: 168)` |
| Coinbase | Same abstract interface | Same abstract interface |
| MEXC | Same abstract interface | Same abstract interface |

All exchanges implement the abstract `ExchangeService` interface. The user switches exchanges via the settings panel, and `AnalysisService.updateExchangeService()` updates the data source.

---

## 7. Differences from Android Dual-Pick System

The Flutter app's leaderboard is an **analytical presentation tool**, not a headless trading bot:

| Aspect | Flutter App (Market Monte) | Android Bot (Previous) |
|--------|---------------------------|----------------------|
| Purpose | Present top opportunities to user | Automatically open positions |
| Picks returned | Top 3 by entropy-penalized EV | 2 (confidence + ROI) |
| Position opening | None (user views and trades manually) | Automatic via Binance API |
| Timeframes per scan | Single (user-selected) | 6 (1H through 1W) per symbol |
| Monitoring | None | 1-minute position monitor |
| Notifications | None | Telegram heartbeat + alerts |
| Balance tracking | None | Real-time via exchange API |
| Scan interval | On-demand (user taps "Scan") | Configurable timer (5min-1hr) |

---

## Configuration Constants

| Constant | Value | Description |
|----------|-------|-------------|
| Top pairs scanned | 10 | `fetchTopUSDTByVolume(limit: 10)` |
| Klines fetched | 168 (1H candles) | Training window per symbol |
| Picks returned | Top 3 | Ranked by entropy-penalized EV |
| Ranking formula | EV * (1 - normalizedEntropy) | Entropy penalty |
| Pipeline per pair | Full 4-layer | HMM + PF + MC + Trade Construction |
