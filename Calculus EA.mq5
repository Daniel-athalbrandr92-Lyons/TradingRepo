//+------------------------------------------------------------------+
//|                                                   CalculusEA.mq5 |
//|                                                           Daniel |
//+------------------------------------------------------------------+
#property copyright "Daniel"
#property version   "1.12"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters
input group "--- Money Management ---"
input bool       InpUseDynamicRisk  = true;      // Use % Risk Scaling
input double     InpRiskPercent     = 1.0;       // % Account Equity to Risk Per Trade
input double     InpFixedLotSize    = 0.1;       // Fixed Lot Size
input ulong      InpMagicNumber     = 20260609;  // Magic Number

input group "--- Risk & Target Points ---"
input int        InpStopLossPoints  = 200;       
input int        InpTakeProfitPoints = 400;      
input int        InpTrailingStopPoints = 300;    

input group "--- Indicator Settings ---"
input int        InpIndPeriod       = 14;        
input ENUM_APPLIED_PRICE InpPriceType = PRICE_CLOSE; 
input double     InpIndMin          = 30.0;      
input double     InpIndMax          = 70.0;      

input group "--- Calculus Thresholds ---"
input double     InpVelocityMin     = 0.0;       
input double     InpAccelerationMin = 0.0;       

input group "--- Operational Risk Filters ---"
input bool       InpUseHolidayFilter = true;     
input int        InpBlackoutStartDay = 20;       
input int        InpBlackoutEndDay   = 3;        

input group "--- Prop Firm Guardrails ---"
input double     InpMaxDailyDDPercent = 5.0;     
input double     InpMaxTotalDDPercent = 10.0;    
input double     InpMinTradesPerWeek  = 2.0;     

//--- Global Variables
double g_tickValue, g_tickSize, g_point, g_minLot, g_maxLot, g_lotStep;
int    indicatorHandle;
double rsiBuffer[];
datetime currentDayTime = 0;
double   dayStartEquity = 0.0;
double   maxDailyDDRecorded = 0.0;
bool     dailyBreachDetected = false;
datetime globalStartTime = 0;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if((InpUseDynamicRisk && InpStopLossPoints <= 0) || (InpStopLossPoints > InpTakeProfitPoints && InpTakeProfitPoints > 0))
      return(INIT_PARAMETERS_INCORRECT);
      
   globalStartTime = TimeCurrent(); 
   g_tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   indicatorHandle = iRSI(_Symbol, _Period, InpIndPeriod, InpPriceType);
   if(indicatorHandle == INVALID_HANDLE) return(INIT_FAILED);
   
   ArraySetAsSeries(rsiBuffer, true);
   
   // Start 60-second timer
   EventSetTimer(60);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) 
{ 
   IndicatorRelease(indicatorHandle); 
   EventKillTimer(); 
}

//+------------------------------------------------------------------+
//| OnTimer: Fires every 60 seconds                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   datetime now = TimeCurrent();
   datetime day_start = now - (now % 86400);
   
   if(day_start != currentDayTime) {
      currentDayTime = day_start;
      dayStartEquity = current_equity;
   }

   if(dayStartEquity > 0.0) {
      double current_dd = ((dayStartEquity - current_equity) / dayStartEquity) * 100.0;
      if(current_dd > maxDailyDDRecorded) maxDailyDDRecorded = current_dd;
      if(current_dd >= InpMaxDailyDDPercent) dailyBreachDetected = true;
   }

   if(InpUseHolidayFilter && IsHolidayBlackout()) {
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      return;
   }

   if(CopyBuffer(indicatorHandle, 0, 0, 4, rsiBuffer) < 4) return;

   double I_t = rsiBuffer[0], I_t_1 = rsiBuffer[1], I_t_2 = rsiBuffer[2];
   double velocity_t = I_t - I_t_1;
   double acceleration = velocity_t - (I_t_1 - I_t_2);

   bool amIBuying = IsPositionOpen(POSITION_TYPE_BUY);
   bool amISelling = IsPositionOpen(POSITION_TYPE_SELL);

   if(!amIBuying && !amISelling) {
      double calculatedLot = CalculateLotSize(InpStopLossPoints);
      if(calculatedLot > 0) {
         if(I_t < InpIndMin && velocity_t > InpVelocityMin && acceleration > InpAccelerationMin)
            ExecuteMarketOrder(POSITION_TYPE_BUY, calculatedLot);
         else if(I_t > InpIndMax && velocity_t < -InpVelocityMin && acceleration < -InpAccelerationMin)
            ExecuteMarketOrder(POSITION_TYPE_SELL, calculatedLot);
      }
   } else {
      if(amIBuying && velocity_t < 0) CloseAllPositions(POSITION_TYPE_BUY);
      else if(amISelling && velocity_t > 0) CloseAllPositions(POSITION_TYPE_SELL);
      else ApplyTrailingStop();
   }
}

void OnTick() {} // Empty - Logic moved to OnTimer

//--- Helper Methods
bool IsHolidayBlackout() {
   MqlDateTime dt; TimeCurrent(dt);
   return ((dt.mon == 12 && dt.day >= InpBlackoutStartDay) || (dt.mon == 1 && dt.day <= InpBlackoutEndDay));
}

double CalculateLotSize(int slPoints) {
   if(!InpUseDynamicRisk) return InpFixedLotSize;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent / 100.0);
   double riskPerLot = slPoints * g_tickValue * (g_point / g_tickSize);
   if(riskPerLot <= 0) return 0.0;
   double targetLot = MathFloor((riskMoney / riskPerLot) / g_lotStep) * g_lotStep;
   return MathMax(g_minLot, MathMin(g_maxLot, targetLot));
}

void ExecuteMarketOrder(ENUM_POSITION_TYPE type, double vol) {
   trade.PositionOpen(_Symbol, (type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), vol, 
                      (type == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID)),
                      0, 0, "Calculus EA");
}

bool IsPositionOpen(ENUM_POSITION_TYPE type) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == type)
         return true;
   }
   return false;
}

void CloseAllPositions(ENUM_POSITION_TYPE type) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == type)
         trade.PositionClose(ticket);
   }
}

void ApplyTrailingStop() {
   if(InpTrailingStopPoints <= 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
         double curr = PositionGetDouble(POSITION_PRICE_CURRENT);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double newSL = curr - (InpTrailingStopPoints * g_point);
            if(newSL > PositionGetDouble(POSITION_SL)) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         } else {
            double newSL = curr + (InpTrailingStopPoints * g_point);
            if(newSL < PositionGetDouble(POSITION_SL) || PositionGetDouble(POSITION_SL) == 0) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}

double OnTester() {
   long totalTrades = TesterStatistics(STAT_TRADES); 
   double netProfit = TesterStatistics(STAT_PROFIT); 
   
   if(netProfit <= 0) return netProfit; 
   if(totalTrades < 5) return 0.0; 

   datetime endTime = TimeCurrent(); 
   double totalDays = (double)(endTime - globalStartTime) / 86400.0; 
   if(totalDays <= 0.5) totalDays = 1.0;  
   double weeks = totalDays / 5.0;  

   if(totalTrades < (weeks * InpMinTradesPerWeek)) return 0.0; 

   if(dailyBreachDetected) return 0.0; 

   double maxEquityDDPercent = TesterStatistics(STAT_EQUITY_DDREL_PERCENT); 
   if(maxEquityDDPercent > InpMaxTotalDDPercent) return 0.0;  

   if(maxEquityDDPercent <= 0.0) maxEquityDDPercent = 0.05; 

   double ddComponent = 1.0 + MathLog(1.0 + maxEquityDDPercent); 
   double stabilizedFitness = netProfit / ddComponent; 

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
   
   double daysPerWeek = isCrypto ? 7.0 : 5.0;
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
   
   double fitness_2 = baseScore * frequencyPenalty;

   if(stabilizedFitness >= 0 || fitness_2 >= 0)
      return stabilizedFitness * fitness_2;
   else 
      return stabilizedFitness * fitness_2 * -1;
}