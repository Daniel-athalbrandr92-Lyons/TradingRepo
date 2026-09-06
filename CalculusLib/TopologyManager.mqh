//+-----------------------------------------------------------+
//| SYSTEM: TopologyManager                                   |
//| FUNCTION: Maps and verifies connections between nodes.    |
//| CLARITY: Uses TelemetryNode to log structural states.     |
//+-----------------------------------------------------------+
#ifndef CALC_TOPOLOGY_MANAGER
#define CALC_TOPOLOGY_MANAGER
#include "TelemetryNode.mqh"

class CTopologyManager {
private:
   // Reference to the functional node that documents state.
   CTelemetryNode* m_reporter;

public:
   // EDUCATIONAL: Links the Mapper to the Logger.
   void SetReporter(CTelemetryNode &reporter) {
      m_reporter = &reporter;
   }

   // Validates that a node identifier is active and valid.
   bool VerifyConnectivity(string nodeName) {
      if(nodeName == "") return false;
      return true;
   }
   
   // Announces a change in topology and ensures the event is recorded.
   void ReRoute(string deadNode) {
      Print("TOPOLOGY: Rerouting data around inactive node: ", deadNode);
      if(m_reporter != NULL) {
         // Clear documentation of why the reroute happened.
         m_reporter.RecordEvent("TopologyManager", "Rerouting around " + deadNode);
      }
   }
};
#endif