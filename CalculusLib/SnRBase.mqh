//+------------------------------------------------------------------+
//|                                                    SnRBase.mqh   |
//|      Copyright (c) 2026, Daniel Lyons & Google's Gemini AI       |
//|      ------------------------------------------------------      |
//|      Conceptual Architect: Daniel Lyons                          |
//|      Technical Implementation: Google's Gemini AI                |
//|                                                                  |
//|      This header defines the structural contract for the         |
//|      Modular Support & Resistance system. All pattern-scanning   |
//|      modules must implement ISnRModule to ensure compatibility   |
//|      with the broader outward-scaling ecosystem.                 |
//+------------------------------------------------------------------+
#property library
#property copyright "Google's Gem & I"

// --- Structural Hierarchies ---
// Tier defines the "Gravity" or significance of a zone. 
// Major levels typically represent higher-timeframe or systemic obstacles.
enum ZoneTier { Minor, Mid, Major };

// --- Zone Structure ---
// Represents a discrete horizontal price region.
// Used as the primary data exchange format between independent modules.
struct Zone { 
    double Top;    // Upper boundary of the S&R zone
    double Bottom; // Lower boundary of the S&R zone
    ZoneTier Tier; // Hierarchical significance
    bool Active;   // Logic toggle for module cleanup
};

// --- ISnRModule (The Architectural Contract) ---
// Any module aiming to contribute to the market analysis (e.g., OBs, 
// Psych Levels, Rejections) must conform to this interface. This 
// decouples the scanning logic from the storage and drawing mechanisms.
class ISnRModule {
public:
    // Every module is provided a snapshot of the current bar context.
    // [in] highs, lows, closes, opens: Array buffers of current timeframe
    // [in] atr: The current volatility context (for dynamic zone sizing)
    virtual void Calculate(double &highs[], double &lows[], double &closes[], double &opens[], double atr) = 0;
    
    // Destructor to ensure clean memory management when modules are discarded
    virtual ~ISnRModule() {}
};