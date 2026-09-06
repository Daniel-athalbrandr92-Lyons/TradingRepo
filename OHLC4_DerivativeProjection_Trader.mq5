//+------------------------------------------------------------------+
//|                        OHLC4_DerivativeProjection_Trader.mq5     |
//|  Same OHLC4 derivative / Taylor-projection engine as the display |
//|  version, but places a single bracket trade in the direction of  |
//|  the projection when the projected move clears a cost threshold. |
//|  FOR BACKTESTING / IDEA VALIDATION ONLY.                          |
//+------------------------------------------------------------------+
#property copyright "Custom"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

input int    InpLookback       = 20;    // Bars of history used to build the derivative series
input int    InpSmooth         = 3;     // Smoothing (SMA) period applied to each derivative
input int    InpProjectBars    = 10;    // Bars ahead to project / trade decision horizon
input double InpLots           = 0.01;  // Fixed lot size
input double InpCommissionPips = 0.7;   // Round-turn commission, in pips
input ulong  InpMagic          = 240901;
input bool   InpDrawLines      = true;  // Draw projected path on chart
input bool   InpShowComment    = true;  // Show numeric readout in chart comment
input color  InpLineColor      = clrDodgerBlue;
input string InpObjPrefix      = "OHLC4Proj_";

CTrade   trade;
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, InpObjPrefix);
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   datetime t0 = iTime(_Symbol, _Period, 1); // last fully closed bar (avoid repaint on forming bar)
   if(t0 == 0 || t0 == g_lastBarTime)
      return;
   g_lastBarTime = t0;
   Calculate();
  }

//+------------------------------------------------------------------+
//| Pip size in price terms (handles 3/5-digit fractional pricing)   |
//+------------------------------------------------------------------+
double PipSize()
  {
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
  }

//+------------------------------------------------------------------+
//| Live spread in price terms                                        |
//+------------------------------------------------------------------+
double SpreadPrice()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return(ask - bid);
  }

//+------------------------------------------------------------------+
//| Is there already an open position of ours on this symbol?        |
//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   if(!PositionSelect(_Symbol))
      return(false);
   return(PositionGetInteger(POSITION_MAGIC) == (long)InpMagic);
  }

//+------------------------------------------------------------------+
//| Core calculation + trade decision                                 |
//+------------------------------------------------------------------+
void Calculate()
  {
   int need = InpLookback + 3;
   if(Bars(_Symbol, _Period) < need + 2)
     {
      Comment("Need at least ", need + 2, " bars of history.");
      return;
     }

   double price[];
   ArrayResize(price, need);
   for(int i = 0; i < need; i++)
     {
      int shift = i + 1; // shift 1 = most recently completed bar
      price[i] = (iOpen(_Symbol, _Period, shift)
                + iHigh(_Symbol, _Period, shift)
                + iLow(_Symbol, _Period, shift)
                + iClose(_Symbol, _Period, shift)) / 4.0;
     }

   double d1[]; BuildDiff(price, d1);
   double d2[]; BuildDiff(d1, d2);
   double d3[]; BuildDiff(d2, d3);

   double P0 = price[0];
   double D1 = SmoothedHead(d1, InpSmooth);
   double D2 = SmoothedHead(d2, InpSmooth);
   double D3 = SmoothedHead(d3, InpSmooth);
   double Pn = ProjectedPrice(P0, D1, D2, D3, InpProjectBars);

   if(InpDrawLines)   DrawProjection(P0, D1, D2, D3);
   if(InpShowComment) ShowReadout(P0, D1, D2, D3, Pn);

   TryEnter(P0, Pn);
  }

//+------------------------------------------------------------------+
//| Entry logic                                                       |
//+------------------------------------------------------------------+
void TryEnter(double P0, double Pn)
  {
   if(HasOpenPosition())
      return; // already in a trade, let SL/TP close it out first

   double moveDistance = MathAbs(Pn - P0);
   double threshold     = (SpreadPrice() + InpCommissionPips * PipSize()) * 2.0;

   if(moveDistance < threshold)
      return; // projected edge doesn't clear the round-trip cost buffer

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(Pn > P0) // bullish projection
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = NormalizeDouble(entry - moveDistance, digits);
      double tp = NormalizeDouble(entry + moveDistance, digits);
      trade.Buy(InpLots, _Symbol, entry, sl, tp, "OHLC4 deriv proj");
     }
   else if(Pn < P0) // bearish projection
     {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble(entry + moveDistance, digits);
      double tp = NormalizeDouble(entry - moveDistance, digits);
      trade.Sell(InpLots, _Symbol, entry, sl, tp, "OHLC4 deriv proj");
     }
  }

//+------------------------------------------------------------------+
//| out[i] = in[i] - in[i+1]                                          |
//+------------------------------------------------------------------+
void BuildDiff(const double &in[], double &out[])
  {
   int n = ArraySize(in) - 1;
   if(n < 1) { ArrayResize(out, 0); return; }
   ArrayResize(out, n);
   for(int i = 0; i < n; i++)
      out[i] = in[i] - in[i + 1];
  }

//+------------------------------------------------------------------+
double SmoothedHead(const double &arr[], int period)
  {
   int total = ArraySize(arr);
   if(total == 0) return(0.0);
   int p = MathMin(period, total);
   double sum = 0.0;
   for(int i = 0; i < p; i++)
      sum += arr[i];
   return(sum / p);
  }

//+------------------------------------------------------------------+
//| Taylor expansion: P(n) = P0 + D1*n + D2*n^2/2! + D3*n^3/3!        |
//+------------------------------------------------------------------+
double ProjectedPrice(double P0, double D1, double D2, double D3, int n)
  {
   return(P0 + D1 * n + D2 * (n * n) / 2.0 + D3 * (n * n * n) / 6.0);
  }

//+------------------------------------------------------------------+
void DrawProjection(double P0, double D1, double D2, double D3)
  {
   ObjectsDeleteAll(0, InpObjPrefix);
   int      periodSeconds = PeriodSeconds(_Period);
   datetime anchorTime    = iTime(_Symbol, _Period, 1);

   datetime prevTime  = anchorTime;
   double   prevPrice = P0;
   for(int n = 1; n <= InpProjectBars; n++)
     {
      datetime nextTime  = anchorTime + periodSeconds * n;
      double   nextPrice = ProjectedPrice(P0, D1, D2, D3, n);
      string   name = InpObjPrefix + IntegerToString(n);

      ObjectCreate(0, name, OBJ_TREND, 0, prevTime, prevPrice, nextTime, nextPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpLineColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);

      prevTime  = nextTime;
      prevPrice = nextPrice;
     }
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void ShowReadout(double P0, double D1, double D2, double D3, double Pn)
  {
   double moveDistance = MathAbs(Pn - P0);
   double threshold     = (SpreadPrice() + InpCommissionPips * PipSize()) * 2.0;

   string txt = "OHLC4 Derivative Projection (Trader)\n";
   txt += "P    = " + DoubleToString(P0, _Digits) + "\n";
   txt += "P'   = " + DoubleToString(D1, _Digits) + "\n";
   txt += "P''  = " + DoubleToString(D2, _Digits) + "\n";
   txt += "P''' = " + DoubleToString(D3, _Digits) + "\n";
   txt += "Projected @+" + IntegerToString(InpProjectBars) + " bars = " + DoubleToString(Pn, _Digits) + "\n";
   txt += "Move required to trade = " + DoubleToString(threshold, _Digits) + "\n";
   txt += "Move projected         = " + DoubleToString(moveDistance, _Digits) + "\n";
   txt += (moveDistance >= threshold ? "-> signal qualifies\n" : "-> below cost threshold\n");
   Comment(txt);
  }
//+------------------------------------------------------------------+