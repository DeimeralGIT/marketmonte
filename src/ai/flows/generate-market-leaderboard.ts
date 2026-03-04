
'use server';
/**
 * @fileOverview This file defines a Genkit flow for identifying the best ROI positions
 * across multiple top-volume cryptocurrency pairs.
 *
 * - generateMarketLeaderboard - A function that handles cross-pair analysis.
 * - MarketLeaderboardInput - The input type for the flow.
 * - MarketLeaderboardOutput - The return type for the flow.
 */

import {ai} from '@/ai/genkit';
import {z} from 'genkit';

const MarketLeaderboardInputSchema = z.object({
  marketData: z.array(z.object({
    symbol: z.string(),
    historicalSummary: z.string()
  })).describe('A list of top pairs and their recent price/volume data summaries.')
});
export type MarketLeaderboardInput = z.infer<typeof MarketLeaderboardInputSchema>;

const LeadPositionSchema = z.object({
  symbol: z.string().describe('The USDT pair symbol.'),
  entryPrice: z.number().describe('The recommended entry price.'),
  exitPrice: z.number().describe('The recommended exit price.'),
  predictedROI: z.number().describe('The predicted ROI percentage.'),
  confidenceScore: z.number().min(0).max(100).describe('Confidence level.'),
  reasoning: z.string().describe('Why this specific pair stands out among the top 10.')
});

const MarketLeaderboardOutputSchema = z.object({
  topPicks: z.array(LeadPositionSchema).describe('The top 3 high-conviction trades across the scanned market.'),
  globalOutlook: z.string().describe('A high-level overview of the current top-market trend.')
});
export type MarketLeaderboardOutput = z.infer<typeof MarketLeaderboardOutputSchema>;

export async function generateMarketLeaderboard(
  input: MarketLeaderboardInput
): Promise<MarketLeaderboardOutput> {
  return marketLeaderboardFlow(input);
}

const leaderboardPrompt = ai.definePrompt({
  name: 'marketLeaderboardPrompt',
  input: {schema: MarketLeaderboardInputSchema},
  output: {schema: MarketLeaderboardOutputSchema},
  prompt: `You are an elite quantitative trader. You have been given historical data for the top 10 cryptocurrency pairs by volume on Binance.

Your task is to perform a comparative analysis using probabilistic models (MCMC-like reasoning) to identify the absolute BEST 3 trading opportunities among these 10 pairs right now.

Input Data:
{{#each marketData}}
- Symbol: {{{symbol}}}
  Data: {{{historicalSummary}}}
{{/each}}

Analyze the volatility, trend strength, and volume profile of each. Pick the 3 symbols that offer the best risk-adjusted ROI. For each pick, provide an entry price, an exit target, a predicted ROI, and a confidence score. Explain exactly why these specific pairs were chosen over the others in the 'reasoning' field.

Provide a brief 'globalOutlook' on the state of these high-volume leaders (e.g., are we seeing a sector-wide breakout or a rotation?).`,
});

const marketLeaderboardFlow = ai.defineFlow(
  {
    name: 'marketLeaderboardFlow',
    inputSchema: MarketLeaderboardInputSchema,
    outputSchema: MarketLeaderboardOutputSchema,
  },
  async input => {
    const {output} = await leaderboardPrompt(input);
    if (!output) throw new Error('Market analysis failed');
    return output;
  }
);
