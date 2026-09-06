//+------------------------------------------------------------------+
//|                                    OHLC4_DerivativeProjection.mq5|
//|  Computes the 1st/2nd/3rd derivatives of (O+H+L+C)/4 via finite  |
//|  differences and reintegrates them into a forward price          |
//|  projection using a Taylor expansion. Calculation/visualization  |
//|  only -- this EA places no trades.                               |
//+------------------------------------------------------------------+
#property copyright "Custom"
#property version   "1.00"
#property strict

input int    InpLookback    = 20;    // Bars of history used to build the derivative series
input int    InpSmooth      = 3;     // Smoothing (SMA) period applied to each derivative
input int    InpProjectBars = 10;    // Bars ahead to project
input bool   InpDrawLines   = true;  // Draw projected path on chart
input bool   InpShowComment = true;  // Show numeric readout in chart comment
input color  InpLineColor   = clrDodgerBlue;
input string InpObjPrefix   = "OHLC4Proj_";

datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
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
//| Core calculation: build OHLC4 series, difference it three times, |
//| smooth each order, then project forward with a Taylor expansion  |
//+------------------------------------------------------------------+
void Calculate()
  {
   int need = InpLookback + 3; // extra bars so the 3rd-difference series still has InpLookback usable points
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
   // price[0] = newest, price[need-1] = oldest

   double d1[]; BuildDiff(price, d1);   // 1st derivative series
   double d2[]; BuildDiff(d1, d2);      // 2nd derivative series
   double d3[]; BuildDiff(d2, d3);      // 3rd derivative series

   double P0 = price[0];
   double D1 = SmoothedHead(d1, InpSmooth);
   double D2 = SmoothedHead(d2, InpSmooth);
   double D3 = SmoothedHead(d3, InpSmooth);

   if(InpDrawLines)   DrawProjection(P0, D1, D2, D3);
   if(InpShowComment) ShowReadout(P0, D1, D2, D3);
  }

//+------------------------------------------------------------------+
//| out[i] = in[i] - in[i+1]  (backward difference, one element      |
//| shorter than 'in')                                                |
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
//| Simple moving average over the most recent 'period' elements     |
//| of a series array (index 0 = newest)                              |
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
//| Draw the projected path as chained trend-line segments into the  |
//| future, anchored at the last completed bar                        |
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
//| Numeric readout in the chart comment                              |
//+------------------------------------------------------------------+
void ShowReadout(double P0, double D1, double D2, double D3)
  {
   string txt = "OHLC4 Derivative Projection\n";
   txt += "P    = " + DoubleToString(P0, _Digits) + "\n";
   txt += "P'   = " + DoubleToString(D1, _Digits) + "\n";
   txt += "P''  = " + DoubleToString(D2, _Digits) + "\n";
   txt += "P''' = " + DoubleToString(D3, _Digits) + "\n\nProjection:\n";
   for(int n = 1; n <= InpProjectBars; n++)
      txt += "  +" + IntegerToString(n) + " bars: "
           + DoubleToString(ProjectedPrice(P0, D1, D2, D3, n), _Digits) + "\n";
   Comment(txt);
  }
//+------------------------------------------------------------------+