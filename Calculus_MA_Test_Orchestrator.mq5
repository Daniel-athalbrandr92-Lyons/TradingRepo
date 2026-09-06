                                                                                                                                   /*| /Calculus_MA_Test_Orchestrator_2.mq5                                  /*
                                                                                                                                  /*| /Daniel Lyons (strategy/conceptual), Google's Gemini (refinement/code)/*
                                                                                                                                 /*| /[https://github.com/athalbrandr92/Trading]                           /*
                                                                                                                                /*|*/                                                                     /*
                                                                                                                               /*|*/#property copyright "Daniel Lyons / Google Gemini"                   /*
                                                                                                                              /*|*/#property link      "[https://github.com/athalbrandr92/Trading]"     /*
                                                                                                                             /*|*/#property version   "2.02"                                           /*
                                                                                                                            /*|*/#property strict                                                     /*
                                                                                                                           /*|*/                                                                     /*
                                                                                                                          /*|*/#include <Trade\Trade.mqh>                                           /*
                                                                                                                         /*|*/#include <CalculusLib\CalculusStrategy.mqh>                          /*
                                                                                                                        /*|*/#include <CalculusLib\RiskManager.mqh>                               /*
                                                                                                                       /*|*/#include <CalculusLib\ExecutionEngine.mqh>                           /*
                                                                                                                      /*|*/#include <CalculusLib\FitnessEvaluator.mqh>                          /*
                                                                                                                     /*|*/#include <CalculusLib\GeometricExit.mqh>                             /*
                                                                                                                    /*|*/#include <Indicators\CustomTools\Aggregator.mqh>                     /*
                                                                                                                   /*|*/#include <Indicators\CustomTools\HMA_Module.mqh>                     /*
                                                                                                                  /*|*/#include <Indicators\CustomTools\StdDev_HMA.mqh>                     /*
                                                                                                                 /*|*/#include <Indicators\CustomTools\TR.mqh>                             /*
                                                                                                                /*|*/                                                                     /*
                                                                                                               /*|*/input group "--- Money Management ---"                               /*
                                                                                                              /*|*/input bool   InpUseDynamicRisk  = true;                              /*
                                                                                                             /*|*/input double InpRiskPercent     = 1.0;                               /*
                                                                                                            /*|*/input double InpFixedLotSize    = 0.1;                               /*
                                                                                                           /*|*/input ulong  InpMagicNumber     = 20260609;                          /*
                                                                                                          /*|*/input group "--- Weighted Decision Thresholds ---"                   /*
                                                                                                         /*|*/input double InpDecisionThreshold = 1.5;                             /*
                                                                                                        /*|*/input double InpVelThreshold      = 1.5;                             /*
                                                                                                       /*|*/input double InpVelMult           = 1.5;                             /*
                                                                                                      /*|*/input double InpAccThreshold      = 1.5;                             /*
                                                                                                     /*|*/input double InpAccMult           = 1.5;                             /*
                                                                                                    /*|*/input double InpNormalAcc         = 1.5;                             /*
                                                                                                   /*|*/input double InpJerkThreshold     = 1.5;                             /*
                                                                                                  /*|*/input double InpJerkMult          = 1.5;                             /*
                                                                                                 /*|*/input double InpSnapThreshold     = 1.5;                             /*
                                                                                                /*|*/input double InpSnapMult          = 1.5;                             /*
                                                                                               /*|*/input double InpCrackleThreshold  = 1.5;                             /*
                                                                                              /*|*/input double InpCrackleMult       = 1.5;                             /*
                                                                                             /*|*/input double InpPopThreshold      = 1.5;                             /*
                                                                                            /*|*/input double InpPopMult           = 1.5;                             /*
                                                                                           /*|*/input double InpAssymetryMult     = 1.5;                             /*
                                                                                          /*|*/input int    InpLookback          = 14;                              /*
                                                                                         /*|*/input group "--- Operational Risk Filters ---"                       /*
                                                                                        /*|*/sinput bool       InpUseHolidayFilter = true;                        /*
                                                                                       /*|*/input int        InpBlackoutStartDay = 20;                           /*
                                                                                      /*|*/input int        InpBlackoutEndDay   = 3;                            /*
                                                                                     /*|*/                                                                     /*
                                                                                    /*|*/input group "--- Prop Firm Guardrails ---"                           /*
                                                                                   /*|*/input double     InpMaxDailyDDPercent = 5.0;                         /*
                                                                                  /*|*/input double     InpMaxTotalDDPercent = 10.0;                        /*
                                                                                 /*|*/input double     InpMinTradesPerWeek  = 2.0;                         /*                                                                               /*|*/
                                                                                /*|*/input group "--- Importance Weights ---"                             /*
                                                                               /*|*/input double W_Vel = 1.0; input double W_Acc = 1.0;                  /*
                                                                              /*|*/input double W_Jerk = 1.0; input double W_Snap = 1.0;                /*
                                                                             /*|*/input double W_Crackle = 1.0; input double W_Pop = 1.0;              /*
                                                                            /*|*/                                                                     /*
                                                                           /*|*/CAggregator_Module* aggEngine; CHMA_Module* hmaEngine_Agg;           /*
                                                                          /*|*/CTR_Module* trEngine; CHMA_Module* hmaEngine_TR;                     /*
                                                                         /*|*/CStdDev_Module* stdDevEngine; CHMA_Module* hmaEngine_Sd;             /*
                                                                        /*|*/CCalculusStrategy* g_strategy; CRiskManager* g_risk;                 /*
                                                                       /*|*/CExecutionEngine* g_execution;                                       /*
                                                                      /*|*/                                                                     /*
                                                                     /*|*/ int OnInit()                                                        /*
                                                                    /*|*/{                                                                    /*
                                                                   /*|*/   aggEngine = new CAggregator_Module(InpLookback);                  /*
                                                                  /*|*/   hmaEngine_Agg  = new CHMA_Module(InpLookback);                    /*
                                                                 /*|*/   trEngine       = new CTR_Module();                                /*
                                                                /*|*/   hmaEngine_TR   = new CHMA_Module(InpLookback);                    /*
                                                               /*|*/                                                                     /*
                                                              /*|*/   stdDevEngine   = new CStdDev_Module(InpLookback);                 /*
                                                             /*|*/   hmaEngine_Sd   = new CHMA_Module(InpLookback);                    /*
                                                            /*|*/   g_strategy     = new CCalculusStrategy();                         /*
                                                           /*|*/   g_risk         = new CRiskManager(InpRiskPercent);                 /*
                                                       /*|*/   g_execution    = new CExecutionEngine(                            /*
                                                      /*|*/                    InpMagicNumber, InpRiskPercent);                 /*
                                                     /*|*/                                                                     /*
                                                    /*|*/   return(INIT_SUCCEEDED);                                           /*
                                                   /*|*/}                                                                    /*
                                                  /*|*/                                                                     /*
                                                 /*|*/void OnTick()                                                        /*
                                                /*|*/{                                                                    /*
                                               /*|*/   double o[], h[], l[], c[]; MqlRates rates[];                      /*
                                              /*|*/   if(CopyRates(_Symbol, _Period, 0, InpLookback, rates) <           /*
                                             /*|*/   InpLookback)                                                      /*
                                            /*|*/       return;                                                       /*
                                           /*|*/   ArrayResize(o, InpLookback); ArrayResize(h, InpLookback);         /*
                                          /*|*/   ArrayResize(l, InpLookback); ArrayResize(c, InpLookback);         /*
                                         /*|*/   for(int i=0; i < InpLookback; i++)                                /*
                                        /*|*/   { o[i] = rates[i].open; h[i] = rates[i].high;                     /*
                                       /*|*/   l[i] = rates[i].low; c[i] = rates[i].close; }                     /*
                                      /*|*/                                                                     /*
                                     /*|*/   AggData packet;                                                   /*
                                    /*|*/   aggEngine.Calculate(o, h, l, c, packet, InpLookback-1);           /*
                                   /*|*/   double hma_agg_val[], hma_tr_val[], hma_sd_val[], src_agg[],      /*
                                  /*|*/   src_tr[], src_sd[];                                               /*
                                 /*|*/   ArrayResize(src_agg, InpLookback); src_agg[0] = packet.ohlc4;     /*
                                /*|*/   hmaEngine_Agg.Calculate(src_agg, hma_agg_val);                    /*
                               /*|*/   double tr = trEngine.Calculate(packet, c[InpLookback-2]);         /*
                              /*|*/   ArrayResize(src_tr, InpLookback); src_tr[0] = tr;                 /*
                             /*|*/   hmaEngine_TR.Calculate(src_tr, hma_tr_val);                       /*
                            /*|*/   double sd; stdDevEngine.Calculate(hma_agg_val, sd);               /*
                           /*|*/   ArrayResize(src_sd, InpLookback); src_sd[0] = sd;                 /*
                          /*|*/   hmaEngine_Sd.Calculate(src_sd, hma_sd_val);                       /*
                         /*|*/                                                                     /*
                        /*|*/   double data[6] = {                                                /*
                       /*|*/      packet.ohlc4,                                                  /*
                      /*|*/      (hma_agg_val[0] / InpVelThreshold) * W_Vel * InpVelMult,       /*
                     /*|*/      (tr / InpAccThreshold) * W_Acc * InpAccMult,                   /*
                    /*|*/      (hma_tr_val[0] / InpJerkThreshold) * W_Jerk * InpJerkMult,     /*
                   /*|*/      (sd / InpSnapThreshold) * W_Snap * InpSnapMult,                /*
                  /*|*/      (hma_sd_val[0] / InpCrackleThreshold) * W_Crackle *            /*
                 /*|*/      InpCrackleMult                                                 /*
                /*|*/   };                                                                /*
               /*|*/                                                                     /*
              /*|*/   string signal = g_strategy.Analyze(data);                         /*
             /*|*/   if(signal == "BUY" || signal == "SELL") {                         /*
            /*|*/       double lotSize =                                              /*
           /*|*/       g_risk.CalcLot(g_strategy.GetVelocity(1));                     /*
         /*|*/       g_execution.SendOrder(_Symbol, (signal == "BUY") ?            /*
        /*|*/       ORDER_TYPE_BUY : ORDER_TYPE_SELL, lotSize);                   /*
       /*|*/   }                                                                 /*
      /*|*/   else if(signal == "EXIT") {                                       /*
     /*|*/      g_execution.CloseAllPositions(_Symbol);                        /*
    /*|*/   }                                                                 /*
   /*|*/}                                                                    /*
  /*|*/                                                                     /*
 /*|\/\/\**Open**\/                                    \/\/\/\**Protocol**\/*
/*|**Autonomous**\/                                    /\/\/\/\/\**Node**\/*
\*       Consent/*                                     \/\/\**Protocol**\/*
 \*   Universal/*                                      /\**Sustenance**\/*
  \*     Value/*                                       \/\/**Routing**\/*
   \*Balanced/*                                        /\**Shared**\/\/*
    \*Exergy/*                                         \**Pipeline**\/*