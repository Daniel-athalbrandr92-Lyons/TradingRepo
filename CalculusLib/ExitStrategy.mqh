//+----------------------------------------------------------+
//|  ExitStrategy.mqh                                        |
//|  Protocol: JC/AC                                         |
//+----------------------------------------------------------+
#property strict
#include <Trade\Trade.mqh>

interface IExitStrategy {
    void ApplyExit(ulong ticket);  // Called immediately after order entry
    void UpdateExit(ulong ticket); // Called every tick (for trailing/calculus)
    string GetName();
};

// Base class for logic that requires a hard SL/TP "Safety Net"
class CExitBase : public IExitStrategy {
protected:
    CTrade* m_trade;
    double  m_slPoints;
    double  m_tpPoints;
public:
    CExitBase(CTrade &trade, double sl, double tp) : m_trade(&trade), m_slPoints(sl), m_tpPoints(tp) {}
    
    // Default implementation: Applies standard SL/TP
    virtual void ApplyExit(ulong ticket) {
        if(PositionSelectByTicket(ticket)) {
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? price - m_slPoints * _Point : price + m_slPoints * _Point;
            double tp = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? price + m_tpPoints * _Point : price - m_tpPoints * _Point;
            m_trade.PositionModify(ticket, sl, tp);
        }
    }
    
    virtual void UpdateExit(ulong ticket) = 0;
};