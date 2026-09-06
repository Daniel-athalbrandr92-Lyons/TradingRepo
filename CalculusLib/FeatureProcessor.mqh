//+------------------------------------------------------------------+
//| SYSTEM SPECIFICATION: FeatureProcessor                           |
//|                                                                  |
//| [SYSTEM INTENT]:                                                 |
//|    To collect different "features" (market signals), clean them  |
//|    up, and put them into a neat list for the Brain to use.       |
//|                                                                  |
//| [CONTRACT]:                                                      |
//|    INPUT:  Raw market data box (MarketData).                     |
//|    OUTPUT: A list (vector) of numbers ready for analysis.        |
//|                                                                  |
//| [ALGORITHM NARRATIVE]:                                           |
//|    1. We have a special list (CArrayObj) where we keep our tools.|
//|    2. We allow other parts of the system to add tools to this    |
//|       list (like adding a ruler or a thermometer).               |
//|    3. When we need the data, we ask every tool in the list to    |
//|       give us its number.                                        |
//|    4. We put all those numbers in a row and hand them over.      |
//+------------------------------------------------------------------+
#ifndef CALC_FEATURE_PROCESSOR // "Hey, have we named this file yet?"
#define CALC_FEATURE_PROCESSOR // "No? Okay, let's name it now."

#include "IFeature.mqh" // We need to include the feature's file in order to process it.
#include <Arrays\ArrayObj.mqh> // I'm not sure how to annotate this one. Passing the torch. 

// A class is like a struct, but it's smarter because it can hold
// functions (methods) that actually "do" stuff with the data inside.
class CFeatureProcessor {
private: // Only for this program.
   // CArrayObj is a special list made by the platform to hold "Objects".
   // It's like a backpack for our feature tools.
   CArrayObj m_features;

public: //For everyone!
   // The tilde (~) is the "Destructor". It's garbage day.
   // When we're done with this class, we need to empty the backpack
   // so we don't clog up the computer's memory.
   ~CFeatureProcessor() { m_features.Clear(); }

   // We pass a pointer (*). Think of a pointer as a sticky note
   // that says "The tool is over there," instead of carrying the whole tool.
   void AddFeature(IFeature* feature) { // Why is it a void?
      m_features.Add(feature); // Okay, so we're adding a feature.
   }

   // double &results[]: The '&' means "reference". 
   // We aren't making a copy of the results, we are just giving
   // the system a direct line to the results list.
   bool GetVector(MarketData &md, double &results[]) { // bool = yes or no?
      int count = m_features.Total(); // How many tools are in our backpack?
      
      // Resizing the list to fit all our numbers.
      if(ArrayResize(results, count) != count) return false; // if the new size of the array doesn't match the count, no
      
      // A loop! We go through every tool in the backpack, 
      // ask it for its number, and put it in our results list.
      for(int i = 0; i < count; i++) { // Why are for loop components separated by semicolon instead of commas?
         // (IFeature*) is "Casting". We're telling the computer:
         // "Trust me, this object in the backpack is a Feature tool."
         IFeature* f = (IFeature*)m_features.At(i); // f is the feature.
         results[i] = f.GetValue(md); // Not entirely sure how to explain this one, either. 
      }
      return true; // Yes!
   }
};

#endif // That's it. We're done with the file.