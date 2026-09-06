//+------------------------------------------------------------------+
//| SYSTEM SPECIFICATION: EntropyMonitorNode                         |
//|                                                                  |
//| [SYSTEM INTENT]:                                                 |
//|    To act as a gatekeeper that checks if incoming market data is  |
//|    smooth or chaotic before letting it into the main strategy.   |
//|                                                                  |
//| [CONTRACT]:                                                      |
//|    INPUT:  A list (stream) of recent price points.               |
//|    OUTPUT: A single number representing the 'noise level'.       |
//|            (Higher number = more messy/jittery data).            |
//|                                                                  |
//| [ALGORITHM NARRATIVE]:                                           |
//|    1. Look at the whole list of price numbers we have saved.     |
//|    2. If we don't have at least two numbers, we can't compare,   |
//|       so we call it 'zero noise'.                                |
//|    3. Take the newest price and the oldest price in our list.    |
//|    4. Calculate the difference between them. If the price jumped |
//|       wildly from the start to the end, we flag it as noise.     |
//|    5. Pass this 'noise score' to the strategy so it knows        |
//|       whether to trust the data or wait for a calmer market.     |
//+------------------------------------------------------------------+
#ifndef CALC_SANITY_MONITOR // If we haven't seen this file before
#define CALC_SANITY_MONITOR // Define it.

class CEntropyMonitorNode { // I'm not really sure how a class is different from a struct. I know a struct doesn't have public and private data.
public: // Available to any program that calls it.
   // Implementation: Calculates the raw difference between the oldest
   // and newest data points to estimate market jitter.
   double GetNoiseLevel(double &dataStream[]) { //double, for precision? Decimals.
      int size = ArraySize(dataStream); //int, integer, counting number.
      
      // Safety: If there isn't enough data, we cannot determine noise.
      if(size < 2) return 0.0; // So, like jackasses, we tell the system there is zero noise, instead of throwing an error or a NaN or a NULL or whatever
      
      // Core Logic: The difference between the start and end of the buffer.
      return MathAbs(dataStream[size-1] - dataStream[0]); // We tell the system the mathematical absolute value (size) of the difference.
   }
};
#endif //Yeah, I don't know how to annotate this one.