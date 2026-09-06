using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;
using cAlgo.API.Indicators;
using cAlgo.Indicators; // Required to see the Indicator's classes

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class RangeBreakoutV27Reverted : Robot
    {
        // --- 1. TIME SETTINGS ---
        [Parameter("Start Time (hour)", DefaultValue = 9, MinValue = 0, MaxValue = 23, Step = 1, Group = "1. Time")] 
        public int StartTime { get; set; }
        [Parameter("End Time (hour)", DefaultValue = 9, MinValue = 0, MaxValue = 23, Group = "1. Time")] 
        public int EndTime { get; set; }
        [Parameter("Open Range Minute", DefaultValue = 0, MinValue = 0, MaxValue = 59, Group = "1. Time")] 
        public int OpenRangeMin { get; set; }

        // --- 2. STRATEGY SETTINGS ---
        [Parameter("Lookback Bars", DefaultValue = 12, MinValue = 1, MaxValue = 90, Group = "2. Strategy")] 
        public int LookbackBars { get; set; }
        [Parameter("Risk Percentage", DefaultValue = 1.0, MinValue = 0.1, MaxValue = 4.9, Step = 0.1, Group = "2. Risk Management")] 
        public double Risk { get; set; }
        [Parameter("Max Dollar Risk", DefaultValue = 1000.0, Group = "2. Strategy")] 
        public double MaxDollarRisk { get; set; }
        [Parameter("ATR Buffer Mult", DefaultValue = 0.5, MinValue = 0.0, MaxValue = 5.0, Step = 0.25, Group = "2. Strategy")] 
        public double AtrBufferMult { get; set; }
        [Parameter("R:R Ratio (Long)", DefaultValue = 9.75, MinValue = 0.5, MaxValue = 15, Step = 0.25, Group = "2. Strategy")] 
        public double RRRatioLong { get; set; }
        [Parameter("R:R Ratio (Short)", DefaultValue = 8.25, MinValue = 0.5, MaxValue = 15, Step = 0.25, Group = "2. Strategy")] 
        public double RRRatioShort { get; set; }

        public enum TpMode { Fixed, HalfAndHalf, TrailingOnly, PivotPoints, SessionExtrema }
        [Parameter("Primary TP Mode", DefaultValue = TpMode.HalfAndHalf, Group = "2. Strategy")] 
        public TpMode SelectedTpMode { get; set; }
        [Parameter("Pivot Level (1-3)", DefaultValue = 2, MinValue = 1, MaxValue = 5, Group = "2. Strategy")] 
        public int PivotLevel { get; set; }
        [Parameter("Extrema Lookback (Days)", DefaultValue = 3, MinValue = 1, MaxValue = 26, Group = "2. Strategy")] 
        public int ExtremaLookbackDays { get; set; }
        [Parameter("Enable Wolfe Override", DefaultValue = true, Group = "2. Strategy")] 
        public bool UseWolfeOverride { get; set; }

        // --- 3. INDICATOR SETTINGS ---
        [Parameter("MA Lookback", DefaultValue = 150, MinValue = 2, MaxValue = 500, Group = "3. Indicators")] 
        public int MALookback { get; set; }
        public enum MaModeType { PriceAboveBelow, SlopeRisingFalling }
        [Parameter("MA Logic Mode", DefaultValue = MaModeType.PriceAboveBelow, Group = "3. Indicators")] 
        public MaModeType MaLogic { get; set; }
        [Parameter("RSI Threshold", DefaultValue = 25, MinValue = 0, MaxValue = 100, Step = 5, Group = "3. Indicators")] 
        public int RSIVal { get; set; }
        [Parameter("RSI High-Low", DefaultValue = true, Group = "3. Indicators")] 
        public bool RSIHiLo { get; set; }
        [Parameter("RSI Reverse", DefaultValue = false, Group = "3. Indicators")] 
        public bool RSIReverse { get; set; }

        // --- 4. ADX FILTER ---
        public enum AdxFilterMode { Off, Min, Max, MinMax }
        [Parameter("ADX Mode", DefaultValue = AdxFilterMode.MinMax, Group = "4. ADX Filter")] 
        public AdxFilterMode AdxMode { get; set; }
        [Parameter("ADX Period", DefaultValue = 14, MinValue = 5, MaxValue = 50, Step = 1, Group = "4. ADX Filter")] 
        public int AdxPeriod { get; set; }
        [Parameter("ADX Min Level", DefaultValue = 15, MinValue = 5, MaxValue = 40, Step = 2.5, Group = "4. ADX Filter")] 
        public double AdxMin { get; set; }
        [Parameter("ADX Max Level", DefaultValue = 27.5, MinValue = 15, MaxValue = 60, Step =  2.5, Group = "4. ADX Filter")] 
        public double AdxMax { get; set; }

        // --- 5. FILTERS ---
        [Parameter("Min Body Ratio", DefaultValue = 0.3, MinValue = 0.2, MaxValue = 1.0, Step = 0.1, Group = "5. Filters")] 
        public double MinBodyRatio { get; set; }
        [Parameter("Max Rejection Wick", DefaultValue = 0.0, MinValue = 0.0, MaxValue = 0.5, Step = 0.1, Group = "5. Filters")] 
        public double MaxRejectionWickRatio { get; set; }
        [Parameter("Max Spread (Pips)", DefaultValue = 45, MinValue = 0.5, MaxValue = 1000, Step = 0.5, Group = "5. Filters")] 
        public double MaxSpread { get; set; }
        [Parameter("Max Candle (ATR Mult)", DefaultValue = 2.8, MinValue = 1.0, MaxValue = 4.0, Step = 0.25, Group = "5. Filters")] 
        public double MaxCandleAtrMultiplier { get; set; }
        [Parameter("Min Volatility Ratio", DefaultValue = 0.7, MinValue = 0.5, MaxValue = 2.0, Step = 0.1, Group = "5. Filters")] 
        public double MinVolatilityRatio { get; set; }
        [Parameter("ATR Short Period", DefaultValue = 14, MinValue = 2, MaxValue = 20, Step = 1, Group = "5. Filters")] 
        public int AtrPeriod { get; set; }
        [Parameter("ATR Long Period", DefaultValue = 100, MinValue = 10, MaxValue = 250, Step = 5, Group = "5. Filters")] 
        public int AtrLongPeriod { get; set; }
        [Parameter("Enable Holiday Blackout", DefaultValue = true, Group = "5. Filters")] 
        public bool EnableHolidayBlackout { get; set; }
        [Parameter("Blackout Start Month", DefaultValue = 12, MinValue = 12, MaxValue = 12, Group = "5. Filters")] 
        public int BlackoutStartMonth { get; set; }
        [Parameter("Blackout Start Day", DefaultValue = 20, MinValue = 10, MaxValue = 24, Group = "5. Filters")] 
        public int BlackoutStartDay { get; set; }
        [Parameter("Blackout End Month", DefaultValue = 1, MinValue = 1, MaxValue = 1, Group = "5. Filters")] 
        public int BlackoutEndMonth { get; set; }
        [Parameter("Blackout End Day", DefaultValue = 5, MinValue = 2, MaxValue = 10, Group = "5. Filters")] 
        public int BlackoutEndDay { get; set; }

        // --- 6. TRAILING STOPS ---
        public enum TrailType { None, PSAR, MTF_EMA, Extrema, Chandelier }
        [Parameter("Trailing Type", DefaultValue = TrailType.None, Group = "6. Trailing")] 
        public TrailType SelectedTrail { get; set; }
        [Parameter("Trail TimeFrame", DefaultValue = "Hour", Group = "6. Trailing")] 
        public TimeFrame TrailTF { get; set; }
        [Parameter("EMA Trail Period", DefaultValue = 49, MinValue = 2, MaxValue = 100, Step = 1, Group = "6. Trailing")] 
        public int EmaTrailPeriod { get; set; }
        [Parameter("Extrema Lookback (Bars)", DefaultValue = 6, MinValue = 1, MaxValue = 50, Group = "6. Trailing")] 
        public int ExtremaBars { get; set; }
        [Parameter("PSAR Min AF", DefaultValue = 0.02, MinValue = 0.01, MaxValue = 0.1, Step = 0.01, Group = "6. Trailing")] 
        public double PsarMinAF { get; set; }
        [Parameter("PSAR Max AF", DefaultValue = 0.2, MinValue = 0.1, MaxValue = 1.0, Step = 0.05, Group = "6. Trailing")] 
        public double PsarMaxAF { get; set; }
        [Parameter("Chandelier Mult", DefaultValue = 3.0, MinValue = 0.25, MaxValue = 5.0, Step = 0.25, Group = "6. Trailing")] 
        public double ChandelierMult { get; set; }

        // --- 7. MANAGEMENT ---
        [Parameter("Max Positions", DefaultValue = 1, MinValue = 1, MaxValue = 10, Group = "7. Management")] public int MaxPositions { get; set; }
        [Parameter("Order Magic", DefaultValue = 1, Group = "7. Management")] public int OrderMagic { get; set; }

        // --- 8. FITNESS ---
        [Parameter("Min Trades", DefaultValue = 75, Group = "8. Fitness")] 
        public int MinTrades { get; set; }
        [Parameter("Linear Bonus?", DefaultValue = false, Group = "8. Fitness")] 
        public bool LinBon { get; set; }
        [Parameter("Linear Divisor", DefaultValue = 3, Group = "8. Fitness")] 
        public int LinDiv { get; set; }
        [Parameter("Hyperbolic Exponent", DefaultValue = 0.75, Group = "8. Fitness")] 
        public double HypExp { get; set; }

        // --- 9. SNR MANAGEMENT ---
        [Parameter("Rejection Logic", DefaultValue = RejectionMode.WickInsideCloseOutside, Group = "9. SnR Management")] 
        public RejectionMode SnRRejectionMode { get; set; }

        // --- 10-13. INDICATOR S&R PARAMETERS (Passed to dynamic initialization) ---
        [Parameter("Show Multiday", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowMultiday { get; set; }
        [Parameter("Show Prev Day", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowPreviousDay { get; set; }
        [Parameter("Show Asian", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowAsianSession { get; set; }
        [Parameter("Show London", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowLondonSession { get; set; }
        [Parameter("Show NY", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowNySession { get; set; }
        [Parameter("Show Psych", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowPsychLevels { get; set; }
        [Parameter("Show OBs", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowOrderBlocks { get; set; }
        [Parameter("Show Doubles", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowDoubleTopsBottoms { get; set; }
        [Parameter("Show Consolidation", DefaultValue = true, Group = "10. Indicator Vis")] 
        public bool IndShowConsolidation { get; set; }

        [Parameter("Ind Macro ATR Mult", DefaultValue = 0.5, MinValue = 0.1, MaxValue = 2.0, Step = 0.1, Group = "11. Indicator Core")] 
        public double IndMacroAtrMult { get; set; }
        [Parameter("Ind Micro ATR Mult", DefaultValue = 0.2, MinValue = 0.0, MaxValue = 0.1, Step = 0.05, Group = "11. Indicator Core")] 
        public double IndMicroAtrMult { get; set; }
        [Parameter("Psych Step", DefaultValue = 25, Group = "11. Indicator Core")] 
        public double IndPsychLevelStep { get; set; }
        [Parameter("UTC Offset", DefaultValue = -5, MinValue = -12, MaxValue = 12, Group = "11. Indicator Core")] 
        public int IndUtcOffset { get; set; }
        [Parameter("Multiday TF", DefaultValue = "Weekly", Group = "11. Indicator Core")] 
        public TimeFrame IndMultidayTimeFrame { get; set; }
        [Parameter("Multiday Lookback", DefaultValue = 1, MinValue = 1, MaxValue = 42, Group = "11. Indicator Core")] 
        public int IndMultidayLookback { get; set; }

        [Parameter("Asian Start", DefaultValue = 18, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndAsianStartHour { get; set; }
        [Parameter("Asian End", DefaultValue = 3, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndAsianEndHour { get; set; }
        [Parameter("London Start", DefaultValue = 3, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndLondonStartHour { get; set; }
        [Parameter("London End", DefaultValue = 11, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndLondonEndHour { get; set; }
        [Parameter("NY Start", DefaultValue = 8, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndNyStartHour { get; set; }
        [Parameter("NY End", DefaultValue = 17, MinValue = 0, MaxValue = 23, Step = 1, Group = "12. Indicator Sessions")] 
        public int IndNyEndHour { get; set; }

        [Parameter("Min Formation", DefaultValue = 10, MinValue = 3, MaxValue = 30, Step = 1, Group = "13. Indicator Patterns")] 
        public int IndMinFormationCandles { get; set; }
        [Parameter("Max Lookback", DefaultValue = 50, MinValue = 15, MaxValue = 150, Step = 5, Group = "13. Indicator Patterns")] public int IndMaxLookbackCandles { get; set; }
        [Parameter("Max Consolidation ATR", DefaultValue = 1.5, MinValue = 0.25, MaxValue = 5.0, Step = 0.25, Group = "13. Indicator Patterns")] public double IndMaxConsolidationAtrWidth { get; set; }

        private Bars _htfBars, _dailyBars;
        private double openHigh, openLow, p1Price, p4Price;
        private int p1Index, p4Index;
        private ExponentialMovingAverage ema, trailEma;
        private RelativeStrengthIndex rsi;
        private AverageTrueRange _atrShort, _atrLong, _chandelierAtr;
        private DirectionalMovementSystem _adx;
        private ParabolicSAR _psar;
        private DynamicSnRBoxes _snrIndicator;
        private DateTime lastBarTime = DateTime.MinValue;
        private string Label => $"RB_{OrderMagic}";
        private double startingBalance;
        private Bars _m1Bars;

        protected override void OnStart()
        {
            ema = Indicators.ExponentialMovingAverage(Bars.ClosePrices, MALookback);
            rsi = Indicators.RelativeStrengthIndex(Bars.ClosePrices, 14);
            _atrShort = Indicators.AverageTrueRange(Bars, AtrPeriod, MovingAverageType.Exponential);
            _atrLong = Indicators.AverageTrueRange(Bars, AtrLongPeriod, MovingAverageType.Exponential);
            _adx = Indicators.DirectionalMovementSystem(AdxPeriod);
            _dailyBars = MarketData.GetBars(TimeFrame.Daily);

            if (SelectedTrail == TrailType.MTF_EMA)
                trailEma = Indicators.ExponentialMovingAverage(MarketData.GetBars(TrailTF).ClosePrices, EmaTrailPeriod);
            if (SelectedTrail == TrailType.PSAR)
                _psar = Indicators.ParabolicSAR(MarketData.GetBars(TrailTF), PsarMinAF, PsarMaxAF);
            if (SelectedTrail == TrailType.Extrema || SelectedTrail == TrailType.Chandelier)
                _htfBars = MarketData.GetBars(TrailTF);
            if (SelectedTrail == TrailType.Chandelier)
                _chandelierAtr = Indicators.AverageTrueRange(_htfBars, AtrPeriod, MovingAverageType.Exponential);

            startingBalance = Account.Balance;

            // Initialize Indicator with ALL parameters exposed to the Optimizer
            _snrIndicator = Indicators.GetIndicator<DynamicSnRBoxes>(
                IndShowMultiday, IndShowPreviousDay, IndShowAsianSession, IndShowLondonSession, IndShowNySession, 
                IndShowPsychLevels, IndShowOrderBlocks, IndShowDoubleTopsBottoms, IndShowConsolidation, 
                IndMacroAtrMult, IndMicroAtrMult, IndPsychLevelStep, IndUtcOffset, IndMultidayTimeFrame, IndMultidayLookback, 
                IndAsianStartHour, IndAsianEndHour, IndLondonStartHour, IndLondonEndHour, IndNyStartHour, IndNyEndHour, 
                IndMinFormationCandles, IndMaxLookbackCandles, IndMaxConsolidationAtrWidth
            );

            InitializeHistoricalRange();

            _m1Bars = MarketData.GetBars(TimeFrame.Minute);
            _m1Bars.BarOpened += OnM1BarOpened;
        }

        private void InitializeHistoricalRange()
        {
            for (int i = Bars.Count - 1; i >= LookbackBars; i--)
            {
                if (Bars.OpenTimes[i].Hour == StartTime && Bars.OpenTimes[i].Minute == OpenRangeMin)
                {
                    p1Index = i - LookbackBars;
                    p1Price = Bars.OpenPrices[p1Index];
                    openHigh = Bars.HighPrices[i - 1];
                    openLow = Bars.LowPrices[i - 1];

                    for (int j = 2; j <= LookbackBars; j++)
                    {
                        openHigh = Math.Max(openHigh, Bars.HighPrices[i - j]);
                        openLow = Math.Min(openLow, Bars.LowPrices[i - j]);
                    }

                    p4Index = i - 1;
                    p4Price = (openHigh + openLow) / 2;
                    break;
                }
            }
        }

        private void OnM1BarOpened(BarOpenedEventArgs args)
        {
            if (SelectedTrail != TrailType.None) 
                HandleTrailing();
        }

        protected override void OnBar()
        {
            // WAKE UP THE INDICATOR
            if (_snrIndicator != null) 
            {
                double wakeUpCall = _snrIndicator.DummySignal.LastValue;
            }

            DefineRanges();
            if (Bars.OpenTimes.LastValue == lastBarTime) return;
            lastBarTime = Bars.OpenTimes.LastValue;

            HandleSnRRejections();

            if (EnableTrade() && Positions.Count(p => p.Label == Label) < MaxPositions)
            {
                if (CheckAdx(_adx.ADX.Last(1)))
                    TradeIfAble();
            }
        }

        private void HandleSnRRejections()
        {
            if (_snrIndicator == null || Bars.Count < 3) return;

            var currBar = Bars.Last(1);
            var prevBar = Bars.Last(2);

            foreach (var pos in Positions.Where(p => p.Label == Label && p.SymbolName == SymbolName))
            {
                double riskAmount = Account.Balance * (Risk / 100.0); 
                if (riskAmount > MaxDollarRisk) riskAmount = MaxDollarRisk;

                double profitAmount = pos.GrossProfit;
                
                if (profitAmount <= 0) continue;

                _snrIndicator.CheckRejection(pos.TradeType, currBar.High, currBar.Low, currBar.Close, prevBar.Close, SnRRejectionMode, out bool rejMinor, out bool rejMid, out bool rejMajor);

                bool shouldClose = false;

                if (profitAmount >= riskAmount * 9)
                {
                    if (rejMajor) shouldClose = true;
                }
                else if (profitAmount >= riskAmount * 6)
                {
                    if (rejMajor || rejMid) shouldClose = true;
                }
                else if (profitAmount >= riskAmount * 3)
                {
                    if (rejMajor || rejMid || rejMinor) shouldClose = true;
                }

                if (shouldClose)
                {
                    Print($"[Management] {SnRRejectionMode} detected. Closing {pos.TradeType} {pos.Id}.");
                    ClosePosition(pos);
                }
            }
        }

        private void TradeIfAble()
        {
            if (Symbol.Spread / Symbol.PipSize > MaxSpread) return;
            double atrS = _atrShort.Result.Last(1);
            if (atrS < (_atrLong.Result.Last(1) * MinVolatilityRatio)) return;

            var lastBar = Bars.Last(1);
            double close = lastBar.Close, open = lastBar.Open;
            double barH = lastBar.High, barL = lastBar.Low;
            double totR = barH - barL;

            // Prevent division by zero on flat candles
            if (totR <= 0) return;

            if (totR > (atrS * MaxCandleAtrMultiplier)) return;

            // --- Body and Wick Calculations ---
            double bodySize = Math.Abs(open - close);
            double bodyRatio = bodySize / totR;

            // Rejection Wick Calculation (The wick in the direction of the breakout)
            double upperWick = barH - Math.Max(open, close);
            double lowerWick = Math.Min(open, close) - barL;
            double upperWickRatio = upperWick / totR;
            double lowerWickRatio = lowerWick / totR;

            // Filter: Minimum Body Requirement
            if (bodyRatio < MinBodyRatio) return;

            bool maB = MaLogic == MaModeType.PriceAboveBelow ? close > ema.Result.LastValue : ema.Result.LastValue > ema.Result.Last(1);
            bool maS = MaLogic == MaModeType.PriceAboveBelow ? close < ema.Result.LastValue : ema.Result.LastValue < ema.Result.Last(1);

            double rsiVal = rsi.Result.Last(1);
            bool rsiLong = (!RSIHiLo && rsiVal > RSIVal) || (RSIHiLo && rsiVal > RSIVal && rsiVal < (100 - RSIVal)) || (RSIReverse && rsiVal < RSIVal);
            bool rsiShort = (!RSIHiLo && rsiVal < (100 - RSIVal)) || (RSIHiLo && rsiVal < (100 - RSIVal) && rsiVal > RSIVal) || (RSIReverse && rsiVal > (100 - RSIVal));

            if (open >= openLow && open <= openHigh)
            {
                // Buy Condition: Check Upper Wick for rejection
                if (close > openHigh && maB && rsiLong)
                {
                    if (MaxRejectionWickRatio > 0 && upperWickRatio > MaxRejectionWickRatio) return;
                    ProcessEntry(TradeType.Buy);
                }
                // Sell Condition: Check Lower Wick for rejection
                else if (close < openLow && maS && rsiShort)
                {
                    if (MaxRejectionWickRatio > 0 && lowerWickRatio > MaxRejectionWickRatio) return;
                    ProcessEntry(TradeType.Sell);
                }
            }
        }

        private void ProcessEntry(TradeType type)
        {
            double entryPrice = type == TradeType.Buy ? Symbol.Ask : Symbol.Bid;
            double atrVal = _atrShort.Result.Last(1);
            double tier1SL = type == TradeType.Buy ? openLow - (atrVal * AtrBufferMult) : openHigh + (atrVal * AtrBufferMult);
            double tier2SL = type == TradeType.Buy ? openLow : openHigh;

            double slPips = Math.Abs(entryPrice - tier1SL) / Symbol.PipSize;
            double finalSL = CalculateRisk(slPips) <= MaxDollarRisk ? tier1SL : (CalculateRisk(Math.Abs(entryPrice - tier2SL) / Symbol.PipSize) <= MaxDollarRisk ? tier2SL : 0);
            if (finalSL == 0) return;

            ExecuteByMode(type, LotCalc(Risk, Math.Abs(entryPrice - finalSL)), finalSL);
        }

        private void ExecuteByMode(TradeType type, double volume, double sl)
        {
            double entry = (type == TradeType.Buy ? Symbol.Ask : Symbol.Bid);
            double? tpPrice = CalculateTPWithOverride(type, entry, sl);
            double slPips = Math.Round(Math.Abs(entry - sl) / Symbol.PipSize, 1);

            if (SelectedTpMode == TpMode.TrailingOnly)
                ExecuteMarketOrder(type, SymbolName, volume, Label, slPips, null);
            else if (SelectedTpMode == TpMode.HalfAndHalf)
            {
                double halfVol = Math.Floor((volume / 2) / Symbol.VolumeInUnitsStep) * Symbol.VolumeInUnitsStep;
                if (halfVol < Symbol.VolumeInUnitsStep) ExecuteMarketOrder(type, SymbolName, volume, Label, slPips, GetPipDist(entry, tpPrice));
                else
                {
                    ExecuteMarketOrder(type, SymbolName, volume - halfVol, Label, slPips, GetPipDist(entry, tpPrice));
                    ExecuteMarketOrder(type, SymbolName, halfVol, Label, slPips, null);
                }
            }
            else ExecuteMarketOrder(type, SymbolName, volume, Label, slPips, GetPipDist(entry, tpPrice));
        }

        private double? CalculateTPWithOverride(TradeType type, double entry, double sl)
        {
            double? baseTP = null;
            switch (SelectedTpMode)
            {
                case TpMode.Fixed:
                case TpMode.HalfAndHalf: baseTP = type == TradeType.Buy ? entry + (Math.Abs(entry - sl) * RRRatioLong) : entry - (Math.Abs(entry - sl) * RRRatioShort); break;
                case TpMode.PivotPoints:
                    double h = _dailyBars.HighPrices.Last(1), l = _dailyBars.LowPrices.Last(1), pivot = (h + l + _dailyBars.ClosePrices.Last(1)) / 3;
                    if (type == TradeType.Buy) baseTP = PivotLevel == 1 ? (2 * pivot) - l : (PivotLevel == 2 ? pivot + (h - l) : h + 2 * (pivot - l));
                    else baseTP = PivotLevel == 1 ? (2 * pivot) - h : (PivotLevel == 2 ? pivot - (h - l) : l - 2 * (h - pivot));
                    break;
                case TpMode.SessionExtrema: 
                    if (type == TradeType.Buy) baseTP = _dailyBars.HighPrices.Maximum(ExtremaLookbackDays);
                    else baseTP = _dailyBars.LowPrices.Minimum(ExtremaLookbackDays);
                    break;
            }

            if (UseWolfeOverride)
            {
                double slope = (p4Price - p1Price) / Math.Max(1, p4Index - p1Index);
                double wolfeEPA = p4Price + (slope * 5);
                if (type == TradeType.Buy && wolfeEPA > (baseTP ?? entry)) return wolfeEPA;
                if (type == TradeType.Sell && wolfeEPA < (baseTP ?? entry)) return wolfeEPA;
            }
            return baseTP;
        }

        private double? GetPipDist(double entry, double? tp) => tp.HasValue ? (double?)Math.Round(Math.Abs(tp.Value - entry) / Symbol.PipSize, 1) : null;

        private void DefineRanges()
        {
            if (Server.Time.Hour == StartTime && Server.Time.Minute == OpenRangeMin)
            {
                p1Index = Bars.Count - LookbackBars; p1Price = Bars.OpenPrices.Last(LookbackBars);
                openHigh = Bars.HighPrices.Last(1); openLow = Bars.LowPrices.Last(1);
                for (int i = 2; i <= LookbackBars; i++) { openHigh = Math.Max(openHigh, Bars.HighPrices.Last(i)); openLow = Math.Min(openLow, Bars.LowPrices.Last(i)); }
                p4Index = Bars.Count - 1; p4Price = (openHigh + openLow) / 2;
            }
        }

        private void HandleTrailing()
        {
            foreach (var pos in Positions.Where(p => p.Label == Label))
            {
                double? nSL = null;
                if (SelectedTrail == TrailType.PSAR) nSL = _psar.Result.LastValue;
                else if (SelectedTrail == TrailType.MTF_EMA) nSL = trailEma.Result.LastValue;
                else if (SelectedTrail == TrailType.Extrema) nSL = pos.TradeType == TradeType.Buy ? _htfBars.LowPrices.Minimum(ExtremaBars) : _htfBars.HighPrices.Maximum(ExtremaBars);
                else if (SelectedTrail == TrailType.Chandelier)
                {
                    double atr = _chandelierAtr.Result.LastValue;
                    int count = Math.Max(1, _htfBars.Count - 1 - _htfBars.OpenTimes.GetIndexByTime(pos.EntryTime));
                    nSL = pos.TradeType == TradeType.Buy ? _htfBars.HighPrices.Maximum(count) - (atr * ChandelierMult) : _htfBars.LowPrices.Minimum(count) + (atr * ChandelierMult);
                }
                if (nSL.HasValue)
                {
                    if (pos.TradeType == TradeType.Buy && nSL > pos.StopLoss && nSL < Symbol.Bid) ModifyPosition(pos, (double)nSL, pos.TakeProfit);
                    else if (pos.TradeType == TradeType.Sell && nSL < pos.StopLoss && nSL > Symbol.Ask) ModifyPosition(pos, (double)nSL, pos.TakeProfit);
                }
            }
        }

        private bool IsHoliday(DateTime currentTime)
        {
            if (!EnableHolidayBlackout) return false;

            int m = currentTime.Month;
            int d = currentTime.Day;

            if (BlackoutStartMonth <= BlackoutEndMonth)
            {
                // Handles blackouts within the same year (e.g., July 1 to July 10)
                DateTime start = new DateTime(currentTime.Year, BlackoutStartMonth, BlackoutStartDay);
                DateTime end = new DateTime(currentTime.Year, BlackoutEndMonth, BlackoutEndDay);
                return currentTime.Date >= start.Date && currentTime.Date <= end.Date;
            }
            else
            {
                // Handles cross-year blackouts (e.g., Dec 20 to Jan 5)
                bool isAfterStart = (m > BlackoutStartMonth) || (m == BlackoutStartMonth && d >= BlackoutStartDay);
                bool isBeforeEnd = (m < BlackoutEndMonth) || (m == BlackoutEndMonth && d <= BlackoutEndDay);
                return isAfterStart || isBeforeEnd;
            }
        }

        private bool CheckAdx(double val) => AdxMode switch { AdxFilterMode.Min => val >= AdxMin, AdxFilterMode.Max => val <= AdxMax, AdxFilterMode.MinMax => val >= AdxMin && val <= AdxMax, _ => true };
        private bool EnableTrade() => !HasOpenPositionsForLabel() && AfterStart() && openHigh != 0 && !IsHoliday(Server.Time);
        private bool AfterStart() 
        { 
            var n = Server.Time; 
            return StartTime < EndTime ? (n.Hour >= StartTime && n.Hour < EndTime) : !(n.Hour >= EndTime && n.Hour < StartTime);
        }
        private bool HasOpenPositionsForLabel() => Positions.Any(p => p.Label == Label && p.SymbolName == SymbolName);
        private double CalculateRisk(double pips) => (pips * Symbol.PipValue * Symbol.VolumeInUnitsStep) * (LotCalc(Risk, pips * Symbol.PipSize) / Symbol.VolumeInUnitsStep);
        private double LotCalc(double rP, double slD) 
        { 
            double rM = Account.Balance * rP / 100.0; 
            double mPS = (slD / Symbol.TickSize) * Symbol.TickValue * Symbol.VolumeInUnitsStep; 
            return Math.Round(Math.Clamp(Math.Floor(rM / mPS) * Symbol.VolumeInUnitsStep, Symbol.VolumeInUnitsMin, Symbol.VolumeInUnitsStep * 1000), 6);
        }
        protected override double GetFitness(GetFitnessArgs args) 
        { 
            if (args.NetProfit <= 0) return args.NetProfit; 
            var trades = args.History.OrderBy(t => t.ClosingTime).ToList(); 
            if(args.TotalTrades < 50)
                return 0;
            double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cum = 0; 
            for (int i = 0; i < trades.Count; i++) 
            { 
                cum += trades[i].NetProfit; 
                sumX += i; 
                sumY += cum; 
                sumXY += i * cum; 
                sumX2 += i * i; 
                sumY2 += cum * cum; 
            } 
            
            double r2 = Math.Pow(((trades.Count * sumXY) - (sumX * sumY)) / Math.Sqrt(((trades.Count * sumX2) - (sumX * sumX)) * ((trades.Count * sumY2) - (sumY * sumY))), 2); 
            if(args.MaxEquityDrawdownPercentages >= 5 && args.MaxEquityDrawdownPercentages < 10) 
                return (((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2 * 0.5; 
            else if(args.MaxEquityDrawdownPercentages >= 10)
                return ((((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2) / args.MaxEquityDrawdownPercentages;
            else if(args.TotalTrades <= MinTrades)
                return ((((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2) * args.TotalTrades/MinTrades;
            else if(args.TotalTrades > MinTrades && LinBon == true)
                return (((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2 * (1 + (args.TotalTrades - MinTrades)/MinTrades/LinDiv); 
            else
                return (((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2 * (1 + (Math.Pow(args.TotalTrades - MinTrades, HypExp)/MinTrades));
        }
    }
}