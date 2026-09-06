//+------------------------------------------------------------------+
//| SYSTEM: CalculusLib                                              |
//| MODULE: SentinelNodes                                            |
//| ELI5: These are the "Guardians" of our robot team.               |
//|       They watch, remember, and make sure we don't crash.        |
//+------------------------------------------------------------------+
#ifndef CALC_SENTINELS
#define CALC_SENTINELS

// The Risk Guardian: Checks if a trade is too big or too dangerous.
class CRiskBarrierNode {
public:
   // ELI5: Before we make a trade, we ask this node: "Is this safe?"
   bool ValidateExposure(double volume) { 
      if(volume > 1.0) return false; 
      return true; 
   }
};

// The Telemetry Guardian: Takes notes on how the system is feeling.
class CTelemetryNode {
public:
   // ELI5: Like a diary, it writes down what the system is doing so we can read it later.
   void Stream(string status) { 
      Print("SYSTEM_HEALTH: ", status); 
   }
};

// The Persistence Guardian: Has a perfect memory.
class CContextPersistenceNode {
public:
   // ELI5: If the computer turns off, this node saves everything we know so we can start exactly where we left off.
   void Serialize() { 
      Print("MEMORY: State snapshot saved."); 
   }
};

// The Governance Guardian: The Boss that decides if we need to change how we work.
class CMetaGovernanceNode {
public:
   // ELI5: If our robot team isn't making money, this node tells everyone to change their strategy.
   void MonitorFitness(double score) { 
      if(score < 0.5) Print("GOVERNANCE: Switching to safe mode."); 
   }
};
#endif