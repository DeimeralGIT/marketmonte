
'use client';

import { useState, useEffect } from 'react';
import { fetchUSDTTradingPairs, BinancePair, fetch24hTicker } from '@/lib/binance';
import { analyzePairAction, scanTopMarketAction } from '@/app/actions/analysis';
import { GenerateCryptoPositionsOutput } from '@/ai/flows/generate-crypto-positions';
import { MarketLeaderboardOutput } from '@/ai/flows/generate-market-leaderboard';
import { Search, Loader2, Info, BrainCircuit, LayoutGrid, Sparkles, Zap, TrendingUp, DollarSign } from 'lucide-react';
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
  const [investmentAmount, setInvestmentAmount] = useState<number>(100);
  const [loading, setLoading] = useState(false);
  const [analysis, setAnalysis] = useState<GenerateCryptoPositionsOutput | null>(null);
  const [leaderboard, setLeaderboard] = useState<MarketLeaderboardOutput | null>(null);
  const [ticker, setTicker] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'single' | 'market'>('single');

  useEffect(() => {
    async function init() {
      const p = await fetchUSDTTradingPairs();
      setPairs(p);
      const t = await fetch24hTicker('BTCUSDT');
      setTicker(t);
    }
    init();
  }, []);

  const handleAnalyze = async () => {
    setLoading(true);
    setError(null);
    setLeaderboard(null);
    setActiveTab('single');
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

  const handleScanMarket = async () => {
    setLoading(true);
    setError(null);
    setAnalysis(null);
    setTicker(null);
    setActiveTab('market');
    try {
      const result = await scanTopMarketAction();
      setLeaderboard(result);
    } catch (err: any) {
      console.error(err);
      setError(err.message || 'Failed to scan market leaders');
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
          <div className="bg-card p-6 rounded-xl border border-border accent-glow relative overflow-hidden">
            <div className="absolute top-0 right-0 p-2 opacity-5 pointer-events-none">
              <Sparkles className="w-16 h-16 text-accent" />
            </div>
            
            <div className="flex flex-col space-y-6">
              <div className="flex flex-col md:flex-row gap-4 items-end">
                <div className="flex-1 space-y-2">
                  <label className="text-xs font-bold text-muted-foreground uppercase ml-1">Symbol Search</label>
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
                    <Input 
                      placeholder="Filter pairs (e.g. SOL, ETH...)" 
                      className="pl-10 bg-background/50 border-border"
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                    />
                  </div>
                </div>

                <div className="w-full md:w-48 space-y-2">
                  <label className="text-xs font-bold text-muted-foreground uppercase ml-1">Investment (USDT)</label>
                  <div className="relative">
                    <DollarSign className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-accent" />
                    <Input 
                      type="number"
                      placeholder="100" 
                      className="pl-10 bg-background/50 border-border font-code"
                      value={investmentAmount}
                      onChange={(e) => setInvestmentAmount(Number(e.target.value))}
                    />
                  </div>
                </div>

                <div className="w-full md:w-56 space-y-2">
                  <label className="text-xs font-bold text-muted-foreground uppercase ml-1">Select Pair</label>
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
                  className="bg-primary hover:bg-primary/90 text-primary-foreground font-semibold px-8 h-10"
                >
                  {loading && activeTab === 'single' ? (
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  ) : (
                    <BrainCircuit className="w-4 h-4 mr-2" />
                  )}
                  Analyze
                </Button>
              </div>

              <div className="pt-4 border-t border-border/50 flex flex-col md:flex-row items-center justify-between gap-4">
                <div className="text-xs text-muted-foreground">
                  <span className="font-bold text-accent">Pro Tip:</span> Your investment amount is used to calculate suggested position sizes.
                </div>
                <Button 
                  onClick={handleScanMarket} 
                  disabled={loading}
                  variant="outline"
                  className="w-full md:w-auto border-accent/30 hover:bg-accent/10 text-accent font-bold"
                >
                  {loading && activeTab === 'market' ? (
                    <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  ) : (
                    <Zap className="w-4 h-4 mr-2" />
                  )}
                  Scan Market Leaders
                </Button>
              </div>
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
          {ticker && activeTab === 'single' && <PairStats ticker={ticker} symbol={selectedPair} />}

          {/* Single Pair Analysis Result */}
          {analysis && activeTab === 'single' && (
            <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
              <div className="bg-primary/10 border border-primary/20 rounded-xl p-6 relative overflow-hidden">
                <div className="absolute top-0 right-0 p-4 opacity-10">
                  <BrainCircuit className="w-24 h-24" />
                </div>
                <h2 className="text-xl font-headline font-bold mb-3 flex items-center gap-2">
                  <Info className="w-5 h-5 text-accent" />
                  Outlook: {selectedPair}
                </h2>
                <p className="text-muted-foreground leading-relaxed">
                  {analysis.analysisSummary}
                </p>
              </div>

              <div className="space-y-6">
                <h3 className="text-lg font-headline font-semibold flex items-center gap-2">
                  <LayoutGrid className="w-5 h-5 text-accent" />
                  Recommended Positions
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {analysis.positions.map((pos, idx) => (
                    <PositionCard 
                      key={idx}
                      rank={idx + 1}
                      symbol={selectedPair}
                      investmentAmount={investmentAmount}
                      {...pos}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Market Leaderboard Results */}
          {leaderboard && activeTab === 'market' && (
            <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
              <div className="bg-accent/5 border border-accent/20 rounded-xl p-6">
                <h2 className="text-xl font-headline font-bold mb-3 flex items-center gap-2 text-accent">
                  <TrendingUp className="w-5 h-5" />
                  Global Market Leaders Scan
                </h2>
                <p className="text-muted-foreground leading-relaxed">
                  {leaderboard.globalOutlook}
                </p>
              </div>

              <div className="space-y-6">
                <h3 className="text-lg font-headline font-semibold flex items-center gap-2">
                  <Zap className="w-5 h-5 text-yellow-400" />
                  Top Alpha Opportunities
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {leaderboard.topPicks.map((pick, idx) => (
                    <PositionCard 
                      key={idx}
                      rank={idx + 1}
                      symbol={pick.symbol}
                      investmentAmount={investmentAmount}
                      entryPrice={pick.entryPrice}
                      exitPrice={pick.exitPrice}
                      predictedROI={pick.predictedROI}
                      confidenceScore={pick.confidenceScore}
                      strategyDescription={pick.reasoning}
                    />
                  ))}
                </div>
              </div>
            </div>
          )}

          {!loading && !analysis && !leaderboard && (
            <div className="flex flex-col items-center justify-center py-20 text-center space-y-4">
              <div className="p-4 rounded-full bg-secondary/50">
                <BrainCircuit className="w-12 h-12 text-muted-foreground opacity-20" />
              </div>
              <div className="space-y-1">
                <h3 className="text-xl font-headline font-semibold text-muted-foreground">Ready for analysis</h3>
                <p className="text-muted-foreground max-w-sm text-sm">
                  Select a pair for deep analysis or scan the top 10 market leaders to find high-ROI breakouts.
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
