//+------------------------------------------------------------------+
//|                                               RangeBreakoutV27.mq5|
//|                                  Copyright 2026, Quant Strategy |
//+------------------------------------------------------------------+
#property copyright "Quant Strategy"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

// --- ENUMS ---
enum ENUM_TP_MODE 
{ 
   TP_MODE_FIXED, 
   TP_MODE_HALF_AND_HALF, 
   TP_MODE_TRAILING_ONLY, 
   TP_MODE_PIVOT_POINTS, 
   TP_MODE_SESSION_EXTREMA 
};

enum ENUM_MA_MODE 
{ 
   MA_MODE_PRICE_ABOVE_BELOW, 
   MA_MODE_SLOPE_RISING_FALLING 
};

enum ENUM_ADX_MODE 
{ 
   ADX_MODE_OFF, 
   ADX_MODE_MIN, 
   ADX_MODE_MAX, 
   ADX_MODE_MIN_MAX 
};

enum ENUM_TRAIL_TYPE 
{ 
   TRAIL_NONE, 
   TRAIL_PSAR, 
   TRAIL_MTF_EMA, 
   TRAIL_EXTREMA, 
   TRAIL_CHANDELIER 
};

enum ENUM_REJECTION_MODE 
{ 
   REJ_WICK_INSIDE_CLOSE_OUTSIDE, 
   REJ_CLOSE_OUTSIDE_WICK_OUTSIDE 
};

// --- INPUT PARAMETERS ---

// 1. Time
input group "1. Time"
input int               InpStartTime          = 9;         // Start Time (hour)
input int               InpEndTime            = 9;         // End Time (hour)
input int               InpOpenRangeMin       = 0;         // Open Range Minute

// 2. Strategy
input group "2. Strategy"
input int               InpLookbackBars       = 12;        // Lookback Bars
input double            InpRisk               = 1.0;       // Risk Percentage
input double            InpMaxDollarRisk      = 1000.0;    // Max Dollar Risk
input double            InpAtrBufferMult      = 0.5;       // ATR Buffer Mult
input double            InpRRRatioLong        = 9.75;      // R:R Ratio (Long)
input double            InpRRRatioShort       = 8.25;      // R:R Ratio (Short)
input ENUM_TP_MODE      InpSelectedTpMode     = TP_MODE_HALF_AND_HALF; // Primary TP Mode
input int               InpPivotLevel         = 2;         // Pivot Level (1-5)
input int               InpExtremaLookbackDays= 3;         // Extrema Lookback (Days)
input bool              InpUseWolfeOverride   = true;      // Enable Wolfe Override

// 3. Indicators
input group "3. Indicators"
input int               InpMALookback         = 150;       // MA Lookback
input ENUM_MA_MODE      InpMaLogic            = MA_MODE_PRICE_ABOVE_BELOW; // MA Logic Mode
input int               InpRSIVal             = 25;        // RSI Threshold
input bool              InpRSIHiLo            = true;      // RSI High-Low
input bool              InpRSIReverse         = false;     // RSI Reverse

// 4. ADX Filter
input group "4. ADX Filter"
input ENUM_ADX_MODE     InpAdxMode            = ADX_MODE_MIN_MAX; // ADX Mode
input int               InpAdxPeriod          = 14;        // ADX Period
input double            InpAdxMin             = 15.0;      // ADX Min Level
input double            InpAdxMax             = 27.5;      // ADX Max Level

// 5. Filters
input group "5. Filters"
input double            InpMinBodyRatio       = 0.3;       // Min Body Ratio
input double            InpMaxRejectionWick   = 0.0;       // Max Rejection Wick
input double            InpMaxSpread          = 45.0;      // Max Spread (Pips)
input double            InpMaxCandleAtrMult   = 2.8;       // Max Candle (ATR Mult)
input double            InpMinVolatilityRatio = 0.7;       // Min Volatility Ratio
input int               InpAtrPeriod          = 14;        // ATR Short Period
input int               InpAtrLongPeriod      = 100;       // ATR Long Period
input bool              InpEnableHolidayBlackout = true;   // Enable Holiday Blackout
input int               InpBlackoutStartMonth = 12;        // Blackout Start Month
input int               InpBlackoutStartDay   = 20;        // Blackout Start Day
input int               InpBlackoutEndMonth   = 1;         // Blackout End Month
input int               InpBlackoutEndDay     = 5;         // Blackout End Day

// 6. Trailing Stops
input group "6. Trailing"
input ENUM_TRAIL_TYPE   InpSelectedTrail      = TRAIL_NONE; // Trailing Type
input ENUM_TIMEFRAMES   InpTrailTF            = PERIOD_H1;  // Trail TimeFrame
input int               InpEmaTrailPeriod     = 49;        // EMA Trail Period
input int               InpExtremaBars        = 6;         // Extrema Lookback (Bars)
input double            InpPsarMinAF          = 0.02;      // PSAR Min AF
input double            InpPsarMaxAF          = 0.2;       // PSAR Max AF
input double            InpChandelierMult     = 3.0;       // Chandelier Mult

// 7. Management
input group "7. Management"
input int               InpMaxPositions       = 1;         // Max Positions
input ulong             InpOrderMagic         = 1;         // Order Magic Number

// 8. Fitness
input group "8. Fitness"
input int               InpMinTrades          = 75;        // Min Trades
input bool              InpLinBon             = false;     // Linear Bonus?
input int               InpLinDiv             = 3;         // Linear Divisor
input double            InpHypExp             = 0.75;      // Hyperbolic Exponent

// 9. SnR Management
input group "9. SnR Management"
input ENUM_REJECTION_MODE InpSnRRejectionMode  = REJ_WICK_INSIDE_CLOSE_OUTSIDE; // Rejection Logic

// 10-13. Indicator S&R Parameters
input group "10. Indicator Vis"
input bool              InpIndShowMultiday    = true;
input bool              InpIndShowPreviousDay = true;
input bool              InpIndShowAsianSession= true;
input bool              InpIndShowLondonSession= true;
input bool              InpIndShowNySession   = true;
input bool              InpIndShowPsychLevels = true;
input bool              InpIndShowOrderBlocks = true;
input bool              InpIndShowDoubleTopsBottoms = true;
input bool              InpIndShowConsolidation = true;

input group "11. Indicator Core"
input double            InpIndMacroAtrMult    = 0.5;
input double            InpIndMicroAtrMult    = 0.2;
input double            InpIndPsychLevelStep  = 25.0;
input int               InpIndUtcOffset       = -5;
input ENUM_TIMEFRAMES   InpIndMultidayTimeFrame = PERIOD_W1;
input int               InpIndMultidayLookback = 1;

input group "12. Indicator Sessions"
input int               InpIndAsianStartHour  = 18;
input int               InpIndAsianEndHour    = 3;
input int               InpIndLondonStartHour = 3;
input int               InpIndLondonEndHour   = 11;
input int               InpIndNyStartHour     = 8;
input int               InpIndNyEndHour       = 17;

input group "13. Indicator Patterns"
input int               InpIndMinFormationCandles = 10;
input int               InpIndMaxLookbackCandles  = 50;
input double            InpIndMaxConsolidationAtrWidth = 1.5;

// --- GLOBAL VARIABLES ---
CTrade        m_trade;
double        m_openHigh = 0.0, m_openLow = 0.0;
double        m_p1Price = 0.0, m_p4Price = 0.0;
int           m_p1Index = 0, m_p4Index = 0;
datetime      m_lastBarTime = 0;
datetime      m_lastM1BarTime = 0;
double        m_startingBalance = 0.0;
string        m_label;

// Indicator Handles
int           m_handleEma = INVALID_HANDLE;
int           m_handleRsi = INVALID_HANDLE;
int           m_handleAtrShort = INVALID_HANDLE;
int           m_handleAtrLong = INVALID_HANDLE;
int           m_handleAdx = INVALID_HANDLE;
int           m_handleTrailEma = INVALID_HANDLE;
int           m_handlePsar = INVALID_HANDLE;
int           m_handleChandelierAtr = INVALID_HANDLE;
int           m_handleSnR = INVALID_HANDLE;

// --- FORWARD DECLARATIONS ---
void     DefineRanges();
void     InitializeHistoricalRange();
void     HandleTrailing();
void     HandleSnRRejections();
void     TradeIfAble();
void     ProcessEntry(ENUM_POSITION_TYPE type);
void     ExecuteByMode(ENUM_POSITION_TYPE type, double volume, double sl);
double   CalculateTPWithOverride(ENUM_POSITION_TYPE type, double entry, double sl);
double   GetPipSize();
double   GetPipDist(double entry, double tp);
bool     IsHoliday(datetime currentTime);
bool     CheckAdx(double val);
bool     EnableTrade();
bool     AfterStart();
bool     HasOpenPositionsForLabel();
double   CalculateRisk(double pips);
double   LotCalc(double riskPercent, double slDistance);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_label = "RB_" + IntegerToString(InpOrderMagic);
   m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_trade.SetExpertMagicNumber(InpOrderMagic);

   // Initialize Core Indicators
   m_handleEma = iMA(_Symbol, _Period, InpMALookback, 0, MODE_EMA, PRICE_CLOSE);
   m_handleRsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   m_handleAtrShort = iATR(_Symbol, _Period, InpAtrPeriod);
   m_handleAtrLong = iATR(_Symbol, _Period, InpAtrLongPeriod);
   m_handleAdx = iADX(_Symbol, _Period, InpAdxPeriod);

   // Trailing Indicators
   if(InpSelectedTrail == TRAIL_MTF_EMA)
      m_handleTrailEma = iMA(_Symbol, InpTrailTF, InpEmaTrailPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(InpSelectedTrail == TRAIL_PSAR)
      m_handlePsar = iSAR(_Symbol, InpTrailTF, InpPsarMinAF, InpPsarMaxAF);
   if(InpSelectedTrail == TRAIL_CHANDELIER)
      m_handleChandelierAtr = iATR(_Symbol, InpTrailTF, InpAtrPeriod);

   // Dynamic S&R Indicator
   m_handleSnR = iCustom(_Symbol, _Period, "DynamicSnRBoxes",
      InpIndShowMultiday, InpIndShowPreviousDay, InpIndShowAsianSession, InpIndShowLondonSession, InpIndShowNySession,
      InpIndShowPsychLevels, InpIndShowOrderBlocks, InpIndShowDoubleTopsBottoms, InpIndShowConsolidation,
      InpIndMacroAtrMult, InpIndMicroAtrMult, InpIndPsychLevelStep, InpIndUtcOffset, InpIndMultidayTimeFrame, InpIndMultidayLookback,
      InpIndAsianStartHour, InpIndAsianEndHour, InpIndLondonStartHour, InpIndLondonEndHour, InpIndNyStartHour, InpIndNyEndHour,
      InpIndMinFormationCandles, InpIndMaxLookbackCandles, InpIndMaxConsolidationAtrWidth
   );

   InitializeHistoricalRange();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(m_handleEma);
   IndicatorRelease(m_handleRsi);
   IndicatorRelease(m_handleAtrShort);
   IndicatorRelease(m_handleAtrLong);
   IndicatorRelease(m_handleAdx);
   
   if(m_handleTrailEma != INVALID_HANDLE) IndicatorRelease(m_handleTrailEma);
   if(m_handlePsar != INVALID_HANDLE) IndicatorRelease(m_handlePsar);
   if(m_handleChandelierAtr != INVALID_HANDLE) IndicatorRelease(m_handleChandelierAtr);
   if(m_handleSnR != INVALID_HANDLE) IndicatorRelease(m_handleSnR);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check M1 timer equivalent for trailing execution
   datetime currentM1Time = iTime(_Symbol, PERIOD_M1, 0);
   if(currentM1Time != m_lastM1BarTime)
   {
      m_lastM1BarTime = currentM1Time;
      if(InpSelectedTrail != TRAIL_NONE)
         HandleTrailing();
   }

   // Primary Bar-Closed logic
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   // Wake up indicator signal if applicable
   if(m_handleSnR != INVALID_HANDLE)
   {
      double dummyVal[];
      CopyBuffer(m_handleSnR, 0, 0, 1, dummyVal);
   }

   DefineRanges();

   if(currentBarTime == m_lastBarTime) return;
   m_lastBarTime = currentBarTime;

   HandleSnRRejections();

   if(EnableTrade() && PositionsTotal() < InpMaxPositions)
   {
      double adxVal[];
      ArraySetAsSeries(adxVal, true);
      if(CopyBuffer(m_handleAdx, 0, 1, 1, adxVal) > 0)
      {
         if(CheckAdx(adxVal[0]))
            TradeIfAble();
      }
   }
}

//+------------------------------------------------------------------+
//| Range Initialization Functions                                   |
//+------------------------------------------------------------------+
void InitializeHistoricalRange()
{
   int totalBars = iBars(_Symbol, _Period);
   for(int i = totalBars - 1; i >= InpLookbackBars; i--)
   {
      datetime barTime = iTime(_Symbol, _Period, i);
      MqlDateTime dt;
      TimeToStruct(barTime, dt);

      if(dt.hour == InpStartTime && dt.min == InpOpenRangeMin)
      {
         m_p1Index = i - InpLookbackBars;
         m_p1Price = iOpen(_Symbol, _Period, m_p1Index);
         m_openHigh = iHigh(_Symbol, _Period, i - 1);
         m_openLow = iLow(_Symbol, _Period, i - 1);

         for(int j = 2; j <= InpLookbackBars; j++)
         {
            m_openHigh = MathMax(m_openHigh, iHigh(_Symbol, _Period, i - j));
            m_openLow = MathMin(m_openLow, iLow(_Symbol, _Period, i - j));
         }

         m_p4Index = i - 1;
         m_p4Price = (m_openHigh + m_openLow) / 2.0;
         break;
      }
   }
}

void DefineRanges()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.hour == InpStartTime && dt.min == InpOpenRangeMin)
   {
      int totalBars = iBars(_Symbol, _Period);
      m_p1Index = totalBars - InpLookbackBars;
      m_p1Price = iOpen(_Symbol, _Period, InpLookbackBars);
      m_openHigh = iHigh(_Symbol, _Period, 1);
      m_openLow = iLow(_Symbol, _Period, 1);

      for(int i = 2; i <= InpLookbackBars; i++)
      {
         m_openHigh = MathMax(m_openHigh, iHigh(_Symbol, _Period, i));
         m_openLow = MathMin(m_openLow, iLow(_Symbol, _Period, i));
      }

      m_p4Index = totalBars - 1;
      m_p4Price = (m_openHigh + m_openLow) / 2.0;
   }
}

//+------------------------------------------------------------------+
//| Rejection & Trailing Management                                  |
//+------------------------------------------------------------------+
void HandleSnRRejections()
{
   if(m_handleSnR == INVALID_HANDLE || iBars(_Symbol, _Period) < 3) return;

   double currHigh = iHigh(_Symbol, _Period, 1);
   double currLow = iLow(_Symbol, _Period, 1);
   double currClose = iClose(_Symbol, _Period, 1);
   double prevClose = iClose(_Symbol, _Period, 2);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpOrderMagic)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double grossProfit = PositionGetDouble(POSITION_PROFIT);

         double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRisk / 100.0);
         if(riskAmount > InpMaxDollarRisk) riskAmount = InpMaxDollarRisk;

         if(grossProfit <= 0) continue;

         // Read signals from Dynamic S&R buffer if available
         bool rejMinor = false, rejMid = false, rejMajor = false;
         double bufferMinor[], bufferMid[], bufferMajor[];
         if(CopyBuffer(m_handleSnR, 1, 1, 1, bufferMinor) > 0) rejMinor = (bufferMinor[0] > 0);
         if(CopyBuffer(m_handleSnR, 2, 1, 1, bufferMid) > 0) rejMid = (bufferMid[0] > 0);
         if(CopyBuffer(m_handleSnR, 3, 1, 1, bufferMajor) > 0) rejMajor = (bufferMajor[0] > 0);

         bool shouldClose = false;
         if(grossProfit >= riskAmount * 9)
         {
            if(rejMajor) shouldClose = true;
         }
         else if(grossProfit >= riskAmount * 6)
         {
            if(rejMajor || rejMid) shouldClose = true;
         }
         else if(grossProfit >= riskAmount * 3)
         {
            if(rejMajor || rejMid || rejMinor) shouldClose = true;
         }

         if(shouldClose)
         {
            PrintFormat("[Management] Rejection detected. Closing position #%I64u", ticket);
            m_trade.PositionClose(ticket);
         }
      }
   }
}

void HandleTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpOrderMagic)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);

         double nSL = 0.0;
         bool hasNewSL = false;

         if(InpSelectedTrail == TRAIL_PSAR)
         {
            double psar[];
            if(CopyBuffer(m_handlePsar, 0, 0, 1, psar) > 0) { nSL = psar[0]; hasNewSL = true; }
         }
         else if(InpSelectedTrail == TRAIL_MTF_EMA)
         {
            double ema[];
            if(CopyBuffer(m_handleTrailEma, 0, 0, 1, ema) > 0) { nSL = ema[0]; hasNewSL = true; }
         }
         else if(InpSelectedTrail == TRAIL_EXTREMA)
         {
            if(type == POSITION_TYPE_BUY)
               nSL = iLow(_Symbol, InpTrailTF, iLowest(_Symbol, InpTrailTF, MODE_LOW, InpExtremaBars, 0));
            else
               nSL = iHigh(_Symbol, InpTrailTF, iHighest(_Symbol, InpTrailTF, MODE_HIGH, InpExtremaBars, 0));
            hasNewSL = true;
         }
         else if(InpSelectedTrail == TRAIL_CHANDELIER)
         {
            double atr[];
            if(CopyBuffer(m_handleChandelierAtr, 0, 0, 1, atr) > 0)
            {
               int entryBar = iBarShift(_Symbol, InpTrailTF, entryTime);
               int count = MathMax(1, entryBar);
               if(type == POSITION_TYPE_BUY)
               {
                  double maxH = iHigh(_Symbol, InpTrailTF, iHighest(_Symbol, InpTrailTF, MODE_HIGH, count, 0));
                  nSL = maxH - (atr[0] * InpChandelierMult);
               }
               else
               {
                  double minL = iLow(_Symbol, InpTrailTF, iLowest(_Symbol, InpTrailTF, MODE_LOW, count, 0));
                  nSL = minL + (atr[0] * InpChandelierMult);
               }
               hasNewSL = true;
            }
         }

         if(hasNewSL && nSL > 0.0)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            if(type == POSITION_TYPE_BUY && nSL > currentSL && nSL < bid)
               m_trade.PositionModify(ticket, nSL, currentTP);
            else if(type == POSITION_TYPE_SELL && (nSL < currentSL || currentSL == 0.0) && nSL > ask)
               m_trade.PositionModify(ticket, nSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Execution Logic                                            |
//+------------------------------------------------------------------+
void TradeIfAble()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPips = (ask - bid) / GetPipSize();

   if(spreadPips > InpMaxSpread) return;

   double atrShort[], atrLong[];
   ArraySetAsSeries(atrShort, true);
   ArraySetAsSeries(atrLong, true);

   if(CopyBuffer(m_handleAtrShort, 0, 1, 1, atrShort) <= 0 || CopyBuffer(m_handleAtrLong, 0, 1, 1, atrLong) <= 0) return;
   if(atrShort[0] < (atrLong[0] * InpMinVolatilityRatio)) return;

   double close1 = iClose(_Symbol, _Period, 1);
   double open1 = iOpen(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);

   double totR = high1 - low1;
   if(totR > (atrShort[0] * InpMaxCandleAtrMult)) return;

   double emaVals[];
   ArraySetAsSeries(emaVals, true);
   if(CopyBuffer(m_handleEma, 0, 0, 2, emaVals) <= 0) return;

   bool maB = (InpMaLogic == MA_MODE_PRICE_ABOVE_BELOW) ? (close1 > emaVals[0]) : (emaVals[0] > emaVals[1]);
   bool maS = (InpMaLogic == MA_MODE_PRICE_ABOVE_BELOW) ? (close1 < emaVals[0]) : (emaVals[0] < emaVals[1]);

   double rsiVals[];
   ArraySetAsSeries(rsiVals, true);
   if(CopyBuffer(m_handleRsi, 0, 1, 1, rsiVals) <= 0) return;
   double rsiVal = rsiVals[0];

   bool rsiLong = (!InpRSIHiLo && rsiVal > InpRSIVal) || 
                  (InpRSIHiLo && rsiVal > InpRSIVal && rsiVal < (100 - InpRSIVal)) || 
                  (InpRSIReverse && rsiVal < InpRSIVal);

   bool rsiShort = (!InpRSIHiLo && rsiVal < (100 - InpRSIVal)) || 
                   (InpRSIHiLo && rsiVal < (100 - InpRSIVal) && rsiVal > InpRSIVal) || 
                   (InpRSIReverse && rsiVal > (100 - InpRSIVal));

   if(open1 >= m_openLow && open1 <= m_openHigh)
   {
      if(close1 > m_openHigh && maB && rsiLong) ProcessEntry(POSITION_TYPE_BUY);
      else if(close1 < m_openLow && maS && rsiShort) ProcessEntry(POSITION_TYPE_SELL);
   }
}

void ProcessEntry(ENUM_POSITION_TYPE type)
{
   double entryPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double atrVals[];
   ArraySetAsSeries(atrVals, true);
   if(CopyBuffer(m_handleAtrShort, 0, 1, 1, atrVals) <= 0) return;
   double atrVal = atrVals[0];

   double tier1SL = (type == POSITION_TYPE_BUY) ? m_openLow - (atrVal * InpAtrBufferMult) : m_openHigh + (atrVal * InpAtrBufferMult);
   double tier2SL = (type == POSITION_TYPE_BUY) ? m_openLow : m_openHigh;

   double slPips1 = MathAbs(entryPrice - tier1SL) / GetPipSize();
   double slPips2 = MathAbs(entryPrice - tier2SL) / GetPipSize();

   double finalSL = 0.0;
   if(CalculateRisk(slPips1) <= InpMaxDollarRisk)
      finalSL = tier1SL;
   else if(CalculateRisk(slPips2) <= InpMaxDollarRisk)
      finalSL = tier2SL;

   if(finalSL == 0.0) return;

   double lotSize = LotCalc(InpRisk, MathAbs(entryPrice - finalSL));
   ExecuteByMode(type, lotSize, finalSL);
}

void ExecuteByMode(ENUM_POSITION_TYPE type, double volume, double sl)
{
   double entry = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tpPrice = CalculateTPWithOverride(type, entry, sl);

   double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(InpSelectedTpMode == TP_MODE_TRAILING_ONLY)
   {
      if(type == POSITION_TYPE_BUY) m_trade.Buy(volume, _Symbol, entry, sl, 0.0, m_label);
      else m_trade.Sell(volume, _Symbol, entry, sl, 0.0, m_label);
   }
   else if(InpSelectedTpMode == TP_MODE_HALF_AND_HALF)
   {
      double halfVol = MathFloor((volume / 2.0) / volStep) * volStep;
      if(halfVol < volStep)
      {
         if(type == POSITION_TYPE_BUY) m_trade.Buy(volume, _Symbol, entry, sl, tpPrice, m_label);
         else m_trade.Sell(volume, _Symbol, entry, sl, tpPrice, m_label);
      }
      else
      {
         if(type == POSITION_TYPE_BUY)
         {
            m_trade.Buy(volume - halfVol, _Symbol, entry, sl, tpPrice, m_label);
            m_trade.Buy(halfVol, _Symbol, entry, sl, 0.0, m_label);
         }
         else
         {
            m_trade.Sell(volume - halfVol, _Symbol, entry, sl, tpPrice, m_label);
            m_trade.Sell(halfVol, _Symbol, entry, sl, 0.0, m_label);
         }
      }
   }
   else
   {
      if(type == POSITION_TYPE_BUY) m_trade.Buy(volume, _Symbol, entry, sl, tpPrice, m_label);
      else m_trade.Sell(volume, _Symbol, entry, sl, tpPrice, m_label);
   }
}

//+------------------------------------------------------------------+
//| Calculations & Utilities                                         |
//+------------------------------------------------------------------+
double CalculateTPWithOverride(ENUM_POSITION_TYPE type, double entry, double sl)
{
   double baseTP = 0.0;

   switch(InpSelectedTpMode)
   {
      case TP_MODE_FIXED:
      case TP_MODE_HALF_AND_HALF:
         baseTP = (type == POSITION_TYPE_BUY) ? entry + (MathAbs(entry - sl) * InpRRRatioLong) : entry - (MathAbs(entry - sl) * InpRRRatioShort);
         break;

      case TP_MODE_PIVOT_POINTS:
      {
         double h = iHigh(_Symbol, PERIOD_D1, 1);
         double l = iLow(_Symbol, PERIOD_D1, 1);
         double c = iClose(_Symbol, PERIOD_D1, 1);
         double pivot = (h + l + c) / 3.0;

         if(type == POSITION_TYPE_BUY)
            baseTP = (InpPivotLevel == 1) ? (2.0 * pivot) - l : ((InpPivotLevel == 2) ? pivot + (h - l) : h + 2.0 * (pivot - l));
         else
            baseTP = (InpPivotLevel == 1) ? (2.0 * pivot) - h : ((InpPivotLevel == 2) ? pivot - (h - l) : l - 2.0 * (h - pivot));
         break;
      }

      case TP_MODE_SESSION_EXTREMA:
      {
         if(type == POSITION_TYPE_BUY)
            baseTP = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, InpExtremaLookbackDays, 1));
         else
            baseTP = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, InpExtremaLookbackDays, 1));
         break;
      }
   }

   if(InpUseWolfeOverride)
   {
      double slope = (m_p4Price - m_p1Price) / (double)MathMax(1, m_p4Index - m_p1Index);
      double wolfeEPA = m_p4Price + (slope * 5.0);

      double evalTP = (baseTP != 0.0) ? baseTP : entry;
      if(type == POSITION_TYPE_BUY && wolfeEPA > evalTP) return wolfeEPA;
      if(type == POSITION_TYPE_SELL && wolfeEPA < evalTP) return wolfeEPA;
   }

   return baseTP;
}

double GetPipSize()
{
   return (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point;
}

double GetPipDist(double entry, double tp)
{
   return (tp > 0.0) ? NormalizeDouble(MathAbs(tp - entry) / GetPipSize(), 1) : 0.0;
}

bool IsHoliday(datetime currentTime)
{
   if(!InpEnableHolidayBlackout) return false;

   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   int m = dt.mon;
   int d = dt.day;

   if(InpBlackoutStartMonth <= InpBlackoutEndMonth)
   {
      datetime start = StructToTime(dt); // construct date
      MqlDateTime startDt = dt, endDt = dt;
      startDt.mon = InpBlackoutStartMonth; startDt.day = InpBlackoutStartDay; startDt.hour=0; startDt.min=0; startDt.sec=0;
      endDt.mon = InpBlackoutEndMonth; endDt.day = InpBlackoutEndDay; endDt.hour=23; endDt.min=59; endDt.sec=59;
      
      datetime startTime = StructToTime(startDt);
      datetime endTime = StructToTime(endDt);
      return (currentTime >= startTime && currentTime <= endTime);
   }
   else
   {
      bool isAfterStart = (m > InpBlackoutStartMonth) || (m == InpBlackoutStartMonth && d >= InpBlackoutStartDay);
      bool isBeforeEnd  = (m < InpBlackoutEndMonth) || (m == InpBlackoutEndMonth && d <= InpBlackoutEndDay);
      return (isAfterStart || isBeforeEnd);
   }
}

bool CheckAdx(double val)
{
   switch(InpAdxMode)
   {
      case ADX_MODE_MIN: return val >= InpAdxMin;
      case ADX_MODE_MAX: return val <= InpAdxMax;
      case ADX_MODE_MIN_MAX: return (val >= InpAdxMin && val <= InpAdxMax);
      default: return true;
   }
}

bool EnableTrade()
{
   return (!HasOpenPositionsForLabel() && AfterStart() && m_openHigh != 0.0 && !IsHoliday(TimeCurrent()));
}

bool AfterStart()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int nHour = dt.hour;

   return (InpStartTime < InpEndTime) ? 
          (nHour >= InpStartTime && nHour < InpEndTime) : 
          !(nHour >= InpEndTime && nHour < InpStartTime);
}

bool HasOpenPositionsForLabel()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpOrderMagic)
         return true;
   }
   return false;
}

double CalculateRisk(double pips)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double pipSize = GetPipSize();

   double lot = LotCalc(InpRisk, pips * pipSize);
   return (pips * pipSize / tickSize) * tickValue * lot;
}

double LotCalc(double riskPercent, double slDistance)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPercent / 100.0;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double moneyPerStep = (slDistance / tickSize) * tickValue * volStep;
   if(moneyPerStep == 0.0) return minVol;

   double lots = MathFloor(riskMoney / moneyPerStep) * volStep;
   lots = MathMax(minVol, MathMin(volStep * 1000.0, lots));

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Custom Optimization Fitness Calculation                          |
//+------------------------------------------------------------------+
double OnTester()
{
   double netProfit = TesterStatistics(STAT_PROFIT);
   if(netProfit <= 0) return netProfit;

   int totalTrades = (int)TesterStatistics(STAT_TRADES);
   int winningTrades = (int)TesterStatistics(STAT_PROFIT_TRADES);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double maxDrawdown = TesterStatistics(STAT_EQUITY_DD);
   double maxDrawdownPct = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);

   // Reconstruct equity curve linear regression R^2
   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cumProfit = 0;
   int count = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         cumProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         sumX += count;
         sumY += cumProfit;
         sumXY += count * cumProfit;
         sumX2 += count * count;
         sumY2 += cumProfit * cumProfit;
         count++;
      }
   }

   if(count <= 1) return netProfit;

   double numerator = (count * sumXY) - (sumX * sumY);
   double denominator = MathSqrt(((count * sumX2) - (sumX * sumX)) * ((count * sumY2) - (sumY * sumY)));
   double r2 = (denominator != 0) ? MathPow(numerator / denominator, 2.0) : 0.0;

   double winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades : 0.0;
   double baseMetric = ((profitFactor * (netProfit / MathMax(1.0, maxDrawdown)) * winRate * r2) * MathLog10(totalTrades)) / MathMax(0.1, maxDrawdownPct);
   double returnRatio = netProfit / MathMax(1.0, m_startingBalance);

   if(maxDrawdownPct >= 5.0 && maxDrawdownPct < 10.0)
      return baseMetric * returnRatio * r2 * 0.5;
   else if(maxDrawdownPct >= 10.0)
      return (baseMetric * returnRatio * r2) / maxDrawdownPct;
   else if(totalTrades <= InpMinTrades)
      return (baseMetric * returnRatio * r2) * ((double)totalTrades / InpMinTrades);
   else if(totalTrades > InpMinTrades && InpLinBon)
      return baseMetric * returnRatio * r2 * (1.0 + ((double)(totalTrades - InpMinTrades) / InpMinTrades / InpLinDiv));
   else
      return baseMetric * returnRatio * r2 * (1.0 + (MathPow(totalTrades - InpMinTrades, InpHypExp) / InpMinTrades));
}