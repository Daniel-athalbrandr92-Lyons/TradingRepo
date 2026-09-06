//+------------------------------------------------------------------+
//|                                                DynamicSnR_EA.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

// ==========================================
// 1. DEFINITIONS AND ENUMS
// ==========================================
enum ENUM_ZONE_TIER 
{
   ZONE_TIER_MINOR,
   ZONE_TIER_MID,
   ZONE_TIER_MAJOR
};

enum ENUM_ZONE_TYPE 
{
   ZONE_ASIAN_HIGH = 0,
   ZONE_ASIAN_LOW,
   ZONE_LONDON_HIGH,
   ZONE_LONDON_LOW,
   ZONE_NY_HIGH,
   ZONE_NY_LOW,
   ZONE_DOUBLE_TOP,
   ZONE_DOUBLE_BOTTOM,
   ZONE_CONSOLIDATION,
   ZONE_MULTIDAY_HIGH,
   ZONE_MULTIDAY_LOW,
   ZONE_DAILY_HIGH,
   ZONE_DAILY_LOW,
   ZONE_PSYCH_LEVEL,
   ZONE_ORDER_BLOCK,
   ZONE_REJECTION,
   ZONE_TYPE_COUNT
};

enum ENUM_REJECTION_MODE 
{
   REJECTION_WICK_INSIDE_CLOSE_OUTSIDE,
   REJECTION_PREV_CLOSE_INSIDE_CURR_CLOSE_OUTSIDE
};

struct Zone 
{
   double top;
   double bottom;
   ENUM_ZONE_TIER tier;
   bool isSet;
};

struct PriceZone 
{
   double high;
   double low;
   int startIndex;
   bool isActive;
   double averageAtr;
};

struct OrderBlock 
{
   double top;
   double bottom;
   int startIndex;
   bool isBullish;
   string name;
};

struct ChartFormation 
{
   double top;
   double bottom;
   int startIndex;
   string name;
};

struct RejectionFormation 
{
   double top;
   double bottom;
   int startIndex;
   string name;
   ENUM_ZONE_TIER tier;
};

// ==========================================
// INPUT PARAMETERS
// ==========================================
//--- Trade Settings
input group "=== Trade Settings ==="
input ulong                InpMagicNumber       = 123456;   // Magic Number
input double               InpLotSize           = 0.1;      // Lot Size
input double               InpSlAtrMult         = 1.5;      // Stop Loss (ATR Multiplier)
input double               InpRiskReward        = 2.0;      // Risk : Reward Ratio
input ENUM_REJECTION_MODE  InpRejectionMode     = REJECTION_WICK_INSIDE_CLOSE_OUTSIDE; // Rejection Trigger Mode
input bool                 InpTradeMinorTiers   = true;     // Trade Minor Tier Signals
input bool                 InpTradeMidTiers     = true;     // Trade Mid Tier Signals
input bool                 InpTradeMajorTiers   = true;     // Trade Major Tier Signals

//--- Visibility / Module Toggles
input group "=== Zone Modules ==="
input bool InpShowMultiday         = true;  // Calculate Multiday H/L
input bool InpShowPreviousDay      = true;  // Calculate Previous Day H/L
input bool InpShowAsianSession     = true;  // Calculate Asian Session
input bool InpShowLondonSession    = true;  // Calculate London Session
input bool InpShowNySession        = true;  // Calculate NY Session
input bool InpShowPsychLevels      = true;  // Calculate Psych Levels
input bool InpShowOrderBlocks       = true;  // Calculate Order Blocks
input bool InpShowDoubleTopsBottoms = true;  // Calculate Double Tops/Bottoms
input bool InpShowConsolidation    = true;  // Calculate Consolidation Zones
input bool InpShowRejections       = true;  // Calculate Rejection Formations

//--- Core Parameters
input group "=== Core Zone Settings ==="
input double InpMacroAtrMultiplier = 0.5;   // Macro ATR Multiplier (Sessions/Psych)
input double InpMicroAtrMultiplier = 0.2;   // Micro ATR Multiplier (Patterns)
input double InpPsychLevelStep     = 25.0;  // Psych Level Step
input int    InpUtcOffset          = -5;    // UTC Offset (Hours)

//--- Multiday Settings
input ENUM_TIMEFRAMES InpMultidayTimeFrame = PERIOD_W1; // Multiday TimeFrame
input int             InpMultidayLookback  = 1;         // Multiday Lookback (Candles)

//--- Session Hours
input group "=== Session Hours ==="
input int InpAsianStartHour  = 18; // Asian Start Hour
input int InpAsianEndHour    = 3;  // Asian End Hour
input int InpLondonStartHour = 3;  // London Start Hour
input int InpLondonEndHour   = 11; // London End Hour
input int InpNyStartHour     = 8;  // NY Start Hour
input int InpNyEndHour       = 17; // NY End Hour

//--- Pattern Rules
input group "=== Pattern Rules ==="
input int    InpMinFormationCandles       = 10;  // Min Formation Candles
input int    InpMaxLookbackCandles        = 50;  // Max Lookback Candles
input double InpMaxConsolidationAtrWidth  = 1.5; // Max Consolidation Width (ATR Mult)

// ==========================================
// GLOBAL VARIABLES
// ==========================================
CTrade trade;
int handleATR;
datetime lastBarTime = 0;

int lastProcessedIndex = -1;
int priorMtfIndex = -1;
int priorDailyIndex = -1;

double tempAsianHigh = -1;
double tempAsianLow = -1;
double tempAsianAtrSum = -1;
int tempAsianCandleCount = -1;

double tempLondonHigh = -1;
double tempLondonLow = -1;
double tempLondonAtrSum = -1;
int tempLondonCandleCount = -1;

double tempNYHigh = -1;
double tempNYLow = -1;
double tempNYAtrSum = -1;
int tempNYCandleCount = -1;

double nearestPsychQuartileAbove;
double nearestPsychQuartileBelow;
double nearestPsychHalfAbove;
double nearestPsychHalfBelow;
double nearestPsychCenturyAbove;
double nearestPsychCenturyBelow;

Zone activeZonesDict[ZONE_TYPE_COUNT];

PriceZone multidayZone;
PriceZone dailyZone;
PriceZone asianZone;
PriceZone londonZone;
PriceZone nyZone;

OrderBlock activeOrderBlocks[];
int obCounter = 0;

ChartFormation activeDoubles[];
int doubleCounter = 0;

ChartFormation activeConsolidations[];
int consolidationCounter = 0;

RejectionFormation activeRejections[];
int rejectionCounter = 0;

int formationCheck;

// Data arrays for EA processing
datetime timeArr[];
double openArr[], highArr[], lowArr[], closeArr[], atrBuffer[];

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   handleATR = iATR(_Symbol, _Period, 14);
   if(handleATR == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator handle.");
      return(INIT_FAILED);
   }

   formationCheck = (int)MathMin(5, InpMinFormationCandles);

   ZeroMemory(multidayZone);
   ZeroMemory(dailyZone);
   ZeroMemory(asianZone);
   ZeroMemory(londonZone);
   ZeroMemory(nyZone);

   asianZone.high = -1;
   asianZone.low = -1;
   londonZone.high = -1;
   londonZone.low = -1;
   nyZone.high = -1;
   nyZone.low = -1;

   for(int i = 0; i < ZONE_TYPE_COUNT; i++)
   {
      activeZonesDict[i].isSet = false;
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return; // Process once per candle close

   int totalBars = iBarShift(_Symbol, _Period, 0) + 1000;
   int fetched = CopyRates(_Symbol, _Period, 0, totalBars, ratesTotal_struct);
   
   int rates_total = CopyTime(_Symbol, _Period, 0, totalBars, timeArr);
   if(rates_total < 50) return;

   CopyOpen(_Symbol, _Period, 0, rates_total, openArr);
   CopyHigh(_Symbol, _Period, 0, rates_total, highArr);
   CopyLow(_Symbol, _Period, 0, rates_total, lowArr);
   CopyClose(_Symbol, _Period, 0, rates_total, closeArr);

   ArraySetAsSeries(timeArr, false);
   ArraySetAsSeries(openArr, false);
   ArraySetAsSeries(highArr, false);
   ArraySetAsSeries(lowArr, false);
   ArraySetAsSeries(closeArr, false);

   if(CopyBuffer(handleATR, 0, 0, rates_total, atrBuffer) <= 0) return;
   ArraySetAsSeries(atrBuffer, false);

   // Update calculations across historical context
   for(int index = 0; index < rates_total; index++)
   {
      if(index == lastProcessedIndex) continue;
      lastProcessedIndex = index;

      if(InpShowAsianSession || InpShowLondonSession || InpShowNySession)
         CalculateSessions(index, timeArr, highArr, lowArr, closeArr);

      if(index % formationCheck == 0)
      {
         if(InpShowMultiday) CalculateMultiday(index, timeArr);
         if(InpShowPreviousDay) CalculateDaily(index, timeArr);
         if(InpShowPsychLevels) CalculatePsychLevels(index, closeArr);

         if(InpShowOrderBlocks) ScanOrderBlocks(index, openArr, highArr, lowArr, closeArr);
         if(InpShowDoubleTopsBottoms) ScanDoubles(index, openArr, highArr, lowArr, closeArr);
         if(InpShowConsolidation) ScanConsolidations(index, openArr, highArr, lowArr, closeArr);
         if(InpShowRejections) ScanRejections(index, openArr, highArr, lowArr, closeArr);
      }
   }

   // Evaluate completed candle (Index = rates_total - 2)
   int completedIdx = rates_total - 2;
   int prevIdx = rates_total - 3;

   if(completedIdx > 0 && prevIdx > 0)
   {
      double currHigh = highArr[completedIdx];
      double currLow = lowArr[completedIdx];
      double currClose = closeArr[completedIdx];
      double prevClose = closeArr[prevIdx];
      double currentAtr = atrBuffer[completedIdx];

      EvaluateTradeSignal(currHigh, currLow, currClose, prevClose, currentAtr);
   }

   lastBarTime = currentBarTime;
}

// MqlRates helper allocation container
MqlRates ratesTotal_struct[];

//+------------------------------------------------------------------+
//| TRADE EXECUTION MODULE                                           |
//+------------------------------------------------------------------+
void EvaluateTradeSignal(double currHigh, double currLow, double currClose, double prevClose, double currentAtr)
{
   if(HasOpenPosition()) return;

   bool buyMinor = false, buyMid = false, buyMajor = false;
   bool sellMinor = false, sellMid = false, sellMajor = false;

   // Check Buy Rejections (0 = Buy)
   CheckRejection(0, currHigh, currLow, currClose, prevClose, InpRejectionMode, buyMinor, buyMid, buyMajor);

   // Check Sell Rejections (1 = Sell)
   CheckRejection(1, currHigh, currLow, currClose, prevClose, InpRejectionMode, sellMinor, sellMid, sellMajor);

   bool executeBuy = (buyMinor && InpTradeMinorTiers) || (buyMid && InpTradeMidTiers) || (buyMajor && InpTradeMajorTiers);
   bool executeSell = (sellMinor && InpTradeMinorTiers) || (sellMid && InpTradeMidTiers) || (sellMajor && InpTradeMajorTiers);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = currentAtr * InpSlAtrMult;

   if(executeBuy)
   {
      double sl = ask - slDistance;
      double tp = ask + (slDistance * InpRiskReward);
      trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Zone Rejection Buy");
   }
   else if(executeSell)
   {
      double sl = bid + slDistance;
      double tp = bid - (slDistance * InpRiskReward);
      trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Zone Rejection Sell");
   }
}

bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS FOR CALCULATIONS                                |
//+------------------------------------------------------------------+
double GetMinLow(const double &low[], int startIdx, int count)
{
   double minVal = DBL_MAX;
   int begin = startIdx - count + 1;
   if(begin < 0) begin = 0;
   for(int k = begin; k <= startIdx; k++)
   {
      if(low[k] < minVal) minVal = low[k];
   }
   return minVal;
}

double GetMaxHigh(const double &high[], int startIdx, int count)
{
   double maxVal = -DBL_MAX;
   int begin = startIdx - count + 1;
   if(begin < 0) begin = 0;
   for(int k = begin; k <= startIdx; k++)
   {
      if(high[k] > maxVal) maxVal = high[k];
   }
   return maxVal;
}

//+------------------------------------------------------------------+
//| CORE MODULES                                                     |
//+------------------------------------------------------------------+
void CalculateMultiday(int index, const datetime &time[])
{
   datetime currentTime = time[index];
   int mtfIndex = iBarShift(_Symbol, InpMultidayTimeFrame, currentTime, false);
   if(mtfIndex < 0) return;

   if(mtfIndex == priorMtfIndex) return;

   if(mtfIndex != priorMtfIndex)
   {
      priorMtfIndex = mtfIndex;
      multidayZone.startIndex = index;
   }

   if(mtfIndex < InpMultidayLookback) return;

   double highest = -DBL_MAX;
   double lowest = DBL_MAX;

   for(int i = 1; i <= InpMultidayLookback; i++)
   {
      double barHigh = iHigh(_Symbol, InpMultidayTimeFrame, mtfIndex + i);
      double barLow = iLow(_Symbol, InpMultidayTimeFrame, mtfIndex + i);

      if(barHigh > highest) highest = barHigh;
      if(barLow < lowest) lowest = barLow;
   }

   multidayZone.high = highest;
   multidayZone.low = lowest;

   double maxSessionAtr = 0;
   if(InpShowAsianSession) maxSessionAtr = MathMax(maxSessionAtr, asianZone.averageAtr);
   if(InpShowLondonSession) maxSessionAtr = MathMax(maxSessionAtr, londonZone.averageAtr);
   if(InpShowNySession) maxSessionAtr = MathMax(maxSessionAtr, nyZone.averageAtr);

   if(maxSessionAtr == 0 || MathIsValidNumber(maxSessionAtr) == false)
   {
      maxSessionAtr = atrBuffer[index];
   }

   multidayZone.averageAtr = maxSessionAtr;

   double atrBufferVal = multidayZone.averageAtr * InpMacroAtrMultiplier;
   activeZonesDict[ZONE_MULTIDAY_HIGH].top = multidayZone.high + atrBufferVal;
   activeZonesDict[ZONE_MULTIDAY_HIGH].bottom = multidayZone.high - atrBufferVal;
   activeZonesDict[ZONE_MULTIDAY_HIGH].tier = ZONE_TIER_MAJOR;
   activeZonesDict[ZONE_MULTIDAY_HIGH].isSet = true;

   activeZonesDict[ZONE_MULTIDAY_LOW].top = multidayZone.low + atrBufferVal;
   activeZonesDict[ZONE_MULTIDAY_LOW].bottom = multidayZone.low - atrBufferVal;
   activeZonesDict[ZONE_MULTIDAY_LOW].tier = ZONE_TIER_MAJOR;
   activeZonesDict[ZONE_MULTIDAY_LOW].isSet = true;
}

void CalculateDaily(int index, const datetime &time[])
{
   datetime currentTime = time[index];
   int dailyIndex = iBarShift(_Symbol, PERIOD_D1, currentTime, false);
   if(dailyIndex < 0) return;

   if(dailyIndex != priorDailyIndex)
   {
      priorDailyIndex = dailyIndex;
      dailyZone.startIndex = index;
   }

   if(dailyIndex < 1) return;

   dailyZone.high = iHigh(_Symbol, PERIOD_D1, dailyIndex + 1);
   dailyZone.low = iLow(_Symbol, PERIOD_D1, dailyIndex + 1);

   double maxSessionAtr = 0;
   if(InpShowAsianSession) maxSessionAtr = MathMax(maxSessionAtr, asianZone.averageAtr);
   if(InpShowLondonSession) maxSessionAtr = MathMax(maxSessionAtr, londonZone.averageAtr);
   if(InpShowNySession) maxSessionAtr = MathMax(maxSessionAtr, nyZone.averageAtr);

   if(maxSessionAtr == 0 || !MathIsValidNumber(maxSessionAtr))
   {
      maxSessionAtr = atrBuffer[index];
   }

   dailyZone.averageAtr = maxSessionAtr;

   double atrBufferVal = dailyZone.averageAtr * InpMacroAtrMultiplier;
   activeZonesDict[ZONE_DAILY_HIGH].top = dailyZone.high + atrBufferVal;
   activeZonesDict[ZONE_DAILY_HIGH].bottom = dailyZone.high - atrBufferVal;
   activeZonesDict[ZONE_DAILY_HIGH].tier = ZONE_TIER_MID;
   activeZonesDict[ZONE_DAILY_HIGH].isSet = true;

   activeZonesDict[ZONE_DAILY_LOW].top = dailyZone.low + atrBufferVal;
   activeZonesDict[ZONE_DAILY_LOW].bottom = dailyZone.low - atrBufferVal;
   activeZonesDict[ZONE_DAILY_LOW].tier = ZONE_TIER_MID;
   activeZonesDict[ZONE_DAILY_LOW].isSet = true;
}

void CalculateSessions(int index, const datetime &time[], const double &high[], const double &low[], const double &close[])
{
   datetime candleTime = time[index] + InpUtcOffset * 3600;
   MqlDateTime dt;
   TimeToStruct(candleTime, dt);
   int currentHour = dt.hour;

   // Asian Session
   if(InpShowAsianSession)
   {
      bool isAsianSession = false;
      if(InpAsianStartHour > InpAsianEndHour)
         isAsianSession = (currentHour >= InpAsianStartHour || currentHour < InpAsianEndHour);
      else
         isAsianSession = (currentHour >= InpAsianStartHour && currentHour < InpAsianEndHour);

      if(isAsianSession)
      {
         if(!asianZone.isActive)
         {
            asianZone.isActive = true;
            tempAsianHigh = -DBL_MAX;
            tempAsianLow = DBL_MAX;
            tempAsianAtrSum = 0;
            tempAsianCandleCount = 0;
         }

         double currentHigh = high[index];
         double currentLow = low[index];

         if(currentHigh > tempAsianHigh) tempAsianHigh = currentHigh;
         if(currentLow < tempAsianLow) tempAsianLow = currentLow;

         if(MathIsValidNumber(atrBuffer[index]))
         {
            tempAsianAtrSum += atrBuffer[index];
            tempAsianCandleCount++;
         }
      }
      else
      {
         if(asianZone.isActive)
         {
            asianZone.isActive = false;
            asianZone.high = tempAsianHigh;
            asianZone.low = tempAsianLow;
            asianZone.averageAtr = (tempAsianCandleCount > 0) ? (tempAsianAtrSum / tempAsianCandleCount) : atrBuffer[index];
            asianZone.startIndex = index;

            double atrBufferVal = asianZone.averageAtr * InpMacroAtrMultiplier;
            activeZonesDict[ZONE_ASIAN_HIGH].top = asianZone.high + atrBufferVal;
            activeZonesDict[ZONE_ASIAN_HIGH].bottom = asianZone.high - atrBufferVal;
            activeZonesDict[ZONE_ASIAN_HIGH].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_ASIAN_HIGH].isSet = true;

            activeZonesDict[ZONE_ASIAN_LOW].top = asianZone.low + atrBufferVal;
            activeZonesDict[ZONE_ASIAN_LOW].bottom = asianZone.low - atrBufferVal;
            activeZonesDict[ZONE_ASIAN_LOW].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_ASIAN_LOW].isSet = true;
         }
      }
   }

   // London Session
   if(InpShowLondonSession)
   {
      bool isLondonSession = false;
      if(InpLondonStartHour > InpLondonEndHour)
         isLondonSession = (currentHour >= InpLondonStartHour || currentHour < InpLondonEndHour);
      else
         isLondonSession = (currentHour >= InpLondonStartHour && currentHour < InpLondonEndHour);

      if(isLondonSession)
      {
         if(!londonZone.isActive)
         {
            londonZone.isActive = true;
            tempLondonHigh = -DBL_MAX;
            tempLondonLow = DBL_MAX;
            tempLondonAtrSum = 0;
            tempLondonCandleCount = 0;
         }

         double currentHigh = high[index];
         double currentLow = low[index];

         if(currentHigh > tempLondonHigh) tempLondonHigh = currentHigh;
         if(currentLow < tempLondonLow) tempLondonLow = currentLow;

         if(MathIsValidNumber(atrBuffer[index]))
         {
            tempLondonAtrSum += atrBuffer[index];
            tempLondonCandleCount++;
         }
      }
      else
      {
         if(londonZone.isActive)
         {
            londonZone.isActive = false;
            londonZone.high = tempLondonHigh;
            londonZone.low = tempLondonLow;
            londonZone.startIndex = index;
            londonZone.averageAtr = (tempLondonCandleCount > 0) ? (tempLondonAtrSum / tempLondonCandleCount) : atrBuffer[index];

            double atrBufferVal = londonZone.averageAtr * InpMacroAtrMultiplier;
            activeZonesDict[ZONE_LONDON_HIGH].top = londonZone.high + atrBufferVal;
            activeZonesDict[ZONE_LONDON_HIGH].bottom = londonZone.high - atrBufferVal;
            activeZonesDict[ZONE_LONDON_HIGH].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_LONDON_HIGH].isSet = true;

            activeZonesDict[ZONE_LONDON_LOW].top = londonZone.low + atrBufferVal;
            activeZonesDict[ZONE_LONDON_LOW].bottom = londonZone.low - atrBufferVal;
            activeZonesDict[ZONE_LONDON_LOW].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_LONDON_LOW].isSet = true;
         }
      }
   }

   // NY Session
   if(InpShowNySession)
   {
      bool isNYSession = false;
      if(InpNyStartHour > InpNyEndHour)
         isNYSession = (currentHour >= InpNyStartHour || currentHour < InpNyEndHour);
      else
         isNYSession = (currentHour >= InpNyStartHour && currentHour < InpNyEndHour);

      if(isNYSession)
      {
         if(!nyZone.isActive)
         {
            nyZone.isActive = true;
            tempNYHigh = -DBL_MAX;
            tempNYLow = DBL_MAX;
            tempNYAtrSum = 0;
            tempNYCandleCount = 0;
         }

         double currentHigh = high[index];
         double currentLow = low[index];

         if(currentHigh > tempNYHigh) tempNYHigh = currentHigh;
         if(currentLow < tempNYLow) tempNYLow = currentLow;

         if(MathIsValidNumber(atrBuffer[index]))
         {
            tempNYAtrSum += atrBuffer[index];
            tempNYCandleCount++;
         }
      }
      else
      {
         if(nyZone.isActive)
         {
            nyZone.isActive = false;
            nyZone.high = tempNYHigh;
            nyZone.low = tempNYLow;
            nyZone.startIndex = index;
            nyZone.averageAtr = (tempNYCandleCount > 0) ? (tempNYAtrSum / tempNYCandleCount) : atrBuffer[index];

            double atrBufferVal = nyZone.averageAtr * InpMacroAtrMultiplier;
            activeZonesDict[ZONE_NY_HIGH].top = nyZone.high + atrBufferVal;
            activeZonesDict[ZONE_NY_HIGH].bottom = nyZone.high - atrBufferVal;
            activeZonesDict[ZONE_NY_HIGH].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_NY_HIGH].isSet = true;

            activeZonesDict[ZONE_NY_LOW].top = nyZone.low + atrBufferVal;
            activeZonesDict[ZONE_NY_LOW].bottom = nyZone.low - atrBufferVal;
            activeZonesDict[ZONE_NY_LOW].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_NY_LOW].isSet = true;
         }
      }
   }
}

void CalculatePsychLevels(int index, const double &close[])
{
   double halfStep = InpPsychLevelStep * 2.0;
   double centuryStep = halfStep * 2.0;
   double currentPrice = close[index];

   double quartileAbove = MathCeil(currentPrice / InpPsychLevelStep) * InpPsychLevelStep;
   double halfAbove = MathCeil(currentPrice / halfStep) * halfStep;
   double centuryAbove = MathCeil(currentPrice / centuryStep) * centuryStep;

   double quartileBelow = MathFloor(currentPrice / InpPsychLevelStep) * InpPsychLevelStep;
   double halfBelow = MathFloor(currentPrice / halfStep) * halfStep;
   double centuryBelow = MathFloor(currentPrice / centuryStep) * centuryStep;

   if(quartileAbove == currentPrice || quartileAbove == halfAbove || quartileAbove == centuryAbove)
      quartileAbove += InpPsychLevelStep;
   if(quartileBelow == currentPrice || quartileBelow == halfBelow || quartileBelow == centuryBelow)
      quartileBelow -= InpPsychLevelStep;
   if(halfAbove == currentPrice || halfAbove == centuryAbove)
      halfAbove += halfStep;
   if(halfBelow == currentPrice || halfBelow == centuryBelow)
      halfBelow -= halfStep;
   if(centuryAbove == currentPrice)
      centuryAbove += centuryStep;
   if(centuryBelow == currentPrice)
      centuryBelow -= centuryStep;

   nearestPsychQuartileAbove = quartileAbove;
   nearestPsychQuartileBelow = quartileBelow;
   nearestPsychHalfAbove = halfAbove;
   nearestPsychHalfBelow = halfBelow;
   nearestPsychCenturyAbove = centuryAbove;
   nearestPsychCenturyBelow = centuryBelow;

   if(dailyZone.averageAtr != 0 && MathIsValidNumber(dailyZone.averageAtr))
   {
      double atrBufferVal = dailyZone.averageAtr * InpMacroAtrMultiplier;

      double closestCentury = (MathAbs(currentPrice - centuryAbove) <= MathAbs(currentPrice - centuryBelow)) ? centuryAbove : centuryBelow;
      double distCentury = MathAbs(currentPrice - closestCentury);

      double closestHalf = (MathAbs(currentPrice - halfAbove) <= MathAbs(currentPrice - halfBelow)) ? halfAbove : halfBelow;
      double distHalf = MathAbs(currentPrice - closestHalf);

      double closestQuartile = (MathAbs(currentPrice - quartileAbove) <= MathAbs(currentPrice - quartileBelow)) ? quartileAbove : quartileBelow;
      double distQuartile = MathAbs(currentPrice - closestQuartile);

      double closestPsych = closestCentury;
      ENUM_ZONE_TIER psychTier = ZONE_TIER_MAJOR;
      double minDist = distCentury;

      if(distHalf < minDist)
      {
         minDist = distHalf;
         closestPsych = closestHalf;
         psychTier = ZONE_TIER_MID;
      }

      if(distQuartile < minDist)
      {
         minDist = distQuartile;
         closestPsych = closestQuartile;
         psychTier = ZONE_TIER_MINOR;
      }

      activeZonesDict[ZONE_PSYCH_LEVEL].top = closestPsych + atrBufferVal;
      activeZonesDict[ZONE_PSYCH_LEVEL].bottom = closestPsych - atrBufferVal;
      activeZonesDict[ZONE_PSYCH_LEVEL].tier = psychTier;
      activeZonesDict[ZONE_PSYCH_LEVEL].isSet = true;
   }
}

void ScanOrderBlocks(int index, const double &open[], const double &high[], const double &low[], const double &close[])
{
   for(int i = ArraySize(activeOrderBlocks) - 1; i >= 0; i--)
   {
      double currentClose = close[index];
      bool broken = (activeOrderBlocks[i].isBullish && currentClose < activeOrderBlocks[i].bottom) ||
                    (!activeOrderBlocks[i].isBullish && currentClose > activeOrderBlocks[i].top);

      if(broken)
         ArrayRemove(activeOrderBlocks, i, 1);
   }

   int idx = index - 1;
   if(idx < 3 || !MathIsValidNumber(atrBuffer[idx])) return;

   double op = open[idx];
   double cl = close[idx];
   double bodySize = MathAbs(cl - op);

   if(bodySize > (atrBuffer[idx] * 1.5))
   {
      bool isBullishImpulse = cl > op;
      int traceIndex = -1;

      if(isBullishImpulse)
      {
         if(close[idx - 1] < open[idx - 1]) traceIndex = idx - 1;
         else if(close[idx - 2] < open[idx - 2]) traceIndex = idx - 2;
         else if(close[idx - 3] < open[idx - 3]) traceIndex = idx - 3;
      }
      else
      {
         if(close[idx - 1] > open[idx - 1]) traceIndex = idx - 1;
         else if(close[idx - 2] > open[idx - 2]) traceIndex = idx - 2;
         else if(close[idx - 3] > open[idx - 3]) traceIndex = idx - 3;
      }

      if(traceIndex != -1)
      {
         obCounter++;
         string obName = (isBullishImpulse ? "OB_Bull_" : "OB_Bear_") + IntegerToString(obCounter);

         int sz = ArraySize(activeOrderBlocks);
         ArrayResize(activeOrderBlocks, sz + 1);
         activeOrderBlocks[sz].top = high[traceIndex];
         activeOrderBlocks[sz].bottom = low[traceIndex];
         activeOrderBlocks[sz].startIndex = traceIndex;
         activeOrderBlocks[sz].isBullish = isBullishImpulse;
         activeOrderBlocks[sz].name = obName;

         activeZonesDict[ZONE_ORDER_BLOCK].top = high[traceIndex];
         activeZonesDict[ZONE_ORDER_BLOCK].bottom = low[traceIndex];
         activeZonesDict[ZONE_ORDER_BLOCK].tier = ZONE_TIER_MID;
         activeZonesDict[ZONE_ORDER_BLOCK].isSet = true;
      }
   }
}

bool ScanDoubles(int index, const double &open[], const double &high[], const double &low[], const double &close[])
{
   bool newFormationAdded = false;

   for(int i = ArraySize(activeDoubles) - 1; i >= 0; i--)
   {
      double currentClose = close[index];
      if(currentClose > activeDoubles[i].top || currentClose < activeDoubles[i].bottom)
      {
         ArrayRemove(activeDoubles, i, 1);
      }
   }

   int idx = index - 1;
   if(idx < InpMinFormationCandles || !MathIsValidNumber(atrBuffer[idx])) return false;

   double currentHigh = high[idx];
   double currentLow = low[idx];

   double microAtrBuffer = atrBuffer[idx] * InpMicroAtrMultiplier;

   for(int i = InpMinFormationCandles; i <= InpMaxLookbackCandles; i++)
   {
      int pastIndex = idx - i;
      if(pastIndex < 0) break;

      double pastHigh = high[pastIndex];
      double pastLow = low[pastIndex];
      double pastBodyMax = MathMax(open[pastIndex], close[pastIndex]);
      double pastBodyMin = MathMin(open[pastIndex], close[pastIndex]);

      // Double Top
      double topWickSize = pastHigh - pastBodyMax;
      double zoneMaxTop = pastHigh + topWickSize;
      double zoneMinTop = pastBodyMax;

      if(currentHigh >= zoneMinTop && currentHigh <= zoneMaxTop)
      {
         double lowestBetween = GetMinLow(low, idx, i);

         if(currentHigh - lowestBetween > microAtrBuffer * 2.0)
         {
            doubleCounter++;
            int sz = ArraySize(activeDoubles);
            ArrayResize(activeDoubles, sz + 1);
            activeDoubles[sz].top = zoneMaxTop;
            activeDoubles[sz].bottom = zoneMinTop;
            activeDoubles[sz].startIndex = pastIndex;
            activeDoubles[sz].name = "DoubleTop_" + IntegerToString(doubleCounter);

            activeZonesDict[ZONE_DOUBLE_TOP].top = zoneMaxTop;
            activeZonesDict[ZONE_DOUBLE_TOP].bottom = zoneMinTop;
            activeZonesDict[ZONE_DOUBLE_TOP].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_DOUBLE_TOP].isSet = true;

            newFormationAdded = true;
            break;
         }
      }

      // Double Bottom
      double bottomWickSize = pastBodyMin - pastLow;
      double zoneMaxBottom = pastBodyMin;
      double zoneMinBottom = pastLow - bottomWickSize;

      if(currentLow <= zoneMaxBottom && currentLow >= zoneMinBottom)
      {
         double highestBetween = GetMaxHigh(high, idx, i);

         if(highestBetween - currentLow > microAtrBuffer * 2.0)
         {
            doubleCounter++;
            int sz = ArraySize(activeDoubles);
            ArrayResize(activeDoubles, sz + 1);
            activeDoubles[sz].top = zoneMaxBottom;
            activeDoubles[sz].bottom = zoneMinBottom;
            activeDoubles[sz].startIndex = pastIndex;
            activeDoubles[sz].name = "DoubleBot_" + IntegerToString(doubleCounter);

            activeZonesDict[ZONE_DOUBLE_BOTTOM].top = zoneMaxBottom;
            activeZonesDict[ZONE_DOUBLE_BOTTOM].bottom = zoneMinBottom;
            activeZonesDict[ZONE_DOUBLE_BOTTOM].tier = ZONE_TIER_MINOR;
            activeZonesDict[ZONE_DOUBLE_BOTTOM].isSet = true;

            newFormationAdded = true;
            break;
         }
      }
   }

   return newFormationAdded;
}

void ScanConsolidations(int index, const double &open[], const double &high[], const double &low[], const double &close[])
{
   for(int i = ArraySize(activeConsolidations) - 1; i >= 0; i--)
   {
      double currentClose = close[index];
      if(currentClose > activeConsolidations[i].top || currentClose < activeConsolidations[i].bottom)
      {
         ArrayRemove(activeConsolidations, i, 1);
      }
   }

   int idx = index - 1;
   if(idx < InpMinFormationCandles || !MathIsValidNumber(atrBuffer[idx])) return;

   for(int i = 0; i < ArraySize(activeConsolidations); i++)
   {
      if(close[idx] <= activeConsolidations[i].top && close[idx] >= activeConsolidations[i].bottom)
         return;
   }

   double maxZoneHeight = atrBuffer[idx] * InpMaxConsolidationAtrWidth;
   double microAtrBuffer = atrBuffer[idx] * InpMicroAtrMultiplier;

   double highestHigh = GetMaxHigh(high, idx, InpMinFormationCandles);
   double lowestLow = GetMinLow(low, idx, InpMinFormationCandles);

   if((highestHigh - lowestLow) <= maxZoneHeight)
   {
      consolidationCounter++;
      int sz = ArraySize(activeConsolidations);
      ArrayResize(activeConsolidations, sz + 1);
      activeConsolidations[sz].top = highestHigh + microAtrBuffer;
      activeConsolidations[sz].bottom = lowestLow - microAtrBuffer;
      activeConsolidations[sz].startIndex = idx - InpMinFormationCandles + 1;
      activeConsolidations[sz].name = "Consolidation_" + IntegerToString(consolidationCounter);

      activeZonesDict[ZONE_CONSOLIDATION].top = highestHigh + microAtrBuffer;
      activeZonesDict[ZONE_CONSOLIDATION].bottom = lowestLow - microAtrBuffer;
      activeZonesDict[ZONE_CONSOLIDATION].tier = ZONE_TIER_MINOR;
      activeZonesDict[ZONE_CONSOLIDATION].isSet = true;
   }
}

void ScanRejections(int index, const double &open[], const double &high[], const double &low[], const double &close[])
{
   int idx = index - 1;
   if(idx < 2 || !MathIsValidNumber(atrBuffer[idx])) return;

   for(int i = ArraySize(activeRejections) - 1; i >= 0; i--)
   {
      double currentClose = close[index];
      if(currentClose > activeRejections[i].top || currentClose < activeRejections[i].bottom)
      {
         ArrayRemove(activeRejections, i, 1);
      }
   }

   for(int i = 0; i < ArraySize(activeRejections); i++)
   {
      if(activeRejections[i].tier == ZONE_TIER_MINOR && activeRejections[i].startIndex == idx - 1)
      {
         if(close[idx] > high[idx - 1] || close[idx] < low[idx - 1])
         {
            activeRejections[i].tier = ZONE_TIER_MID;
            activeZonesDict[ZONE_REJECTION].top = activeRejections[i].top;
            activeZonesDict[ZONE_REJECTION].bottom = activeRejections[i].bottom;
            activeZonesDict[ZONE_REJECTION].tier = ZONE_TIER_MID;
            activeZonesDict[ZONE_REJECTION].isSet = true;
         }
      }
      else if(activeRejections[i].tier == ZONE_TIER_MID && activeRejections[i].startIndex == idx - 2)
      {
         if(close[idx] > high[idx - 1] || close[idx] < low[idx - 1])
         {
            activeRejections[i].tier = ZONE_TIER_MAJOR;
            activeZonesDict[ZONE_REJECTION].top = activeRejections[i].top;
            activeZonesDict[ZONE_REJECTION].bottom = activeRejections[i].bottom;
            activeZonesDict[ZONE_REJECTION].tier = ZONE_TIER_MAJOR;
            activeZonesDict[ZONE_REJECTION].isSet = true;
         }
      }
   }

   double op = open[idx];
   double cl = close[idx];
   double hi = high[idx];
   double lo = low[idx];

   double body = MathAbs(cl - op);
   double totalRange = hi - lo;
   double lowerWick = MathMin(op, cl) - lo;
   double upperWick = hi - MathMax(op, cl);

   bool isBullishRejection = (lowerWick >= (body * 2.0)) && (lowerWick >= (totalRange * 0.5));
   bool isBearishRejection = (upperWick >= (body * 2.0)) && (upperWick >= (totalRange * 0.5));

   if(isBullishRejection || isBearishRejection)
   {
      bool exists = false;
      int count = ArraySize(activeRejections);
      if(count > 0 && activeRejections[count - 1].startIndex == idx)
         exists = true;

      if(!exists)
      {
         rejectionCounter++;
         double microAtr = atrBuffer[idx] * InpMicroAtrMultiplier;
         double topVal, bottomVal;

         if(isBullishRejection)
         {
            bottomVal = lo - microAtr;
            topVal = cl + lowerWick + microAtr;
         }
         else
         {
            topVal = hi + microAtr;
            bottomVal = cl - upperWick - microAtr;
         }

         ArrayResize(activeRejections, count + 1);
         activeRejections[count].top = topVal;
         activeRejections[count].bottom = bottomVal;
         activeRejections[count].startIndex = idx;
         activeRejections[count].name = "Rejection_" + IntegerToString(rejectionCounter);
         activeRejections[count].tier = ZONE_TIER_MINOR;

         activeZonesDict[ZONE_REJECTION].top = topVal;
         activeZonesDict[ZONE_REJECTION].bottom = bottomVal;
         activeZonesDict[ZONE_REJECTION].tier = ZONE_TIER_MINOR;
         activeZonesDict[ZONE_REJECTION].isSet = true;
      }
   }
}

// ==========================================
// BOT HELPER METHODS
// ==========================================
Zone GetClosestZone(const ENUM_ZONE_TYPE &typesToSearch[], double currentPrice)
{
   Zone closestZone;
   ZeroMemory(closestZone);
   closestZone.isSet = false;
   double smallestDistance = DBL_MAX;

   for(int i = 0; i < ArraySize(typesToSearch); i++)
   {
      ENUM_ZONE_TYPE type = typesToSearch[i];
      if(activeZonesDict[type].isSet)
      {
         Zone zoneToCheck = activeZonesDict[type];
         double zoneCenter = (zoneToCheck.top + zoneToCheck.bottom) / 2.0;
         double distance = MathAbs(currentPrice - zoneCenter);

         if(distance < smallestDistance)
         {
            smallestDistance = distance;
            closestZone = zoneToCheck;
         }
      }
   }
   return closestZone;
}

void CheckRejection(int tradeType, double currHigh, double currLow, double currClose, double prevClose, ENUM_REJECTION_MODE mode, bool &rejectedMinor, bool &rejectedMid, bool &rejectedMajor)
{
   rejectedMinor = false;
   rejectedMid = false;
   rejectedMajor = false;

   Zone closestZonesToTest[];

   ENUM_ZONE_TYPE typesSessionHigh[] = { ZONE_ASIAN_HIGH, ZONE_LONDON_HIGH, ZONE_NY_HIGH };
   Zone sessionHigh = GetClosestZone(typesSessionHigh, currClose);
   if(sessionHigh.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = sessionHigh; }

   ENUM_ZONE_TYPE typesSessionLow[] = { ZONE_ASIAN_LOW, ZONE_LONDON_LOW, ZONE_NY_LOW };
   Zone sessionLow = GetClosestZone(typesSessionLow, currClose);
   if(sessionLow.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = sessionLow; }

   ENUM_ZONE_TYPE typesMultidayHigh[] = { ZONE_MULTIDAY_HIGH };
   Zone multidayHigh = GetClosestZone(typesMultidayHigh, currClose);
   if(multidayHigh.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = multidayHigh; }

   ENUM_ZONE_TYPE typesMultidayLow[] = { ZONE_MULTIDAY_LOW };
   Zone multidayLow = GetClosestZone(typesMultidayLow, currClose);
   if(multidayLow.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = multidayLow; }

   ENUM_ZONE_TYPE typesDailyHigh[] = { ZONE_DAILY_HIGH };
   Zone dailyHigh = GetClosestZone(typesDailyHigh, currClose);
   if(dailyHigh.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = dailyHigh; }

   ENUM_ZONE_TYPE typesDailyLow[] = { ZONE_DAILY_LOW };
   Zone dailyLow = GetClosestZone(typesDailyLow, currClose);
   if(dailyLow.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = dailyLow; }

   ENUM_ZONE_TYPE typesOB[] = { ZONE_ORDER_BLOCK };
   Zone orderBlock = GetClosestZone(typesOB, currClose);
   if(orderBlock.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = orderBlock; }

   ENUM_ZONE_TYPE typesPsych[] = { ZONE_PSYCH_LEVEL };
   Zone psychLevel = GetClosestZone(typesPsych, currClose);
   if(psychLevel.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = psychLevel; }

   ENUM_ZONE_TYPE typesDT[] = { ZONE_DOUBLE_TOP };
   Zone doubleTop = GetClosestZone(typesDT, currClose);
   if(doubleTop.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = doubleTop; }

   ENUM_ZONE_TYPE typesDB[] = { ZONE_DOUBLE_BOTTOM };
   Zone doubleBot = GetClosestZone(typesDB, currClose);
   if(doubleBot.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = doubleBot; }

   ENUM_ZONE_TYPE typesCons[] = { ZONE_CONSOLIDATION };
   Zone consolidation = GetClosestZone(typesCons, currClose);
   if(consolidation.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = consolidation; }

   ENUM_ZONE_TYPE typesRej[] = { ZONE_REJECTION };
   Zone rejectionFormation = GetClosestZone(typesRej, currClose);
   if(rejectionFormation.isSet) { int sz = ArraySize(closestZonesToTest); ArrayResize(closestZonesToTest, sz+1); closestZonesToTest[sz] = rejectionFormation; }

   for(int i = 0; i < ArraySize(closestZonesToTest); i++)
   {
      Zone zone = closestZonesToTest[i];
      bool isRejected = false;

      if(mode == REJECTION_WICK_INSIDE_CLOSE_OUTSIDE)
      {
         if(tradeType == 0 && currHigh >= zone.bottom && currClose < zone.bottom) // Buy = 0
            isRejected = true;
         else if(tradeType == 1 && currLow <= zone.top && currClose > zone.top) // Sell = 1
            isRejected = true;
      }
      else if(mode == REJECTION_PREV_CLOSE_INSIDE_CURR_CLOSE_OUTSIDE)
      {
         bool prevCloseInside = (prevClose >= zone.bottom && prevClose <= zone.top);
         if(tradeType == 0 && prevCloseInside && currClose < zone.bottom)
            isRejected = true;
         else if(tradeType == 1 && prevCloseInside && currClose > zone.top)
            isRejected = true;
      }

      if(isRejected)
      {
         if(zone.tier == ZONE_TIER_MINOR) rejectedMinor = true;
         else if(zone.tier == ZONE_TIER_MID) rejectedMid = true;
         else if(zone.tier == ZONE_TIER_MAJOR) rejectedMajor = true;
      }
   }
}