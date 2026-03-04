# Flutter Conversion Instruction — Market Monte

> **Purpose**: Paste this entire document into a fresh AI chat session. It contains everything needed to convert the Market Monte Next.js/React app into a Flutter app in a single session. Work through the steps sequentially — each step's output feeds the next.

---

## GLOBAL RULES FOR THE ENTIRE SESSION

1. **Target**: Flutter 3.x, Dart 3.x. Platforms: iOS + Android (Web optional).
2. **State management**: Use `flutter_riverpod` (with `StateNotifier` pattern).
3. **HTTP**: Use the `http` package (not `dio`).
4. **Font**: Inter via `google_fonts` package.
5. **Icons**: Use `lucide_icons` package to match the current app's icon set.
6. **No code generation build step**: Use manual `fromJson`/`toJson` on models (avoid `json_serializable` + `build_runner` complexity).
7. **Single `lib/` tree** — no feature-first folders. Use flat grouping: `models/`, `services/`, `providers/`, `screens/`, `widgets/`, `theme/`, `utils/`.
8. **Dark theme only**. No light mode toggle.
9. **Every file you create must be complete and runnable** — no placeholders, no "TODO", no `// ...rest`.
10. After each step, confirm completion before moving to the next.

---

## APP CONTEXT — WHAT THIS APP DOES

Market Monte is a crypto trading analysis tool. It:
- Fetches USDT trading pairs from the Binance public REST API
- Lets the user pick a pair and set an investment amount (USDT)
- Runs a local MCMC (Markov Chain Monte Carlo) statistical engine on historical kline data to generate predicted trading positions with entry/exit prices, ROI, and confidence scores
- Has a "Scan Market Leaders" feature that analyzes the top 10 pairs by volume and returns the best 3
- Links out to Binance for execution
- Uses a dark purple/blue theme with accent sky-blue

---

## STEP 1 — Project Scaffolding

Run these commands (or instruct me to run them):

```bash
flutter create market_monte --org com.marketmonte --platforms ios,android
cd market_monte
```

Then replace `pubspec.yaml` dependencies with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  flutter_riverpod: ^2.5.0
  google_fonts: ^6.1.0
  lucide_icons: ^0.257.0
  url_launcher: ^6.2.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  flutter_launcher_icons: ^0.14.0
```

Create the folder structure inside `lib/`:
```
lib/
  main.dart
  models/
  services/
  providers/
  screens/
  widgets/
  theme/
  utils/
```

---

## STEP 2 — Theme (`lib/theme/app_theme.dart`)

Port this exact color system (from CSS HSL variables):

| Token | HSL | Hex |
|---|---|---|
| background | 260, 9%, 14% | `#23202A` |
| foreground | 0, 0%, 98% | `#FAFAFA` |
| card | 260, 9%, 16% | `#282530` |
| primary | 249, 41%, 42% | `#4D4099` |
| primary-foreground | 0, 0%, 100% | `#FFFFFF` |
| secondary | 260, 9%, 22% | `#37333E` |
| muted | 260, 9%, 22% | `#37333E` |
| muted-foreground | 240, 5%, 65% | `#A3A1A8` |
| accent | 210, 100%, 70% | `#66B2FF` |
| accent-foreground | 260, 9%, 14% | `#23202A` |
| destructive | 0, 84%, 60% | `#EF4444` |
| border | 260, 9%, 22% | `#37333E` |

Additional styling rules:
- Border radius: 12px (0.75rem)
- Font family: Inter (via `google_fonts`)
- Card gradient: `LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x194D4099), Color(0x80222026)])`
- Accent glow: `BoxShadow(color: Color(0x2666B2FF), blurRadius: 20)`

Create a full `ThemeData.dark().copyWith(...)` that covers: `scaffoldBackgroundColor`, `colorScheme`, `cardTheme`, `appBarTheme`, `inputDecorationTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `textTheme` (using `GoogleFonts.interTextTheme`).

---

## STEP 3 — Data Models (`lib/models/`)

### `lib/models/binance_models.dart`

```dart
class BinancePair {
  final String symbol;
  final String baseAsset;
  final String quoteAsset;
  // fromJson constructor from Binance exchangeInfo response "symbols" array items
}

class KlineData {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  // fromJson: Binance klines returns arrays: [openTime, open, high, low, close, volume, ...]
  // Parse index 0=time, 1=open, 2=high, 3=low, 4=close, 5=volume (all strings → doubles)
}
```

### `lib/models/analysis_models.dart`

```dart
class TradingPosition {
  final double entryPrice;
  final double exitPrice;
  final double predictedROI;
  final int confidenceScore; // 0-100
  final String strategyDescription;
}

class CryptoAnalysisResult {
  final List<TradingPosition> positions;
  final String analysisSummary;
}

class LeadPosition {
  final String symbol;
  final double entryPrice;
  final double exitPrice;
  final double predictedROI;
  final int confidenceScore;
  final String reasoning;
}

class MarketLeaderboardResult {
  final List<LeadPosition> topPicks;
  final String globalOutlook;
}
```

---

## STEP 4 — Services (`lib/services/`)

### `lib/services/binance_service.dart`

Base URL: `https://api.binance.com/api/v3`

Implement these methods (all return Futures, all handle errors gracefully with try/catch returning empty lists/null):

1. **`fetchUSDTTradingPairs()`** → `Future<List<BinancePair>>`
   - GET `/exchangeInfo`
   - Filter: `status == 'TRADING' && quoteAsset == 'USDT'`

2. **`fetchTopUSDTByVolume({int limit = 10})`** → `Future<List<String>>`
   - GET `/ticker/24hr`
   - Filter symbols ending with 'USDT', sort by `quoteVolume` descending, take `limit`

3. **`fetchHistoricalKlines(String symbol, {int limit = 100})`** → `Future<List<KlineData>>`
   - GET `/klines?symbol=$symbol&interval=1h&limit=$limit`

4. **`fetch24hTicker(String symbol)`** → `Future<Map<String, dynamic>?>`
   - GET `/ticker/24hr?symbol=$symbol`

5. **`getBinanceTradeUrl(String symbol, {double? investmentAmount})`** → `String`
   - Format: `https://www.binance.com/en/trade/${base}_USDT?type=spot`
   - If `investmentAmount > 0`, append `&quoteOrderQty=$investmentAmount`

### `lib/services/analysis_service.dart`

Port the **exact** MCMC logic from the original. Here is the complete algorithm:

```
function runLocalMCMC(symbol, klines):
  prices = klines.map(k => k.close)
  currentPrice = prices[last]

  avg = mean(prices)
  stdDev = population standard deviation of prices
  volatility = stdDev / avg

  recentTrend = (currentPrice - prices[0]) / prices[0]

  Position A (Conservative):
    entry = currentPrice * 0.998
    exit  = currentPrice * (1 + volatility * 1.2)
    roi   = ((exit - entry) / entry) * 100
    confidence = min(95, floor(80 - (volatility * 100)))
    strategy = "Conservative statistical entry based on 1.2-sigma volatility bands."

  Position B (Aggressive):
    entry = currentPrice * 1.005
    exit  = currentPrice * (1 + volatility * 2.5)
    roi   = ((exit - entry) / entry) * 100
    confidence = min(75, floor(60 - (volatility * 50)))
    strategy = "Aggressive breakout target aiming for a 2.5-sigma momentum move."

  Sort positions by predictedROI descending.

  analysisSummary = "Local Engine Analysis: $symbol is showing a
    ${recentTrend > 0 ? 'bullish' : 'bearish'} trend with a 24h volatility
    of ${(volatility * 100).toFixed(2)}%. Statistical support is found near
    $${(currentPrice * 0.98).toFixed(2)}."
```

Implement two public methods:

1. **`analyzePair(String symbol)`** → `Future<CryptoAnalysisResult>`
   - Fetch 50 klines, run MCMC, return result

2. **`scanTopMarket()`** → `Future<MarketLeaderboardResult>`
   - Fetch top 10 by volume
   - For each: fetch 24 klines, run MCMC
   - Sort by ROI descending, take top 3
   - Each pick's reasoning: `"Leading the market in risk-adjusted ROI potential within the high-volume cluster."`
   - globalOutlook: `"The global market scan is utilizing local statistical models. High volume leaders are being ranked by their volatility-to-trend ratios."`

---

## STEP 5 — State Management (`lib/providers/`)

### `lib/providers/market_providers.dart`

Use Riverpod. Define:

1. **`binanceServiceProvider`** — simple Provider returning a `BinanceService` singleton
2. **`analysisServiceProvider`** — Provider returning `AnalysisService(ref.read(binanceServiceProvider))`
3. **`pairsProvider`** — `FutureProvider<List<BinancePair>>` that calls `fetchUSDTTradingPairs()`
4. **`marketStateProvider`** — `StateNotifierProvider<MarketStateNotifier, MarketState>`

### `MarketState` class (immutable):
```dart
class MarketState {
  final String selectedPair;        // default: 'BTCUSDT'
  final String searchQuery;         // default: ''
  final double investmentAmount;    // default: 100.0
  final bool loading;               // default: false
  final String? error;
  final CryptoAnalysisResult? analysis;
  final MarketLeaderboardResult? leaderboard;
  final Map<String, dynamic>? ticker;
  final ActiveTab activeTab;        // enum: single, market
}

enum ActiveTab { single, market }
```

### `MarketStateNotifier` — methods:
- `setSelectedPair(String pair)`
- `setSearchQuery(String query)`
- `setInvestmentAmount(double amount)`
- `analyzePair()` — sets loading, clears leaderboard, calls service, sets analysis + ticker, handles errors
- `scanMarket()` — sets loading, clears analysis + ticker, calls service, sets leaderboard, handles errors
- `init()` — fetch initial ticker for BTCUSDT

---

## STEP 6 — Screens & Widgets

### `lib/main.dart`
- Wrap app in `ProviderScope`
- `MaterialApp` with theme from Step 2, home: `HomeScreen`
- No routing needed (single screen app)

### `lib/screens/home_screen.dart`
This is the main screen. Structure (maps to AppContainer.tsx):

```
Scaffold(
  body: CustomScrollView(
    slivers: [
      AppHeader (as SliverAppBar or just a widget),
      SliverToBoxAdapter(
        child: Column(
          children: [
            ControlsCard,        // search, investment input, pair dropdown, analyze button, scan button
            if (error) ErrorBanner,
            if (ticker && tab==single) PairStatsRow,
            if (analysis && tab==single) AnalysisResultSection,
            if (leaderboard && tab==market) LeaderboardSection,
            if (empty state) EmptyState,
            Footer,
          ]
        )
      )
    ]
  )
)
```

### `lib/widgets/app_header.dart`
Port from Header.tsx:
- Row: logo icon (TrendingUp in a purple rounded container) + "Market Monte" title (white, "Monte" in accent blue) + subtitle "MCMC Prediction Engine"
- Right side: "Connect API" / "API Connected" toggle button
- Sticky at top, semi-transparent background with blur (if possible, else solid card color)
- Use `SliverAppBar` with `floating: true`

### `lib/widgets/controls_card.dart`
Port from AppContainer.tsx controls section:
- Card with accent glow shadow
- Search TextField with search icon prefix
- Investment amount TextField with dollar icon prefix, numeric keyboard
- Pair dropdown — use `DropdownButtonFormField` or a custom searchable list:
  - Filter pairs by `searchQuery`
  - Show max 100 items
- "Analyze" ElevatedButton (primary color, BrainCircuit icon)
- Divider
- "Scan Market Leaders" OutlinedButton (accent border, Zap icon)
- Show loading spinner in buttons when `loading` is true

### `lib/widgets/pair_stats.dart`
Port from PairStats.tsx:
- Horizontal scrollable row of 4 cards (or 2x2 grid on narrow screens):
  1. **Price** — `lastPrice`, with `priceChangePercent` colored green/red with ▲/▼
  2. **24h High** — `highPrice`
  3. **24h Low** — `lowPrice`
  4. **Volume** — `volume` + base asset name
- Each card: secondary background, icon in top-right, monospace numbers

### `lib/widgets/position_card.dart`
Port from PositionCard.tsx:
- Card with gradient background (`crypto-card-gradient`)
- Header: Rank badge (outlined, accent), confidence %, ROI target (large, green if positive / red if negative)
- Arrow icon top-right in circle
- Body:
  - 2-column grid: Entry Price | Exit Target (monospace)
  - Size calculation row: `quantity = investmentAmount / entryPrice`, show `quantity BASE_ASSET` and `"For $X USDT"`
  - Strategy description (italic, quoted)
- Footer: "Trade on Binance" button → opens URL via `url_launcher`

### `lib/widgets/analysis_section.dart`
Port from AppContainer.tsx analysis display:
- Outlook card: primary tinted background, BrainCircuit icon watermark, title "Outlook: {symbol}", summary text
- "Recommended Positions" header with LayoutGrid icon
- Grid of PositionCards (use `Wrap` or responsive grid)

### `lib/widgets/leaderboard_section.dart`
Port from AppContainer.tsx leaderboard display:
- Global outlook card: accent tinted, TrendingUp icon, title "Global Market Leaders Scan"
- "Top Alpha Opportunities" header with Zap icon
- Grid of PositionCards (3 cards)

### `lib/widgets/empty_state.dart`
- Centered: BrainCircuit icon (large, muted), "Ready for analysis" title, subtitle text

### `lib/widgets/footer.dart`
- Centered small text: "MARKET MONTE IS AN ANALYTICAL TOOL. TRADING CRYPTOCURRENCIES INVOLVES RISK."
- Top border, padding

---

## STEP 7 — Utility Helpers (`lib/utils/`)

### `lib/utils/formatters.dart`
- `formatPrice(double price)` — locale-aware number format with commas
- `formatVolume(double volume)` — locale-aware
- `formatROI(double roi)` — "+X.XX%" or "-X.XX%"

---

## STEP 8 — App Icon & Final Config

In `pubspec.yaml` add:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  adaptive_icon_background: "#222026"
  adaptive_icon_foreground: "assets/icon.png"
```

(The user will supply the icon asset separately.)

---

## STEP 9 — Verification Checklist

After all files are created, verify:

- [ ] `flutter analyze` passes with no errors
- [ ] App launches to HomeScreen with dark theme
- [ ] Pair list loads from Binance on startup
- [ ] Selecting a pair and tapping "Analyze" shows loading → stats + positions
- [ ] "Scan Market Leaders" shows loading → leaderboard with 3 picks
- [ ] "Trade on Binance" button opens correct URL
- [ ] Investment amount changes recalculate position sizes
- [ ] Pair search filtering works
- [ ] Error states display correctly (try with airplane mode)
- [ ] Responsive: looks good on narrow (375px) and wide (428px) phones

---

## FILE CREATION ORDER (for the AI)

Create files in this exact order to avoid forward-reference issues:

1. `lib/theme/app_theme.dart`
2. `lib/models/binance_models.dart`
3. `lib/models/analysis_models.dart`
4. `lib/services/binance_service.dart`
5. `lib/services/analysis_service.dart`
6. `lib/utils/formatters.dart`
7. `lib/providers/market_providers.dart`
8. `lib/widgets/app_header.dart`
9. `lib/widgets/pair_stats.dart`
10. `lib/widgets/position_card.dart`
11. `lib/widgets/controls_card.dart`
12. `lib/widgets/analysis_section.dart`
13. `lib/widgets/leaderboard_section.dart`
14. `lib/widgets/empty_state.dart`
15. `lib/widgets/footer.dart`
16. `lib/screens/home_screen.dart`
17. `lib/main.dart`

---

## IMPORTANT NOTES

- The original app uses Next.js server actions — in Flutter, all API calls happen client-side directly. There is no server component.
- The GenAI/Genkit integration is **dormant** in the current app (replaced by local MCMC). Do NOT port the Genkit flows. Only port the local statistical engine.
- The shadcn/ui component library (35 files, 3700+ lines) does NOT need to be ported — use Flutter's built-in Material widgets styled via the theme.
- Number formatting: the original uses `toLocaleString()` and `toFixed()`. Use Dart's `NumberFormat` from the `intl` package.
- The original PWA detection (`display-mode: standalone` media query) can be dropped for native Flutter. If targeting Flutter Web later, it can be added back.
