//+------------------------------------------------------------------+
//| SYSTEM: RiskBarrierNode.mqh                                      |
//| ELI5: The "bouncer" node. It doesn't decide rules, it just       |
//|       stops trades that violate the RiskManager's instructions.  |
//+------------------------------------------------------------------+
#ifndef CALC_RISK_BARRIER
#define CALC_RISK_BARRIER

class CRiskBarrierNode {
public:
   // ELI5: This is the actual "Gate" function. If we return true, 
   // the trade is allowed. If false, the trade is blocked.
   bool ValidateExposure(double volume, double limit) {
      if(volume > limit) {
         Print("BARRIER_BLOCK: Trade volume ", volume, " exceeds limit ", limit);
         return false;
      }
      return true;
   }
};
#endif