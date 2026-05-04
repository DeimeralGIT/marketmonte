# **App Name**: AlgoTrade Sim

## Platforms

- **Web:** Next.js (TypeScript) — dashboard, simulation, strategies, performance pages
- **Android:** Native Kotlin — headless background trading on dead-screen phone, controlled entirely via Telegram

## Core Features:

- **4-Layer Trading Engine:** Threshold-based regime detection, volatility adaptation (volScale), analytical drift/sigma baseline, and EV-optimized trade construction with Kelly sizing. Identical implementation in TypeScript (web) and Kotlin (Android).
- **Dual-Pick Scan System:** Scans top 10 USDT pairs by volume across 6 timeframes (1h, 4h, 12h, 1d, 2d, 1w), selecting independently the best CONFIDENCE pick and best ROI pick per cycle.
- **Dynamic Position Sizing:** Position size is calculated as `balance × basePositionPct × (confidence / 50)`, scaling with both account balance and trade confidence. `basePositionPct` adapts after each close (grows on wins, shrinks on losses).
- **Real-time Market Data:** Fetches cryptocurrency price data via Binance Public REST API (no auth required) for live simulation across multiple trading pairs.
- **24/7 Android Foreground Service:** Runs as a persistent foreground service with WakeLock, auto-restarts on device boot via BootReceiver. Performs continuous scan loops (5-min default) and TP/SL/liquidation/timeout monitoring (1-minute intervals). Survives OS kills via multi-layer persistence: `START_STICKY`, AlarmManager watchdog (15-min heartbeat), `onTaskRemoved` restart, and battery optimization exemption.
- **Position Monitor Network Resilience:** When price fetch fails during monitoring, retries 2 more times at 1-minute intervals. After 3 consecutive failures, overdue positions are voided — capital refunded, not counted in statistics.
- **Telegram Bot Integration:** Full bot command interface for managing the trading system. Forum topic routing separates notifications into Status (errors/service events), Algorithm (DA reports/heartbeats), Positions (opens/closes), Scan Results (scanned cryptos with prices), and Logs (cumulative position history + algorithm change logs) topics.
- **Telegram Bot Commands:** /balance, /reset (full reset: drops positions, clears history, zeroes stats, restores default balance), /set_balance (inline keyboard), /stats, /positions, /drop_positions, /joke (cowsay ASCII art), /statistics (extended stats with pick type breakdown), /reset_statistics, /reset_algorithm (revert engine parameters to compiled defaults), /set_interval (inline keyboard: 5m/10m/30m/1h), /start, /stop, /help (random quote).
- **Dynamic Adjustment Reports:** After each position close, generates a Markdown report comparing entry-time vs current engine parameters (volScale, regime, persistenceBoost, Kelly), with conditional recommendations. Sent as .md files to Telegram. **On losing positions**, DA findings are applied to the engine's runtime `AlgorithmConfig` — adapting stop multiplier, regime thresholds, discounts, drift, and persistence for subsequent scans.
- **Runtime Algorithm Config:** 17 tunable engine parameters stored in `AlgorithmConfig` (persisted via SharedPreferences). Auto-adapted when positions lose, manually resettable via `/reset_algorithm`.
- **Leverage System:** Each trade calculates optimal leverage based on SL distance, confidence, and regime using `(0.35 × confScale × regimeScale) / slDistancePct`, clamped to [1, maxLeverage]. Amplifies both EV and expectedROI. Positions are liquidated if leveraged loss ≥ margin.
- **Dashboard Display (Web):** Overview of success rate, open positions, total P&L, live BTC price, equity growth chart, and algorithm status indicators.
- **Simulation Configuration (Web):** Input interface for setting simulation parameters: scan frequency, target position duration, and initial capital.
- **Strategy File Ingestion (Web):** Built-in Markdown editor for trading algorithm definitions and rules, with export and Telegram sharing capabilities.
- **AI-Powered Analysis (Web):** Genkit + Gemini 2.5 Flash for performance summaries, parameter adjustment suggestions, and strategy blueprint generation.
- **Performance Metrics (Web):** Detailed performance metrics including success rate, win/loss ratio, confidence levels, expected vs actual ROI comparison, and historical simulation data.

## Android Architecture:

- **minSdk:** 26, **targetSdk:** 35, **compileSdk:** 35
- **Language:** Kotlin 2.1.0, AGP 8.7.3
- **Dependencies:** OkHttp 4.12.0, Kotlinx Coroutines 1.9.0, AndroidX core-ktx 1.15.0
- **Data Persistence:** SharedPreferences-backed TradingStore (balance, positions, history, config, scan interval, algorithm config)
- **APIs:** Binance (market data), Telegram Bot API (notifications + commands), JokeAPI v2 (jokes), zenquotes.io (quotes)

## Telegram Forum Topics:

| Topic | Thread ID | Content |
|-------|-----------|---------|
| Status | 5 | Service start/stop, errors, interruptions |
| Algorithm | 4 | DA reports (.md), scan heartbeats, retrospective summaries |
| Positions | 2 | Position opened/closed notifications |
| Scan Results | 378 | Scanned crypto names, current prices, open position counts |
| Logs | 3392 | Cumulative position history + algorithm change logs (.md files) |
## Style Guidelines:

- Primary color: A deep, intelligent blue-violet (#3333CC) for main interactive elements.
- Background color: A heavily desaturated, dark blue-violet (#16161D) for a calm, focused environment.
- Accent color: A vibrant light cyan (#75F0FF) for highlighting important data and active states.
- Font: 'Inter' — modern, neutral sans-serif for data-intensive readability.
- Minimalist, outline-style icons for financial indicators and navigation.
- Modular, grid-based dashboard layout with clearly defined sections.
- Subtle, non-intrusive animations for chart updates and data transitions.
