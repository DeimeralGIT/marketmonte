
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Target, ArrowUpRight, ShieldCheck, ChevronRight } from 'lucide-react';
import { cn } from '@/lib/utils';

interface PositionProps {
  entryPrice: number;
  exitPrice: number;
  predictedROI: number;
  confidenceScore: number;
  strategyDescription: string;
  rank: number;
}

export default function PositionCard({ 
  entryPrice, 
  exitPrice, 
  predictedROI, 
  confidenceScore, 
  strategyDescription,
  rank
}: PositionProps) {
  const isPositive = predictedROI > 0;

  return (
    <Card className="crypto-card-gradient border-border/40 hover:border-accent/40 transition-all duration-300 group">
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
      
      <CardContent className="space-y-4">
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

        <div className="space-y-2">
          <p className="text-xs font-semibold text-muted-foreground flex items-center gap-1 uppercase tracking-tight">
            <Target className="w-3 h-3" /> Strategy Outlook
          </p>
          <p className="text-sm text-foreground/80 leading-relaxed italic">
            "{strategyDescription}"
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
