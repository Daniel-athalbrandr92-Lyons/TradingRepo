//+------------------------------------------------------------------+
//|                                         CalculusMultimodalEA.mq5 |
//|                                                    Daniel Lyons  |
//+------------------------------------------------------------------+
#property copyright "Daniel Lyons"
#property version   "4.16"

//--- Include Trade Library for execution logistics
#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters
input group "--- Optimization Constraints ---"
input int            InpCombinatorialMask = 1;              // Bitmask Combo (1 to 31)
input ENUM_MA_METHOD InpMAMethod          = MODE_SMA;       // Smoothing Method
input ENUM_APPLIED_PRICE InpAppliedPrice  = PRICE_WEIGHTED; // Applied Price Vector
input double         InpLotSize           = 0.01;           // Fixed Lot Size Allocation

input group "--- Dynamic Ribbon Risk Brackets ---"
input double         InpSLMultiplier      = 2.5;            // Stop Loss & Trailing Multiplier (of Ribbon Dispersion)
input double         InpTPMultiplier      = 5.0;            // Take Profit Multiplier (of Ribbon Dispersion)
input int            InpMinBracketPoints  = 150;            // Minimum Floor Protection (Points)
input bool           InpTrailImmediately  = true;           // True = Trail Instantly | False = Wait for Profit Gate

input group "--- Calculus Thresholds ---"
input double         InpVelocityMin       = 3.25;           // Minimum f' slope threshold
input double         InpAccelerationMin   = 0.00;           // Minimum f'' turn threshold

input group "--- Operational Risk Filters ---"
input bool           InpUseHolidayFilter  = true;           // Enable Year-End Holiday Blackout
input int            InpBlackoutStartDay  = 20;             // December Blackout Start Day
input int            InpBlackoutEndDay    = 3;              // January Blackout End Day

input group "--- Prop Firm Guardrails ---"
input double         InpMaxDailyDDPercent = 5.0;            // Hard Daily Drawdown Limit (%)
input double         InpMaxTotalDDPercent = 10.0;           // Hard Total Drawdown Limit (%)
input double         InpMinTradesPerWeek  = 2.0;            // Dynamic Density Target (Trades/Week Floor)

input long OrderMagic = 1;

//--- System Constants & Internal Matrix State
const int   NODE_PERIODS[5] = {11, 36, 44, 65, 100};
int         ActiveHandles[5];
bool        ActiveNodes[5];
int         TotalActiveNodes = 0;
double      startingBalance  = 0.0;
datetime    globalStartTime  = 0;

//--- Memory Matrix Optimized for Real-Tick Iteration
double      CalculusMatrix[5][3]; 

//--- Real-time Prop Tracker Variables
datetime    currentDayTime       = 0; 
double      dayStartEquity       = 0.0; 
double      maxDailyDDRecorded   = 0.0; 
bool        dailyBreachDetected  = false; 

//--- Precision Minute Tracking
datetime    lastExecutionTime    = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(OrderMagic); 
   TotalActiveNodes = 0; 
   startingBalance  = AccountInfoDouble(ACCOUNT_BALANCE); 
   globalStartTime  = TimeCurrent(); 
   
   currentDayTime      = 0; 
   dayStartEquity      = 0.0; 
   maxDailyDDRecorded  = 0.0; 
   dailyBreachDetected = false; 
   lastExecutionTime   = 0;

   ArrayInitialize(CalculusMatrix, 0.0); 

   for(int i = 0; i < 5; i++)
     {
      if((InpCombinatorialMask & (1 << i)) != 0) 
        {
         ActiveNodes[i] = true; 
         ActiveHandles[i] = iMA(_Symbol, _Period, NODE_PERIODS[i], 0, InpMAMethod, InpAppliedPrice); 
         if(ActiveHandles[i] == INVALID_HANDLE) return(INIT_FAILED); 
         TotalActiveNodes++; 
        }
      else
        {
         ActiveNodes[i] = false; 
         ActiveHandles[i] = INVALID_HANDLE; 
        }
     }

   if(TotalActiveNodes == 0) return(INIT_PARAMETERS_INCORRECT); 
   return(INIT_SUCCEEDED); 
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   for(int i = 0; i < 5; i++)
     {
      if(ActiveHandles[i] != INVALID_HANDLE) IndicatorRelease(ActiveHandles[i]); 
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- PRECISION TIME GATE: Force execution precisely once per 60-second window
   datetime currentTime = TimeCurrent();
   if(currentTime - lastExecutionTime < 60) return;
   lastExecutionTime = currentTime - (currentTime % 60); // Align perfectly to the minute mark

   //--- CRITICAL PROP CHECK: Evaluated at the minute gate
   datetime now = TimeCurrent(); 
   datetime day_start = now - (now % 86400); 
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY); 

   if(day_start != currentDayTime) 
     {
      currentDayTime = day_start; 
      dayStartEquity = current_equity; 
     }

   if(dayStartEquity > 0.0) 
     {
      double current_dd = ((dayStartEquity - current_equity) / dayStartEquity) * 100.0; 
      if(current_dd > maxDailyDDRecorded) maxDailyDDRecorded = current_dd; 
      if(current_dd >= InpMaxDailyDDPercent) dailyBreachDetected = true; 
     }

   if(InpUseHolidayFilter && IsHolidayBlackout()) 
     {
      if(PositionSelectWithMagic(_Symbol, OrderMagic, POSITION_TYPE_BUY))  ClosePosition(POSITION_TYPE_BUY); 
      if(PositionSelectWithMagic(_Symbol, OrderMagic, POSITION_TYPE_SELL)) ClosePosition(POSITION_TYPE_SELL); 
      return; 
     }

   double current_values[5] = {0,0,0,0,0}; 
   double prime_f[5]        = {0,0,0,0,0}; 

   for(int i = 0; i < 5; i++)
     {
      if(!ActiveNodes[i]) continue; 
      
      double temp_buf[3]; 
      if(CopyBuffer(ActiveHandles[i], 0, 0, 3, temp_buf) < 3) return; 
      
      current_values[i] = temp_buf[2];  
      prime_f[i] = current_values[i] - temp_buf[1]; 
     }

   double total_spread_velocity = 0.0; 
   int    spread_calculations   = 0; 
   double max_node_val          = -1.0; 
   double min_node_val          = 9999999.0; 

   for(int i = 0; i < 5; i++)
     {
      if(!ActiveNodes[i]) continue; 
      if(current_values[i] > max_node_val) max_node_val = current_values[i]; 
      if(current_values[i] < min_node_val) min_node_val = current_values[i]; 
      
      for(int j = i + 1; j < 5; j++) 
        {
         if(!ActiveNodes[j]) continue; 
         double current_spread = current_values[i] - current_values[j]; 
         double spread_f_prime = current_spread - (CalculusMatrix[i][1] - CalculusMatrix[j][1]); 
         total_spread_velocity += spread_f_prime; 
         spread_calculations++; 
        }
     }

   double ribbon_dispersion = (TotalActiveNodes > 1 && max_node_val > 0) ?  
                              (max_node_val - min_node_val) : MathAbs(prime_f[GetFirstActiveNode()]); 
   double avg_spread_f_prime = (spread_calculations > 0) ? (total_spread_velocity / spread_calculations) : 0.0; 
   
   double calculated_sl_points = MathMax(InpMinBracketPoints, (ribbon_dispersion / _Point) * InpSLMultiplier); 
   double calculated_tp_points = MathMax(InpMinBracketPoints, (ribbon_dispersion / _Point) * InpTPMultiplier); 

   // EXECUTE TRAILING: Derived smoothly from the exact minute-bar ribbon spread logic
   ApplyDynamicDispersionTrailing(calculated_sl_points); 

   bool buy_signal  = true; 
   bool sell_signal = true; 
   bool open_buy    = PositionSelectWithMagic(_Symbol, OrderMagic, POSITION_TYPE_BUY); 
   bool open_sell   = PositionSelectWithMagic(_Symbol, OrderMagic, POSITION_TYPE_SELL); 

   for(int i = 0; i < 5; i++)
     {
      if(!ActiveNodes[i]) continue; 
      double acc_calc = current_values[i] - (2.0 * CalculusMatrix[i][1]) + CalculusMatrix[i][0]; 

      if(prime_f[i] < InpVelocityMin || acc_calc < InpAccelerationMin) buy_signal = false; 
      if(prime_f[i] > -InpVelocityMin || acc_calc > -InpAccelerationMin) sell_signal = false; 
     }

   if(spread_calculations > 0) 
     {
      if(avg_spread_f_prime < 0) buy_signal  = false; 
      if(avg_spread_f_prime > 0) sell_signal = false;  
     }

   if(open_buy) 
     {
      bool close_long = false; 
      for(int i = 0; i < 5; i++) { if(ActiveNodes[i] && prime_f[i] < 0) { close_long = true; break; } } 
      if(close_long) ClosePosition(POSITION_TYPE_BUY); 
     }

   if(open_sell) 
     {
      bool close_short = false; 
      for(int i = 0; i < 5; i++) { if(ActiveNodes[i] && prime_f[i] > 0) { close_short = true; break; } } 
      if(close_short) ClosePosition(POSITION_TYPE_SELL); 
     }

   if(buy_signal && !open_buy && !open_sell) 
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
      trade.Buy(InpLotSize, _Symbol, ask, ask - (calculated_sl_points * _Point), ask + (calculated_tp_points * _Point), "Calculus Long"); 
     }

   if(sell_signal && !open_buy && !open_sell) 
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
      trade.Sell(InpLotSize, _Symbol, bid, bid + (calculated_sl_points * _Point), bid - (calculated_tp_points * _Point), "Calculus Short"); 
     }

   // Update memory cache
   for(int i = 0; i < 5; i++)
     {
      if(!ActiveNodes[i]) continue; 
      double temp_buf[3]; 
      if(CopyBuffer(ActiveHandles[i], 0, 0, 3, temp_buf) == 3) 
        {
         CalculusMatrix[i][0] = temp_buf[0]; 
         CalculusMatrix[i][1] = temp_buf[1]; 
         CalculusMatrix[i][2] = temp_buf[2]; 
        }
     }
  }

bool IsHolidayBlackout()
  {
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); 
   return ((dt.mon == 12 && dt.day >= InpBlackoutStartDay) || (dt.mon == 1 && dt.day <= InpBlackoutEndDay)); 
  }

int GetFirstActiveNode() { for(int i = 0; i < 5; i++) { if(ActiveNodes[i]) return(i); } return(0); } 

//+------------------------------------------------------------------+
//| Symmetrical Dynamic Dispersion Trailing                           |
//+------------------------------------------------------------------+
void ApplyDynamicDispersionTrailing(double dynamic_points)
  {
   if(dynamic_points <= 0) return; 
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == OrderMagic) 
        {
         ulong ticket = PositionGetInteger(POSITION_TICKET); 
         double current_sl = PositionGetDouble(POSITION_SL); 
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN); 
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) 
           {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID); 
            double target_sl = bid - (dynamic_points * _Point); 
            if(InpTrailImmediately || (bid - open_price > dynamic_points * _Point)) 
              {
               if(current_sl < target_sl || current_sl == 0.0) trade.PositionModify(ticket, NormalizeDouble(target_sl, _Digits), PositionGetDouble(POSITION_TP)); 
              }
           }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) 
           {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK); 
            double target_sl = ask + (dynamic_points * _Point); 
            if(InpTrailImmediately || (open_price - ask > dynamic_points * _Point)) 
              {
               if(current_sl > target_sl || current_sl == 0.0) trade.PositionModify(ticket, NormalizeDouble(target_sl, _Digits), PositionGetDouble(POSITION_TP)); 
              }
           }
        }
     }
  }

bool PositionSelectWithMagic(string symbol, long magic, ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == magic && PositionGetInteger(POSITION_TYPE) == type) return true; 
     }
   return false; 
  }

void ClosePosition(ENUM_POSITION_TYPE type)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == OrderMagic && PositionGetInteger(POSITION_TYPE) == type) trade.PositionClose(PositionGetTicket(i)); 
     }
  }

//+------------------------------------------------------------------+
//| Multi-Tier Prop Bracket Verification Module                       |
//+------------------------------------------------------------------+
double OnTester()
{
   long totalTrades = TesterStatistics(STAT_TRADES); 
   double netProfit = TesterStatistics(STAT_PROFIT); 
   
   if(netProfit <= 0) return netProfit; 
   if(totalTrades < 5) return 0.0; 

   datetime endTime = TimeCurrent(); 
   double totalDays = (double)(endTime - globalStartTime) / 86400.0; 
   if(totalDays <= 0.5) totalDays = 1.0;  
   double weeks = totalDays / 5.0;  

   if(totalTrades < (weeks * InpMinTradesPerWeek)) return 0.0; 

   // Hard Daily Breach Check
   if(dailyBreachDetected) return 0.0; 

   // Hard Total Drawdown Check
   double maxEquityDDPercent = TesterStatistics(STAT_EQUITY_DDREL_PERCENT); 
   if(maxEquityDDPercent > InpMaxTotalDDPercent) return 0.0;  

   if(maxEquityDDPercent <= 0.0) maxEquityDDPercent = 0.05; 

   double ddComponent = 1.0 + MathLog(1.0 + maxEquityDDPercent); 
   double stabilizedFitness = netProfit / ddComponent; 

   return stabilizedFitness; 
}