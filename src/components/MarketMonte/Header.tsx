
import { TrendingUp, Activity } from 'lucide-react';

export default function Header() {
  return (
    <header className="border-b border-border/50 bg-background/50 backdrop-blur-md sticky top-0 z-50">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="bg-primary p-2 rounded-lg">
            <TrendingUp className="w-5 h-5 text-primary-foreground" />
          </div>
          <div>
            <h1 className="text-xl font-headline font-bold tracking-tight text-white">
              Market <span className="text-accent">Monte</span>
            </h1>
            <p className="text-[10px] text-muted-foreground uppercase tracking-widest font-semibold">
              MCMC Prediction Engine
            </p>
          </div>
        </div>
        
        <div className="hidden md:flex items-center gap-6">
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Activity className="w-4 h-4 text-accent" />
            <span>Binance Live Feed</span>
          </div>
          <div className="h-4 w-px bg-border"></div>
          <div className="text-xs font-medium px-2 py-1 rounded bg-secondary text-secondary-foreground border border-border">
            USDT PAIRS ONLY
          </div>
        </div>
      </div>
    </header>
  );
}
