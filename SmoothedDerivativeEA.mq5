//+------------------------------------------------------------------+
//|                                     SmoothedDerivativeEA.mq5    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "3.00"

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "--- Risk & Execution ---"
input double   InpLotSize            = 0.01;     // Fixed Lot Size
input int      InpEmaPeriod          = 5;        // Price Smoothing EMA Period
input int      InpAtrPeriod          = 14;       // ATR Period for Volatility Scaling
input double   InpAtrSlMultiplier    = 1.5;      // Stop Loss Multiplier (in ATR)
input double   InpRiskRewardRatio    = 1.0;      // Risk to Reward Ratio (1.0 = 1:1)

input group "--- Position Management ---"
input bool     InpUseBreakEven       = true;     // Enable Break-Even
input double   InpBreakEvenAtr       = 1.0;      // Break-Even Trigger Distance (in ATR)
input double   InpBreakEvenLockAtr   = 0.1;      // Break-Even Profit Lock Distance (in ATR)
input bool     InpUseTrailingStop    = true;     // Enable Trailing Stop
input double   InpTrailingStopAtr    = 1.5;      // Trailing Stop Distance (in ATR)
input double   InpTrailingStepAtr    = 0.2;      // Trailing Step (in ATR)

input group "--- Derivative Weights & Threshold ---"
input double   InpThreshold          = 0.5;      // Normalized Signal Threshold
input double   InpWeight1            = 1.0;      // Weight: 1st Derivative (Velocity)
input double   InpWeight2            = 0.75;     // Weight: 2nd Derivative (Acceleration)
input double   InpWeight3            = 0.50;     // Weight: 3rd Derivative (Jerk)
input double   InpWeight4            = 0.25;     // Weight: 4th Derivative (Snap)
input double   InpWeight5            = 0.10;     // Weight: 5th Derivative (Crackle)
input double   InpWeight6            = 0.05;     // Weight: 6th Derivative (Pop)

input ulong    InpMagicNumber        = 987654;   // Magic Number

//--- Global Handles & Variables
CTrade         trade;
int            handleEma;
int            handleAtr;
datetime       lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   lastBarTime = 0;

   // Initialize Indicator Handles
   handleEma = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA, PRICE_WEIGHTED); // (O+H+L+C)/4
   handleAtr = iATR(_Symbol, _Period, InpAtrPeriod);

   if(handleEma == INVALID_HANDLE || handleAtr == INVALID_HANDLE)
   {
      Print("Error creating indicator handles.");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleEma);
   IndicatorRelease(handleAtr);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Always manage existing open positions on every tick (BE & Trailing Stop)
   ManagePositions();

   // 2. New Bar Check for Trade Entry Signals
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   // Check if a position is already open for this EA
   if(HasOpenPosition())
      return;

   // Fetch Smoothed Price (EMA) for last 7 closed bars
   double ma[];
   ArraySetAsSeries(ma, true);
   if(CopyBuffer(handleEma, 0, 1, 7, ma) < 7)
      return;

   // Fetch Current ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handleAtr, 0, 1, 1, atr) < 1 || atr[0] <= 0)
      return;

   double currentAtr = atr[0];

   // Calculate 1st through 6th finite backward derivatives on the smoothed series
   double d1 = ma[0] - ma[1];
   double d2 = ma[0] - (2.0 * ma[1]) + ma[2];
   double d3 = ma[0] - (3.0 * ma[1]) + (3.0 * ma[2]) - ma[3];
   double d4 = ma[0] - (4.0 * ma[1]) + (6.0 * ma[2]) - (4.0 * ma[3]) + ma[4];
   double d5 = ma[0] - (5.0 * ma[1]) + (10.0 * ma[2]) - (10.0 * ma[3]) + (5.0 * ma[4]) - ma[5];
   double d6 = ma[0] - (6.0 * ma[1]) + (15.0 * ma[2]) - (20.0 * ma[3]) + (15.0 * ma[4]) - (6.0 * ma[5]) + ma[6];

   // Normalize derivatives by ATR to stabilize scale
   double rawScore = (d1 * InpWeight1) + 
                     (d2 * InpWeight2) + 
                     (d3 * InpWeight3) + 
                     (d4 * InpWeight4) + 
                     (d5 * InpWeight5) + 
                     (d6 * InpWeight6);

   double normalizedScore = rawScore / currentAtr;

   // Market execution values
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDistance = currentAtr * InpAtrSlMultiplier;
   double tpDistance = slDistance * InpRiskRewardRatio;

   // Entry Execution
   if(normalizedScore > InpThreshold)
   {
      double sl = NormalizeDouble(ask - slDistance, digits);
      double tp = NormalizeDouble(ask + tpDistance, digits);

      trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Smoothed Derivative Buy");
   }
   else if(normalizedScore < -InpThreshold)
   {
      double sl = NormalizeDouble(bid + slDistance, digits);
      double tp = NormalizeDouble(bid - tpDistance, digits);

      trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Smoothed Derivative Sell");
   }
}

//+------------------------------------------------------------------+
//| Manage Active Positions: Break-Even and Trailing Stop            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!InpUseBreakEven && !InpUseTrailingStop)
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handleAtr, 0, 0, 1, atr) < 1 || atr[0] <= 0)
      return;

   double currentAtr = atr[0];
   int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         long   posType     = PositionGetInteger(POSITION_TYPE);
         double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSl   = PositionGetDouble(POSITION_SL);
         double currentTp   = PositionGetDouble(POSITION_TP);

         // --- BUY POSITION MANAGEMENT ---
         if(posType == POSITION_TYPE_BUY)
         {
            // 1. Break-Even Logic
            if(InpUseBreakEven)
            {
               double triggerPrice = openPrice + (currentAtr * InpBreakEvenAtr);
               double newBeSl       = NormalizeDouble(openPrice + (currentAtr * InpBreakEvenLockAtr), digits);

               if(bid >= triggerPrice && (currentSl < openPrice || currentSl == 0))
               {
                  trade.PositionModify(ticket, newBeSl, currentTp);
                  continue;
               }
            }

            // 2. Trailing Stop Logic
            if(InpUseTrailingStop)
            {
               double trailDist = currentAtr * InpAtrSlMultiplier;
               double stepDist  = currentAtr * InpAtrSlMultiplier;
               double newSl     = NormalizeDouble(bid - trailDist, digits);

               if(bid - openPrice > trailDist)
               {
                  if(currentSl == 0 || (newSl - currentSl) >= stepDist)
                  {
                     trade.PositionModify(ticket, newSl, currentTp);
                  }
               }
            }
         }
         // --- SELL POSITION MANAGEMENT ---
         else if(posType == POSITION_TYPE_SELL)
         {
            // 1. Break-Even Logic
            if(InpUseBreakEven)
            {
               double triggerPrice = openPrice - (currentAtr * InpBreakEvenAtr);
               double newBeSl       = NormalizeDouble(openPrice - (currentAtr * InpBreakEvenLockAtr), digits);

               if(ask <= triggerPrice && (currentSl > openPrice || currentSl == 0))
               {
                  trade.PositionModify(ticket, newBeSl, currentTp);
                  continue;
               }
            }

            // 2. Trailing Stop Logic
            if(InpUseTrailingStop)
            {
               double trailDist = currentAtr * InpTrailingStopAtr;
               double stepDist  = currentAtr * InpTrailingStepAtr;
               double newSl     = NormalizeDouble(ask + trailDist, digits);

               if(openPrice - ask > trailDist)
               {
                  if(currentSl == 0 || (currentSl - newSl) >= stepDist)
                  {
                     trade.PositionModify(ticket, newSl, currentTp);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Helper: Check for open positions belonging to this EA            |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}