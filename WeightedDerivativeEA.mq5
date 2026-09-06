//+------------------------------------------------------------------+
//|                                          WeightedDerivativeEA.mq5|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>

//--- Input Parameters
input double   InpLotSize         = 0.01;     // Fixed Lot Size
input int      InpStopLossPoints  = 200;      // Stop Loss in Points (1:1 R:R implies TP = SL)
input double   InpThresholdPoints = 10.0;     // Min composite score threshold (in Points)

//--- Derivative Weights (w1 to w6)
input double   InpWeight1         = 1.0;      // Weight: 1st Derivative (Velocity)
input double   InpWeight2         = 0.8;      // Weight: 2nd Derivative (Acceleration)
input double   InpWeight3         = 0.6;      // Weight: 3rd Derivative (Jerk)
input double   InpWeight4         = 0.4;      // Weight: 4th Derivative (Snap)
input double   InpWeight5         = 0.2;      // Weight: 5th Derivative (Crackle)
input double   InpWeight6         = 0.1;      // Weight: 6th Derivative (Pop)

input ulong    InpMagicNumber     = 987654;   // Magic Number

//--- Global Variables
CTrade         trade;
datetime       lastBarTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   lastBarTime = 0;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Ensure calculation only runs once on a newly closed bar (Non-repainting)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   // Fetch (O+H+L+C)/4 for 7 closed candles (Bars 1 through 7)
   double p1 = GetMeanPrice(1);
   double p2 = GetMeanPrice(2);
   double p3 = GetMeanPrice(3);
   double p4 = GetMeanPrice(4);
   double p5 = GetMeanPrice(5);
   double p6 = GetMeanPrice(6);
   double p7 = GetMeanPrice(7);

   if(p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0 || p5 <= 0 || p6 <= 0 || p7 <= 0)
      return;

   // Calculate 1st through 6th backward finite derivatives
   double d1 = p1 - p2;
   double d2 = p1 - (2.0 * p2) + p3;
   double d3 = p1 - (3.0 * p2) + (3.0 * p3) - p4;
   double d4 = p1 - (4.0 * p2) + (6.0 * p3) - (4.0 * p4) + p5;
   double d5 = p1 - (5.0 * p2) + (10.0 * p3) - (10.0 * p4) + (5.0 * p5) - p6;
   double d6 = p1 - (6.0 * p2) + (15.0 * p3) - (20.0 * p4) + (15.0 * p5) - (6.0 * p6) + p7;

   // Calculate composite weighted derivative score
   double compositeScore = (d1 * InpWeight1) + 
                           (d2 * InpWeight2) + 
                           (d3 * InpWeight3) + 
                           (d4 * InpWeight4) + 
                           (d5 * InpWeight5) + 
                           (d6 * InpWeight6);

   // Check if a position is already open for this EA
   if(HasOpenPosition())
      return;

   double point         = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits        = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask           = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid           = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double thresholdValue = InpThresholdPoints * point;

   // Trade execution based on weighted derivative score
   if(compositeScore > thresholdValue)
   {
      // BUY Signal: 1:1 R:R
      double sl = NormalizeDouble(ask - (InpStopLossPoints * point), digits);
      double tp = NormalizeDouble(ask + (InpStopLossPoints * point), digits);

      trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "6-Derivative EA Buy");
   }
   else if(compositeScore < -thresholdValue)
   {
      // SELL Signal: 1:1 R:R
      double sl = NormalizeDouble(bid + (InpStopLossPoints * point), digits);
      double tp = NormalizeDouble(bid - (InpStopLossPoints * point), digits);

      trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "6-Derivative EA Sell");
   }
}

//+------------------------------------------------------------------+
//| Helper: Get (O+H+L+C)/4 for a given closed bar shift             |
//+------------------------------------------------------------------+
double GetMeanPrice(int shift)
{
   double open  = iOpen(_Symbol, _Period, shift);
   double high  = iHigh(_Symbol, _Period, shift);
   double low   = iLow(_Symbol, _Period, shift);
   double close = iClose(_Symbol, _Period, shift);

   return (open + high + low + close) / 4.0;
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