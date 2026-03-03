
export interface BinancePair {
  symbol: string;
  baseAsset: string;
  quoteAsset: string;
}

export interface KlineData {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

const BINANCE_BASE_URL = 'https://api.binance.com/api/v3';

export async function fetchUSDTTradingPairs(): Promise<BinancePair[]> {
  try {
    const response = await fetch(`${BINANCE_BASE_URL}/exchangeInfo`);
    if (!response.ok) throw new Error('Failed to fetch exchange info');
    const data = await response.json();
    
    return data.symbols
      .filter((s: any) => s.status === 'TRADING' && s.quoteAsset === 'USDT')
      .map((s: any) => ({
        symbol: s.symbol,
        baseAsset: s.baseAsset,
        quoteAsset: s.quoteAsset,
      }));
  } catch (error) {
    console.error('Error fetching Binance pairs:', error);
    return [];
  }
}

export async function fetchHistoricalKlines(symbol: string, limit = 100): Promise<KlineData[]> {
  try {
    const response = await fetch(`${BINANCE_BASE_URL}/klines?symbol=${symbol}&interval=1h&limit=${limit}`);
    if (!response.ok) throw new Error(`Failed to fetch klines for ${symbol}`);
    const data = await response.json();
    
    return data.map((k: any) => ({
      time: k[0],
      open: parseFloat(k[1]),
      high: parseFloat(k[2]),
      low: parseFloat(k[3]),
      close: parseFloat(k[4]),
      volume: parseFloat(k[5]),
    }));
  } catch (error) {
    console.error(`Error fetching klines for ${symbol}:`, error);
    return [];
  }
}

export async function fetch24hTicker(symbol: string) {
  try {
    const response = await fetch(`${BINANCE_BASE_URL}/ticker/24hr?symbol=${symbol}`);
    if (!response.ok) throw new Error(`Failed to fetch ticker for ${symbol}`);
    return await response.json();
  } catch (error) {
    console.error(`Error fetching ticker for ${symbol}:`, error);
    return null;
  }
}

/**
 * Generates a Binance deep-link URL for a specific trading pair.
 * Formats standard symbols like BTCUSDT to Binance-friendly BTC_USDT for the URL path.
 */
export function getBinanceTradeUrl(symbol: string): string {
  // Binance trade URLs usually prefer symbols in base_quote format for redirects
  // though many direct symbols work too.
  const formattedSymbol = symbol.endsWith('USDT') 
    ? `${symbol.replace('USDT', '')}_USDT` 
    : symbol;
  return `https://www.binance.com/en/trade/${formattedSymbol}?type=spot`;
}
