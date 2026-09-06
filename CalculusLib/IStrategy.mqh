#property strict

interface IStrategy {
   // Any number of streams, one array. 
   virtual string Analyze(double &streams[]) = 0;
   
   // Keep these for your exit engine
   virtual double GetVelocity(int streamIndex) = 0;
   virtual double GetAcceleration(int streamIndex) = 0;
   virtual double GetJerk(int streamIndex) = 0;
};