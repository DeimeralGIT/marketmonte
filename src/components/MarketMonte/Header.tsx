
import { TrendingUp, Activity, Wallet, UserCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useState } from 'react';

export default function Header() {
  const [isConnected, setIsConnected] = useState(false);

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
        
        <div className="flex items-center gap-4 md:gap-8">
          <div className="hidden md:flex items-center gap-6">
            <div className="flex items-center gap-2 text-sm text-muted-foreground">
              <Activity className="w-4 h-4 text-accent" />
              <span>Binance Live Feed</span>
            </div>
            <div className="h-4 w-px bg-border"></div>
          </div>

          <Button 
            variant={isConnected ? "outline" : "default"}
            size="sm"
            className={isConnected ? "border-accent/50 text-accent" : "bg-accent hover:bg-accent/90 text-accent-foreground"}
            onClick={() => setIsConnected(!isConnected)}
          >
            {isConnected ? (
              <>
                <UserCircle className="w-4 h-4 mr-2" />
                API Connected
              </>
            ) : (
              <>
                <Wallet className="w-4 h-4 mr-2" />
                Connect API
              </>
            )}
          </Button>
        </div>
      </div>
    </header>
  );
}
