
'use server';

import { generateCryptoPositions, GenerateCryptoPositionsOutput } from '@/ai/flows/generate-crypto-positions';
import { generateMarketLeaderboard, MarketLeaderboardOutput } from '@/ai/flows/generate-market-leaderboard';
import { fetchHistoricalKlines, fetchTopUSDTByVolume } from '@/lib/binance';

export async function analyzePairAction(symbol: string): Promise<GenerateCryptoPositionsOutput> {
  if (!symbol) throw new Error('Symbol is required');

  const historicalData = await fetchHistoricalKlines(symbol, 50);
  
  if (!historicalData.length) {
    throw new Error('No historical data available for this pair');
  }

  const formattedData = JSON.stringify({
    symbol,
    recentPrices: historicalData.map(k => ({
      t: k.time,
      o: k.open,
      h: k.high,
      l: k.low,
      c: k.close,
      v: k.volume
    }))
  });

  const result = await generateCryptoPositions({
    cryptoPair: symbol,
    historicalData: formattedData
  });

  return result;
}

export async function scanTopMarketAction(): Promise<MarketLeaderboardOutput> {
  const topSymbols = await fetchTopUSDTByVolume(10);
  
  const marketDataPromises = topSymbols.map(async (symbol) => {
    const klines = await fetchHistoricalKlines(symbol, 24); // 24h summary for quick scan
    return {
      symbol,
      historicalSummary: JSON.stringify(klines.map(k => ({ c: k.close, v: k.volume })))
    };
  });

  const marketData = await Promise.all(marketDataPromises);

  const result = await generateMarketLeaderboard({ marketData });
  return result;
}
