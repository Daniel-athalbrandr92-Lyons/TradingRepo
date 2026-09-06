//+-------------------------------------------------------------------------+
//|                                                   IndicatorLibrary.mqh  |
//|  Daniel Lyons (strategy/conceptual), Google's Gemini (refinement/code)  |
//|                             [https://github.com/athalbrandr92/Trading]  |
//+-------------------------------------------------------------------------+
#ifndef INDICATOR_LIBRARY_MQH
#define INDICATOR_LIBRARY_MQH
#property copyright "Daniel Lyons / Google Gemini"
#property link      "[https://github.com/athalbrandr92/Trading]"
#property strict

enum ENUM_INDICATOR_TYPE { IND_AGGREGATOR, IND_HMA, IND_TR, IND_STDDEV_HMA };

// Update IndicatorLibrary.mqh
int GetHandle(ENUM_INDICATOR_TYPE type, int lookback, int handle1 = 0, int handle2 = 0, int buffer1 = 0) {
    // If lookback is passed as 0, force a default to prevent division errors
    int safeLookback = (lookback > 0) ? lookback : 14; 
    
    switch(type) {
        case IND_AGGREGATOR: return iCustom(_Symbol, _Period, "CustomTools\\Aggregator", safeLookback);
        case IND_HMA:        return iCustom(_Symbol, _Period, "CustomTools\\HMA", safeLookback, handle1, buffer1);
        case IND_TR:         return iCustom(_Symbol, _Period, "CustomTools\\TR", handle1); // TR usually doesn't need lookback
        case IND_STDDEV_HMA: return iCustom(_Symbol, _Period, "CustomTools\\StdDev_HMA", safeLookback, handle1, buffer1, handle2);
        default: return INVALID_HANDLE;
    }
}
#endif