//+-----------------------------------------------------------+
//|  IFeature.mqh                                             |
//+-----------------------------------------------------------+
#include "DataManager.mqh"
#include <Object.mqh>

class IFeature : public CObject {
public:
   virtual double GetValue(MarketData &md) = 0;
   virtual string GetName() = 0;
};