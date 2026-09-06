// 1. GATEKEEPER: "If we haven't defined 'CALC_MESSAGE_BUS' yet..."
#ifndef CALC_MESSAGE_BUS
// 2. STICKER: "...then define it now so we know we've visited this file."
#define CALC_MESSAGE_BUS

class CMessageBus {
public:
   // The 'Publish' method is like a town crier. 
   // It shouts a message to the logs.
   void Publish(string channel, string message) {
      Print("BUS_EVENT: [", channel, "] -> ", message);
   }
};
// 3. END: "That's the end of the gatekeeper instructions."
#endif