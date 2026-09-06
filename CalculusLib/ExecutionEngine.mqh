//+------------------------------------------------------------------+
//| COMPONENT: ExecutionEngine                                       |
//| PURPOSE: The "Dispatcher." Manages the full lifecycle of a trade.|
//| INTERFACE: Accepts an IExitStrategy object (The "Exit Logic").   |
//+------------------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>
#include "ExitStrategy.mqh"

interface IExecutionEngine {
   ulong SendOrder(string symbol, ENUM_ORDER_TYPE type, double volume);
   void  UpdateActiveExits(); 
   bool  CheckRiskConstraints(double current_drawdown);
};

class CExecutionEngine : public IExecutionEngine {
private:
   CTrade trade;
   double max_drawdown_limit;
   long   m_magic;
   IExitStrategy* m_strategy;

public:
   CExecutionEngine(long magic, double dd_limit = 0.05) 
      : m_magic(magic), max_drawdown_limit(dd_limit), m_strategy(NULL) { trade.SetExpertMagicNumber(m_magic); }

   CTrade* GetTradeObject() { return &trade; }

   // Dependency Injection: Inject any exit strategy (Trailing, Hard SL, etc.)
   void SetExitStrategy(IExitStrategy* strategy) { m_strategy = strategy; }

   bool CheckRiskConstraints(double current_drawdown) {
      return (current_drawdown < max_drawdown_limit);
   }
   
   bool IsMyPositionOpen(string symbol, ulong magic)
   {
    // Loop through all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // Only care if it matches MY symbol AND MY magic number
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == magic)
            {
                return true;
            }
        }
    }
    return false;
   }

   ulong SendOrder(string symbol, ENUM_ORDER_TYPE type, double volume) {
      bool success = (type == ORDER_TYPE_BUY) ? trade.Buy(volume, symbol) : trade.Sell(volume, symbol);
      if(success) {
         ulong ticket = trade.ResultOrder();
         if(m_strategy != NULL) m_strategy.ApplyExit(ticket);
         return ticket;
      }
      return 0;
   }

   void UpdateActiveExits() {
      if(m_strategy == NULL) return;
      // Iterates through all trades; if owned by this magic number, manage the exit.
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == m_magic) {
         Print("Debug: Checking ticket ", ticket, " | Magic: ", PositionGetInteger(POSITION_MAGIC));
            m_strategy.UpdateExit(ticket);
         }
      }
   }
   
   void CloseAllPositions(string symbol) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)){
            // Verify ownership via MagicNumber
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == m_magic) {
               trade.PositionClose(ticket);
            }
         }
      }
   }
};