//+------------------------------------------------------------------+
//| SYSTEM: SystemManifest.mqh                                        |
//| ELI5: Map your existing files here. No renaming required.       |
//+------------------------------------------------------------------+
#ifndef CALC_SYSTEM_MANIFEST
#define CALC_SYSTEM_MANIFEST

class CSystemManifest {
public:
   static int GetExpectedCount() { return 27; } 
   
   static void GetModuleSpecs(string &names[]) {
      ArrayResize(names, 27);
      // Fill these with your ACTUAL filenames
      names[0]="DataManager";      names[1]="MessageBus";       names[2]="GenericIndicator";
      names[3]="IFeature";         names[4]="IndicatorBase";    names[5]="SnRBase";
      names[6]="Integrator";       names[7]="SystemContract";   names[8]="SystemRegistry";
      
      names[9]="FlowEngine";       names[10]="RecursiveNode";   names[11]="FeatureProcessor";
      names[12]="StrategyKernel";  names[13]="CalculusStrategy";names[14]="ProjectionAdapterNode";
      names[15]="TemporalSyncNode";names[16]="EntropyMonitorNode";names[17]="AdaptiveTunerNode";
      
      // Update these to match your specific local filenames
      names[18]="ExecutionEngine"; names[19]="ExitStrategy";    
      names[20]="RiskManagerNode"; names[21]="TopologyManagerNode";
      names[22]="RiskBarrierNode"; names[23]="TelemetryNode";
      names[24]="FitnessEvaluator";names[25]="StructuralAuditor";
      names[26]="SystemOrchestrator";
   }
};
#endif