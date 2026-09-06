//+------------------------------------------------------------------+
//| SYSTEM: CalculusLib                                              |
//| MODULE: SystemRegistry                                           |
//| ELI5: The Clipboard. It remembers who is in the team.           |
//+------------------------------------------------------------------+
#ifndef CALC_SYSTEM_REGISTRY
#define CALC_SYSTEM_REGISTRY

class CSystemRegistry {
private:
   // ELI5: An internal list to hold the names of our 27 team members.
   static string m_registry[];

public:
   // ELI5: Add a new member to our list.
   static void Register(string name) {
      int size = ArraySize(m_registry);
      ArrayResize(m_registry, size + 1);
      m_registry[size] = name;
   }

   // ELI5: Clear the list at the start of every day.
   static void Clear() {
      ArrayFree(m_registry);
   }

   // ELI5: The bouncer uses this to count heads. Returns total registered.
   static int Total() {
      return ArraySize(m_registry);
   }
};

// Initialize the static registry array
string CSystemRegistry::m_registry[];

#endif