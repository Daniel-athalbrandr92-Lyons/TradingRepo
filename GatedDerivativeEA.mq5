//+------------------------------------------------------------------+
//|                                     GatedDerivativeEA.mq5        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "4.00"

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

input group "--- Derivative 1 (Velocity) ---"
input double   InpWeight1            = 1.0;      // Weight d1
input double   InpMinD1              = 0.10;     // Min d1 (in ATR)
input double   InpMaxD1              = 2.00;     // Max d1 (in ATR)

input group "--- Derivative 2 (Acceleration) ---"
input double   InpWeight2            = 0.75;     // Weight d2
input double   InpMinD2              = 0.05;     // Min d2 (in ATR)
input double   InpMaxD2              = 1.50;     // Max d2 (in ATR)

input group "--- Derivative 3 (Jerk) ---"
input double   InpWeight3            = 0.50;     // Weight d3
input double   InpMinD3              = 0.02;     // Min d3 (in ATR)
input double   InpMaxD3              = 1.00;     // Max d3 (in ATR)

input group "--- Derivative 4 (Snap) ---"
input double   InpWeight4            = 0.25;     // Weight d4
input double   InpMinD4              = 0.00;     // Min d4 (in ATR)
input double   InpMaxD4              = 0.75;     // Max d4 (in ATR)

input group "--- Derivative 5 (Crackle) ---"
input double   InpWeight5            = 0.10;     // Weight d5
input double   InpMinD5              = 0.00;     // Min d5 (in ATR)
input double   InpMaxD5              = 0.50;     // Max d5 (in ATR)

input group "--- Derivative 6 (Pop) ---"
input double   InpWeight6            = 0.05;     // Weight d6
input double   InpMinD6              = 0.00;     // Min d6 (in ATR)
input double   InpMaxD6              = 0.25;     // Max d6 (in ATR)

input group "--- System Settings ---"
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
   // 1. Manage active positions on every tick
   ManagePositions();

   // 2. New Bar Check for Trade Entry Signals
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   // Check if a position is already open for this EA
   if(HasOpenPosition())
      return;

   // Fetch Smoothed Price (EMA) for 7 closed bars (Bar 1 to Bar 7)
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

   // Compute raw derivative cascade
   double rawDerivatives[6];
   ComputeDerivatives(ma, rawDerivatives);

   // Normalize derivatives by ATR
   double normD[6];
   for(int i = 0; i < 6; i++)
   {
      normD[i] = rawDerivatives[i] / currentAtr;
   }

   // Load Threshold and Weight Arrays
   double minThresholds[6] = {InpMinD1, InpMinD2, InpMinD3, InpMinD4, InpMinD5, InpMinD6};
   double maxThresholds[6] = {InpMaxD1, InpMaxD2, InpMaxD3, InpMaxD4, InpMaxD5, InpMaxD6};
   double weights[6]        = {InpWeight1, InpWeight2, InpWeight3, InpWeight4, InpWeight5, InpWeight6};

   // Evaluate BUY Gate Conditions (All d_k must fall between Min_k and Max_k)
   bool buyValid = true;
   for(int k = 0; k < 6; k++)
   {
      if(normD[k] < minThresholds[k] || normD[k] > maxThresholds[k])
      {
         buyValid = false;
         break;
      }
   }

   // Evaluate SELL Gate Conditions (All d_k must fall between -Max_k and -Min_k)
   bool sellValid = true;
   for(int k = 0; k < 6; k++)
   {
      if(normD[k] > -minThresholds[k] || normD[k] < -maxThresholds[k])
      {
         sellValid = false;
         break;
      }
   }

   // Execution Data
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDistance = currentAtr * InpAtrSlMultiplier;
   double tpDistance = slDistance * InpRiskRewardRatio;

   // Place BUY Trade if all positive derivative thresholds are met
   if(buyValid)
   {
      double sl = NormalizeDouble(ask - slDistance, digits);
      double tp = NormalizeDouble(ask + tpDistance, digits);

      trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Gated Derivative Buy");
   }
   // Place SELL Trade if all negative derivative thresholds are met
   else if(sellValid)
   {
      double sl = NormalizeDouble(bid + slDistance, digits);
      double tp = NormalizeDouble(bid - tpDistance, digits);

      trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Gated Derivative Sell");
   }
}

//+------------------------------------------------------------------+
//| Recursive Cascade Engine: Computes d1..d6 from series array       |
//+------------------------------------------------------------------+
void ComputeDerivatives(const double &priceSeries[], double &outDerivatives[])
{
   double tempBuffer[7];
   ArrayCopy(tempBuffer, priceSeries);

   for(int order = 1; order <= 6; order++)
   {
      for(int i = 0; i <= (7 - order - 1); i++)
      {
         tempBuffer[i] = tempBuffer[i] - tempBuffer[i + 1];
      }
      outDerivatives[order - 1] = tempBuffer[0];
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

            if(InpUseTrailingStop)
            {
               double trailDist = currentAtr * InpTrailingStopAtr;
               double stepDist  = currentAtr * InpTrailingStepAtr;
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