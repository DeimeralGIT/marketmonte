
'use server';

import { generateCryptoPositions, GenerateCryptoPositionsOutput } from '@/ai/flows/generate-crypto-positions';
import { fetchHistoricalKlines } from '@/lib/binance';

export async function analyzePairAction(symbol: string): Promise<GenerateCryptoPositionsOutput> {
  if (!symbol) throw new Error('Symbol is required');

  const historicalData = await fetchHistoricalKlines(symbol, 50);
  
  if (!historicalData.length) {
    throw new Error('No historical data available for this pair');
  }

  // Format historical data for the GenAI flow
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
