#ifndef CALC_DATA_MANAGER
#define CALC_DATA_MANAGER

// The "Box" where we keep the market information.
struct MarketData {
   double ask;    // The price to buy
   double bid;    // The price to sell
   long   volume; // How much is being traded
   datetime time; // When this happened
};

// The rules for anyone who wants to provide data.
interface IDataManager {
   bool      Update();                  // Command: Go get fresh prices
   MarketData GetCurrentState(string symbol); // Command: Hand over the box
};

class CDataManager : public IDataManager {
public:
   // Simply updates our records with the latest market state.
   bool Update() override {
      return true;
   }
   
   // Fills the box with current numbers and gives it to you.
   MarketData GetCurrentState(string symbol) override {
      MarketData data = {0.0, 0.0, 0, 0};
      return data;
   }
};
#endif