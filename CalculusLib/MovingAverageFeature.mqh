//+-----------------------------------------------------------+
//|  MovingAverageFeature.mqh                                 |
//+-----------------------------------------------------------+
#include "IndicatorBase.mqh"

class CMovingAverageFeature : public CIndicatorBase {
private:
   int m_period;
   string m_symbol;

public:
   // Now accepts Method and Applied Price for proper optimization
   CMovingAverageFeature(string symbol, int period, ENUM_MA_METHOD method, ENUM_APPLIED_PRICE price) 
      : m_symbol(symbol), m_period(period) {
      m_handle = iMA(m_symbol, _Period, m_period, 0, method, price);
   }

   double GetValue(MarketData &md) override {
      return FetchLastValue();
   }

   string GetName() override { return "SMA_" + IntegerToString(m_period); }
};