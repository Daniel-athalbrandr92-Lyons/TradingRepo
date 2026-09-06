//+-----------------------------------------------------------+
//|  StrategyKernel.mqh (Decoupled)                           |
//+-----------------------------------------------------------+
#include "SystemContract.mqh"
#include "MessageBus.mqh"
#include "IStrategy.mqh"

class CStrategyKernel {
private:
   CMessageBus* m_bus;
   IStrategy* m_strategy; // The Strategy being executed

public:
   CStrategyKernel() : m_strategy(NULL) { 
      m_bus = new CMessageBus(); 
   }
   
   ~CStrategyKernel() { delete m_bus; }

   // Inject the strategy (e.g., CCalculusMAStrategy or CIndicatorStrategy)
   void SetStrategy(IStrategy* strategy) { m_strategy = strategy; }

   string Analyze(MarketData &md) {
      if(m_strategy == NULL) return "HOLD";
      return m_strategy.Analyze(md);
   }
};