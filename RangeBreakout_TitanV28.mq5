//+------------------------------------------------------------------+
//|                                     RangeBreakout_TitanV28.mq5   |
//|                                  Copyright 2026, Quant Strategy  |
//+------------------------------------------------------------------+
#property copyright "Quant Strategy"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>

// --- ENUMS ---
enum ENUM_TP_MODE { TP_MODE_FIXED, TP_MODE_HALF_AND_HALF, TP_MODE_TRAILING_ONLY, TP_MODE_PIVOT_POINTS, TP_MODE_SESSION_EXTREMA };
enum ENUM_MA_MODE { MA_MODE_PRICE_ABOVE_BELOW, MA_MODE_SLOPE_RISING_FALLING };
enum ENUM_ADX_MODE { ADX_MODE_OFF, ADX_MODE_MIN, ADX_MODE_MAX, ADX_MODE_MIN_MAX };
enum ENUM_TRAIL_TYPE { TRAIL_NONE, TRAIL_PSAR, TRAIL_MTF_EMA, TRAIL_EXTREMA, TRAIL_CHANDELIER };
enum ENUM_REJECTION_MODE { REJ_WICK_INSIDE_CLOSE_OUTSIDE, REJ_CLOSE_OUTSIDE_WICK_OUTSIDE };

// --- INPUT PARAMETERS ---

input group "1. Arbitrary Time & Range"
input int               InpStartHour          = 9;         // Range Start (Hour: 0-23)
input int               InpStartMinute        = 30;        // Range Start (Minute: 0-59)
input int               InpRangeDurationMins  = 60;        // Range Duration (Mins)
input int               InpTradeDurationMins  = 180;       // Max Trade Wait After Range (Mins)

input group "2. Range & Candle Volatility Bounds"
input double            InpMinRangeAtrMult    = 0.5;       // Min Range Width (ATR Mult)
input double            InpMaxRangeAtrMult    = 3.0;       // Max Range Width (ATR Mult)
input double            InpMaxCandleAtrMult   = 1.5;       // Max Breakout Candle Size (ATR Mult)
input double            InpMinBodyRatio       = 0.50;      // Min Breakout Body/Total Ratio
input double            InpMaxRejectionWick   = 0.25;      // Max Breakout Rejection Wick Ratio
input double            InpBreakoutBufferAtr  = 0.1;       // Buffer line outside range (ATR Mult)

input group "3. Calculus (Kinematics)"
input bool              InpUseKinematics      = true;      // Enable Calculus Filters
input int               InpCalcMALookback     = 20;        // Kinematics MA Period
input int               InpCalcDeltaBars      = 3;         // Delta T (Bars for Derivative dt)
input bool              InpRequireVelocity    = true;      // Require Velocity > 0 (1st Deriv)
input bool              InpRequireAccel       = false;     // Require Acceleration > 0 (2nd Deriv)

input group "4. Trend Directional Bias"
input int               InpFastMALookback     = 50;        // Fast Trend MA (0 = Off)
input int               InpSlowMALookback     = 200;       // Slow Trend MA (0 = Off)

input group "5. Strategy & Risk"
input double            InpRisk               = 1.0;       // Risk Percentage
input double            InpMaxDollarRisk      = 1000.0;    // Max Dollar Risk
input double            InpAtrBufferMult      = 0.5;       // SL ATR Buffer Mult
input double            InpRRRatioLong        = 2.0;       
input double            InpRRRatioShort       = 2.0;       
input ENUM_TP_MODE      InpSelectedTpMode     = TP_MODE_HALF_AND_HALF;
input int               InpPivotLevel         = 2;         
input int               InpExtremaLookbackDays= 3;         
input bool              InpUseWolfeOverride   = true;      

input group "6. Core Indicators"
input int               InpMALookback         = 150;       // Primary MA Lookback
input ENUM_MA_MODE      InpMaLogic            = MA_MODE_PRICE_ABOVE_BELOW;
input int               InpRSIVal             = 25;        
input bool              InpRSIHiLo            = true;      
input bool              InpRSIReverse         = false;     
input ENUM_ADX_MODE     InpAdxMode            = ADX_MODE_MIN_MAX;
input int               InpAdxPeriod          = 14;        
input double            InpAdxMin             = 15.0;      
input double            InpAdxMax             = 35.0;      

input group "7. Filters & Environment"
input double            InpMaxSpread          = 45.0;      
input double            InpMinVolatilityRatio = 0.7;       // Min Volatility Ratio (Short/Long ATR)
input int               InpAtrPeriod          = 14;        
input int               InpAtrLongPeriod      = 100;       
input bool              InpEnableHolidayBlackout = true;   
input int               InpBlackoutStartMonth = 12;        
input int               InpBlackoutStartDay   = 20;        
input int               InpBlackoutEndMonth   = 1;         
input int               InpBlackoutEndDay     = 5;         

input group "8. Management & Trailing"
input ENUM_TRAIL_TYPE   InpSelectedTrail      = TRAIL_NONE; 
input ENUM_TIMEFRAMES   InpTrailTF            = PERIOD_H1;  
input int               InpEmaTrailPeriod     = 49;        
input int               InpExtremaBars        = 6;         
input double            InpPsarMinAF          = 0.02;      
input double            InpPsarMaxAF          = 0.2;       
input double            InpChandelierMult     = 3.0;       
input int               InpMaxPositions       = 1;         
input ulong             InpOrderMagic         = 8888;      

input group "9. Optimizer Fitness"
input int               InpMinTrades          = 75;        
input bool              InpLinBon             = false;     
input int               InpLinDiv             = 3;         
input double            InpHypExp             = 0.75;      

// --- GLOBAL VARIABLES ---
CTrade        m_trade;
double        m_openHigh = 0.0, m_openLow = 0.0;
double        m_p1Price = 0.0, m_p4Price = 0.0;
int           m_p1Index = 0, m_p4Index = 0;
datetime      m_lastBarTime = 0;
datetime      m_lastM1BarTime = 0;
datetime      m_rangeStartTime = 0;
bool          m_rangeValid = false;
double        m_startingBalance = 0.0;
string        m_label;

int           m_handleEma = INVALID_HANDLE;
int           m_handleRsi = INVALID_HANDLE;
int           m_handleAtrShort = INVALID_HANDLE;
int           m_handleAtrLong = INVALID_HANDLE;
int           m_handleAdx = INVALID_HANDLE;
int           m_handleCalcMA = INVALID_HANDLE;
int           m_handleFastMA = INVALID_HANDLE;
int           m_handleSlowMA = INVALID_HANDLE;
// (Include SnR, Trail handles as per original setup)

//+------------------------------------------------------------------+
int OnInit()
{
   m_label = "RB_Titan_" + IntegerToString(InpOrderMagic);
   m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_trade.SetExpertMagicNumber(InpOrderMagic);

   m_handleEma = iMA(_Symbol, _Period, InpMALookback, 0, MODE_EMA, PRICE_CLOSE);
   m_handleRsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   m_handleAtrShort = iATR(_Symbol, _Period, InpAtrPeriod);
   m_handleAtrLong = iATR(_Symbol, _Period, InpAtrLongPeriod);
   m_handleAdx = iADX(_Symbol, _Period, InpAdxPeriod);

   if(InpCalcMALookback > 0) m_handleCalcMA = iMA(_Symbol, _Period, InpCalcMALookback, 0, MODE_EMA, PRICE_CLOSE);
   if(InpFastMALookback > 0) m_handleFastMA = iMA(_Symbol, _Period, InpFastMALookback, 0, MODE_EMA, PRICE_CLOSE);
   if(InpSlowMALookback > 0) m_handleSlowMA = iMA(_Symbol, _Period, InpSlowMALookback, 0, MODE_EMA, PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(m_handleEma != INVALID_HANDLE) IndicatorRelease(m_handleEma);
   if(m_handleRsi != INVALID_HANDLE) IndicatorRelease(m_handleRsi);
   if(m_handleAtrShort != INVALID_HANDLE) IndicatorRelease(m_handleAtrShort);
   if(m_handleAtrLong != INVALID_HANDLE) IndicatorRelease(m_handleAtrLong);
   if(m_handleAdx != INVALID_HANDLE) IndicatorRelease(m_handleAdx);
   if(m_handleCalcMA != INVALID_HANDLE) IndicatorRelease(m_handleCalcMA);
   if(m_handleFastMA != INVALID_HANDLE) IndicatorRelease(m_handleFastMA);
   if(m_handleSlowMA != INVALID_HANDLE) IndicatorRelease(m_handleSlowMA);
}

void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   DefineRanges(); // Define Temporal Box dynamically on every tick

   if(currentBarTime == m_lastBarTime) return; // Process primary logic strictly on Bar Close
   m_lastBarTime = currentBarTime;

   if(EnableTrade() && PositionsTotal() < InpMaxPositions)
   {
      TradeIfAble();
   }
}

//+------------------------------------------------------------------+
//| 1. Dynamic Arbitrary Temporal Engine                             |
//+------------------------------------------------------------------+
void DefineRanges()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   MqlDateTime dt; TimeToStruct(currentBarTime, dt);
   
   MqlDateTime startDt = dt;
   startDt.hour = InpStartHour;
   startDt.min = InpStartMinute;
   startDt.sec = 0;
   
   datetime rangeStart = StructToTime(startDt);
   if(rangeStart > currentBarTime) rangeStart -= 86400; // Look at yesterday if today's window hasn't arrived
   
   datetime rangeEnd = rangeStart + (InpRangeDurationMins * 60);
   datetime tradeEnd = rangeEnd + (InpTradeDurationMins * 60);
   
   if(currentBarTime >= rangeEnd && currentBarTime <= tradeEnd)
   {
      if(m_rangeStartTime != rangeStart) // Calculate bounds exactly once per window
      {
         int startBar = iBarShift(_Symbol, _Period, rangeStart);
         int endBar = iBarShift(_Symbol, _Period, rangeEnd);
         
         if(startBar >= 0 && endBar >= 0 && startBar >= endBar)
         {
            int count = startBar - endBar + 1;
            int highestIdx = iHighest(_Symbol, _Period, MODE_HIGH, count, endBar);
            int lowestIdx  = iLowest(_Symbol, _Period, MODE_LOW, count, endBar);
            
            if(highestIdx >= 0 && lowestIdx >= 0)
            {
               m_openHigh = iHigh(_Symbol, _Period, highestIdx);
               m_openLow  = iLow(_Symbol, _Period, lowestIdx);
               m_p4Price  = (m_openHigh + m_openLow) / 2.0;
               m_p1Price  = iOpen(_Symbol, _Period, startBar);
               m_p1Index  = startBar;
               m_p4Index  = endBar;
               
               m_rangeStartTime = rangeStart;
               m_rangeValid = true;
            }
         }
      }
   }
   else m_rangeValid = false; // Outside trade window
}

//+------------------------------------------------------------------+
//| 2. The Kitchen Sink Breakout Gauntlet                            |
//+------------------------------------------------------------------+
void TradeIfAble()
{
   if(!m_rangeValid) return; 

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(((ask - bid) / GetPipSize()) > InpMaxSpread) return;

   // 1. Goldilocks Range Quality & Volatility Base
   double atrShort[], atrLong[];
   ArraySetAsSeries(atrShort, true); ArraySetAsSeries(atrLong, true);
   if(CopyBuffer(m_handleAtrShort, 0, 1, 1, atrShort) <= 0 || CopyBuffer(m_handleAtrLong, 0, 1, 1, atrLong) <= 0) return;
   
   double atr = atrShort[0];
   if(atr < (atrLong[0] * InpMinVolatilityRatio)) return; // Macro dead market
   
   double rangeWidth = m_openHigh - m_openLow;
   if(rangeWidth < (atr * InpMinRangeAtrMult) || rangeWidth > (atr * InpMaxRangeAtrMult)) return; // Too tight or exhausted

   // 2. Breakout Candle Anatomy (Commitment)
   double close1 = iClose(_Symbol, _Period, 1), open1  = iOpen(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol, _Period, 1), low1   = iLow(_Symbol, _Period, 1);

   double cRange = high1 - low1;
   if(cRange == 0 || cRange > (atr * InpMaxCandleAtrMult)) return; // Prevent FOMO on massive exhaustion spikes

   double cBody = MathAbs(close1 - open1);
   if((cBody / cRange) < InpMinBodyRatio) return; // Prevent entering on indecision (Dojis)
   
   // 3. Directional Bias Alignment
   bool trendBull = true, trendBear = true;
   if(m_handleFastMA != INVALID_HANDLE && m_handleSlowMA != INVALID_HANDLE)
   {
      double fMa[], sMa[]; ArraySetAsSeries(fMa, true); ArraySetAsSeries(sMa, true);
      if(CopyBuffer(m_handleFastMA, 0, 1, 1, fMa) > 0 && CopyBuffer(m_handleSlowMA, 0, 1, 1, sMa) > 0)
      {
         trendBull = fMa[0] > sMa[0];
         trendBear = fMa[0] < sMa[0];
      }
   }

   // 4. Kinematics (Calculus of Momentum)
   bool kinBull = true, kinBear = true;
   if(InpUseKinematics && m_handleCalcMA != INVALID_HANDLE)
   {
      double calcMA[]; ArraySetAsSeries(calcMA, true);
      if(CopyBuffer(m_handleCalcMA, 0, 1, InpCalcDeltaBars * 2 + 1, calcMA) > 0)
      {
         double v1 = calcMA[0] - calcMA[InpCalcDeltaBars]; // Current Velocity
         double v2 = calcMA[InpCalcDeltaBars] - calcMA[InpCalcDeltaBars * 2]; // Previous Velocity
         double accel = v1 - v2; // Acceleration (Change in velocity)
         
         kinBull = (!InpRequireVelocity || v1 > 0) && (!InpRequireAccel || accel > 0);
         kinBear = (!InpRequireVelocity || v1 < 0) && (!InpRequireAccel || accel < 0);
      }
   }

   // 5. Traditional Confluences
   double adxVal[]; ArraySetAsSeries(adxVal, true);
   if(CopyBuffer(m_handleAdx, 0, 1, 1, adxVal) > 0 && !CheckAdx(adxVal[0])) return;
   
   double emaVals[]; ArraySetAsSeries(emaVals, true);
   if(CopyBuffer(m_handleEma, 0, 1, 2, emaVals) <= 0) return; 
   bool maB = (InpMaLogic == MA_MODE_PRICE_ABOVE_BELOW) ? (close1 > emaVals[0]) : (emaVals[0] > emaVals[1]);
   bool maS = (InpMaLogic == MA_MODE_PRICE_ABOVE_BELOW) ? (close1 < emaVals[0]) : (emaVals[0] < emaVals[1]);

   // 6. Trigger Execution Gauntlet
   double buffer = atr * InpBreakoutBufferAtr;
   
   // Breakout criteria: Open must be inside/near range, Close must clear the buffer threshold
   bool brokeLong  = (close1 > m_openHigh + buffer) && (open1 <= m_openHigh + buffer); 
   bool brokeShort = (close1 < m_openLow - buffer)  && (open1 >= m_openLow - buffer);

   if(brokeLong && maB && trendBull && kinBull)
   {
      double topWick = high1 - MathMax(open1, close1);
      if((topWick / cRange) <= InpMaxRejectionWick) ProcessEntry(POSITION_TYPE_BUY);
   }
   else if(brokeShort && maS && trendBear && kinBear)
   {
      double botWick = MathMin(open1, close1) - low1;
      if((botWick / cRange) <= InpMaxRejectionWick) ProcessEntry(POSITION_TYPE_SELL);
   }
}

//+------------------------------------------------------------------+
//| Core Utilities & Entry Processing                                |
//+------------------------------------------------------------------+
void ProcessEntry(ENUM_POSITION_TYPE type)
{
   double entryPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVals[]; ArraySetAsSeries(atrVals, true);
   if(CopyBuffer(m_handleAtrShort, 0, 1, 1, atrVals) <= 0) return;
   
   double tierSL = (type == POSITION_TYPE_BUY) ? m_openLow - (atrVals[0] * InpAtrBufferMult) : m_openHigh + (atrVals[0] * InpAtrBufferMult);
   
   double slDist = MathAbs(entryPrice - tierSL);
   double lotSize = LotCalc(InpRisk, slDist);
   
   ExecuteByMode(type, lotSize, tierSL);
}

void ExecuteByMode(ENUM_POSITION_TYPE type, double volume, double sl)
{
   double entry = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tpPrice = (type == POSITION_TYPE_BUY) ? entry + (MathAbs(entry - sl) * InpRRRatioLong) : entry - (MathAbs(entry - sl) * InpRRRatioShort);

   if(type == POSITION_TYPE_BUY) m_trade.Buy(volume, _Symbol, entry, sl, tpPrice, m_label);
   else m_trade.Sell(volume, _Symbol, entry, sl, tpPrice, m_label);
}

bool EnableTrade() { return (!HasOpenPositionsForLabel() && m_rangeValid && m_openHigh != 0.0); }
bool HasOpenPositionsForLabel() { for(int i = PositionsTotal() - 1; i >= 0; i--) { if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpOrderMagic) return true; } return false; }
bool CheckAdx(double val) { switch(InpAdxMode) { case ADX_MODE_MIN: return val >= InpAdxMin; case ADX_MODE_MAX: return val <= InpAdxMax; case ADX_MODE_MIN_MAX: return (val >= InpAdxMin && val <= InpAdxMax); default: return true; } }
double GetPipSize() { return (_Digits == 3 || _Digits == 5) ? _Point * 10.0 : _Point; }
double LotCalc(double riskPercent, double slDistance)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;
   double moneyPerStep = (slDistance / tickSize) * tickValue * volStep;
   if(moneyPerStep == 0.0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lots = MathFloor(riskMoney / moneyPerStep) * volStep;
   return MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), lots);
}

//+------------------------------------------------------------------+
//| Custom Optimization Fitness (R-Squared Equity Curve)             |
//+------------------------------------------------------------------+
double OnTester()
{
   double netProfit = TesterStatistics(STAT_PROFIT);
   if(netProfit <= 0) return netProfit;

   int totalTrades = (int)TesterStatistics(STAT_TRADES);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double maxDrawdown = TesterStatistics(STAT_EQUITY_DD);

   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cumProfit = 0;
   int count = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         cumProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         sumX += count; sumY += cumProfit; sumXY += count * cumProfit;
         sumX2 += count * count; sumY2 += cumProfit * cumProfit;
         count++;
      }
   }

   if(count <= 1) return netProfit;

   double num = (count * sumXY) - (sumX * sumY);
   double den = MathSqrt(((count * sumX2) - (sumX * sumX)) * ((count * sumY2) - (sumY * sumY)));
   double r2 = (den != 0) ? MathPow(num / den, 2.0) : 0.0; // R-Squared Linearity

   double baseMetric = (profitFactor * (netProfit / MathMax(1.0, maxDrawdown)) * r2);
   
   // Strangle curve-fitting: Aggressively penalize low trade counts
   if(totalTrades < InpMinTrades) return baseMetric * MathPow((double)totalTrades / InpMinTrades, 2.0);
   return baseMetric * MathLog10(totalTrades);
}