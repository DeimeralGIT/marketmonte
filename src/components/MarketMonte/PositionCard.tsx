
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Target, ArrowUpRight, ShieldCheck, ExternalLink, Calculator } from 'lucide-react';
import { cn } from '@/lib/utils';
import { getBinanceTradeUrl } from '@/lib/binance';

interface PositionProps {
  entryPrice: number;
  exitPrice: number;
  predictedROI: number;
  confidenceScore: number;
  strategyDescription: string;
  rank: number;
  symbol: string;
  investmentAmount: number;
}

export default function PositionCard({ 
  entryPrice, 
  exitPrice, 
  predictedROI, 
  confidenceScore, 
  strategyDescription,
  rank,
  symbol,
  investmentAmount
}: PositionProps) {
  const isPositive = predictedROI > 0;
  const binanceUrl = getBinanceTradeUrl(symbol, investmentAmount);
  
  // Calculate quantity to buy
  const quantity = investmentAmount > 0 ? (investmentAmount / entryPrice) : 0;
  const baseAsset = symbol.replace('USDT', '');

  return (
    <Card className="crypto-card-gradient border-border/40 hover:border-accent/40 transition-all duration-300 group flex flex-col">
      <CardHeader className="pb-3 flex flex-row items-start justify-between">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="text-accent border-accent/30 bg-accent/5">
              RANK #{rank}
            </Badge>
            <div className="flex items-center gap-1 text-xs font-medium text-muted-foreground">
              <ShieldCheck className="w-3 h-3 text-accent" />
              {confidenceScore}% Confidence
            </div>
          </div>
          <CardTitle className="text-lg font-headline flex items-center gap-2 mt-2">
            ROI Target: 
            <span className={cn(
              "text-2xl",
              isPositive ? "text-green-400" : "text-red-400"
            )}>
              {isPositive ? '+' : ''}{predictedROI.toFixed(2)}%
            </span>
          </CardTitle>
        </div>
        <div className="p-3 rounded-full bg-secondary group-hover:bg-accent/10 transition-colors">
          <ArrowUpRight className="w-6 h-6 text-accent" />
        </div>
      </CardHeader>
      
      <CardContent className="space-y-4 flex-1">
        <div className="grid grid-cols-2 gap-4">
          <div className="p-3 rounded-lg bg-background/40 border border-border/50">
            <p className="text-[10px] text-muted-foreground uppercase font-bold mb-1">Entry Price</p>
            <p className="text-xl font-code font-medium">${entryPrice.toLocaleString()}</p>
          </div>
          <div className="p-3 rounded-lg bg-background/40 border border-border/50">
            <p className="text-[10px] text-muted-foreground uppercase font-bold mb-1">Exit Target</p>
            <p className="text-xl font-code font-medium text-accent">${exitPrice.toLocaleString()}</p>
          </div>
        </div>

        {investmentAmount > 0 && (
          <div className="p-3 rounded-lg bg-accent/5 border border-accent/20 flex items-center justify-between">
            <div className="flex items-center gap-2 text-xs font-bold text-accent uppercase">
              <Calculator className="w-3 h-3" />
              Size
            </div>
            <div className="text-right">
              <p className="text-sm font-code font-bold">
                {quantity.toLocaleString(undefined, { maximumFractionDigits: 6 })} {baseAsset}
              </p>
              <p className="text-[10px] text-muted-foreground">For ${investmentAmount} USDT</p>
            </div>
          </div>
        )}

        <div className="space-y-2">
          <p className="text-xs font-semibold text-muted-foreground flex items-center gap-1 uppercase tracking-tight">
            <Target className="w-3 h-3" /> Strategy Outlook
          </p>
          <p className="text-sm text-foreground/80 leading-relaxed italic">
            "{strategyDescription}"
          </p>
        </div>

        <div className="pt-4 mt-auto">
          <Button 
            asChild
            className="w-full bg-secondary hover:bg-accent hover:text-accent-foreground border border-border/50 group/btn"
          >
            <a href={binanceUrl} target="_blank" rel="noopener noreferrer" className="flex items-center justify-center gap-2">
              <ExternalLink className="w-4 h-4" />
              Trade on Binance
            </a>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
