using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;
using cAlgo.API.Indicators;
using cAlgo.Indicators;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class RangeBreakout : Robot
    {
        // --- 1. TIME SETTINGS ---
        [Parameter("Start Time (hour)", DefaultValue = 10, MinValue = 0, MaxValue = 23, Step = 1, Group = "1. Time")] 
        public int StartHour { get; set; }
        [Parameter("End Time (hour)", DefaultValue = 10, MinValue = 0, MaxValue = 23, Group = "1. Time")] 
        public int EndHour { get; set; }
        [Parameter("Open Range Minute", DefaultValue = 0, MinValue = 0, MaxValue = 59, Group = "1. Time")] 
        public int StartMinute { get; set; }
        [Parameter("Lookback Minutes", DefaultValue = 45, MinValue = 1, MaxValue = 90, Group = "1. Time")] 
        public int LookbackMinutes { get; set; }
        [Parameter("Enable Holiday Blackout", DefaultValue = true, Group = "1. Time")] 
        public bool EnableHolidayBlackout { get; set; }
        [Parameter("Blackout Start Month", DefaultValue = 12, MinValue = 1, MaxValue = 12, Group = "1. Time")] 
        public int BlackoutStartMonth { get; set; }
        [Parameter("Blackout Start Day", DefaultValue = 20, MinValue = 1, MaxValue = 31, Group = "1. Time")] 
        public int BlackoutStartDay { get; set; }
        [Parameter("Blackout End Month", DefaultValue = 1, MinValue = 1, MaxValue = 12, Group = "1. Time")] 
        public int BlackoutEndMonth { get; set; }
        [Parameter("Blackout End Day", DefaultValue = 5, MinValue = 1, MaxValue = 31, Group = "1. Time")] 
        public int BlackoutEndDay { get; set; }

        // --- 2. STRATEGY SETTINGS ---
        [Parameter("Risk %", DefaultValue = 0.2, MinValue = 0.1, MaxValue = 4.9, Step = 0.1, Group = "2. Strategy")] 
        public double Risk { get; set; }
        [Parameter("Max Dollar Risk", DefaultValue = 10000000, MinValue = 1, Group = "2. Strategy")] 
        public int MaxDollarRisk { get; set; }
        [Parameter("ATR Buffer Mult", DefaultValue = 3.00, MinValue = 0, Group = "2. Strategy")] 
        public double AtrBufferMult { get; set; }
        [Parameter("TP Mode", DefaultValue = TpMode.PivotPoints, Group = "2. Strategy")] 
        public TpMode SelectedTpMode { get; set; }
        [Parameter("Pivot Level", DefaultValue = 4.5, MinValue = 0.5, MaxValue = 8, Step = 0.5, Group = "2. Strategy")] 
        public double PivotLevel { get; set; }
        [Parameter("Extrema Lookback (Days)", DefaultValue = 3, MinValue = 1, Group = "2. Strategy")] 
        public int ExtremaLookbackDays { get; set; }
        [Parameter("R:R Ratio Long", DefaultValue = 9.75, Group = "2. Strategy")] 
        public double RRRatioLong { get; set; }
        [Parameter("R:R Ratio Short", DefaultValue = 8.25, Group = "2. Strategy")] 
        public double RRRatioShort { get; set; }
        [Parameter("Enable Wolfe Override", DefaultValue = false, Group = "2. Strategy")] 
        public bool UseWolfeOverride { get; set; }

        // --- 3. FILTER SETTINGS ---
        [Parameter("EMA TimeFrame", DefaultValue = "Hour4", Group = "3. Filters")] 
        public TimeFrame EMATimeFrame { get; set; }
        [Parameter("EMA Lookback", DefaultValue = 150, MinValue = 2, MaxValue = 500, Group = "3. Filters")] 
        public int MALookback { get; set; }
        [Parameter("EMA Logic Mode", DefaultValue = MaModeType.PriceAboveBelow, Group = "3. Filters")] 
        public MaModeType MaLogic { get; set; }
        [Parameter("RSI Threshold", DefaultValue = 65, MinValue = 1, MaxValue = 100, Group = "3. Filters")] 
        public int RSIVal { get; set; }
        [Parameter("RSI High-Low", DefaultValue = true, Group = "3. Filters")] 
        public bool RSIHiLo { get; set; }
        [Parameter("RSI Reverse", DefaultValue = false, Group = "3. Filters")] 
        public bool RSIReverse { get; set; }
        [Parameter("Adx Mode", DefaultValue = AdxFilterMode.MinMax, Group = "3. Filters")] 
        public AdxFilterMode AdxMode { get; set; }
        [Parameter("HTF Adx TimeFrame", DefaultValue = "Hour", Group = "3. Filters")] 
        public TimeFrame AdxTimeFrame { get; set; }
        [Parameter("HTF Adx Period", DefaultValue = 14, Group = "3. Filters")] 
        public int htfAdxperiod { get; set; }
        [Parameter("HTF Adx Min Level", DefaultValue = 25, Group = "3. Filters")] 
        public int htfAdxmin { get; set; }
        [Parameter("Adx Period", DefaultValue = 14, Group = "3. Filters")] 
        public int AdxPeriod { get; set; }
        [Parameter("Adx Min Level", DefaultValue = 15, Group = "3. Filters")] 
        public double AdxMin { get; set; }
        [Parameter("Adx Max Level", DefaultValue = 27.5, Group = "3. Filters")] 
        public double AdxMax { get; set; }
        [Parameter("Min Body Ratio", DefaultValue = 0.3, MinValue = 0, MaxValue = 1, Group = "3. Filters")] 
        public double MinBodyRatio { get; set; }
        [Parameter("Max Rejection Wick %", DefaultValue = 0.1, MinValue = 0, MaxValue = 1, Group = "3. Filters")] 
        public double MaxRejectionWickRatio { get; set; }
        [Parameter("Max Candle (ATR Mult)", DefaultValue = 2.5, Group = "3. Filters")] 
        public double MaxCandleAtrMultiplier { get; set; }
        [Parameter("Min Volatility Ratio", DefaultValue = 0.75, Group = "3. Filters")] 
        public double MinVolatilityRatio { get; set; }
        [Parameter("ATR Short Period", DefaultValue = 14, MinValue = 2, MaxValue = 20, Group = "3. Filters")] 
        public int AtrPeriod { get; set; }
        [Parameter("ATR Long Period", DefaultValue = 100, MinValue = 10, MaxValue = 250, Group = "3. Filters")] 
        public int AtrLongPeriod { get; set; }

        // --- 4. TRAILING STOP SETTINGS ---
        [Parameter("Trailing Stop Type", DefaultValue = TrailType.Chandelier, Group = "4. Trailing Stops")] 
        public TrailType SelectedTrail { get; set; }
        [Parameter("Trail TimeFrame", DefaultValue = "Hour", Group = "4. Trailing Stops")] 
        public TimeFrame TrailTF { get; set; }
        [Parameter("EMA Trail Period", DefaultValue = 49, MinValue = 2, MaxValue = 101, Group = "4. Trailing Stops")] 
        public int EmaTrailPeriod { get; set; }
        [Parameter("Extrema Lookback (Bars)", DefaultValue = 5, MinValue = 1, Group = "4. Trailing Stops")] 
        public int ExtremaBars { get; set; }
        [Parameter("PSAR Min AF", DefaultValue = 0.02, Step = 0.005, Group = "4. Trailing Stops")] 
        public double PsarMinAF { get; set; }
        [Parameter("PSAR Max AF", DefaultValue = 0.2, Step = 0.01, Group = "4. Trailing Stops")] 
        public double PsarMaxAF { get; set; }
        [Parameter("Chandelier Multiplier", DefaultValue = 3.0, Group = "4. Trailing Stops")] 
        public double ChandelierMult { get; set; }

        // --- 5. PROTECTION & VIX SETTINGS ---
        [Parameter("Base Max Spread (Pips)", DefaultValue = 2.0, MinValue = 0.1, Group = "5. Protection")]
        public double BaseMaxSpread { get; set; }
        [Parameter("VIX Symbol Name", DefaultValue = "VIX", Group = "5. Protection")]
        public string VixSymbolName { get; set; }
        [Parameter("Baseline VIX Level", DefaultValue = 15.0, MinValue = 1.0, Group = "5. Protection")]
        public double BaselineVix { get; set; }
        [Parameter("VIX Scale Factor", DefaultValue = 1.2, MinValue = 0.1, Group = "5. Protection")]
        public double VixScaleFactor { get; set; }

        // --- 6. MANAGEMENT & FITNESS ---
        [Parameter("Max Positions", DefaultValue = 1, MinValue = 1, Group = "6. Management")] 
        public int MaxPositions { get; set; }
        [Parameter("Magic Number", DefaultValue = 1, Group = "6. Management")] 
        public int OrderMagic { get; set; }
        [Parameter("Min Trades for Fitness", DefaultValue = 75, Group = "6. Management")] 
        public int MinTrades { get; set; }

        public enum TpMode { PivotPoints, SessionExtrema, Fixed, TrailingOnly }
        public enum MaModeType { PriceAboveBelow, SlopeRisingFalling }
        public enum AdxFilterMode { Off, Min, Max, MinMax }
        public enum TrailType { None, Psar, MtfEma, Extrema, Chandelier }

        private string Label;
        private double startingBalance;
        private int rsiMode = -1;
        private double openHigh, openLow, p1Price, p4Price;
        private int p1Index, p4Index;

        private double currentDayHigh = -2;
        private double currentDayLow = 2500000;
        private double currentDayClose = -1;

        private Bars _m1Bars, _htfEmaBars, _htfAdxBars, _dailyBars, _trailBars, _execBars;
        private RelativeStrengthIndex _rsi;
        private AverageTrueRange _atrShort, _atrLong, _chandelierAtr;
        private ExponentialMovingAverage _ema, _trailEma;
        private ParabolicSAR _psar;
        private Symbol _vixSymbol;

        private MT5ADXEquivalent _customAdx;
        private MT5ADXEquivalent _customHtfAdx;

        protected override void OnStart()
        {
            if(StartHour != EndHour)
                Stop();

            Label = "RB_" + OrderMagic;
            startingBalance = Account.Balance;
            rsiMode = RSIHiLo ? 1 : (RSIReverse ? 2 : 0);

            // Initialize Bars
            _m1Bars = MarketData.GetBars(TimeFrame.Minute);
            _execBars = MarketData.GetBars(TimeFrame);
            _htfEmaBars = MarketData.GetBars(EMATimeFrame);
            _htfAdxBars = MarketData.GetBars(AdxTimeFrame);
            _dailyBars = MarketData.GetBars(TimeFrame.Daily);
            _trailBars = MarketData.GetBars(TrailTF);

            // Initialize Indicators
            _rsi = Indicators.RelativeStrengthIndex(_execBars.ClosePrices, 14);
            _atrShort = Indicators.AverageTrueRange(_execBars, AtrPeriod, MovingAverageType.Simple);
            _atrLong = Indicators.AverageTrueRange(_execBars, AtrLongPeriod, MovingAverageType.Simple);
    
            // Initialize Adx only if filter is used
            if (AdxMode != AdxFilterMode.Off) 
            {   
                _customAdx = Indicators.GetIndicator<MT5ADXEquivalent>(_execBars, AdxPeriod);
                _customHtfAdx = Indicators.GetIndicator<MT5ADXEquivalent>(_htfAdxBars, htfAdxperiod);
            }
    
            _ema = Indicators.ExponentialMovingAverage(_htfEmaBars.ClosePrices, MALookback);

            if (SelectedTrail == TrailType.MtfEma) _trailEma = Indicators.ExponentialMovingAverage(_trailBars.ClosePrices, EmaTrailPeriod);
            if (SelectedTrail == TrailType.Psar) _psar = Indicators.ParabolicSAR(_trailBars, PsarMinAF, PsarMaxAF);
            if (SelectedTrail == TrailType.Chandelier) _chandelierAtr = Indicators.AverageTrueRange(_trailBars, AtrPeriod, MovingAverageType.Simple);

            _vixSymbol = Symbols.GetSymbol(VixSymbolName);

            InitializeHistoricalRange();
        }

        private void InitializeHistoricalRange()
        {
            if (_dailyBars.Count > 1)
            {
                currentDayHigh = _dailyBars.HighPrices.Last(1);
                currentDayClose = _dailyBars.ClosePrices.Last(1);
                currentDayLow = _dailyBars.LowPrices.Last(1);
            }

            DynamicScanRange(Server.Time);
        }

        public double GetSynchronizedAdx(MT5ADXEquivalent AdxIndicator, Bars sourceBars, int targetBarIndex)
        {
            if (AdxIndicator == null || sourceBars == null || targetBarIndex < 0 || targetBarIndex >= sourceBars.Count)
                return double.NaN;

            DateTime barTime = sourceBars.OpenTimes[targetBarIndex];
            
            // Universal Fallback: Scan backwards to find the latest HTF bar that opened before or exactly at the execution bar's open time
            var indicatorBars = AdxIndicator.Bars;
            int AdxIndex = -1;

            for (int i = indicatorBars.Count - 1; i >= 0; i--)
            {
                if (indicatorBars.OpenTimes[i] <= barTime)
                {
                    AdxIndex = i;
                    break;
                }
            }

            if (AdxIndex < 0 || AdxIndex >= AdxIndicator.ExtADXBuffer.Count) 
                return double.NaN;

            return AdxIndicator.ExtADXBuffer[AdxIndex];
        }

        protected override void OnBar()
        {
            if (_execBars.Count < 2) return;

            // Warmup Gate with explicit safety checks
            if (AdxMode != AdxFilterMode.Off)
            {
                if (_customAdx == null || _customHtfAdx == null) return;

                double currentAdx = GetSynchronizedAdx(_customAdx, _execBars, _execBars.Count - 2);
                double currentHtfAdx = GetSynchronizedAdx(_customHtfAdx, _execBars, _execBars.Count - 2);

                if (double.IsNaN(currentAdx) || double.IsNaN(currentHtfAdx))
                {
                    return;
                }
            }

            if (SelectedTrail != TrailType.None) HandleTrailing();

            var lastBar = _execBars.Last(0);
            DateTime virtualBarTime = lastBar.OpenTime.AddHours(3);
            
            if (virtualBarTime.Minute == StartMinute && virtualBarTime.Hour == StartHour)
            {
                DefineRanges();
            }
            else if (openHigh == 0)
            {
                DynamicScanRange(lastBar.OpenTime);
            }

            if (EnableTrade() && Positions.Count(p => p.Label == Label) < MaxPositions)
            {
                bool m5AdxPass = true;
                if (AdxMode != AdxFilterMode.Off)
                {
                    double AdxVal = GetSynchronizedAdx(_customAdx, _execBars, _execBars.Count - 2);
                    m5AdxPass = (AdxMode == AdxFilterMode.Min && AdxVal >= AdxMin) ||
                                (AdxMode == AdxFilterMode.Max && AdxVal <= AdxMax) ||
                                (AdxMode == AdxFilterMode.MinMax && AdxVal >= AdxMin && AdxVal <= AdxMax);
                }

                bool htfAdxPass = true;
                if (AdxMode != AdxFilterMode.Off)
                {
                    double currentHtf = GetSynchronizedAdx(_customHtfAdx, _execBars, _execBars.Count - 2);
                    double prevHtf = GetSynchronizedAdx(_customHtfAdx, _execBars, _execBars.Count - 3);
                    
                    htfAdxPass = !double.IsNaN(currentHtf) && !double.IsNaN(prevHtf) && currentHtf >= htfAdxmin && currentHtf > prevHtf;
                }

                if (m5AdxPass && htfAdxPass) TradeIfAble();
            }
        }

        private void TradeIfAble()
        {
            if (!IsSpreadAndVolatilitySafe()) 
            {
                Print("FILTER_REJECT: Spread/Volatility not safe");
                return;
            }

            double atrS = _atrShort.Result.Last(1);
            double atrL = _atrLong.Result.Last(1);
            if (atrS < (atrL * MinVolatilityRatio))
            {
                Print("FILTER_REJECT: Volatility Ratio Gate Blocked");
                return;
            }

            var signalBar = _execBars.Last(1);
            double totR = signalBar.High - signalBar.Low;
            if (totR > (atrS * MaxCandleAtrMultiplier) || totR == 0) 
            {
                Print("FILTER_REJECT: Candle exceeded Max ATR Multiplier");
                return;
            }

            double bodySize = Math.Abs(signalBar.Close - signalBar.Open);
            if ((bodySize / totR) < MinBodyRatio)
            {
                Print("FILTER_REJECT: Body Ratio too small");
                return;
            }

            double emaCurr = _ema.Result.Last(1);
            double emaPrev = _ema.Result.Last(2);
            bool maB = MaLogic == MaModeType.PriceAboveBelow ? signalBar.Close > emaCurr : emaCurr > emaPrev;
            bool maS = MaLogic == MaModeType.PriceAboveBelow ? signalBar.Close < emaCurr : emaCurr < emaPrev;

            double rsiVal = _rsi.Result.Last(1);
            bool rsiLong = rsiMode == 1 ? (rsiVal > RSIVal && rsiVal < (100 - RSIVal)) : (rsiMode == 0 ? rsiVal > RSIVal : rsiVal < RSIVal);
            bool rsiShort = rsiMode == 1 ? (rsiVal < (100 - RSIVal) && rsiVal > RSIVal) : (rsiMode == 0 ? rsiVal < (100 - RSIVal) : rsiVal > (100 - RSIVal));

            bool bullSig = signalBar.Close > openHigh && maB && rsiLong;
            bool bearSig = signalBar.Close < openLow && maS && rsiShort;

            double rejWick = bullSig ? (signalBar.High - Math.Max(signalBar.Open, signalBar.Close)) : (Math.Min(signalBar.Open, signalBar.Close) - signalBar.Low);
            if ((rejWick / totR) > MaxRejectionWickRatio) 
            {
                Print("FILTER_REJECT: Rejection wick too large");
                return;
            }

            var prevBar = _execBars.Last(2);
            bool signalTouchZone = (signalBar.Low <= openHigh && signalBar.High >= openLow);
            bool gapUpBreakout = (prevBar.Close >= openLow && prevBar.Close <= openHigh && signalBar.Open > openHigh);
            bool gapDownBreakout = (prevBar.Close >= openLow && prevBar.Close <= openHigh && signalBar.Open < openLow);

            if (bullSig && (signalTouchZone || gapUpBreakout)) ProcessEntry(TradeType.Buy);
            if (bearSig && (signalTouchZone || gapDownBreakout)) ProcessEntry(TradeType.Sell);
        }

        private bool IsSpreadAndVolatilitySafe()
        {
            double currentSpreadInPips = (Symbol.Ask - Symbol.Bid) / Symbol.PipSize;
            double dynamicMaxSpread = BaseMaxSpread;

            if (_vixSymbol != null)
            {
                double currentVix = _vixSymbol.Bid; 
                if (currentVix > BaselineVix)
                {
                    double varianceRatio = currentVix / BaselineVix;
                    dynamicMaxSpread = BaseMaxSpread * (1.0 + (varianceRatio - 1.0) * VixScaleFactor);
                }
            }

            return currentSpreadInPips <= dynamicMaxSpread;
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

            double volume = LotCalc(Risk, Math.Abs(entryPrice - finalSL));
            ExecuteByMode(type, volume, finalSL);
        }

        private void ExecuteByMode(TradeType type, double volume, double sl)
        {
            double entry = type == TradeType.Buy ? Symbol.Ask : Symbol.Bid;
            double? tpPrice = CalculateTPWithOverride(type, entry, sl);

            if ((type == TradeType.Buy && tpPrice.HasValue && tpPrice.Value <= entry) || (type == TradeType.Sell && tpPrice.HasValue && tpPrice.Value >= entry)) return;
            ExecuteMarketOrder(type, SymbolName, volume, Label, sl, SelectedTpMode == TpMode.TrailingOnly ? null : tpPrice);
        }

        private double? CalculateTPWithOverride(TradeType type, double entry, double sl)
        {
            double? baseTP = null;
            switch (SelectedTpMode)
            {
                case TpMode.Fixed:
                    baseTP = type == TradeType.Buy ? entry + (Math.Abs(entry - sl) * RRRatioLong) : entry - (Math.Abs(entry - sl) * RRRatioShort);
                    break;
                case TpMode.PivotPoints:
                    double pp = (currentDayHigh + currentDayLow + currentDayClose) / 3;
                    double range = currentDayHigh - currentDayLow;
                    double gapH = currentDayHigh - pp; double gapL = pp - currentDayLow;
                    double r1 = (2 * pp) - currentDayLow, s1 = (2 * pp) - currentDayHigh;
                    double r2 = pp + range, s2 = pp - range;
                    double r3 = currentDayHigh + 2 * (pp - currentDayLow), s3 = currentDayLow - 2 * (currentDayHigh - pp);
                    double r4 = pp + 2 * range, s4 = pp - 2 * range;
                    double r5 = r1 + 2 * range, s5 = s1 - 2 * range;
                    double r6 = pp + 3 * range, s6 = pp - 3 * range;
                    double r7 = r1 + 3 * range, s7 = s1 - 3 * range;
                    double r8 = pp + 4 * range, s8 = pp - 4 * range;
                    double r05 = pp + 0.5 * gapL, s05 = pp - 0.5 * gapH;
                    double r15 = r1 + 0.5 * gapH, s15 = s1 - 0.5 * gapL;
                    double r25 = r2 + 0.5 * gapL, s25 = s2 - 0.5 * gapH;
                    double r35 = r3 + 0.5 * gapH, s35 = s3 - 0.5 * gapL;
                    double r45 = r4 + 0.5 * gapL, s45 = s4 - 0.5 * gapH;

                    if (type == TradeType.Buy)
                    {
                        if (PivotLevel <= 0.5) baseTP = r05; else if (PivotLevel <= 1) baseTP = r1; else if (PivotLevel <= 1.5) baseTP = r15; else if (PivotLevel <= 2) baseTP = r2; else if (PivotLevel <= 2.5) baseTP = r25; else if (PivotLevel <= 3) baseTP = r3; else if (PivotLevel <= 3.5) baseTP = r35; else if (PivotLevel <= 4) baseTP = r4; else if (PivotLevel <= 4.5) baseTP = r45; else if (PivotLevel <= 5) baseTP = r5; else if (PivotLevel <= 5.5) baseTP = r5 + 0.5 * gapH; else if (PivotLevel <= 6) baseTP = r6; else if (PivotLevel <= 6.5) baseTP = r6 + 0.5 * gapL; else if (PivotLevel <= 7) baseTP = r7; else if (PivotLevel <= 7.5) baseTP = r7 + 0.5 * gapH; else if (PivotLevel <= 8) baseTP = r8;
                    }
                    else
                    {
                        if (PivotLevel <= 0.5) baseTP = s05; else if (PivotLevel <= 1) baseTP = s1; else if (PivotLevel <= 1.5) baseTP = s15; else if (PivotLevel <= 2) baseTP = s2; else if (PivotLevel <= 2.5) baseTP = s25; else if (PivotLevel <= 3) baseTP = s3; else if (PivotLevel <= 3.5) baseTP = s35; else if (PivotLevel <= 4) baseTP = s4; else if (PivotLevel <= 4.5) baseTP = s45; else if (PivotLevel <= 5) baseTP = s5; else if (PivotLevel <= 5.5) baseTP = s5 - 0.5 * gapL; else if (PivotLevel <= 6) baseTP = s6; else if (PivotLevel <= 6.5) baseTP = s6 - 0.5 * gapH; else if (PivotLevel <= 7) baseTP = s7; else if (PivotLevel <= 7.5) baseTP = s7 - 0.5 * gapL; else if (PivotLevel <= 8) baseTP = s8;
                    }
                    break;
                case TpMode.SessionExtrema: 
                    if (type == TradeType.Buy) baseTP = _dailyBars.HighPrices.Maximum(ExtremaLookbackDays);
                    else baseTP = _dailyBars.LowPrices.Minimum(ExtremaLookbackDays);
                    break;
            }

            if (UseWolfeOverride)
            {
                double slope = (p4Price - p1Price) / Math.Max(1, LookbackMinutes - 1);
                double wolfeEPA = p4Price + (slope * 5);
                if (type == TradeType.Buy && wolfeEPA > (baseTP ?? entry)) return wolfeEPA;
                if (type == TradeType.Sell && wolfeEPA < (baseTP ?? entry)) return wolfeEPA;
            }
            return baseTP;
        }

        private void DefineRanges()
        {
            if (_m1Bars.Count < LookbackMinutes) return;
            p1Index = _m1Bars.Count - LookbackMinutes; 
            p1Price = _m1Bars.OpenPrices.Last(LookbackMinutes);
            openHigh = _m1Bars.HighPrices.Last(1); 
            openLow = _m1Bars.LowPrices.Last(1);
            for (int i = 2; i <= LookbackMinutes; i++) 
            { 
                openHigh = Math.Max(openHigh, _m1Bars.HighPrices.Last(i)); 
                openLow = Math.Min(openLow, _m1Bars.LowPrices.Last(i)); 
            }
            p4Index = _m1Bars.Count - 1; 
            p4Price = (openHigh + openLow) / 2;

            if (_dailyBars.Count > 1)
            {
                currentDayHigh = _dailyBars.HighPrices.Last(1);
                currentDayClose = _dailyBars.ClosePrices.Last(1);
                currentDayLow = _dailyBars.LowPrices.Last(1);
            }

            Print("openHigh = ", openHigh, ", openLow = ", openLow, ", currentDayHigh = ", currentDayHigh, ", currentDayClose = ", currentDayClose, ", currentDayLow = ", currentDayLow);
        }

        private void HandleTrailing()
        {
            foreach (var pos in Positions.Where(p => p.Label == Label))
            {
                double? nSL = null;
                if (SelectedTrail == TrailType.Psar) nSL = _psar.Result.Last(1);
                else if (SelectedTrail == TrailType.MtfEma) nSL = _trailEma.Result.Last(1);
                else if (SelectedTrail == TrailType.Extrema) nSL = pos.TradeType == TradeType.Buy ? _trailBars.LowPrices.Minimum(ExtremaBars) : _trailBars.HighPrices.Maximum(ExtremaBars);
                else if (SelectedTrail == TrailType.Chandelier)
                {
                    double atr = _chandelierAtr.Result.Last(1);
                    int barsSinceEntry = 0;
                    for (int i = 0; i < _trailBars.Count; i++)
                    {
                        if (_trailBars.OpenTimes.Last(i) <= pos.EntryTime)
                        {
                            barsSinceEntry = i + 1;
                            break;
                        }
                    }
                    int count = Math.Max(1, barsSinceEntry);
                    nSL = pos.TradeType == TradeType.Buy ? _trailBars.HighPrices.Maximum(count) - (atr * ChandelierMult) : _trailBars.LowPrices.Minimum(count) + (atr * ChandelierMult);
                }

                if (nSL.HasValue)
                {
                    if (pos.TradeType == TradeType.Buy && (!pos.StopLoss.HasValue || nSL.Value > pos.StopLoss.Value) && nSL.Value < Symbol.Bid)
                        ModifyPosition(pos, nSL.Value, pos.TakeProfit);
                    else if (pos.TradeType == TradeType.Sell && (!pos.StopLoss.HasValue || nSL.Value < pos.StopLoss.Value) && nSL.Value > Symbol.Ask)
                        ModifyPosition(pos, nSL.Value, pos.TakeProfit);
                }
            }
        }

        private bool EnableTrade() 
        {
            DateTime virtualMt5Time = Server.Time.AddHours(3);
            return IsInWindow(virtualMt5Time) && openHigh != 0 && !IsHoliday(virtualMt5Time);
        }

        private bool IsInWindow(DateTime targetTime)
        {
            int currentMins = targetTime.Hour * 60 + targetTime.Minute;
            int startMins = StartHour * 60 + StartMinute;
            int endMins = EndHour * 60;

            if (startMins < endMins) return currentMins >= startMins && currentMins < endMins;
            return currentMins >= startMins || currentMins < endMins;
        }

        private void DynamicScanRange(DateTime targetTime)
        {
            for (int i = _m1Bars.Count - 1; i >= LookbackMinutes; i--)
            {
                DateTime virtualBarTime = _m1Bars.OpenTimes[i].AddHours(3);

                if (virtualBarTime.Hour == StartHour && virtualBarTime.Minute == StartMinute)
                {
                    p1Index = i - LookbackMinutes;
                    p1Price = _m1Bars.OpenPrices[p1Index];
                    openHigh = _m1Bars.HighPrices[i - 1];
                    openLow = _m1Bars.LowPrices[i - 1];

                    for (int j = 2; j <= LookbackMinutes; j++)
                    {
                        openHigh = Math.Max(openHigh, _m1Bars.HighPrices[i - j]);
                        openLow = Math.Min(openLow, _m1Bars.LowPrices[i - j]);
                    }

                    p4Index = i - 1;
                    p4Price = (openHigh + openLow) / 2;
                    break;
                }
            }
            Print("openHigh = ", openHigh, ", openLow = ", openLow, ", currentDayHigh = ", currentDayHigh, ", currentDayClose = ", currentDayClose, ", currentDayLow = ", currentDayLow);
        }

        private bool IsHoliday(DateTime currentTime)
        {
            if (!EnableHolidayBlackout) return false;
            int m = currentTime.Month, d = currentTime.Day;
            if (BlackoutStartMonth <= BlackoutEndMonth)
                return (m > BlackoutStartMonth || (m == BlackoutStartMonth && d >= BlackoutStartDay)) && (m < BlackoutEndMonth || (m == BlackoutEndMonth && d <= BlackoutEndDay));
            return ((m > BlackoutStartMonth) || (m == BlackoutStartMonth && d >= BlackoutStartDay)) || ((m < BlackoutEndMonth) || (m == BlackoutEndMonth && d <= BlackoutEndDay));
        }

        private double CalculateRisk(double pips) => (pips * Symbol.PipSize * (Symbol.VolumeInUnitsStep / Symbol.PipValue) * Symbol.PipValue) * (LotCalc(Risk, pips * Symbol.PipSize) / Symbol.VolumeInUnitsStep);
        private double LotCalc(double rP, double slD)
        {
            double rM = Account.Balance * rP / 100;
            if (slD == 0) return Symbol.VolumeInUnitsMin;
            double calculated = Math.Floor(rM / ((slD / Symbol.TickSize) * Symbol.TickValue * Symbol.VolumeInUnitsStep)) * Symbol.VolumeInUnitsStep;
            return Math.Min(Math.Max(calculated, Symbol.VolumeInUnitsMin), Symbol.VolumeInUnitsMax);
        }
    }
}