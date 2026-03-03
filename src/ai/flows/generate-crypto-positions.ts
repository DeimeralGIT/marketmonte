'use server';
/**
 * @fileOverview This file defines a Genkit flow for generating crypto trading positions
 * based on historical data and simulated MCMC analysis.
 *
 * - generateCryptoPositions - A function that handles the generation of crypto trading positions.
 * - GenerateCryptoPositionsInput - The input type for the generateCryptoPositions function.
 * - GenerateCryptoPositionsOutput - The return type for the generateCryptoPositions function.
 */

import {ai} from '@/ai/genkit';
import {z} from 'genkit';

// Input Schema
const GenerateCryptoPositionsInputSchema = z.object({
  cryptoPair: z.string().describe('The USDT crypto trading pair (e.g., "BTCUSDT").'),
  historicalData: z.string().describe(
    'A summary or raw data of historical price, volume, and order book information for the crypto pair. ' +
      'This data is used to inform the MCMC prediction engine. Example: "{"prices": [{}], "volumes": [{}], ...}"'
  ),
});
export type GenerateCryptoPositionsInput = z.infer<typeof GenerateCryptoPositionsInputSchema>;

// Trading Position Schema
const TradingPositionSchema = z.object({
  entryPrice: z.number().describe('The recommended entry price for the position.'),
  exitPrice: z.number().describe('The recommended exit price for taking profit or stopping loss.'),
  predictedROI: z.number().describe('The predicted Return on Investment for this position as a percentage.'),
  confidenceScore: z.number().min(0).max(100).describe('A confidence score (0-100) for the prediction.'),
  strategyDescription: z.string().describe('A brief explanation of the proposed trading strategy for this position.'),
});

// Output Schema
const GenerateCryptoPositionsOutputSchema = z.object({
  positions: z.array(TradingPositionSchema).describe('A list of potential trading positions, ranked by predicted ROI.'),
  analysisSummary: z.string().describe('A summary of the MCMC-like analysis and market outlook for the crypto pair.'),
});
export type GenerateCryptoPositionsOutput = z.infer<typeof GenerateCryptoPositionsOutputSchema>;

// Exported wrapper function
export async function generateCryptoPositions(
  input: GenerateCryptoPositionsInput
): Promise<GenerateCryptoPositionsOutput> {
  return generateCryptoPositionsFlow(input);
}

// Prompt Definition
const generateCryptoPositionsPrompt = ai.definePrompt({
  name: 'generateCryptoPositionsPrompt',
  input: {schema: GenerateCryptoPositionsInputSchema},
  output: {schema: GenerateCryptoPositionsOutputSchema},
  prompt: `You are an expert financial analyst specializing in cryptocurrency trading, specifically using advanced probabilistic models like Markov Chain Monte Carlo (MCMC) for predicting market movements.

Given the following cryptocurrency trading pair and its historical data, simulate an MCMC-like analysis to identify potential future market states and generate concrete trading positions. Your analysis should consider price action, volume, and order book dynamics (as inferred from the historical data provided).

Your goal is to propose several trading positions, each with an entry price, an exit price, a probabilistic predicted Return on Investment (ROI), and a confidence score. Rank these positions by their predicted ROI from highest to lowest. Provide a brief strategy description for each position. Conclude with a general summary of your market outlook based on the simulated analysis.

Crypto Pair: {{{cryptoPair}}}

Historical Data (summary/raw):
{{{historicalData}}}

Please provide the output in JSON format, adhering strictly to the defined output schema, including the 'positions' array (ranked by predictedROI) and an 'analysisSummary'. Ensure ROI is a percentage and confidence is 0-100. If no viable positions are found, return an empty array for positions and explain why in the analysisSummary.`,
});

// Flow Definition
const generateCryptoPositionsFlow = ai.defineFlow(
  {
    name: 'generateCryptoPositionsFlow',
    inputSchema: GenerateCryptoPositionsInputSchema,
    outputSchema: GenerateCryptoPositionsOutputSchema,
  },
  async input => {
    // Call the prompt with the input
    const {output} = await generateCryptoPositionsPrompt(input);

    // The output from the prompt is already expected to conform to GenerateCryptoPositionsOutputSchema
    // because we defined output.schema for the prompt.
    // If the LLM output is null for some reason, throw an error or handle it gracefully.
    if (!output) {
      throw new Error('Failed to generate crypto positions. LLM returned no output.');
    }

    return output;
  }
);
