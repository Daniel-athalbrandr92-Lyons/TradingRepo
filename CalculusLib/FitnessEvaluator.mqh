//+----------------------------------------------------------+
//|  CFitnessEvaluator.mqh                                   |
//+----------------------------------------------------------+
#property strict

struct FitnessParams {
   double maxTotalDD;
   double minTradesPerWeek;
   long   magicNumber;
   datetime globalStartTime;
   bool isCrypto;
};

double winRatio;

class CFitnessEvaluator {
private:
   // Helper to calculate your Custom Consistency Logic
   static double CalculateConsistency() {
      long maxWin = TesterStatistics(STAT_CONPROFITMAX_TRADES);
      long maxLoss = TesterStatistics(STAT_CONLOSSMAX_TRADES);
      long totalWins = TesterStatistics(STAT_PROFIT_TRADES);
      long totalTrades = TesterStatistics(STAT_TRADES);
      double avgWinStreak = TesterStatistics(STAT_PROFITTRADES_AVGCON);
      double avgLossStreak = TesterStatistics(STAT_LOSSTRADES_AVGCON);

      if (totalTrades == 0) return 0.0;
      winRatio = (double)totalWins / (double)totalTrades;
      double streakRatio = (maxLoss == 0) ? (double)maxWin : (double)maxWin / (double)maxLoss;
      double avgStreakRatio = (avgLossStreak == 0) ? avgWinStreak : avgWinStreak / avgLossStreak;

      return streakRatio * winRatio * avgStreakRatio;
   }

public:
   static double Calculate(double startingBalance, bool dailyBreachDetected, FitnessParams &p) {
      long totalTrades = TesterStatistics(STAT_TRADES); 
      double netProfit = TesterStatistics(STAT_PROFIT); 
      
      // Early exit if metrics are failing
      if(netProfit <= 0) return -TesterStatistics(STAT_EQUITY_DDREL_PERCENT); 
      
      // --- Frequency Threshold Check ---
      datetime endTime = TimeCurrent(); 
      double totalDays = (double)(endTime - p.globalStartTime) / 86400.0; 
      if(totalDays <= 0.5) totalDays = 1.0;
      double weeks;
      if(p.isCrypto)
         weeks = totalDays / 7.0;
      else  
         weeks = totalDays / 5.0;  
      
      double tradesPerWeek = (double)totalTrades / weeks;

      if(totalTrades < (weeks * p.minTradesPerWeek)) return -tradesPerWeek; 

      // --- Drawdown Breach Check ---
      if(dailyBreachDetected) return -TesterStatistics(STAT_EQUITY_DDREL_PERCENT); 
      double maxEquityDDPercent = TesterStatistics(STAT_EQUITY_DDREL_PERCENT); 
      if(maxEquityDDPercent > p.maxTotalDD) return -TesterStatistics(STAT_EQUITY_DDREL_PERCENT);  

      

      // --- R2 / Regression Logic ---
      double r2 = 0.0;
      int tradeIndex = 0;
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cum = 0;
      
      if(HistorySelect(0, TimeCurrent())) {
         int totalHistory = HistoryDealsTotal();
         for(int i = 0; i < totalHistory; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
               if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == p.magicNumber && 
                  HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                  
                  double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                                     HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                                     HistoryDealGetDouble(ticket, DEAL_SWAP);
                  cum += dealProfit;
                  sumX += tradeIndex;
                  sumY += cum;
                  sumXY += (double)tradeIndex * cum;
                  sumX2 += (double)tradeIndex * tradeIndex;
                  sumY2 += cum * cum;
                  tradeIndex++;
                  
                  if(tradeIndex > 1) {
                     double denominator = MathSqrt(((tradeIndex * sumX2) - (sumX * sumX)) * ((tradeIndex * sumY2) - (sumY * sumY)));
                     r2 = (denominator == 0) ? 0 : MathPow(((tradeIndex * sumXY) - (sumX * sumY)) / denominator, 2.0);
                  }
               }
            }
         }
      }

      // --- Final Scoring ---
      double frequencyPenalty = MathPow(MathMin(1.0, tradesPerWeek / p.minTradesPerWeek), 4.0);
      double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
      double ddDivider = MathMax(1.0, TesterStatistics(STAT_EQUITY_DD));
      double logTrades = MathLog10((double)totalTrades);
      double ddPercentDenominator = MathMax(0.1, p.maxTotalDD);
      double balanceRatio = netProfit / startingBalance;
      
      // Apply chosen metric into the Base Score
      double baseScore = (((profitFactor * (netProfit / ddDivider) * winRatio * r2) * logTrades) / ddPercentDenominator) * balanceRatio * r2;
      
      // --- Metric Selection Logic ---
      double finalScore = baseScore * frequencyPenalty;      
      return finalScore;
   }
   
   static double CalculateWeightedScore(double startingBalance, bool dailyBreachDetected, FitnessParams &p) {
      // 1. Prepare Normalized Components (0.0 to 1.0+ range)
      double mProfit       = 1.0 + (TesterStatistics(STAT_PROFIT) / startingBalance);
      double mPF           = TesterStatistics(STAT_PROFIT_FACTOR) / 5.0; // Normalized vs 5.0 target
      double mPayoff       = 1.0 + (TesterStatistics(STAT_EXPECTED_PAYOFF) / startingBalance);
      double mRecovery     = TesterStatistics(STAT_RECOVERY_FACTOR) / 10.0; // Normalized vs 10.0 target
      double mSharpe       = TesterStatistics(STAT_SHARPE_RATIO) / 3.0;     // Normalized vs 3.0 target
      double mLinearity    = Calculate(startingBalance, dailyBreachDetected, p); 
      double mConsistency  = CalculateConsistency();

      // 2. Additive Weighted Aggregation (The "Good" Stuff)
      double score = (mLinearity   * 0.500) + 
                     (mConsistency * 0.225) + 
                     (mSharpe      * 0.175) +
                     (mProfit      * 0.02)  + 
                     (mPF          * 0.02)  + 
                     (mPayoff      * 0.02)  + 
                     (mRecovery    * 0.02)  + 
                     (1.0          * 0.02); // Placeholder for any remaining weight

      // 3. Multiplicative Gatekeepers (The "Excellence" Penalties)
      // These act as multipliers (0.0 - 1.0). If they are low, the score drops drastically.
      
      // Gate A: MT5 Complex Criterion (0.0 - 1.0 scale)
      double penaltyComplex = TesterStatistics(STAT_COMPLEX_CRITERION) / 100.0;
      
      // Gate B: Drawdown Penalty (Inverse: Lower DD = Higher score)
      // If DD is 0%, multiplier is 1.0. If DD is 20%, multiplier is 0.8.
      double penaltyDD = MathMax(0.0, 1.0 - (TesterStatistics(STAT_EQUITY_DDREL_PERCENT) / 100.0));

      return score * penaltyComplex * penaltyDD;
   }
};