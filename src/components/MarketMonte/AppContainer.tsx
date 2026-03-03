
'use client';

import { useState, useEffect } from 'react';
import { fetchUSDTTradingPairs, BinancePair, fetch24hTicker } from '@/lib/binance';
import { analyzePairAction } from '@/app/actions/analysis';
import { GenerateCryptoPositionsOutput } from '@/ai/flows/generate-crypto-positions';
import { Search, Loader2, Info, BrainCircuit, LayoutGrid } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from '@/components/ui/select';
import Header from './Header';
import PositionCard from './PositionCard';
import PairStats from './PairStats';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';

export default function AppContainer() {
  const [pairs, setPairs] = useState<BinancePair[]>([]);
  const [selectedPair, setSelectedPair] = useState<string>('BTCUSDT');
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [analysis, setAnalysis] = useState<GenerateCryptoPositionsOutput | null>(null);
  const [ticker, setTicker] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function init() {
      const p = await fetchUSDTTradingPairs();
      setPairs(p);
      // Auto-fetch BTC stats on load
      const t = await fetch24hTicker('BTCUSDT');
      setTicker(t);
    }
    init();
  }, []);

  const handleAnalyze = async () => {
    setLoading(true);
    setError(null);
    try {
      const [analysisResult, tickerData] = await Promise.all([
        analyzePairAction(selectedPair),
        fetch24hTicker(selectedPair)
      ]);
      setAnalysis(analysisResult);
      setTicker(tickerData);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'An error occurred during analysis');
    } finally {
      setLoading(false);
    }
  };

  const filteredPairs = pairs
    .filter(p => p.symbol.toLowerCase().includes(searchQuery.toLowerCase()))
    .slice(0, 100);

  return (
    <div className="flex flex-col min-h-screen bg-[#222026]">
      <Header />
      
      <main className="flex-1 container mx-auto px-4 py-8">
        <section className="max-w-4xl mx-auto space-y-8">
          
          {/* Controls */}
          <div className="bg-card p-6 rounded-xl border border-border accent-glow">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                <Input 
                  placeholder="Filter pairs (e.g. SOL, ETH...)" 
                  className="pl-10 bg-background/50 border-border"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>
              <div className="w-full md:w-64">
                <Select value={selectedPair} onValueChange={setSelectedPair}>
                  <SelectTrigger className="bg-background/50 border-border font-code">
                    <SelectValue placeholder="Select a pair" />
                  </SelectTrigger>
                  <SelectContent className="max-h-[300px]">
                    {filteredPairs.map(p => (
                      <SelectItem key={p.symbol} value={p.symbol} className="font-code">
                        {p.symbol}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <Button 
                onClick={handleAnalyze} 
                disabled={loading}
                className="bg-primary hover:bg-primary/90 text-primary-foreground font-semibold px-8"
              >
                {loading ? (
                  <>
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                    Calculating...
                  </>
                ) : (
                  <>
                    <BrainCircuit className="w-4 h-4 mr-2" />
                    Generate Positions
                  </>
                )}
              </Button>
            </div>
          </div>

          {error && (
            <Alert variant="destructive">
              <Info className="h-4 w-4" />
              <AlertTitle>Analysis Error</AlertTitle>
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}

          {/* Results Area */}
          {ticker && <PairStats ticker={ticker} symbol={selectedPair} />}

          {analysis ? (
            <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
              
              {/* Analysis Summary */}
              <div className="bg-primary/10 border border-primary/20 rounded-xl p-6 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-10">
                  <BrainCircuit className="w-24 h-24" />
                </div>
                <h2 className="text-xl font-headline font-bold mb-3 flex items-center gap-2">
                  <Info className="w-5 h-5 text-accent" />
                  Market Monte Outlook: {selectedPair}
                </h2>
                <p className="text-muted-foreground leading-relaxed">
                  {analysis.analysisSummary}
                </p>
              </div>

              {/* Positions List */}
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  <h3 className="text-lg font-headline font-semibold flex items-center gap-2">
                    <LayoutGrid className="w-5 h-5 text-accent" />
                    Recommended Positions
                  </h3>
                  <p className="text-xs text-muted-foreground italic">
                    Ranked by Probabilistic ROI
                  </p>
                </div>

                {analysis.positions.length > 0 ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {analysis.positions.map((pos, idx) => (
                      <PositionCard 
                        key={idx}
                        rank={idx + 1}
                        {...pos}
                      />
                    ))}
                  </div>
                ) : (
                  <div className="text-center py-12 bg-secondary/20 rounded-xl border border-dashed border-border">
                    <p className="text-muted-foreground">No high-probability positions found for this window.</p>
                  </div>
                )}
              </div>
            </div>
          ) : !loading && (
            <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
              <div className="p-4 rounded-full bg-secondary/50">
                <BrainCircuit className="w-12 h-12 text-muted-foreground opacity-20" />
              </div>
              <div className="space-y-1">
                <h3 className="text-xl font-headline font-semibold text-muted-foreground">Ready for analysis</h3>
                <p className="text-muted-foreground max-w-sm text-sm">
                  Select a USDT trading pair above and click "Generate Positions" to run the MCMC prediction engine.
                </p>
              </div>
            </div>
          )}
        </section>
      </main>

      <footer className="py-8 border-t border-border/30">
        <div className="container mx-auto px-4 text-center">
          <p className="text-[10px] text-muted-foreground font-semibold uppercase tracking-[0.2em]">
            MARKET MONTE IS AN ANALYTICAL TOOL. TRADING CRYPTOCURRENCIES INVOLVES RISK.
          </p>
        </div>
      </footer>
    </div>
  );
}
