
import { Card, CardContent } from '@/components/ui/card';
import { BarChart3, LineChart, RefreshCw } from 'lucide-react';

interface StatsProps {
  ticker: any;
  symbol: string;
}

export default function PairStats({ ticker, symbol }: StatsProps) {
  if (!ticker) return null;

  const priceChangePercent = parseFloat(ticker.priceChangePercent);
  const isUp = priceChangePercent >= 0;

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
      <Card className="bg-secondary/30 border-border/50">
        <CardContent className="pt-6">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-muted-foreground font-bold uppercase">Price</p>
            <LineChart className="w-4 h-4 text-accent" />
          </div>
          <p className="text-2xl font-code font-bold">${parseFloat(ticker.lastPrice).toLocaleString()}</p>
          <p className={cn(
            "text-xs mt-1 font-medium",
            isUp ? "text-green-400" : "text-red-400"
          )}>
            {isUp ? '▲' : '▼'} {priceChangePercent.toFixed(2)}% (24h)
          </p>
        </CardContent>
      </Card>

      <Card className="bg-secondary/30 border-border/50">
        <CardContent className="pt-6">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-muted-foreground font-bold uppercase">24h High</p>
            <BarChart3 className="w-4 h-4 text-muted-foreground" />
          </div>
          <p className="text-2xl font-code font-bold">${parseFloat(ticker.highPrice).toLocaleString()}</p>
        </CardContent>
      </Card>

      <Card className="bg-secondary/30 border-border/50">
        <CardContent className="pt-6">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-muted-foreground font-bold uppercase">24h Low</p>
            <BarChart3 className="w-4 h-4 text-muted-foreground" />
          </div>
          <p className="text-2xl font-code font-bold">${parseFloat(ticker.lowPrice).toLocaleString()}</p>
        </CardContent>
      </Card>

      <Card className="bg-secondary/30 border-border/50">
        <CardContent className="pt-6">
          <div className="flex items-center justify-between mb-2">
            <p className="text-xs text-muted-foreground font-bold uppercase">Volume</p>
            <RefreshCw className="w-4 h-4 text-muted-foreground" />
          </div>
          <p className="text-2xl font-code font-bold truncate">
            {parseFloat(ticker.volume).toLocaleString()} {symbol.replace('USDT', '')}
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

import { cn } from '@/lib/utils';
