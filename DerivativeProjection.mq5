//+------------------------------------------------------------------+
//|                                          DerivativeProjection.mq5|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.20"

#include <Trade\Trade.mqh>

//--- Input Parameters
input double   InpLotSize         = 0.01;     // Fixed Lot Size
input int      InpProjectionBars  = 3;        // Future Projection Horizon (Bars)
input double   InpDampingFactor   = 0.25;     // Higher-Order Damping (0.0 = Pure Linear, 1.0 = Full Taylor)
input int      InpMinStopPoints   = 10;       // Safety filter: Min required distance in points
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

   // Calculate (O+H+L+C)/4 for the last 4 closed candles (Bars 1, 2, 3, 4)
   double p1 = GetMeanPrice(1);
   double p2 = GetMeanPrice(2);
   double p3 = GetMeanPrice(3);
   double p4 = GetMeanPrice(4);

   if(p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0)
      return;

   // Calculate 1st, 2nd, and 3rd finite backward derivatives
   double d1 = p1 - p2;                           // 1st Derivative (Velocity)
   double d2 = p1 - (2.0 * p2) + p3;              // 2nd Derivative (Acceleration)
   double d3 = p1 - (3.0 * p2) + (3.0 * p3) - p4;  // 3rd Derivative (Jerk)

   // Clamp damping factor between 0.0 and 1.0
   double gamma = MathMax(0.0, MathMin(1.0, InpDampingFactor));

   // Reintegrate via Damped Taylor Expansion for N steps ahead
   double dt = (double)InpProjectionBars;
   
   double linearTerm = d1 * dt;                      // 1st order term (linear)
   double accelTerm  = 0.5 * d2 * dt * dt * gamma;   // 2nd order term (damped)
   double jerkTerm   = (1.0 / 6.0) * d3 * dt * dt * dt * (gamma * gamma); // 3rd order term (strongly damped)

   double projectedPrice = p1 + linearTerm + accelTerm + jerkTerm;

   // Check if a position is already open for this EA
   if(HasOpenPosition())
      return;

   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   // Execute trades based on N-bar projection relative to current closed mean price
   if(projectedPrice > p1)
   {
      double tpDistance = projectedPrice - ask;
      double minDistance = MathMax((double)InpMinStopPoints, (double)stopsLevel) * point;

      // Ensure target distance meets broker minimum stops requirements
      if(tpDistance >= minDistance)
      {
         double tp = NormalizeDouble(projectedPrice, digits);
         double sl = NormalizeDouble(ask - tpDistance, digits); // 1:1 R:R

         trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Derivative EA Buy");
      }
   }
   else if(projectedPrice < p1)
   {
      double tpDistance = bid - projectedPrice;
      double minDistance = MathMax((double)InpMinStopPoints, (double)stopsLevel) * point;

      // Ensure target distance meets broker minimum stops requirements
      if(tpDistance >= minDistance)
      {
         double tp = NormalizeDouble(projectedPrice, digits);
         double sl = NormalizeDouble(bid + tpDistance, digits); // 1:1 R:R

         trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Derivative EA Sell");
      }
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