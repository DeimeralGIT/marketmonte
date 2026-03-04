# **App Name**: Market Monte

> **Last updated:** 2026-03-04

## Core Features:

- **Crypto Pair Selection:** Allows users to select available USDT trading pairs from Binance for analysis, with a search/filter field for quick lookup.
- **Historical Data Retrieval:** Fetches historical price, volume, and order book data for selected pairs from Binance public APIs.
- **Student-t HMM + Particle Filter + State-Space MC Engine:** A four-layer probabilistic pipeline — regime detection (Student-t HMM with Baum-Welch EM), volatility adaptation (500-particle filter), sticky regime Monte Carlo simulation (10,000 paths), and EV-optimized trade construction with barrier pricing and Kelly sizing. See [algorithm.md](algorithm.md) for full technical reference.
- **ROI Position Generation:** Suggests potential long/short trading positions with entry price, exit target, stop loss, expected value, SL/TP probabilities, and strategy outlook — all ranked by predicted ROI.
- **Configurable Time Horizon:** Users choose from 1H, 4H, 1D, 1W, or 1M analysis windows, each adjusting the simulation step count.
- **Investment Sizing:** Users input a USDT investment amount; position size (quantity) and expected value are scaled to the investment.
- **Regime Detection Display:** Visual regime card showing detected volatility regime (Low / Medium / High), probability bars, stability score, and annualized volatility.
- **Market Leaderboard:** Global scan mode that evaluates top USDT pairs by volume and surfaces the highest-alpha opportunities.
- **Pair Statistics Banner:** Unified card with a hero price display (crypto icon, name, large monospace price, 24h change badge) above a 3-column stat grid (24h High, 24h Low, Volume) separated by a subtle divider — no horizontal scrolling.
- **Exit Reminder / Calendar Integration:** After tapping the trade button, a bottom sheet offers to create a Google Calendar event with the exit target, close-by time, and ROI target pre-filled.
- **Deep Link to Exchange:** One-tap launch to the selected exchange's trading page (or app if installed) for the selected pair. Supports Binance, Coinbase, and MEXC.
- **Settings Drawer:** Slides in from the right via a hamburger menu button in the app bar. Contains a dark/light theme toggle (persisted via `shared_preferences`), a ludomania mode toggle (persisted via `shared_preferences`), an exchange selector (Binance / Coinbase / MEXC, persisted via `shared_preferences`), and a 6-language selector (persisted via `easy_localization`).
- **Ludomania Mode:** Optional setting that, when enabled, appends an extra high risk/reward "YOLO" position to the analysis results. The ludomania position uses more aggressive parameters (1.8× the aggressive base discount, P90/P10 exit targets, 2.5× SL multiplier, full Kelly sizing up to 10%). It is visually highlighted with an orange border, gradient, and a flame-icon “LUDOMANIA” badge. Persisted via `shared_preferences` through `LudomaniaNotifier`.- **Pull to Refresh:** The main scrollable body is wrapped in a `RefreshIndicator` (with `AlwaysScrollableScrollPhysics`). Pulling down refreshes the current view: if a single-pair analysis was active it re-fetches the ticker and re-runs `analyzePair()`; if the market leaderboard was showing it re-runs `scanMarket()`; otherwise it refreshes the 24h ticker only. The ludomania flag is forwarded on refresh so the YOLO position is preserved when enabled.
## Internationalization (i18n):

- **Framework:** `easy_localization` (^3.0.7) with JSON translation files.
- **Supported Languages:** English (en), Russian (ru), Spanish (es), French (fr), Portuguese (pt), Italian (it).
- **Translation Files:** `assets/translations/{en,ru,es,fr,pt,it}.json` — nested key structure with `namedArgs` for all dynamic text (`{regime}`, `{score}`, `{symbol}`, `{rank}`, `{horizon}`, `{asset}`, `{price}`, `{quantity}`, `{amount}`, `{exchange}`).
- **Coverage:** All user-facing UI text is localized — headers, labels, buttons, hints, status messages, regime/time-period display names, position card fields, and the reminder dialog. Algorithmic/strategy description strings remain in English (runtime-generated).
- **Fallback:** English (`Locale('en')`).
- **Guideline:** Any new user-facing text must be added to all 6 translation JSON files and referenced via `tr()` with `namedArgs` where dynamic values are needed. Enum display names are translated at point-of-use via helper methods rather than in the enum definition.

## Architecture:

- **Framework:** Flutter / Dart
- **State Management:** Riverpod (`flutter_riverpod`)
- **Navigation:** Single-screen app with card-based modular layout
- **Services:** `ExchangeService` (abstract API interface), `BinanceExchangeService` / `CoinbaseExchangeService` / `MexcExchangeService` (concrete implementations), `AnalysisService` (probabilistic engine)
- **Models:** `analysis_models.dart` (enums, result types), `binance_models.dart` (API DTOs), `exchange_models.dart` (Exchange enum)
- **Theming:** Dynamic `AppColors` proxy class backed by dark/light `_ColorScheme` objects (`app_theme.dart`). `ThemeNotifier` (Riverpod) manages `ThemeMode`, persisted to `shared_preferences`. `MaterialApp` receives both `theme` (light) and `darkTheme` (dark) with `themeMode` from the provider.

## Style Guidelines:

- The app supports **dark and light themes**, toggled from the settings drawer. Dark mode uses a deep purplish-gray background (#23202A) with light foreground (#FAFAFA) and sky-blue accent (#66B2FF). Light mode uses a soft lavender-gray background (#F6F5F9) with dark foreground (#1A1820) and a saturated blue accent (#3B82F6). The primary brand color (#4D4099) is consistent across both themes. Theme preference persists across sessions.
- The application uses 'Inter' (sans-serif) for all text elements. This modern, objective, and neutral typeface ensures high readability for complex data sets and numerical information, maintaining a clean and professional aesthetic across headlines, body text, and data tables. It promotes clarity and reduces cognitive load when presenting analytical results.
- Use minimalist, outline-style icons (Lucide icon set) with clear visual metaphors related to financial charts, data, and trading actions. Icons should maintain a consistent line weight and be subtle, complementing the data-centric UI without adding visual clutter.
- Employ a modular and data-dense layout. Key information, such as selected pairs, real-time metrics, and predicted positions, should be organized into clearly delineated cards or sections. The design prioritizes responsiveness, ensuring a seamless experience across various screen sizes while maintaining information hierarchy. Critical actionable insights are highlighted for easy recognition.
- Position cards use a responsive 2-column grid for price boxes (Entry/Exit, StopLoss/EV, SL Prob/TP Prob) with `FittedBox` auto-scaling and `Wrap`-based header badges for mobile-friendly display.
- Pair stats use a unified card: hero price banner on top with crypto icon, name, large monospace price, and a colored 24h change badge, separated by a subtle divider from a 3-column stat grid (24h High, 24h Low, Volume) with vertical dividers — no horizontal scrolling.
- Implement subtle, fluid animations for data updates and state changes, such as loading new data or re-ranking positions. These micro-interactions provide visual feedback to the user, enhancing the perception of responsiveness and adding a layer of polish without distracting from the core information.

## File Structure:

```
lib/
  main.dart                          # App entry, EasyLocalization bootstrap
  models/
    analysis_models.dart             # Enums (TimePeriod, VolatilityRegime, TradeDirection), result types
    binance_models.dart              # API DTOs (shared across exchanges)
    exchange_models.dart             # Exchange enum (binance, coinbase, mexc)
  providers/
    market_providers.dart            # Riverpod providers, state notifier
    theme_provider.dart              # ThemeNotifier + themeProvider (dark/light, persisted)
    exchange_provider.dart           # ExchangeNotifier + exchangeProvider (persisted)
    ludomania_provider.dart          # LudomaniaNotifier + ludomaniaProvider (on/off, persisted)
  screens/
    home_screen.dart                 # Main screen with tab-like controls
  services/
    analysis_service.dart            # Four-layer probabilistic engine
    binance_service.dart             # Legacy Binance REST API client
    exchange_service.dart            # Abstract ExchangeService interface
    regime_detection_service.dart    # Student-t HMM regime detection
    exchanges/
      binance_exchange_service.dart  # Binance implementation of ExchangeService
      coinbase_exchange_service.dart # Coinbase implementation of ExchangeService
      mexc_exchange_service.dart     # MEXC implementation of ExchangeService
  theme/
    app_theme.dart                   # AppColors, AppTheme constants
  utils/
    formatters.dart                  # Price/ROI formatting helpers
    crypto_names.dart                # Ticker-to-full-name mapping
  widgets/
    analysis_section.dart            # Regime card, probability bars, engine summary
    app_header.dart                  # Market Monte branding header (app icon asset) + settings menu button
    controls_card.dart               # Pair selector, investment input, time horizon, analyze/scan buttons
    empty_state.dart                 # Empty/ready state placeholder
    footer.dart                      # Disclaimer footer
    leaderboard_section.dart         # Global scan results
    pair_stats.dart                  # Hero price + 3-column stat grid + crypto icon/name
    position_card.dart               # Trade position card with exchange deeplink + reminder dialog
    settings_drawer.dart             # Right-slide settings panel (theme toggle, ludomania toggle, exchange selector, language picker)
    crypto_icon.dart                 # CryptoIcon widget (CoinCap CDN with letter fallback)
assets/
  icon/
    app_icon.png                     # App icon asset (1x / 2.0x / 3.0x resolution variants)
  translations/
    en.json, ru.json, es.json, fr.json, pt.json, it.json
docs/
  blueprint.md                       # This file
  algorithm.md                       # Full algorithm technical reference
```