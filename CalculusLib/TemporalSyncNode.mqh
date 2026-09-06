//+-----------------------------------------------------------+
//| SYSTEM: TemporalSyncNode.mqh                              |
//| ELI5: The Clock Keeper. Syncs the past with the present.  |
//+-----------------------------------------------------------+
class CTemporalSyncNode {
public:
   // Ensures the MovingAverage time-series matches the current Tick
   bool Align(datetime historicalTime, datetime currentTick) {
      // If the difference is too large, we are looking at old, stale data
      return (currentTick - historicalTime) < 300; // 5 minute limit
   }
};