using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;
using System.Collections.Generic;

namespace cAlgo.Robots
{
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class ShadowExpansionProBot : Robot
    {
        [Parameter("Quantity (Lots)", Group = "Trading", DefaultValue = 0.01, MinValue = 0.01, Step = 0.01)]
        public double Quantity { get; set; }

        [Parameter("Label", Group = "Trading", DefaultValue = "ShadowExp")]
        public string SignalLabel { get; set; }

        [Parameter("Expansion Threshold", Group = "Logic", DefaultValue = 2.0, MinValue = 1.0, Step = 0.1)]
        public double ExpThreshold { get; set; }

        [Parameter("Conflict Dominance", Group = "Logic", DefaultValue = 1.5, MinValue = 1.0, Step = 0.1)]
        public double ConflictDominance { get; set; }

        // --- ADX Filter ---
        [Parameter("Use ADX Filter", Group = "Filters", DefaultValue = false)]
        public bool UseAdxFilter { get; set; }

        [Parameter("ADX Period", Group = "Filters", DefaultValue = 14)]
        public int AdxPeriod { get; set; }

        [Parameter("ADX Min Level", Group = "Filters", DefaultValue = 20, MinValue = 0)]
        public double AdxMin { get; set; }

        [Parameter("ADX Max Level", Group = "Filters", DefaultValue = 50, MinValue = 0)]
        public double AdxMax { get; set; }

        // --- Time Filter ---
        [Parameter("Use Time Filter", Group = "Time Filter", DefaultValue = false)]
        public bool UseTimeFilter { get; set; }

        [Parameter("Start Hour", Group = "Time Filter", DefaultValue = 9, MinValue = 0, MaxValue = 23)]
        public int StartHour { get; set; }

        [Parameter("End Hour", Group = "Time Filter", DefaultValue = 17, MinValue = 0, MaxValue = 23)]
        public int EndHour { get; set; }

        // --- Chandelier Trailing Stop ---
        [Parameter("Use Chandelier Trail", Group = "Trailing Stop", DefaultValue = false)]
        public bool UseChandelier { get; set; }

        [Parameter("Trail TimeFrame", Group = "Trailing Stop", DefaultValue = "Hour")]
        public TimeFrame TrailTf { get; set; }

        [Parameter("Chandelier Period", Group = "Trailing Stop", DefaultValue = 22)]
        public int ChandelierPeriod { get; set; }

        [Parameter("Chandelier Multiplier", Group = "Trailing Stop", DefaultValue = 3.0)]
        public double ChandelierMultiplier { get; set; }

        private DirectionalMovementSystem _adx;
        private AverageTrueRange _atr;
        private Bars _tfBars;
        private double _startingBalance;

        protected override void OnStart()
        {
            _startingBalance = Account.Balance;
            _adx = Indicators.DirectionalMovementSystem(AdxPeriod);
            
            _tfBars = MarketData.GetBars(TrailTf);
            _atr = Indicators.AverageTrueRange(_tfBars, ChandelierPeriod, MovingAverageType.Exponential);
        }

        protected override void OnBar()
        {
            if (!IsInsideTimeWindow()) return;

            int index = Bars.Count - 1;
            int prevIndex = index - 1;
            if (prevIndex < 1) return;

            // --- Shadow Calculations ---
            double currentUpper = Bars.HighPrices[index] - Math.Max(Bars.OpenPrices[index], Bars.ClosePrices[index]);
            double currentLower = Math.Min(Bars.OpenPrices[index], Bars.ClosePrices[index]) - Bars.LowPrices[index];

            double prevUpper = Bars.HighPrices[prevIndex] - Math.Max(Bars.OpenPrices[prevIndex], Bars.ClosePrices[prevIndex]);
            double prevLower = Math.Min(Bars.OpenPrices[prevIndex], Bars.ClosePrices[prevIndex]) - Bars.LowPrices[prevIndex];

            double ratioUpper = prevUpper > 0 ? currentUpper / prevUpper : 0;
            double ratioLower = prevLower > 0 ? currentLower / prevLower : 0;

            bool upperMet = ratioUpper >= ExpThreshold;
            bool lowerMet = ratioLower >= ExpThreshold;

            bool longSignal = false;
            bool shortSignal = false;

            if (upperMet && lowerMet)
            {
                if (ratioUpper >= ConflictDominance * ratioLower) shortSignal = true;
                else if (ratioLower >= ConflictDominance * ratioUpper) longSignal = true;
            }
            else
            {
                shortSignal = upperMet;
                longSignal = lowerMet;
            }

            // --- ADX Filter Logic ---
            if (UseAdxFilter)
            {
                double adxVal = _adx.ADX.LastValue;
                if (adxVal < AdxMin || adxVal > AdxMax)
                {
                    longSignal = false;
                    shortSignal = false;
                }
            }

            // --- Execution ---
            if (longSignal)
            {
                ClosePositions(TradeType.Sell);
                if (!HasPosition(TradeType.Buy))
                    ExecuteMarketOrder(TradeType.Buy, SymbolName, Symbol.QuantityToVolumeInUnits(Quantity), SignalLabel);
            }
            else if (shortSignal)
            {
                ClosePositions(TradeType.Buy);
                if (!HasPosition(TradeType.Sell))
                    ExecuteMarketOrder(TradeType.Sell, SymbolName, Symbol.QuantityToVolumeInUnits(Quantity), SignalLabel);
            }
        }

        protected override void OnTick()
        {
            if (UseChandelier)
            {
                UpdateChandelierTrail();
            }
        }

        private void UpdateChandelierTrail()
        {
            double atrVal = _atr.Result.LastValue;
            foreach (var pos in Positions.Where(p => p.Label == SignalLabel && p.SymbolName == SymbolName))
            {
                if (pos.TradeType == TradeType.Buy)
                {
                    // Chandelier Long: Highest High - (Multiplier * ATR)
                    double highestHigh = _tfBars.HighPrices.Maximum(ChandelierPeriod);
                    double newSL = highestHigh - (ChandelierMultiplier * atrVal);
                    if (pos.StopLoss == null || newSL > pos.StopLoss)
                        ModifyPosition(pos, newSL, pos.TakeProfit);
                }
                else
                {
                    // Chandelier Short: Lowest Low + (Multiplier * ATR)
                    double lowestLow = _tfBars.LowPrices.Minimum(ChandelierPeriod);
                    double newSL = lowestLow + (ChandelierMultiplier * atrVal);
                    if (pos.StopLoss == null || newSL < pos.StopLoss)
                        ModifyPosition(pos, newSL, pos.TakeProfit);
                }
            }
        }

        private bool IsInsideTimeWindow()
        {
            if (!UseTimeFilter) return true;
            int currentHour = Server.Time.Hour;
            return (currentHour >= StartHour && currentHour < EndHour);
        }

        private bool HasPosition(TradeType type) => Positions.Any(p => p.Label == SignalLabel && p.SymbolName == SymbolName && p.TradeType == type);

        private void ClosePositions(TradeType type)
        {
            foreach (var pos in Positions.Where(p => p.Label == SignalLabel && p.SymbolName == SymbolName && p.TradeType == type))
                ClosePosition(pos);
        }

        // --- Custom Fitness Function ---
        protected override double GetFitness(GetFitnessArgs args) 
        { 
            if (args.NetProfit <= 0) return args.NetProfit;
            if (args.TotalTrades == 1) return 0; 

            bool isCrypto = SymbolName.ToUpper().Contains("BTC") || 
                            SymbolName.ToUpper().Contains("ETH") || 
                            SymbolName.ToUpper().Contains("XBT");

            TimeSpan duration = args.History.Last().ClosingTime - args.History.First().EntryTime;
            double daysPerWeek = isCrypto ? 7.0 : 5.0;
            double weeks = Math.Max(0.1, duration.TotalDays / daysPerWeek);
            double tradesPerWeek = args.TotalTrades / weeks;
            double frequencyPenalty = Math.Pow(Math.Min(1.0, tradesPerWeek / 2.0), 4); 

            var trades = args.History.OrderBy(t => t.ClosingTime).ToList(); 
            double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0, cum = 0; 
            for (int i = 0; i < trades.Count; i++) 
            { 
                cum += trades[i].NetProfit; sumX += i; sumY += cum; 
                sumXY += i * cum; sumX2 += i * i; sumY2 += cum * cum; 
            } 

            double denominator = Math.Sqrt(((trades.Count * sumX2) - (sumX * sumX)) * ((trades.Count * sumY2) - (sumY * sumY)));
            double r2 = (denominator == 0) ? 0 : Math.Pow(((trades.Count * sumXY) - (sumX * sumY)) / denominator, 2); 

            double baseScore;
            if (args.MaxEquityDrawdownPercentages >= 10) 
            {
                baseScore = ((((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / _startingBalance) * r2) / args.MaxEquityDrawdownPercentages;
            }
            else 
            {
                baseScore = (((args.ProfitFactor * (args.NetProfit / Math.Max(1, args.MaxEquityDrawdown)) * ((double)args.WinningTrades / args.TotalTrades) * r2) * Math.Log10(args.TotalTrades)) / Math.Max(0.1, args.MaxEquityDrawdownPercentages)) * (args.NetProfit / _startingBalance) * r2;
            }

            return baseScore * frequencyPenalty;
        }
    }
}