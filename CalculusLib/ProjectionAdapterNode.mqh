//+-----------------------------------------------------------+
//| SYSTEM: ProjectionAdapterNode.mqh                         |
//| ELI5: The Translator. Simplifies complex math for action. |
//+-----------------------------------------------------------+
class CProjectionAdapterNode {
public:
   // Maps a multi-dimensional feature value into a single decision scalar
   double Project(double tensorValue) {
      // Normalization: Squeezing high-dim data into a 0.0 to 1.0 range
      return MathMin(MathMax(tensorValue, 0.0), 1.0);
   }
};