//+-----------------------------------------------------------+
//|  GenericIndicator.mqh                                     |
//|  One class to rule them all.                              |
//+-----------------------------------------------------------+
#include "IndicatorBase.mqh"

class CGenericIndicator : public CIndicatorBase {
private:
   string m_name;

public:
   // Pass the handle created in the Orchestrator
   CGenericIndicator(string name, int handle) : m_name(name) {
      m_handle = handle;
   }

   double GetValue(MarketData &md) override {
      return FetchLastValue();
   }

   string GetName() override { return m_name; }
};