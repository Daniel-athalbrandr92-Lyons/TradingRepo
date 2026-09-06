//+------------------------------------------------------------------+
//|                                             RangeBreakoutV29.mq5 |
//|                                                    Daniel Lyons  |
//+------------------------------------------------------------------+
#property copyright "Daniel Lyons"
#property link      ""
#property version   "1.02"
#property strict

#include <Trade\Trade.mqh>

// --- WIN32 NAMED PIPE DLL IMPORTS ---
#define GENERIC_WRITE         0x40000000
#define OPEN_EXISTING         3
#define INVALID_HANDLE_VALUE -1

#import "kernel32.dll"
int  CreateFileW(string lpFileName, uint dwDesiredAccess, uint dwShareMode, int lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, int hTemplateFile);
bool WriteFile(int hFile, string lpBuffer, uint nNumberOfBytesToWrite, uint &lpNumberOfBytesWritten, int lpOverlapped);
bool CloseHandle(int hObject);
#import

// --- ENUMS ---
enum ENUM_TP_MODE {
   TP_MODE_PIVOT_POINTS,
   TP_MODE_SESSION_EXTREMA,
   TP_MODE_FIXED,
   TP_MODE_TRAILING_ONLY
};

enum ENUM_MA_MODE_TYPE {
   MA_MODE_PRICE_ABOVE_BELOW,
   MA_MODE_SLOPE_RISING_FALLING
};

enum ENUM_ADX_FILTER_MODE {
   ADX_FILTER_OFF,
   ADX_FILTER_MIN,
   ADX_FILTER_MAX,
   ADX_FILTER_MIN_MAX
};

enum ENUM_TRAIL_TYPE {
   TRAIL_NONE,
   TRAIL_PSAR,
   TRAIL_MTF_EMA,
   TRAIL_EXTREMA,
   TRAIL_CHANDELIER
};

// --- INPUTS ---
input group "--- 1. Time Settings ---"
input int      StartHour               = 9;            // Start Time (hour) (0-23)
input int      EndHour                 = 9;            // End Time (hour) (0-23)
input int      StartMinute             = 0;            // Open Range Minute (0-59)
input int      LookbackMinutes         = 12;           // Lookback Minutes (1-90)
input bool     EnableHolidayBlackout   = true;         // Enable Holiday Blackout
input int      BlackoutStartMonth      = 12;           // Blackout Start Month (12)
input int      BlackoutStartDay        = 20;           // Blackout Start Day (10-24)
input int      BlackoutEndMonth        = 1;            // Blackout End Month (1)
input int      BlackoutEndDay          = 5;            // Blackout End Day (2-10)

input group "--- 2. Strategy Settings ---"
input double   Risk                    = 1.0;          // Risk Percentage (0.1-4.9)
input int      MaxDollarRisk           = 45;           // Max Dollar Risk
input double   AtrBufferMult           = 0.75;         // ATR Buffer Mult
input ENUM_TP_MODE SelectedTpMode      = TP_MODE_FIXED;// Primary TP Mode
input double   PivotLevel              = 2.0;          // Pivot Level (0.5-8.0)
input int      ExtremaLookbackDays     = 3;            // Extrema Lookback (Days)
input double   RRRatioLong             = 9.75;         // R:R Ratio (Long)
input double   RRRatioShort            = 8.25;         // R:R Ratio (Short)
input bool     UseWolfeOverride        = false;        // Enable Momentum Extension Override

input group "--- 3. Filter Settings ---"
input ENUM_TIMEFRAMES EMATimeFrame     = PERIOD_H1;    // EMA Timeframe
input int      MALookback              = 150;          // EMA Lookback (2-500)
input ENUM_MA_MODE_TYPE MaLogic        = MA_MODE_PRICE_ABOVE_BELOW; // EMA Logic Mode
input int      RSIVal                  = 25;           // RSI Threshold
input bool     RSIHiLo                 = true;         // RSI High-Low
input bool     RSIReverse              = false;        // RSI Reverse
input ENUM_ADX_FILTER_MODE AdxMode     = ADX_FILTER_MIN_MAX; // ADX Mode
input ENUM_TIMEFRAMES ADXTimeFrame     = PERIOD_H1;    // Higher Timeframe ADX Timeframe
input int      htfADXperiod            = 14;           // Higher Timeframe ADX Period
input int      htfADXmin               = 25;           // Higher Timeframe ADX Min Level
input int      AdxPeriod               = 14;           // ADX Period
input double   AdxMin                  = 15.0;         // ADX Min Level
input double   AdxMax                  = 27.5;         // ADX Max Level
input double   MinBodyRatio            = 0.3;          // Min Body Ratio
input double   MaxRejectionWickRatio   = 0.1;          // Max Rejection Wick
input double   MaxSpread               = 45.0;         // Base Max Spread (Pips)
input double   MaxCandleAtrMultiplier  = 2.5;          // Max Candle (ATR Mult)
input double   MinVolatilityRatio      = 0.75;         // Min Volatility Ratio
input int      AtrPeriod               = 14;           // ATR Short Period (2-20)
input int      AtrLongPeriod           = 100;          // ATR Long Period (10-250)

input group "--- 4. Trailing Stops ---"
input ENUM_TRAIL_TYPE SelectedTrail    = TRAIL_CHANDELIER; // Trailing Type
input ENUM_TIMEFRAMES TrailTF          = PERIOD_H1;    // Trail TimeFrame
input int      EmaTrailPeriod          = 49;           // EMA Trail Period (2-101)
input int      ExtremaBars             = 5;            // Extrema Lookback (Bars)
input double   PsarMinAF               = 0.02;         // PSAR Min AF
input double   PsarMaxAF               = 0.2;          // PSAR Max AF
input double   ChandelierMult          = 3.0;          // Chandelier Mult

input group "--- 5. Management & Fitness ---"
input int      MaxPositions            = 1;            // Max Positions
input ulong    OrderMagic              = 1;            // Order Magic
input int      MinTrades               = 75;           // Min Trades for Optimization Fitness

input group "--- 6. Bridge Pipeline Configuration ---"
input string   InpBasePipeName         = "MT5_Bridge_"; // Base prefix for the pipe channel
input int      InpMagicNumber          = 1;            // Must match cTrader Magic Number exactly
input bool     EnableCTraderBridge     = true;         // TRUE routes trades to cTrader, FALSE uses MT5 internally

// --- GLOBAL VARIABLES ---
CTrade         trade;
string         Label;
double         startingBalance;
int            rsiMode = -1;
double         openHigh = 0, openLow = 0, p1Price = 0, p4Price = 0;
datetime       lastBarTime = 0;
double         currentDayHigh = -2;
double         currentDayLow = 2500000;
double         currentDayClose = -1;

// Indicator Handles
int            h_rsi, h_atrShort, h_atrLong, h_adx, h_htfADX, h_ema, h_trailEma, h_psar, h_chandelierAtr;

// Forward Declarations
void     InitializeHistoricalRange();
void     HandleTrailing();
void     DefineRanges();
bool     EnableTrade();
bool     IsInWindow();
bool     IsHoliday(datetime currentTime);
bool     CheckAdx(double val);
void     TradeIfAble();
void     ProcessEntry(ENUM_ORDER_TYPE type);
void     ExecuteByMode(ENUM_ORDER_TYPE type, double volume, double sl);
double   CalculateTPWithOverride(ENUM_ORDER_TYPE type, double entry, double sl);
int      GetPositionsCount();
double   CalculateRisk(double pips);
double   LotCalc(double rP, double slD);
double   GetSeriesValue(int handle, int buffer, int index);
double   GetHighestHigh(ENUM_TIMEFRAMES tf, int count);
double   GetLowestLow(ENUM_TIMEFRAMES tf, int count);
double   GetPipSize();
bool     IsOptimizerSanityInvalid();
void     TransmitSignalOverPipe(string message);
string   TrimString(string text);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   string targetPipe = "\\\\.\\pipe\\" + InpBasePipeName + IntegerToString(InpMagicNumber);
   Print("MT5 Range Breakout Signal Sender Initialized.");
   if(EnableCTraderBridge)
      Print("Target Pipe Channel: ", targetPipe);
   else
      Print("Bridge Setup Standby. Running internally in native MT5 execution mode.");

   Label = "RB_" + IntegerToString(OrderMagic);
   trade.SetExpertMagicNumber(OrderMagic);

   // Fast out if optimizer feeds an invalid setup
   if(IsOptimizerSanityInvalid())
   {
      Print("[OPTIMIZER SHIELD] Invalid parameter combination detected. Stopping initialization.");
      return(INIT_FAILED);
   }

   // Initialize Handles
   h_rsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   h_atrShort = iATR(_Symbol, _Period, AtrPeriod);
   h_atrLong = iATR(_Symbol, _Period, AtrLongPeriod);
   
   if(AdxMode != ADX_FILTER_OFF)
      h_adx = iADX(_Symbol, _Period, AdxPeriod);
   else
      h_adx = INVALID_HANDLE;
      
   h_htfADX = iADX(_Symbol, ADXTimeFrame, htfADXperiod);
   h_ema = iMA(_Symbol, EMATimeFrame, MALookback, 0, MODE_EMA, PRICE_CLOSE);

   if(SelectedTrail == TRAIL_MTF_EMA)
      h_trailEma = iMA(_Symbol, TrailTF, EmaTrailPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(SelectedTrail == TRAIL_PSAR)
      h_psar = iSAR(_Symbol, TrailTF, PsarMinAF, PsarMaxAF);
   if(SelectedTrail == TRAIL_CHANDELIER)
      h_chandelierAtr = iATR(_Symbol, TrailTF, AtrPeriod);

   startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   rsiMode = RSIHiLo ? 1 : (RSIReverse ? 2 : 0);
   
   InitializeHistoricalRange();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Optimizer Sanity Check Engine                                    |
//+------------------------------------------------------------------+
bool IsOptimizerSanityInvalid()
{
   if(AdxMode == ADX_FILTER_MIN_MAX && AdxMin >= AdxMax) return true;
   
   if(SelectedTrail == TRAIL_PSAR)
   {
      if(PsarMinAF <= 0 || PsarMaxAF <= 0 || PsarMinAF >= PsarMaxAF) return true;
   }
   if(SelectedTrail == TRAIL_MTF_EMA)
   {
      if(EmaTrailPeriod < 2 || EmaTrailPeriod > 200) return true;
   }
   if(SelectedTrail == TRAIL_EXTREMA)
   {
      if(ExtremaBars < 2 || ExtremaBars > 50) return true;
   }
   if(SelectedTrail == TRAIL_CHANDELIER)
   {
      if(ChandelierMult <= 0) return true;
   }

   if(SelectedTpMode == TP_MODE_FIXED)
   {
      if(RRRatioLong <= 0 || RRRatioShort <= 0) return true;
   }
   if(SelectedTpMode == TP_MODE_PIVOT_POINTS)
   {
      if(PivotLevel < 0.5 || PivotLevel > 8.0) return true;
   }
   if(SelectedTpMode == TP_MODE_SESSION_EXTREMA)
   {
      if(ExtremaLookbackDays < 1 || ExtremaLookbackDays > 10) return true;
   }

   if(EnableHolidayBlackout)
   {
      if(BlackoutStartMonth < 1 || BlackoutStartMonth > 12) return true;
      if(BlackoutEndMonth < 1 || BlackoutEndMonth > 12) return true;
      if(BlackoutStartDay < 1 || BlackoutStartDay > 31) return true;
      if(BlackoutEndDay < 1 || BlackoutEndDay > 31) return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_atrShort);
   IndicatorRelease(h_atrLong);
   if(h_adx != INVALID_HANDLE) IndicatorRelease(h_adx);
   IndicatorRelease(h_htfADX);
   IndicatorRelease(h_ema);
   if(SelectedTrail == TRAIL_MTF_EMA) IndicatorRelease(h_trailEma);
   if(SelectedTrail == TRAIL_PSAR) IndicatorRelease(h_psar);
   if(SelectedTrail == TRAIL_CHANDELIER) IndicatorRelease(h_chandelierAtr);
}

//+------------------------------------------------------------------+
//| Pip scale configuration mapper                                   |
//+------------------------------------------------------------------+
double GetPipSize()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5) return _Point * 10.0;
   return _Point;
}

//+------------------------------------------------------------------+
//| Initialize range parameters from historical M1 data              |
//+------------------------------------------------------------------+
void InitializeHistoricalRange()
{
   MqlRates dailyRates[];
   ArraySetAsSeries(dailyRates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, dailyRates) > 0)
   {
      currentDayHigh = dailyRates[0].high;
      currentDayClose = dailyRates[0].close;
      currentDayLow = dailyRates[0].low;
   }

   MqlRates m1Rates[];
   ArraySetAsSeries(m1Rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 4000, m1Rates);
   if(copied <= LookbackMinutes) return;
   for(int i = 0; i < copied - LookbackMinutes; i++)
   {
      MqlDateTime dt;
      TimeToStruct(m1Rates[i].time, dt);
      if(dt.hour == StartHour && dt.min == StartMinute)
      {
         p1Price = m1Rates[i + LookbackMinutes].open;
         openHigh = m1Rates[i + 1].high;
         openLow = m1Rates[i + 1].low;
         for(int j = 2; j <= LookbackMinutes; j++)
         {
            if((i + j) < copied)
            {
               openHigh = MathMax(openHigh, m1Rates[i + j].high);
               openLow = MathMin(openLow, m1Rates[i + j].low);
            }
         }

         p4Price = (openHigh + openLow) / 2.0;
         break;
      }
   }
   
   Print("openHigh = ", openHigh, ", openLow = ", openLow, ", currentDayHigh = ", currentDayHigh, ", currentDayClose = ", currentDayClose, ", currentDayLow = ", currentDayLow);
}

//+------------------------------------------------------------------+
//| OnTick execution loop                                            |
//+------------------------------------------------------------------+
void OnTick()
{

   // --- TEMPORARY FORCE-FIRE TEST ---
   // Delete or comment this out after testing!
   //static bool testSent = false;
   //if(!testSent)
   //{
     // Print("[TEST] Forcing a test BUY signal over the pipe...");
      //TransmitSignalOverPipe("BUY," + _Symbol + ",0.01");
      //testSent = true;
   //}
   
   if(IsOptimizerSanityInvalid()) return;

   datetime currentBarTimeClose = iTime(_Symbol, _Period, 0);
   if(currentBarTimeClose != lastBarTime)
   {
      lastBarTime = currentBarTimeClose;
      
      if(SelectedTrail != TRAIL_NONE && !EnableCTraderBridge) 
         HandleTrailing();

      MqlDateTime dt;
      TimeCurrent(dt);
      if(dt.min == StartMinute && dt.hour == StartHour)
         DefineRanges();
         
      if(EnableTrade() && GetPositionsCount() < MaxPositions)
      {
         bool m5AdxPass = true;
         if(h_adx != INVALID_HANDLE)
         {
            double adxVal = GetSeriesValue(h_adx, 0, 1);
            m5AdxPass = CheckAdx(adxVal);
            Print("M5 ADX = ", adxVal);
         }
         
         bool htfAdxPass = true;
         double htfAdxCurr = GetSeriesValue(h_htfADX, 0, 1);
         double htfAdxPrev = GetSeriesValue(h_htfADX, 0, 2);
         htfAdxPass = (htfAdxCurr >= htfADXmin && htfAdxCurr > htfAdxPrev);
         
         if(m5AdxPass && htfAdxPass)
         {
            TradeIfAble();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Strategy logic evaluation and entry selection                    |
//+------------------------------------------------------------------+
void TradeIfAble()
{
   double atrS = GetSeriesValue(h_atrShort, 0, 1);
   double atrL = GetSeriesValue(h_atrLong, 0, 1);
   double volRatio = atrS / MathMax(0.00001, atrL);
   double dynamicMaxSpread = MathFloor(MaxSpread * volRatio);           
   
   if(((double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) / GetPipSize()) > dynamicMaxSpread) return;
   if(atrS < (atrL * MinVolatilityRatio)) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return;
   double close = rates[1].close;
   double open  = rates[1].open;
   double barH  = rates[1].high;
   double barL  = rates[1].low;
   double prevClose = rates[2].close;
   
   double totR = barH - barL;
   if(totR > (atrS * MaxCandleAtrMultiplier)) return;
   if(totR == 0) return;
   double bodySize = MathAbs(close - open);
   double bodyRatio = bodySize / totR;
   if(bodyRatio < MinBodyRatio) return;
   double emaCurr = GetSeriesValue(h_ema, 0, 1);
   double emaPrev = GetSeriesValue(h_ema, 0, 2);
   
   bool maB = MaLogic == MA_MODE_PRICE_ABOVE_BELOW ? close > emaCurr : emaCurr > emaPrev;
   bool maS = MaLogic == MA_MODE_PRICE_ABOVE_BELOW ? close < emaCurr : emaCurr < emaPrev;

   double rsiVal = GetSeriesValue(h_rsi, 0, 1);
   bool rsiLong = false;
   bool rsiShort = false;

   if(rsiMode == 1) { 
      rsiLong = rsiVal > RSIVal && rsiVal < (100.0 - RSIVal);
      rsiShort = rsiVal < (100.0 - RSIVal) && rsiVal > RSIVal;
   }
   else if(rsiMode == 0) { 
      rsiLong = rsiVal > RSIVal;
      rsiShort = rsiVal < (100.0 - RSIVal); 
   }
   else if(rsiMode == 2) { 
      rsiLong = rsiVal < RSIVal;
      rsiShort = rsiVal > (100.0 - RSIVal); 
   }

   bool bullSig = close > openHigh && maB && rsiLong;
   bool bearSig = close < openLow && maS && rsiShort;
   
   double rejWick = -1;
   if(bullSig) rejWick = barH - MathMax(open, close);
   else if(bearSig) rejWick = MathMin(open, close) - barL;
   if(totR > 0 && (rejWick / totR) > MaxRejectionWickRatio) return;

   bool signalTouchZone = (barL <= openHigh && barH >= openLow);
   bool gapUpBreakout = (prevClose >= openLow && prevClose <= openHigh && open > openHigh);
   bool gapDownBreakout = (prevClose >= openLow && prevClose <= openHigh && open < openLow);
   if(bullSig)
   {
      if(signalTouchZone || gapUpBreakout) ProcessEntry(ORDER_TYPE_BUY);
   }
   else if(bearSig)
   {
      if(signalTouchZone || gapDownBreakout) ProcessEntry(ORDER_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Risk management evaluation and lot estimation                    |
//+------------------------------------------------------------------+
void ProcessEntry(ENUM_ORDER_TYPE type)
{
   double pipSize = GetPipSize();
   double entryPrice = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal = GetSeriesValue(h_atrShort, 0, 1);
   
   double tier1SL = (type == ORDER_TYPE_BUY) ? openLow - (atrVal * AtrBufferMult) : openHigh + (atrVal * AtrBufferMult);
   double tier2SL = (type == ORDER_TYPE_BUY) ? openLow : openHigh;

   double slPips = MathAbs(entryPrice - tier1SL) / pipSize;
   double finalSL = CalculateRisk(slPips) <= MaxDollarRisk ? tier1SL : (CalculateRisk(MathAbs(entryPrice - tier2SL) / pipSize) <= MaxDollarRisk ? tier2SL : 0);
   if(finalSL == 0) return;
   double volume = LotCalc(Risk, MathAbs(entryPrice - finalSL));
   ExecuteByMode(type, volume, finalSL);
}

//+------------------------------------------------------------------+
//| Routing execution: Diverts orders to named pipes format          |
//+------------------------------------------------------------------+
void ExecuteByMode(ENUM_ORDER_TYPE type, double volume, double sl)
{

   double entry = (type == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   
   if(EnableCTraderBridge)
   {
   
      // ADD THIS CHECK:
        if(IsLocked(_Symbol))
        {
            Print("Signal blocked: Lock file exists for ", _Symbol);
            return; 
        }
        
        
      // Exactly formatted to match the background reader requirement: COMMAND,SYMBOL,VOLUME
      string action = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      // Append SL and TP as well
      string signalPayload = action + "," + _Symbol + "," + DoubleToString(volume, 2) + "," + DoubleToString(sl, _Digits) + "," + DoubleToString(CalculateTPWithOverride(type, entry, sl), _Digits);
      
      TransmitSignalOverPipe(signalPayload);
   }
   else
   {
      // Internal execution loop for local strategy backtesting / updates
 
      double tpPrice = CalculateTPWithOverride(type, entry, sl);
      
      if((type == ORDER_TYPE_BUY && tpPrice > 0 && tpPrice <= entry) || (type == ORDER_TYPE_SELL && tpPrice > 0 && tpPrice >= entry))
         return;

      if(SelectedTpMode == TP_MODE_TRAILING_ONLY)
      {
         if(type == ORDER_TYPE_BUY) trade.Buy(volume, _Symbol, entry, sl, 0, Label);
         else trade.Sell(volume, _Symbol, entry, sl, 0, Label);
      }
      else 
      {
         if(type == ORDER_TYPE_BUY) trade.Buy(volume, _Symbol, entry, sl, tpPrice, Label);
         else trade.Sell(volume, _Symbol, entry, sl, tpPrice, Label);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate customized TP matrix matching Pivot or Session limits |
//+------------------------------------------------------------------+
double CalculateTPWithOverride(ENUM_ORDER_TYPE type, double entry, double sl)
{
   double baseTP = 0;
   switch(SelectedTpMode)
   {   
      case TP_MODE_FIXED:
         baseTP = type == ORDER_TYPE_BUY ? entry + (MathAbs(entry - sl) * RRRatioLong) : entry - (MathAbs(entry - sl) * RRRatioShort); 
         break;
      case TP_MODE_PIVOT_POINTS:
      {
         double h = currentDayHigh, l = currentDayLow, c = currentDayClose;
         double pp = (h + l + c) / 3.0;
         double range = h - l;
         double gapH = h - pp;
         double gapL = pp - l;
         double r1 = (2.0 * pp) - l,        s1 = (2.0 * pp) - h;
         double r2 = pp + range,            s2 = pp - range;
         double r3 = h + 2.0 * (pp - l),    s3 = l - 2.0 * (h - pp);
         double r4 = pp + 2.0 * range,      s4 = pp - 2.0 * range;
         double r5 = r1 + 2.0 * range,      s5 = s1 - 2.0 * range;
         double r6 = pp + 3.0 * range,      s6 = pp - 3.0 * range;
         double r7 = r1 + 3.0 * range,      s7 = s1 - 3.0 * range;
         double r8 = pp + 4.0 * range,      s8 = pp - 4.0 * range;
         double r05 = pp + 0.5 * gapL;      double s05 = pp - 0.5 * gapH;
         double r15 = r1 + 0.5 * gapH;      double s15 = s1 - 0.5 * gapL;
         double r25 = r2 + 0.5 * gapL;      double s25 = s2 - 0.5 * gapH;
         double r35 = r3 + 0.5 * gapH;      double s35 = s3 - 0.5 * gapL;
         double r45 = r4 + 0.5 * gapL;      double s45 = s4 - 0.5 * gapH;
         if(type == ORDER_TYPE_BUY)
         {
            if(PivotLevel <= 0.5) baseTP = r05;
            else if(PivotLevel <= 1.0) baseTP = r1; else if(PivotLevel <= 1.5) baseTP = r15;
            else if(PivotLevel <= 2.0) baseTP = r2; else if(PivotLevel <= 2.5) baseTP = r25;
            else if(PivotLevel <= 3.0) baseTP = r3; else if(PivotLevel <= 3.5) baseTP = r35;
            else if(PivotLevel <= 4.0) baseTP = r4; else if(PivotLevel <= 4.5) baseTP = r45;
            else if(PivotLevel <= 5.0) baseTP = r5; else if(PivotLevel <= 5.5) baseTP = r5 + 0.5 * gapH;
            else if(PivotLevel <= 6.0) baseTP = r6; else if(PivotLevel <= 6.5) baseTP = r6 + 0.5 * gapL;
            else if(PivotLevel <= 7.0) baseTP = r7; else if(PivotLevel <= 7.5) baseTP = r7 + 0.5 * gapH;
            else if(PivotLevel <= 8.0) baseTP = r8;
         }
         else
         {
            if(PivotLevel <= 0.5) baseTP = s05;
            else if(PivotLevel <= 1.0) baseTP = s1; else if(PivotLevel <= 1.5) baseTP = s15;
            else if(PivotLevel <= 2.0) baseTP = s2; else if(PivotLevel <= 2.5) baseTP = s25;
            else if(PivotLevel <= 3.0) baseTP = s3; else if(PivotLevel <= 3.5) baseTP = s35;
            else if(PivotLevel <= 4.0) baseTP = s4; else if(PivotLevel <= 4.5) baseTP = s45;
            else if(PivotLevel <= 5.0) baseTP = s5; else if(PivotLevel <= 5.5) baseTP = s5 - 0.5 * gapL;
            else if(PivotLevel <= 6.0) baseTP = s6; else if(PivotLevel <= 6.5) baseTP = s6 - 0.5 * gapH;
            else if(PivotLevel <= 7.0) baseTP = s7; else if(PivotLevel <= 7.5) baseTP = s7 - 0.5 * gapL;
            else if(PivotLevel <= 8.0) baseTP = s8;
         }
         break;
      }
      case TP_MODE_SESSION_EXTREMA: 
      {
         if(type == ORDER_TYPE_BUY) baseTP = GetHighestHigh(PERIOD_D1, ExtremaLookbackDays);
         else baseTP = GetLowestLow(PERIOD_D1, ExtremaLookbackDays);
         break;
      }
      default:
         break;
   }

   if(UseWolfeOverride)
   {
      double slope = (p4Price - p1Price) / (double)MathMax(1, LookbackMinutes - 1);
      double wolfeEPA = p4Price + (slope * 5.0);
      double comparisonTP = (baseTP > 0) ? baseTP : entry;
      if(type == ORDER_TYPE_BUY && wolfeEPA > comparisonTP) return wolfeEPA;
      if(type == ORDER_TYPE_SELL && wolfeEPA < comparisonTP) return wolfeEPA;
   }
   return baseTP;
}

//+------------------------------------------------------------------+
//| Redefine Session boundary rules relative to operational windows |
//+------------------------------------------------------------------+
void DefineRanges()
{
   MqlRates m1Rates[];
   ArraySetAsSeries(m1Rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_M1, 1, LookbackMinutes, m1Rates);
   if(copied < LookbackMinutes) return;
   p1Price = m1Rates[LookbackMinutes - 1].open;
   openHigh = m1Rates[0].high; 
   openLow = m1Rates[0].low;
   for(int i = 1; i < LookbackMinutes; i++) { 
      openHigh = MathMax(openHigh, m1Rates[i].high);
      openLow = MathMin(openLow, m1Rates[i].low); 
   }
   p4Price = (openHigh + openLow) / 2.0;

   MqlRates dailyRates[];
   ArraySetAsSeries(dailyRates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, dailyRates) > 0)
   {
      currentDayHigh = dailyRates[0].high;
      currentDayClose = dailyRates[0].close;
      currentDayLow = dailyRates[0].low;
   }
   Print("DefineRanges checks: openHigh = ", openHigh, ", openLow = ", openLow, ", currentDayHigh = ", currentDayHigh, ", currentDayClose = ", currentDayClose, ", currentDayLow = ", currentDayLow);
}

//+------------------------------------------------------------------+
//| Dynamic trailing management logic loop                           |
//+------------------------------------------------------------------+
void HandleTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == OrderMagic)
      {
         double nSL = 0;
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
         double currentSL = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         if(SelectedTrail == TRAIL_PSAR) 
            nSL = GetSeriesValue(h_psar, 0, 1);
         else if(SelectedTrail == TRAIL_MTF_EMA) 
            nSL = GetSeriesValue(h_trailEma, 0, 1);
         else if(SelectedTrail == TRAIL_EXTREMA) 
            nSL = posType == POSITION_TYPE_BUY ? GetLowestLow(TrailTF, ExtremaBars) : GetHighestHigh(TrailTF, ExtremaBars);
         else if(SelectedTrail == TRAIL_CHANDELIER)
         {
            double atr = GetSeriesValue(h_chandelierAtr, 0, 1);
            int barIndex = iBarShift(_Symbol, TrailTF, entryTime);
            int count = MathMax(1, barIndex);
            nSL = posType == POSITION_TYPE_BUY ? GetHighestHigh(TrailTF, count) - (atr * ChandelierMult) : GetLowestLow(TrailTF, count) + (atr * ChandelierMult);
         }
         
         if(nSL > 0)
         {
            if(posType == POSITION_TYPE_BUY && (currentSL == 0 || nSL > currentSL) && nSL < SymbolInfoDouble(_Symbol, SYMBOL_BID)) 
               trade.PositionModify(PositionGetTicket(i), nSL, tp);
            else if(posType == POSITION_TYPE_SELL && (currentSL == 0 || nSL < currentSL) && nSL > SymbolInfoDouble(_Symbol, SYMBOL_ASK)) 
               trade.PositionModify(PositionGetTicket(i), nSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Evaluate holiday parameters and target matching boundaries      |
//+------------------------------------------------------------------+
bool IsHoliday(datetime currentTime)
{
   if(!EnableHolidayBlackout) return false;
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   int m = dt.mon, d = dt.day;
   if(BlackoutStartMonth <= BlackoutEndMonth) {
      return (m > BlackoutStartMonth || (m == BlackoutStartMonth && d >= BlackoutStartDay)) &&
             (m < BlackoutEndMonth || (m == BlackoutEndMonth && d <= BlackoutEndDay));
   } else {
      bool isAfterStart = (m > BlackoutStartMonth) || (m == BlackoutStartMonth && d >= BlackoutStartDay);
      bool isBeforeEnd = (m < BlackoutEndMonth) || (m == BlackoutEndMonth && d <= BlackoutEndDay);
      return isAfterStart || isBeforeEnd;
   }
}

//+------------------------------------------------------------------+
//| Internal conditional parsing validation for active ADX levels   |
//+------------------------------------------------------------------+
bool CheckAdx(double val) 
{
   if(AdxMode == ADX_FILTER_MIN) return val >= AdxMin;
   if(AdxMode == ADX_FILTER_MAX) return val <= AdxMax;
   if(AdxMode == ADX_FILTER_MIN_MAX) return val >= AdxMin && val <= AdxMax;
   return true;
}

//+------------------------------------------------------------------+
//| Verification boolean confirming active availability rules        |
//+------------------------------------------------------------------+
bool EnableTrade() 
{
   return (IsInWindow() && openHigh != 0 && !IsHoliday(TimeCurrent()));
}

//+------------------------------------------------------------------+
//| Window evaluation mapping across execution timeline intervals     |
//+------------------------------------------------------------------+
bool IsInWindow()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int currentMins = dt.hour * 60 + dt.min;
   int startMins = StartHour * 60 + StartMinute;
   int endMins = EndHour * 60; 

   if(startMins < endMins)
   {
      return (currentMins >= startMins && currentMins < endMins);
   }
   
   return (currentMins >= startMins || currentMins < endMins);
}

//+------------------------------------------------------------------+
//| Active position validation count assigned to Magic Number parameters|
//+------------------------------------------------------------------+
int GetPositionsCount()
{
   if(EnableCTraderBridge) return 0; // Managed externally by cTrader environment variables
   
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == OrderMagic)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Monetary sizing evaluation assessing balance risks               |
//+------------------------------------------------------------------+
double CalculateRisk(double pips) 
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tickSize == 0) return 0;
   return (pips * _Point * (volumeStep / tickSize) * tickValue) * (LotCalc(Risk, pips * _Point) / volumeStep);
}

//+------------------------------------------------------------------+
//| Lot calculation optimizing volume step restrictions               |
//+------------------------------------------------------------------+
double LotCalc(double rP, double slD) 
{ 
   double rM = AccountInfoDouble(ACCOUNT_BALANCE) * rP / 100.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volumeMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(tickSize == 0) return volumeMin;
   double mPS = (slD / tickSize) * tickValue * volumeStep; 
   if(mPS == 0) return volumeMin;
   double calculated = MathFloor(rM / mPS) * volumeStep;
   return NormalizeDouble(MathMin(MathMax(calculated, volumeMin), volumeStep * 1000.0), 2);
}

//+------------------------------------------------------------------+
//| Indicator buffer handling proxy tool                            |
//+------------------------------------------------------------------+
double GetSeriesValue(int handle, int buffer, int index)
{
   double val[1];
   if(CopyBuffer(handle, buffer, index, 1, val) > 0) return val[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Historical maximum series search tool                           |
//+------------------------------------------------------------------+
double GetHighestHigh(ENUM_TIMEFRAMES tf, int count)
{
   double highVals[];
   ArraySetAsSeries(highVals, true);
   if(CopyHigh(_Symbol, tf, 0, count, highVals) > 0) return highVals[ArrayMaximum(highVals)];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Historical minimum series search tool                            |
//+------------------------------------------------------------------+
double GetLowestLow(ENUM_TIMEFRAMES tf, int count)
{
   double lowVals[];
   ArraySetAsSeries(lowVals, true);
   if(CopyLow(_Symbol, tf, 0, count, lowVals) > 0) return lowVals[ArrayMinimum(lowVals)];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Win32 IPC Pipeline Transmission Core                            |
//+------------------------------------------------------------------+
void TransmitSignalOverPipe(string message)
{
   
   Print("DEBUG: Attempting to write to pipe...");
   Success(message);   
   Print("DEBUG: WriteFile result: ", Success(message));

   
}

bool Success(string message)
{
   string fullPipePath = "\\\\.\\pipe\\" + InpBasePipeName + IntegerToString(InpMagicNumber);
   int hPipe = CreateFileW(fullPipePath, GENERIC_WRITE, 0, 0, OPEN_EXISTING, 0, 0);
   if(hPipe == INVALID_HANDLE_VALUE)
   {
      Print("[BRIDGE ERROR] Connection failed. Confirm cTrader background server is active on target channel name: '", InpBasePipeName, InpMagicNumber, "'");
      return false;
   }

   uint bytesWritten = 0;
   // Explicit line feed to cleanly wake up and trigger StreamReader.ReadLine() inside the cBot
   string finalizedBuffer = message + "\n";
   uint bufferLengthBytes = (StringLen(finalizedBuffer) * 2);
   if(!WriteFile(hPipe, finalizedBuffer, bufferLengthBytes, bytesWritten, 0))
   {
      Print("[BRIDGE ERROR] Failed writing payload bytes down the named pipe link.");
      return false;
   }
   else
   {
      Print("[BRIDGE SUCCESS] Signal packet forwarded downstream: ", TrimString(finalizedBuffer));
      return true;
   }
   
   CloseHandle(hPipe);
}

// Simple logging formatting tool
string TrimString(string text)
{
   StringReplace(text, "\n", "");
   StringReplace(text, "\r", "");
   return text;
}

//+------------------------------------------------------------------+
//| OnTester framework parsing full GetFitness formula               |
//+------------------------------------------------------------------+
double OnTester()
{
   if(IsOptimizerSanityInvalid()) return -9999.0;

   long totalTrades = TesterStatistics(STAT_TRADES);
   double netProfit = TesterStatistics(STAT_PROFIT);
   if(netProfit <= 0) return netProfit;
   if(totalTrades <= 1) return 0.0;
   if(totalTrades < MinTrades) return 0.0;

   string symName = _Symbol;
   StringToUpper(symName);
   bool isCrypto = (StringFind(symName, "BTC") >= 0 || StringFind(symName, "ETH") >= 0 || StringFind(symName, "XBT") >= 0);
   datetime firstEntry = 0, lastClosing = 0;
   ulong ticket;
   
   if(HistorySelect(0, TimeCurrent()))
   {
      int totalHistory = HistoryDealsTotal();
      bool assignedFirst = false;
      for(int i = 0; i < totalHistory; i++)
      {
         if((ticket = HistoryDealGetTicket(i)) > 0)
         {
            long magicNum = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            if(magicNum == OrderMagic)
            {
               datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               if(!assignedFirst) { firstEntry = dealTime; assignedFirst = true; }
               lastClosing = dealTime;
            }
         }
      }
   }
   
   double totalDays = (double)(lastClosing - firstEntry) / 86400.0;
   double daysPerWeek = isCrypto ? 7.0 : 5.0;
   double weeks = MathMax(0.1, totalDays / daysPerWeek);
   double tradesPerWeek = (double)totalTrades / weeks;
   
   double frequencyPenalty = MathMin(1.0, tradesPerWeek / 2.0);
   frequencyPenalty = MathPow(frequencyPenalty, 4.0);
   int tradeIndex = 0;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cum = 0;
   if(HistorySelect(0, TimeCurrent()))
   {
      int totalHistory = HistoryDealsTotal();
      for(int i = 0; i < totalHistory; i++)
      {
         if((ticket = HistoryDealGetTicket(i)) > 0)
         {
            long magicNum = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            
            if(magicNum == OrderMagic && entryType == DEAL_ENTRY_OUT)
            {
               double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
               cum += dealProfit;
               sumX += tradeIndex;
               sumY += cum;
               sumXY += tradeIndex * cum;
               sumX2 += (double)tradeIndex * tradeIndex;
               sumY2 += cum * cum;
               tradeIndex++;
            }
         }
      }
   }

   double r2 = 0.0;
   if(tradeIndex > 1)
   {
      double denominator = MathSqrt(((tradeIndex * sumX2) - (sumX * sumX)) * ((tradeIndex * sumY2) - (sumY * sumY)));
      r2 = (denominator == 0) ? 0 : MathPow(((tradeIndex * sumXY) - (sumX * sumY)) / denominator, 2.0);
   }

   double maxEquityDDPercent = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double maxEquityDD = TesterStatistics(STAT_EQUITY_DD);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   long winningTrades = TesterStatistics(STAT_PROFIT_TRADES);
   double ddDivider = MathMax(1.0, maxEquityDD);
   double winRatio = (double)winningTrades / (double)totalTrades;
   double logTrades = MathLog10((double)totalTrades);
   double ddPercentDenominator = MathMax(0.1, maxEquityDDPercent);
   double balanceRatio = netProfit / startingBalance;

   double baseScore = 0.0;
   if(maxEquityDDPercent >= 10.0) 
   {
      baseScore = ((((profitFactor * (netProfit / ddDivider) * winRatio * r2) * logTrades) / ddPercentDenominator) * balanceRatio * r2) / maxEquityDDPercent;
   }
   else 
   {
      baseScore = (((profitFactor * (netProfit / ddDivider) * winRatio * r2) * logTrades) / ddPercentDenominator) * balanceRatio * r2;
   }

   return baseScore * frequencyPenalty;
}

bool IsLocked(string symbol)
{
    string filePath = "Trading_Bridge\\" + symbol + "_Lock.txt";
    // FILE_EXISTS returns true if the file is found
    return FileIsExist(filePath, FILE_COMMON);
}
