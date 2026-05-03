# Cross-Asset Selection (Leaderboard)

> **File:** `lib/services/analysis_service.dart`, method `scanTopMarket()`  
> **Parent doc:** [algorithm.md](algorithm.md)

---

## Algorithm

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

Regime entropy is defined in [particle_filter.md](particle_filter.md#61-regime-entropy).

---

## Risk Controls

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
