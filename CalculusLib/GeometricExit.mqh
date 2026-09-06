#include "ExitStrategy.mqh"
#include "FlowEngine.mqh"
#include <Trade\Trade.mqh>

class CGeometricExit : public IExitStrategy {
private:
    CFlowEngine* m_engine;
    CTrade* m_trade;

public:
    // Pass the engine AND the trade object to handle the closure
    CGeometricExit(CFlowEngine* engine, CTrade* trade) 
        : m_engine(engine), m_trade(trade) {}
    
    void ApplyExit(ulong ticket) override { /* No entry-specific logic needed */ }
    
    string GetName() override { return "GeometricExit"; }

    void UpdateExit(ulong ticket) override {
    // 1. DEFENSIVE CHECK: Prevent the crash
    if(m_trade == NULL) {
        Print("CRITICAL: CGeometricExit m_trade is NULL. Ensure GetTradeObject() returns a valid reference!");
        return;
    }

    if(!PositionSelectByTicket(ticket)) return;
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double vol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN); 
    
    CFlowEngine::FlowState state = m_engine.GetFlowState(vol);
    ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

    // 2. Geometric Exit Logic
    if(type == POSITION_TYPE_BUY && state.Acceleration < 0.0 && state.Jerk < 0.0 && state.Snap < 0.0)
        m_trade.PositionClose(ticket);
    else if(type == POSITION_TYPE_SELL && state.Acceleration > 0.0 && state.Jerk > 0.0 && state.Snap > 0.0)
        m_trade.PositionClose(ticket);
   }
};