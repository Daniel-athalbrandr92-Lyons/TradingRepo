//+------------------------------------------------------------------+
//| SYSTEM SPECIFICATION: AdaptiveTunerNode                          |
//|                                                                  |
//| [SYSTEM INTENT]:                                                 |
//|    To act as a "Learning" node. It watches how well the system   |
//|    is performing and makes small tweaks to our settings if       |
//|    things are running poorly.                                    |
//|                                                                  |
//| [CONTRACT]:                                                      |
//|    INPUT:  fitnessScore (The "Grade" we get for performance).    |
//|            variableToTune (The specific setting we want to fix). |
//|    OUTPUT: None (It changes the setting directly).               |
//|                                                                  |
//| [ALGORITHM NARRATIVE]:                                           |
//|    1. Check the performance score (the "fitness").               |
//|    2. If the score is low (below 0.5), the system is failing.    |
//|    3. We nudge our variable (the setting) up by 5% to see if     |
//|       this helps the score improve in the next round.            |
//|    4. We keep a log of this change so we can see what happened.  |
//+------------------------------------------------------------------+
#ifndef CALC_ADAPTIVE_TUNER // "Have we read this file before?"
#define CALC_ADAPTIVE_TUNER // "No? Keep track of it so we don't load it twice."

class CAdaptiveTunerNode { // A self-directing struct, box, folder, body.
public: // These functions are public, meaning other files can use them.

   // "void" means: "Do this job, but don't bother sending a report back."
   // We use void here because we are modifying the setting directly, 
   // not asking for a calculation result.
   //
   // double &variableToTune: The '&' is the "Direct Link".
   // It means we aren't editing a copy of the variable; we are going
   // straight to the source and changing the real thing.
   void Evolve(double fitnessScore, double &variableToTune) { // Evolve, because that's what adaptive tuners do. What living, thinking beings do. Now I'm wondering about plant thoughts...
      
      // "if" is our fork in the road.
      if(fitnessScore < 0.5) { // if ya ain't fit...
         
         // variableToTune *= 1.05: This is shorthand for 
         // "Take the current value and multiply it by 1.05."
         variableToTune *= 1.05; // ...tune your variables.
         
         // Print: This writes a message to our status log. 
         // It helps us keep a paper trail of what the system "learned."
         Print("ADAPTIVE: Settings adjusted to improve performance. New value: ", variableToTune); //Ya know, so others can read it, too.
      }
   }
};

#endif // The Gatekeeper closes.