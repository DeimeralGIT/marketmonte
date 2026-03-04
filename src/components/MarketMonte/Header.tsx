
'use client';

import { TrendingUp, Activity, Wallet, UserCircle, Smartphone } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useState, useEffect } from 'react';

export default function Header() {
  const [isConnected, setIsConnected] = useState(false);
  const [isStandalone, setIsStandalone] = useState(false);

  useEffect(() => {
    // Detect if the app is running as a PWA (standalone)
    const checkStandalone = () => {
      if (typeof window !== 'undefined') {
        const isPWA = window.matchMedia('(display-mode: standalone)').matches 
          || (window.navigator as any).standalone 
          || document.referrer.includes('android-app://');
        setIsStandalone(isPWA);
      }
    };
    
    checkStandalone();
  }, []);

  return (
    <header className="border-b border-border/50 bg-background/50 backdrop-blur-md sticky top-0 z-50 pt-[env(safe-area-inset-top)]">
      <div className="container mx-auto px-4 h-16 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className="bg-primary p-2 rounded-lg">
            <TrendingUp className="w-5 h-5 text-primary-foreground" />
          </div>
          <div>
            <h1 className="text-xl font-headline font-bold tracking-tight text-white leading-tight">
              Market <span className="text-accent">Monte</span>
            </h1>
            <div className="flex items-center gap-1.5">
              <p className="text-[9px] text-muted-foreground uppercase tracking-widest font-semibold">
                MCMC Prediction Engine
              </p>
              {isStandalone && (
                <span className="flex items-center gap-0.5 px-1 rounded bg-accent/10 text-accent text-[8px] font-bold">
                  <Smartphone className="w-2 h-2" /> APP
                </span>
              )}
            </div>
          </div>
        </div>
        
        <div className="flex items-center gap-3 md:gap-8">
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
            className={isConnected 
              ? "border-accent/50 text-accent h-9" 
              : "bg-accent hover:bg-accent/90 text-accent-foreground font-bold h-9"
            }
            onClick={() => setIsConnected(!isConnected)}
          >
            {isConnected ? (
              <>
                <UserCircle className="w-4 h-4 md:mr-2" />
                <span className="hidden md:inline">API Connected</span>
              </>
            ) : (
              <>
                <Wallet className="w-4 h-4 md:mr-2" />
                <span className="hidden md:inline">Connect API</span>
                <span className="md:hidden">Login</span>
              </>
            )}
          </Button>
        </div>
      </div>
    </header>
  );
}
