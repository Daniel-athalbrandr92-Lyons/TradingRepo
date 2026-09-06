//+-----------------------------------------------------------+
//| SYSTEM: CalculusLib                                       |
//| MODULE: StructuralAuditor                                 |
//| ELI5: The Bouncer's Checklist. It needs to ask the right  |
//|       question to get the count of the guests inside.     |
//+-----------------------------------------------------------+
#ifndef CALC_STRUCTURAL_AUDITOR
#define CALC_STRUCTURAL_AUDITOR

#include "SystemRegistry.mqh"
#include "SystemManifest.mqh"

class CStructuralAuditor {
public:
   // ELI5: The Auditor verifies the headcount matches the manifest.
   static bool AuditSystem() {
      // Use the 'Total' method that we defined in SystemRegistry
      int active = CSystemRegistry::Total();
      int expected = CSystemManifest::GetExpectedCount();
      
      if(active != expected) {
         Print("STRUCTURAL_ERROR: Grid imbalance detected. Active: ", active, " Expected: ", expected);
         return false;
      }
      
      Print("STRUCTURAL_SUCCESS: 3x3x3 Equilibrium verified.");
      return true;
   }
};
#endif