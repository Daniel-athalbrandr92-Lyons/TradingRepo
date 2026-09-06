using System;
using System.Linq;
using System.Collections.Generic;
using cAlgo.API;
using cAlgo.API.Internals;
using cAlgo.API.Indicators;
using cAlgo.Indicators;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class WaveRider : Robot
    {
        // --- 1. CORE SETTINGS ---
        [Parameter("Risk (%)", DefaultValue = 0.2, Group = "1. Core")] public double Risk { get; set; }
        [Parameter("Max Dollar Risk", DefaultValue = 50.0, Group = "1. Core")] public double MaxDollarRisk { get; set; }
        [Parameter("Max Spread (Pips)", DefaultValue = 1.0, Group = "1. Core")] public double MaxSpread { get; set; }
        [Parameter("Min SL Distance (Pips)", DefaultValue = 0.1, Group = "1. Core")] public double MinSlPips { get; set; }
        [Parameter("Macro ATR Mult (Sync with Indicator)", DefaultValue = 0.5, Group = "1. Core")] public double MacroAtrMult { get; set; }
        [Parameter("Micro ATR Mult (Sync with Indicator)", DefaultValue = 0.2, Group = "1. Core")] public double MicroAtrMult { get; set; }

        // --- 2. MANAGEMENT SETTINGS ---
        public enum TpStrategy { PureReversal, NextZoneQuarter }
        [Parameter("TP Strategy", DefaultValue = TpStrategy.NextZoneQuarter, Group = "2. Management")] public TpStrategy SelectedTpStrategy { get; set; }
        [Parameter("Enable Trailing Stops", DefaultValue = true, Group = "2. Management")] public bool EnableTrailing { get; set; }
        [Parameter("Rejection Logic", DefaultValue = RejectionMode.WickInsideCloseOutside, Group = "2. Management")] public RejectionMode SnRRejectionMode { get; set; }

        // --- 3. FITNESS ---
        [Parameter("Min Trades", DefaultValue = 75, Group = "3. Fitness")] public int MinTrades { get; set; }
        [Parameter("Linear Bonus?", DefaultValue = false, Group = "3. Fitness")] public bool LinBon { get; set; }
        [Parameter("Linear Divisor", DefaultValue = 3, Group = "3. Fitness")] public int LinDiv { get; set; }
        [Parameter("Hyperbolic Exponent", DefaultValue = 0.60, Group = "3. Fitness")] public double HypExp { get; set; }

        // --- 4. FILTERS ---
        [Parameter("Enable EMA Filter", DefaultValue = true, Group = "4. Filters")] public bool EnableEma { get; set; }
        [Parameter("EMA Period", DefaultValue = 48, Group = "4. Filters")] public int EmaPeriod { get; set; }
        public enum AdxFilterMode { Off, Min, Max, MinMax }
        [Parameter("ADX Mode", DefaultValue = AdxFilterMode.MinMax, Group = "4. Filters")] public AdxFilterMode AdxMode { get; set; }
        [Parameter("ADX Period", DefaultValue = 14, Group = "4. Filters")] public int AdxPeriod { get; set; }
        [Parameter("ADX Min Level", DefaultValue = 20, Group = "4. Filters")] public double AdxMin { get; set; }
        [Parameter("ADX Max Level", DefaultValue = 45, Group = "4. Filters")] public double AdxMax { get; set; }
        
        [Parameter("Enable MACD Filter", DefaultValue = true, Group = "4. Filters")] public bool EnableMacd { get; set; }
        public enum MacdFilterMode { Normal, Reverse }
        [Parameter("MACD Mode", DefaultValue = MacdFilterMode.Normal, Group = "4. Filters")] public MacdFilterMode SelectedMacdMode { get; set; }
        [Parameter("MACD Long Cycle", DefaultValue = 26, Group = "4. Filters")] public int MacdLongCycle { get; set; }
        [Parameter("MACD Short Cycle", DefaultValue = 12, Group = "4. Filters")] public int MacdShortCycle { get; set; }
        [Parameter("MACD Signal Periods", DefaultValue = 9, Group = "4. Filters")] public int MacdSignalPeriods { get; set; }
        
        [Parameter("Enable Holiday Blackout", DefaultValue = true, Group = "4. Filters")] public bool EnableHolidayBlackout { get; set; }
        [Parameter("Blackout Start Month", DefaultValue = 12, Group = "4. Filters")] public int BlackoutStartMonth { get; set; }
        [Parameter("Blackout Start Day", DefaultValue = 20, Group = "4. Filters")] public int BlackoutStartDay { get; set; }
        [Parameter("Blackout End Month", DefaultValue = 1, Group = "4. Filters")] public int BlackoutEndMonth { get; set; }
        [Parameter("Blackout End Day", DefaultValue = 5, Group = "4. Filters")] public int BlackoutEndDay { get; set; }

        // --- 5. INDICATOR S&R PARAMETERS ---
        [Parameter("Show Multiday", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowMultiday { get; set; }
        [Parameter("Show Prev Day", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowPreviousDay { get; set; }
        [Parameter("Show Asian", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowAsianSession { get; set; }
        [Parameter("Show London", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowLondonSession { get; set; }
        [Parameter("Show NY", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowNySession { get; set; }
        [Parameter("Show Centuries", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowPsychCenturies { get; set; }
        [Parameter("Show Halves", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowPsychHalves { get; set; }
        [Parameter("Show Quartiles", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowPsychQuartiles { get; set; }
        [Parameter("Show OBs", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowOrderBlocks { get; set; }
        [Parameter("Show Doubles", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowDoubleTopsBottoms { get; set; }
        [Parameter("Show Consolidation", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowConsolidation { get; set; }
        [Parameter("Show Rejections", DefaultValue = true, Group = "5. Indicator Vis")] public bool IndShowRejections { get; set; }

        [Parameter("Psych Step", DefaultValue = 25, Group = "5. Indicator Core")] public double IndPsychLevelStep { get; set; }
        [Parameter("UTC Offset", DefaultValue = 0, Group = "5. Indicator Core")] public int IndUtcOffset { get; set; }
        [Parameter("Multiday TF", DefaultValue = "Weekly", Group = "5. Indicator Core")] public TimeFrame IndMultidayTimeFrame { get; set; }
        [Parameter("Multiday Lookback", DefaultValue = 1, Group = "5. Indicator Core")] public int IndMultidayLookback { get; set; }

        [Parameter("Asian Start", DefaultValue = 19, Group = "5. Indicator Sessions")] public int IndAsianStartHour { get; set; }
        [Parameter("Asian End", DefaultValue = 10, Group = "5. Indicator Sessions")] public int IndAsianEndHour { get; set; }
        [Parameter("London Start", DefaultValue = 6, Group = "5. Indicator Sessions")] public int IndLondonStartHour { get; set; }
        [Parameter("London End", DefaultValue = 17, Group = "5. Indicator Sessions")] public int IndLondonEndHour { get; set; }
        [Parameter("NY Start", DefaultValue = 11, Group = "5. Indicator Sessions")] public int IndNyStartHour { get; set; }
        [Parameter("NY End", DefaultValue = 22, Group = "5. Indicator Sessions")] public int IndNyEndHour { get; set; }

        [Parameter("Min Formation", DefaultValue = 10, Group = "5. Indicator Patterns")] public int IndMinFormationCandles { get; set; }
        [Parameter("Max Lookback", DefaultValue = 50, Group = "5. Indicator Patterns")] public int IndMaxLookbackCandles { get; set; }
        [Parameter("Max Consolidation ATR", DefaultValue = 1.5, Group = "5. Indicator Patterns")] public double IndMaxConsolidationAtrWidth { get; set; }

        private DynamicSnRBoxes _snrIndicator;
        private AverageTrueRange _atr;
        private ExponentialMovingAverage _ema;
        private DirectionalMovementSystem _adx;
        private MacdCrossOver _macd;
        private Bars _m1Bars;
        private DateTime _lastBarTime = DateTime.MinValue;
        private double startingBalance;

        private const string LBL_MINOR = "WaveRider_Minor";
        private const string LBL_MID = "WaveRider_Mid";
        private const string LBL_MAJOR = "WaveRider_Major";

        protected override void OnStart()
        {
            if (RunningMode == RunningMode.Optimization)
            {
                bool redundant = false;
                if (!EnableEma && EmaPeriod != 48) redundant = true;
                if (AdxMode == AdxFilterMode.Off && (AdxPeriod != 14 || AdxMin != 20 || AdxMax != 45)) redundant = true;
                if (!EnableMacd && (MacdLongCycle != 26 || MacdShortCycle != 12 || MacdSignalPeriods != 9)) redundant = true;
                if (!EnableHolidayBlackout && (BlackoutStartMonth != 12 || BlackoutStartDay != 20 || BlackoutEndMonth != 1 || BlackoutEndDay != 5)) redundant = true;
                if (redundant) { Stop(); return; }
            }

            _atr = Indicators.AverageTrueRange(14, MovingAverageType.Simple);
            _snrIndicator = Indicators.GetIndicator<DynamicSnRBoxes>(
                IndShowMultiday, IndShowPreviousDay, IndShowAsianSession, IndShowLondonSession, IndShowNySession, 
                IndShowPsychCenturies, IndShowPsychHalves, IndShowPsychQuartiles, IndShowOrderBlocks, 
                IndShowDoubleTopsBottoms, IndShowConsolidation, IndShowRejections,
                MacroAtrMult, MicroAtrMult, IndPsychLevelStep, IndUtcOffset, IndMultidayTimeFrame, IndMultidayLookback,
                IndAsianStartHour, IndAsianEndHour, IndLondonStartHour, IndLondonEndHour, IndNyStartHour, IndNyEndHour,
                IndMinFormationCandles, IndMaxLookbackCandles, IndMaxConsolidationAtrWidth
            );

            _ema = Indicators.ExponentialMovingAverage(Bars.ClosePrices, EmaPeriod);
            _adx = Indicators.DirectionalMovementSystem(AdxPeriod);
            _macd = Indicators.MacdCrossOver(Bars.ClosePrices, MacdLongCycle, MacdShortCycle, MacdSignalPeriods);
            
            startingBalance = Account.Balance;
            _m1Bars = MarketData.GetBars(TimeFrame.Minute);
            _m1Bars.BarOpened += OnM1BarOpened;
        }

        private void OnM1BarOpened(BarOpenedEventArgs args)
        {
            if (EnableTrailing) HandleTrailingStops();
        }

        protected override void OnBar()
        {
            if (_snrIndicator != null) { double wakeUpCall = _snrIndicator.DummySignal.LastValue; }

            if (Bars.OpenTimes.LastValue == _lastBarTime) return;
            _lastBarTime = Bars.OpenTimes.LastValue;

            if (_snrIndicator == null || Bars.Count < Math.Max(3, EmaPeriod)) 
            {
                if (Bars.Count < Math.Max(3, EmaPeriod)) Print("ONBAR WAIT: Insufficient bars ({0})", Bars.Count);
                return;
            }

            var currBar = Bars.Last(1);
            var prevBar = Bars.Last(2);

            _snrIndicator.CheckRejection(TradeType.Buy, currBar.High, currBar.Low, currBar.Close, prevBar.Close, SnRRejectionMode, out bool rejMinorBuy, out bool rejMidBuy, out bool rejMajorBuy);
            _snrIndicator.CheckRejection(TradeType.Sell, currBar.High, currBar.Low, currBar.Close, prevBar.Close, SnRRejectionMode, out bool rejMinorSell, out bool rejMidSell, out bool rejMajorSell);
            CheckForBreakouts(currBar, prevBar, out bool brkMinorBuy, out bool brkMidBuy, out bool brkMajorBuy, out bool brkMinorSell, out bool brkMidSell, out bool brkMajorSell);

            if (rejMajorBuy || brkMajorBuy || rejMajorSell || brkMajorSell || rejMidBuy || brkMidBuy || rejMidSell || brkMidSell || rejMinorBuy || brkMinorBuy || rejMinorSell || brkMinorSell)
            {
                Print("ONBAR SIGNAL: MajB:{0} MajS:{1} MidB:{2} MidS:{3} MinB:{4} MinS:{5}", 
                    rejMajorBuy || brkMajorBuy, rejMajorSell || brkMajorSell, 
                    rejMidBuy || brkMidBuy, rejMidSell || brkMidSell, 
                    rejMinorBuy || brkMinorBuy, rejMinorSell || brkMinorSell);
            }

            if (rejMajorBuy || brkMajorBuy) ExecuteWave(ZoneTier.Major, TradeType.Buy);
            if (rejMajorSell || brkMajorSell) ExecuteWave(ZoneTier.Major, TradeType.Sell);
            if (rejMidBuy || brkMidBuy) ExecuteWave(ZoneTier.Mid, TradeType.Buy);
            if (rejMidSell || brkMidSell) ExecuteWave(ZoneTier.Mid, TradeType.Sell);
            if (rejMinorBuy || brkMinorBuy) ExecuteWave(ZoneTier.Minor, TradeType.Buy);
            if (rejMinorSell || brkMinorSell) ExecuteWave(ZoneTier.Minor, TradeType.Sell);
        }

        private void ExecuteWave(ZoneTier triggerTier, TradeType direction)
        {
            string label = triggerTier == ZoneTier.Major ? LBL_MAJOR : (triggerTier == ZoneTier.Mid ? LBL_MID : LBL_MINOR);
            CloseOppositePositions(label, direction);
            OpenPositionIfNone(label, direction, triggerTier);
        }

        private void OpenPositionIfNone(string label, TradeType direction, ZoneTier tier)
        {
            if (EnableHolidayBlackout && IsHoliday(Server.Time)) { Print("{0} Skip: Holiday", label); return; }
            if (Symbol.Spread / Symbol.PipSize > MaxSpread) { Print("{0} Skip: Spread", label); return; }

            if (AdxMode != AdxFilterMode.Off)
            {
                double adxVal = _adx.ADX.Last(1);
                if ((AdxMode == AdxFilterMode.Min && adxVal < AdxMin) || (AdxMode == AdxFilterMode.Max && adxVal > AdxMax) || (AdxMode == AdxFilterMode.MinMax && (adxVal < AdxMin || adxVal > AdxMax))) return;
            }

            if (EnableEma)
            {
                if ((direction == TradeType.Buy && Bars.ClosePrices.Last(1) < _ema.Result.Last(1)) || (direction == TradeType.Sell && Bars.ClosePrices.Last(1) > _ema.Result.Last(1))) return;
            }

            if (EnableMacd)
            {
                bool isPositive = _macd.Histogram.Last(1) > 0;
                if (SelectedMacdMode == MacdFilterMode.Normal)
                {
                    if (direction == TradeType.Buy && !isPositive) { Print("{0} Skip: MACD Norm Buy", label); return; }
                    if (direction == TradeType.Sell && isPositive) { Print("{0} Skip: MACD Norm Sell", label); return; }
                }
                else // Reverse Mode
                {
                    if (direction == TradeType.Buy && isPositive) { Print("{0} Skip: MACD Rev Buy", label); return; }
                    if (direction == TradeType.Sell && !isPositive) { Print("{0} Skip: MACD Rev Sell", label); return; }
                }
            }

            if (Positions.Any(p => p.Label == label && p.SymbolName == SymbolName)) return;

            double entryPrice = direction == TradeType.Buy ? Symbol.Ask : Symbol.Bid;
            double? sl = CalculateInitialStopLoss(direction, entryPrice, tier);
            if (!sl.HasValue) { Print("{0} Skip: No Zone Found", label); return; }

            double slDistance = Math.Abs(entryPrice - sl.Value);
            if (slDistance < (MinSlPips * Symbol.PipSize))
            {
                slDistance = MinSlPips * Symbol.PipSize;
                sl = direction == TradeType.Buy ? entryPrice - slDistance : entryPrice + slDistance;
                Print("{0} Info: Nudging SL to Min", label);
            }

            if (slDistance <= Symbol.Spread) { Print("{0} Skip: SL <= Spread", label); return; }

            double dollarRisk = Math.Min(Account.Balance * (Risk / 100.0), MaxDollarRisk);
            double volume = LotCalcDollar(dollarRisk, slDistance);

            double? estimatedMargin = Symbol.GetEstimatedMargin(direction, volume);
            if (estimatedMargin.HasValue && estimatedMargin.Value > Account.FreeMargin)
            {
                double maxPossibleVolume = (Account.FreeMargin / estimatedMargin.Value) * volume * 0.95;
                volume = Symbol.NormalizeVolumeInUnits(maxPossibleVolume, RoundingMode.Down);
                Print("{0} Info: Scaled Vol to {1}", label, volume);
            }

            if (volume < Symbol.VolumeInUnitsMin) { Print("{0} Skip: Vol < Min", label); return; }

            double? tp = SelectedTpStrategy == TpStrategy.NextZoneQuarter ? CalculateQuarterZoneTakeProfit(direction, entryPrice, tier) : null;
            
            Print("{0} SUCCESS: Order Executed {1} lots", label, volume);
            ExecuteMarketOrder(direction, SymbolName, volume, label, sl, tp);
        }

        private double LotCalcDollar(double riskAmount, double slDistance)
        {
            double mPS = (slDistance / Symbol.TickSize) * Symbol.TickValue * Symbol.VolumeInUnitsStep; 
            double rawVolume = (riskAmount / mPS) * Symbol.VolumeInUnitsStep;
            return Symbol.NormalizeVolumeInUnits(rawVolume, RoundingMode.Down);
        }

        private void CloseOppositePositions(string label, TradeType newDirection)
        {
            var positions = Positions.Where(p => p.Label == label && p.SymbolName == SymbolName && p.TradeType != newDirection).ToList();
            foreach (var pos in positions) ClosePosition(pos);
        }

        private bool IsHoliday(DateTime currentTime)
        {
            if (!EnableHolidayBlackout) return false;
            int m = currentTime.Month; int d = currentTime.Day;
            if (BlackoutStartMonth <= BlackoutEndMonth)
            {
                DateTime start = new DateTime(currentTime.Year, BlackoutStartMonth, BlackoutStartDay);
                DateTime end = new DateTime(currentTime.Year, BlackoutEndMonth, BlackoutEndDay);
                return currentTime.Date >= start.Date && currentTime.Date <= end.Date;
            }
            else
            {
                bool isAfterStart = (m > BlackoutStartMonth) || (m == BlackoutStartMonth && d >= BlackoutStartDay);
                bool isBeforeEnd = (m < BlackoutEndMonth) || (m == BlackoutEndMonth && d <= BlackoutEndDay);
                return isAfterStart || isBeforeEnd;
            }
        }

        private double? CalculateInitialStopLoss(TradeType direction, double entryPrice, ZoneTier tier)
        {
            var activeZones = _snrIndicator.ActiveZonesDict.Values.Where(z => z.Tier == tier).ToList();
            if (!activeZones.Any()) return null;
            var currentZone = activeZones.OrderBy(z => Math.Abs(((z.Top + z.Bottom) / 2) - entryPrice)).First();
            double atrBuffer = _atr.Result.Last(1) * (tier == ZoneTier.Minor ? MicroAtrMult : MacroAtrMult);
            return direction == TradeType.Buy ? currentZone.Bottom - (atrBuffer / 2) : currentZone.Top + (atrBuffer / 2); 
        }

        private double? CalculateQuarterZoneTakeProfit(TradeType direction, double entryPrice, ZoneTier tier)
        {
            var activeZones = _snrIndicator.ActiveZonesDict.Values.Where(z => z.Tier == tier).ToList();
            if (!activeZones.Any()) return null;
            Zone targetZone = direction == TradeType.Buy ? activeZones.Where(z => z.Bottom > entryPrice).OrderBy(z => z.Bottom).FirstOrDefault() : activeZones.Where(z => z.Top < entryPrice).OrderByDescending(z => z.Top).FirstOrDefault();
            if (targetZone != null)
            {
                double zoneHeight = targetZone.Top - targetZone.Bottom;
                return direction == TradeType.Buy ? targetZone.Bottom + (zoneHeight * 0.25) : targetZone.Top - (zoneHeight * 0.25);
            }
            return null;
        }

        private void CheckForBreakouts(Bar currBar, Bar prevBar, out bool brkMinorBuy, out bool brkMidBuy, out bool brkMajorBuy, out bool brkMinorSell, out bool brkMidSell, out bool brkMajorSell)
        {
            brkMinorBuy = brkMidBuy = brkMajorBuy = brkMinorSell = brkMidSell = brkMajorSell = false;
            foreach (var zone in _snrIndicator.ActiveZonesDict.Values)
            {
                if (prevBar.Close <= zone.Top && currBar.Close > zone.Top)
                {
                    if (zone.Tier == ZoneTier.Minor) brkMinorBuy = true;
                    else if (zone.Tier == ZoneTier.Mid) brkMidBuy = true;
                    else if (zone.Tier == ZoneTier.Major) brkMajorBuy = true;
                }
                else if (prevBar.Close >= zone.Bottom && currBar.Close < zone.Bottom)
                {
                    if (zone.Tier == ZoneTier.Minor) brkMinorSell = true;
                    else if (zone.Tier == ZoneTier.Mid) brkMidSell = true;
                    else if (zone.Tier == ZoneTier.Major) brkMajorSell = true;
                }
            }
        }

        private void HandleTrailingStops()
        {
            foreach (var pos in Positions.Where(p => p.SymbolName == SymbolName))
            {
                double? newSl = null;
                var currentPrice = pos.TradeType == TradeType.Buy ? Symbol.Bid : Symbol.Ask;
                if (pos.Label == LBL_MINOR) newSl = FindTrailingZoneSl(pos.TradeType, currentPrice, new[] { ZoneTier.Minor, ZoneTier.Mid, ZoneTier.Major });
                else if (pos.Label == LBL_MID) newSl = FindTrailingZoneSl(pos.TradeType, currentPrice, new[] { ZoneTier.Mid, ZoneTier.Major });
                else if (pos.Label == LBL_MAJOR) newSl = FindTrailingZoneSl(pos.TradeType, currentPrice, new[] { ZoneTier.Major });

                if (newSl.HasValue)
                {
                    if (pos.TradeType == TradeType.Buy && newSl > pos.StopLoss && newSl < currentPrice) 
                        ModifyPosition(pos, newSl, pos.TakeProfit);
                    else if (pos.TradeType == TradeType.Sell && newSl < pos.StopLoss && newSl > currentPrice) 
                        ModifyPosition(pos, newSl, pos.TakeProfit);
                }
            }
        }

        private double? FindTrailingZoneSl(TradeType direction, double currentPrice, ZoneTier[] allowedTiers)
        {
            var validZones = _snrIndicator.ActiveZonesDict.Values.Where(z => allowedTiers.Contains(z.Tier)).ToList();
            if (!validZones.Any()) return null;
            var trailingZone = direction == TradeType.Buy ? validZones.Where(z => z.Top < currentPrice).OrderByDescending(z => z.Top).FirstOrDefault() : validZones.Where(z => z.Bottom > currentPrice).OrderBy(z => z.Bottom).FirstOrDefault();
            if (trailingZone != null)
            {
                double atrBuffer = _atr.Result.LastValue * (trailingZone.Tier == ZoneTier.Minor ? MicroAtrMult : MacroAtrMult);
                return direction == TradeType.Buy ? trailingZone.Bottom - atrBuffer : trailingZone.Top + atrBuffer; 
            }
            return null;
        }

        protected override double GetFitness(GetFitnessArgs args) 
        { 
            if (args.NetProfit <= 0) return args.NetProfit; 
            var trades = args.History.OrderBy(t => t.ClosingTime).ToList(); 
            double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cum = 0; 
            for (int i = 0; i < trades.Count; i++) 
            { 
                cum += trades[i].NetProfit; 
                sumX += i; sumY += cum; sumXY += i * cum; sumX2 += i * i; sumY2 += cum * cum; 
            } 
            double r2 = Math.Pow(((trades.Count * sumXY) - (sumX * sumY)) / Math.Sqrt(((trades.Count * sumX2) - (sumX * sumX)) * ((trades.Count * sumY2) - (sumY * sumY))), 2); 
            double basicFitness = (((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / startingBalance) * r2;

            if(args.MaxEquityDrawdownPercentages >= 5 && args.MaxEquityDrawdownPercentages < 10) return basicFitness * 0.5; 
            if(args.MaxEquityDrawdownPercentages >= 10) return basicFitness / args.MaxEquityDrawdownPercentages;
            if(args.TotalTrades <= MinTrades) return basicFitness * args.TotalTrades/MinTrades;
            if(LinBon) return basicFitness * (1 + (args.TotalTrades - MinTrades)/MinTrades/LinDiv); 
            return basicFitness * (1 + (Math.Pow(args.TotalTrades - MinTrades, HypExp)/MinTrades));
        }
    }
}