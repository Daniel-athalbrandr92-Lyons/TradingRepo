using System;
using System.Collections.Generic;
using cAlgo.API;
using cAlgo.API.Internals;
using cAlgo.API.Indicators;

namespace cAlgo.Indicators
{
    // ==========================================
    // 1. DEFINITIONS FOR THE BOT TO READ
    // ==========================================
    public enum ZoneTier { Minor, Mid, Major }
    public enum ZoneType { AsianHigh, AsianLow, LondonHigh, LondonLow, NyHigh, NyLow, DoubleTop, DoubleBottom, Consolidation, MultidayHigh, MultidayLow, DailyHigh, DailyLow, PsychLevel, OrderBlock, Rejection }
    public enum RejectionMode { WickInsideCloseOutside, PrevCloseInsideCurrCloseOutside }

    public class Zone
    {
        public double Top { get; set; }
        public double Bottom { get; set; }
        public ZoneTier Tier { get; set; }
    }

    [Indicator(IsOverlay = true, TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class DynamicSnRBoxes : Indicator
    {
        // ==========================================
        // 1. VISIBILITY TOGGLES
        // ==========================================
        [Parameter("Show Multiday H/L", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowMultiday { get; set; }

        [Parameter("Show Previous Day H/L", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowPreviousDay { get; set; }

        [Parameter("Show Asian Session", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowAsianSession { get; set; }

        [Parameter("Show London Session", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowLondonSession { get; set; }

        [Parameter("Show NY Session", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowNySession { get; set; }

        [Parameter("Show Psych Levels", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowPsychLevels { get; set; }

        [Parameter("Show Order Blocks", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowOrderBlocks { get; set; } 

        [Parameter("Show Double Tops/Bottoms", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowDoubleTopsBottoms { get; set; }

        [Parameter("Show Consolidation Zones", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowConsolidation { get; set; }

        [Parameter("Show Rejection Formations", DefaultValue = true, Group = "Visibility Toggles")]
        public bool ShowRejections { get; set; }

        [Output("Dummy Signal", LineColor = "Transparent")]
        public IndicatorDataSeries DummySignal { get; set; }

        // ==========================================
        // 2. CORE MATH & ATR SETTINGS
        // ==========================================
        [Parameter("Macro ATR Multiplier (Sessions/Psych)", DefaultValue = 0.5, MinValue = 0.25, Step = 0.25, Group = "Core Settings")]
        public double MacroAtrMultiplier { get; set; }

        [Parameter("Micro ATR Multiplier (Patterns)", DefaultValue = 0.2, MinValue = 0.1, Step = 0.1, Group = "Core Settings")]
        public double MicroAtrMultiplier { get; set; }

        [Parameter("Psych Level Step (e.g. 25 or 0.0025)", DefaultValue = 25, MinValue = 0.0025, Step = 0.0025, Group = "Core Settings")]
        public double PsychLevelStep { get; set; }

        [Parameter("UTC Offset (Hours)", DefaultValue = -5, Group = "Core Settings")]
        public int UtcOffset { get; set; }

        // ==========================================
        // 3. MULTIDAY SETTINGS
        // ==========================================
        [Parameter("Multiday TimeFrame", DefaultValue = "Weekly", Group = "Multiday Settings")]
        public TimeFrame MultidayTimeFrame { get; set; }

        [Parameter("Multiday Lookback (Candles)", DefaultValue = 1, MinValue = 1, Group = "Multiday Settings")]
        public int MultidayLookback { get; set; }

        // ==========================================
        // 4. SESSION HOURS (0-23)
        // ==========================================
        [Parameter("Asian Start Hour", DefaultValue = 18, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int AsianStartHour { get; set; }

        [Parameter("Asian End Hour", DefaultValue = 3, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int AsianEndHour { get; set; }

        [Parameter("London Start Hour", DefaultValue = 3, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int LondonStartHour { get; set; }

        [Parameter("London End Hour", DefaultValue = 11, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int LondonEndHour { get; set; }

        [Parameter("NY Start Hour", DefaultValue = 8, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int NyStartHour { get; set; }

        [Parameter("NY End Hour", DefaultValue = 17, MinValue = 0, MaxValue = 23, Group = "Session Hours")]
        public int NyEndHour { get; set; }

        // ==========================================
        // 5. PATTERN RECOGNITION RULES
        // ==========================================
        [Parameter("Min Formation Candles", DefaultValue = 10, MinValue = 3, Group = "Pattern Rules")]
        public int MinFormationCandles { get; set; }

        [Parameter("Max Lookback Candles", DefaultValue = 50, MinValue = 10, Group = "Pattern Rules")]
        public int MaxLookbackCandles { get; set; }

        [Parameter("Max Consolidation Width (ATR Mult)", DefaultValue = 1.5, MinValue = 0.5, Step = 0.25, Group = "Pattern Rules")]
        public double MaxConsolidationAtrWidth { get; set; }
        
        // ==========================================
        // GLOBAL VARIABLES
        // ==========================================
        private AverageTrueRange _atr;
        private Bars _multidayBars;
        private Bars _dailyBars; 
        private int _lastProcessedIndex = -1; 
        private int priorMtfIndex = -1;
        private int priorDailyIndex = -1;
        private double _tempAsianHigh = -1;
        private double _tempAsianLow = -1;
        private double _tempAsianAtrSum = -1;
        private int _tempAsianCandleCount = -1;
        private double _tempLondonHigh = -1;
        private double _tempLondonLow = -1;
        private double _tempLondonAtrSum = -1;
        private int _tempLondonCandleCount = -1;
        private double _tempNYHigh = -1;
        private double _tempNYLow = -1;
        private double _tempNYAtrSum = -1;
        private int _tempNYCandleCount = -1;
        private double _nearestPsychQuartileAbove;
        private double _nearestPsychQuartileBelow;
        private double _nearestPsychHalfAbove;
        private double _nearestPsychHalfBelow;
        private double _nearestPsychCenturyAbove;
        private double _nearestPsychCenturyBelow;

        // THE DICTIONARY FOR THE BOT
        public Dictionary<ZoneType, Zone> ActiveZonesDict = new Dictionary<ZoneType, Zone>();

        // ==========================================
        // DATA STRUCTURES
        // ==========================================
        public class PriceZone
        {
            public double High { get; set; }
            public double Low { get; set; }
            public int StartIndex { get; set; }
            public bool IsActive { get; set; }
            public double AverageAtr { get; set; } 
        }
        private PriceZone _multidayZone = new PriceZone();
        private PriceZone _dailyZone = new PriceZone();
        private PriceZone _asianZone = new PriceZone();
        private PriceZone _londonZone = new PriceZone();
        private PriceZone _nyZone = new PriceZone();

        public class OrderBlock
        {
            public double Top { get; set; }
            public double Bottom { get; set; }
            public int StartIndex { get; set; }
            public bool IsBullish { get; set; }
            public string Name { get; set; } 
        }

        private List<OrderBlock> _activeOrderBlocks = new List<OrderBlock>();
        private int _obCounter = 0; 

        public class ChartFormation
        {
            public double Top { get; set; }
            public double Bottom { get; set; }
            public int StartIndex { get; set; }
            public string Name { get; set; }
        }

        private List<ChartFormation> _activeDoubles = new List<ChartFormation>();
        private int _doubleCounter = 0;

        private List<ChartFormation> _activeConsolidations = new List<ChartFormation>();
        private int _consolidationCounter = 0;

        public class RejectionFormation
        {
            public double Top { get; set; }
            public double Bottom { get; set; }
            public int StartIndex { get; set; }
            public string Name { get; set; }
            public ZoneTier Tier { get; set; }
        }

        private List<RejectionFormation> _activeRejections = new List<RejectionFormation>();
        private int _rejectionCounter = 0;

        private int formationCheck; 

        protected override void Initialize()
        {
            _atr = Indicators.AverageTrueRange(14, MovingAverageType.Simple);

            if (ShowMultiday)
            {
                _multidayBars = MarketData.GetBars(MultidayTimeFrame);
            }

            if (ShowPreviousDay)
            {
                _dailyBars = MarketData.GetBars(TimeFrame.Daily);
            }

            formationCheck = Math.Min(5, MinFormationCandles);
        }

        public override void Calculate(int index)
        {
            DummySignal[index] = 0;

            if (index == _lastProcessedIndex) return;
            _lastProcessedIndex = index;

            // 1. Core Session Math (Fast)
            if(ShowAsianSession || ShowLondonSession || ShowNySession)
                CalculateSessions();

            // 2. Structural Math (Only run on new bars or specific intervals)
            if (index % formationCheck == 0) 
            {
                if(ShowMultiday) CalculateMultiday();
                if(ShowPreviousDay) CalculateDaily();
                if(ShowPsychLevels) CalculatePsychLevels();
        
                // 3. Heavy Pattern Scanning
                if(ShowOrderBlocks) ScanOrderBlocks();
                if(ShowDoubleTopsBottoms) ScanDoubles();
                if(ShowConsolidation) ScanConsolidations();
                if(ShowRejections) ScanRejections();
            }

            // 4. DRAWING (Skip entirely if optimizing)
            if (!IsBacktesting) 
            {
                if(ShowMultiday) DrawMultiday();
                if(ShowPreviousDay) DrawDaily();
                DrawSessions();
                if(ShowPsychLevels) DrawPsychLevels();
                if(ShowOrderBlocks) DrawOrderBlocks();
                if(ShowDoubleTopsBottoms) DrawDoubles();
                if(ShowConsolidation) DrawConsolidations();
                if(ShowRejections) DrawRejections();
            }
        }

        private void CalculateMultiday()
        {
            DateTime currentTime = Bars.OpenTimes[_lastProcessedIndex];
            int mtfIndex = _multidayBars.OpenTimes.GetIndexByTime(currentTime);
    
            // ONLY run the heavy math if we have moved to a NEW MTF bar
            if(mtfIndex == priorMtfIndex) return;
            
            if(mtfIndex != priorMtfIndex)
            {
                priorMtfIndex = mtfIndex;
                _multidayZone.StartIndex = _lastProcessedIndex;
            }

            if (mtfIndex < MultidayLookback)
                return;

            double highest = double.MinValue;
            double lowest = double.MaxValue;

            for (int i = 1; i <= MultidayLookback; i++)
            {
                double barHigh = _multidayBars.HighPrices[mtfIndex - i];
                double barLow = _multidayBars.LowPrices[mtfIndex - i];

                if (barHigh > highest) highest = barHigh;
                if (barLow < lowest) lowest = barLow;
            }

            _multidayZone.High = highest;
            _multidayZone.Low = lowest;

            double maxSessionAtr = 0;
            if (ShowAsianSession) maxSessionAtr = Math.Max(maxSessionAtr, _asianZone.AverageAtr);
            if (ShowLondonSession) maxSessionAtr = Math.Max(maxSessionAtr, _londonZone.AverageAtr);
            if (ShowNySession) maxSessionAtr = Math.Max(maxSessionAtr, _nyZone.AverageAtr);

            if (maxSessionAtr == 0 || double.IsNaN(maxSessionAtr))
            {
                maxSessionAtr = _atr.Result[_lastProcessedIndex];
            }   

            _multidayZone.AverageAtr = maxSessionAtr;

            // --- Update Dictionary for Bot ---
            double atrBuffer = _multidayZone.AverageAtr * MacroAtrMultiplier;
            ActiveZonesDict[ZoneType.MultidayHigh] = new Zone { Top = _multidayZone.High + atrBuffer, Bottom = _multidayZone.High - atrBuffer, Tier = ZoneTier.Major };
            ActiveZonesDict[ZoneType.MultidayLow] = new Zone { Top = _multidayZone.Low + atrBuffer, Bottom = _multidayZone.Low - atrBuffer, Tier = ZoneTier.Major };
        }

        private void DrawMultiday()
        {
            if (double.IsNaN(_atr.Result[_lastProcessedIndex])) return;

            double atrBuffer = _multidayZone.AverageAtr * MacroAtrMultiplier;
            double resTop = _multidayZone.High + atrBuffer;
            double resBottom = _multidayZone.High - atrBuffer;
            double supTop = _multidayZone.Low + atrBuffer;
            double supBottom = _multidayZone.Low - atrBuffer;

            Color multidayColor = Color.FromArgb(204, Color.Red);

            string resName = "Multiday_Res_" + _multidayZone.StartIndex;
            string supName = "Multiday_Sup_" + _multidayZone.StartIndex;

            var resBox = Chart.DrawRectangle(resName, _multidayZone.StartIndex, resTop, _lastProcessedIndex + 1, resBottom, multidayColor);
            resBox.IsFilled = true;
            var supBox = Chart.DrawRectangle(supName, _multidayZone.StartIndex, supTop, _lastProcessedIndex + 1, supBottom, multidayColor);
            supBox.IsFilled = true;
        }

        private void CalculateDaily()
        {
            DateTime currentTime = Bars.OpenTimes[_lastProcessedIndex];
            int dailyIndex = _dailyBars.OpenTimes.GetIndexByTime(currentTime);
            
            if(dailyIndex != priorDailyIndex)
            {
                priorDailyIndex = dailyIndex;
                _dailyZone.StartIndex = _lastProcessedIndex;
            }

            if (dailyIndex < 1)
                return;

            _dailyZone.High = _dailyBars.HighPrices[dailyIndex - 1];
            _dailyZone.Low = _dailyBars.LowPrices[dailyIndex - 1];

            double maxSessionAtr = 0;
            if (ShowAsianSession) maxSessionAtr = Math.Max(maxSessionAtr, _asianZone.AverageAtr);
            if (ShowLondonSession) maxSessionAtr = Math.Max(maxSessionAtr, _londonZone.AverageAtr);
            if (ShowNySession) maxSessionAtr = Math.Max(maxSessionAtr, _nyZone.AverageAtr);

            if (maxSessionAtr == 0 || double.IsNaN(maxSessionAtr))
            {
                maxSessionAtr = _atr.Result[_lastProcessedIndex];
            }   

            _dailyZone.AverageAtr = maxSessionAtr;

            // --- Update Dictionary for Bot ---
            double atrBuffer = _dailyZone.AverageAtr * MacroAtrMultiplier;
            ActiveZonesDict[ZoneType.DailyHigh] = new Zone { Top = _dailyZone.High + atrBuffer, Bottom = _dailyZone.High - atrBuffer, Tier = ZoneTier.Mid };
            ActiveZonesDict[ZoneType.DailyLow] = new Zone { Top = _dailyZone.Low + atrBuffer, Bottom = _dailyZone.Low - atrBuffer, Tier = ZoneTier.Mid };
        }

        private void DrawDaily()
        {
            if (double.IsNaN(_atr.Result[_lastProcessedIndex])) return;

            double atrBuffer = _dailyZone.AverageAtr * MacroAtrMultiplier;
            double resTop = _dailyZone.High + atrBuffer;
            double resBottom = _dailyZone.High - atrBuffer;
            double supTop = _dailyZone.Low + atrBuffer;
            double supBottom = _dailyZone.Low - atrBuffer;

            Color dailyColor = Color.FromArgb(153, Color.Red);

            string resName = "Daily_Res_" + _dailyZone.StartIndex;
            string supName = "Daily_Sup_" + _dailyZone.StartIndex;

            var resBox = Chart.DrawRectangle(resName, _dailyZone.StartIndex, resTop, _lastProcessedIndex + 1, resBottom, dailyColor);
            resBox.IsFilled = true;
            var supBox = Chart.DrawRectangle(supName, _dailyZone.StartIndex, supTop, _lastProcessedIndex + 1, supBottom, dailyColor);
            supBox.IsFilled = true;            
        }

        private void CalculateSessions()
        {
            DateTime candleTime = Bars.OpenTimes[_lastProcessedIndex].AddHours(UtcOffset);
            int currentHour = candleTime.Hour;

            // ==========================================
            // ASIAN SESSION LOGIC
            // ==========================================
            if(ShowAsianSession)
            {
                bool isAsianSession = false;
                if (AsianStartHour > AsianEndHour)
                    isAsianSession = (currentHour >= AsianStartHour || currentHour < AsianEndHour);
                else
                    isAsianSession = (currentHour >= AsianStartHour && currentHour < AsianEndHour);

                if (isAsianSession)
                {
                    if (!_asianZone.IsActive)
                    {
                        _asianZone.IsActive = true;
                        _tempAsianHigh = double.MinValue;
                        _tempAsianLow = double.MaxValue;
                        _tempAsianAtrSum = 0; 
                        _tempAsianCandleCount = 0;
                    }

                    double currentHigh = Bars.HighPrices[_lastProcessedIndex];
                    double currentLow = Bars.LowPrices[_lastProcessedIndex];

                    if (currentHigh > _tempAsianHigh) 
                        _tempAsianHigh = currentHigh;
                    if (currentLow < _tempAsianLow) 
                        _tempAsianLow = currentLow;

                    if(!double.IsNaN(_atr.Result[_lastProcessedIndex]))
                    {
                        _tempAsianAtrSum += _atr.Result[_lastProcessedIndex];
                        _tempAsianCandleCount++;
                    }
                }
                else
                {
                    if (_asianZone.IsActive)
                    {
                        _asianZone.IsActive = false; 
                        _asianZone.High = _tempAsianHigh;
                        _asianZone.Low = _tempAsianLow;
                        _asianZone.AverageAtr = _tempAsianAtrSum / _tempAsianCandleCount;
                        _asianZone.StartIndex = _lastProcessedIndex; 

                        // --- Update Dictionary for Bot ---
                        double atrBuffer = _asianZone.AverageAtr * MacroAtrMultiplier;
                        ActiveZonesDict[ZoneType.AsianHigh] = new Zone { Top = _asianZone.High + atrBuffer, Bottom = _asianZone.High - atrBuffer, Tier = ZoneTier.Minor };
                        ActiveZonesDict[ZoneType.AsianLow] = new Zone { Top = _asianZone.Low + atrBuffer, Bottom = _asianZone.Low - atrBuffer, Tier = ZoneTier.Minor };
                    }
                }
            }
    
            // ==========================================
            // London SESSION LOGIC
            // ==========================================
            if(ShowLondonSession)
            {
                bool isLondonSession = false;
                if (LondonStartHour > LondonEndHour)
                    isLondonSession = (currentHour >= LondonStartHour || currentHour < LondonEndHour);
                else
                    isLondonSession = (currentHour >= LondonStartHour && currentHour < LondonEndHour);

                if (isLondonSession)
                {
                    if (!_londonZone.IsActive)
                    {
                        _londonZone.IsActive = true;
                        _tempLondonHigh = double.MinValue;
                        _tempLondonLow = double.MaxValue;
                        _tempLondonAtrSum = 0; 
                        _tempLondonCandleCount = 0;
                    }

                    double currentHigh = Bars.HighPrices[_lastProcessedIndex];
                    double currentLow = Bars.LowPrices[_lastProcessedIndex];

                    if (currentHigh > _tempLondonHigh) 
                        _tempLondonHigh = currentHigh;
                    if (currentLow < _tempLondonLow) 
                        _tempLondonLow = currentLow;

                    _tempLondonAtrSum += _atr.Result[_lastProcessedIndex];
                    _tempLondonCandleCount++;
                }
                else
                {
                    if (_londonZone.IsActive)
                    {
                        _londonZone.IsActive = false; 
                        _londonZone.High = _tempLondonHigh;
                        _londonZone.Low = _tempLondonLow;
                        _londonZone.StartIndex = _lastProcessedIndex;
                        _londonZone.AverageAtr = _tempLondonAtrSum / _tempLondonCandleCount; 

                        // --- Update Dictionary for Bot ---
                        double atrBuffer = _londonZone.AverageAtr * MacroAtrMultiplier;
                        ActiveZonesDict[ZoneType.LondonHigh] = new Zone { Top = _londonZone.High + atrBuffer, Bottom = _londonZone.High - atrBuffer, Tier = ZoneTier.Minor };
                        ActiveZonesDict[ZoneType.LondonLow] = new Zone { Top = _londonZone.Low + atrBuffer, Bottom = _londonZone.Low - atrBuffer, Tier = ZoneTier.Minor };
                    }
                }
            }

            // ==========================================
            // NEW YORK SESSION LOGIC
            // ==========================================
            if(ShowNySession)
            {
                bool isNYSession = false;
                if (NyStartHour > NyEndHour)
                    isNYSession = (currentHour >= NyStartHour || currentHour < NyEndHour);
                else
                    isNYSession = (currentHour >= NyStartHour && currentHour < NyEndHour);

                if (isNYSession)
                {
                    if (!_nyZone.IsActive)
                    {
                        _nyZone.IsActive = true;
                        _tempNYHigh = double.MinValue;
                        _tempNYLow = double.MaxValue;
                        _tempNYAtrSum = 0; 
                        _tempNYCandleCount = 0;
                    }

                    double currentHigh = Bars.HighPrices[_lastProcessedIndex];
                    double currentLow = Bars.LowPrices[_lastProcessedIndex];

                    if (currentHigh > _tempNYHigh) 
                        _tempNYHigh = currentHigh;
                    if (currentLow < _tempNYLow) 
                        _tempNYLow = currentLow;

                    _tempNYAtrSum += _atr.Result[_lastProcessedIndex];
                    _tempNYCandleCount++;
                }
                else
                {
                    if (_nyZone.IsActive)
                    {
                        _nyZone.IsActive = false; 
                        _nyZone.High = _tempNYHigh;
                        _nyZone.Low = _tempNYLow;
                        _nyZone.StartIndex = _lastProcessedIndex;
                        _nyZone.AverageAtr = _tempNYAtrSum / _tempNYCandleCount;

                        // --- Update Dictionary for Bot ---
                        double atrBuffer = _nyZone.AverageAtr * MacroAtrMultiplier;
                        ActiveZonesDict[ZoneType.NyHigh] = new Zone { Top = _nyZone.High + atrBuffer, Bottom = _nyZone.High - atrBuffer, Tier = ZoneTier.Minor };
                        ActiveZonesDict[ZoneType.NyLow] = new Zone { Top = _nyZone.Low + atrBuffer, Bottom = _nyZone.Low - atrBuffer, Tier = ZoneTier.Minor };
                    }
                }
            }
        }

        private void DrawSessions()
        {
            if (double.IsNaN(_atr.Result[_lastProcessedIndex])) return;

            double AsianAtrBuffer = _asianZone.AverageAtr * MacroAtrMultiplier;
            double asianHighTop = _asianZone.High + AsianAtrBuffer;
            double asianHighBottom = _asianZone.High - AsianAtrBuffer;
            double asianLowTop = _asianZone.Low + AsianAtrBuffer;
            double asianLowBottom = _asianZone.Low - AsianAtrBuffer;
            double LondonAtrBuffer = _londonZone.AverageAtr * MacroAtrMultiplier;
            double londonHighTop = _londonZone.High + LondonAtrBuffer;
            double londonHighBottom = _londonZone.High - LondonAtrBuffer;
            double londonLowTop = _londonZone.Low + LondonAtrBuffer;
            double londonLowBottom = _londonZone.Low - LondonAtrBuffer;
            double NyAtrBuffer = _nyZone.AverageAtr * MacroAtrMultiplier;
            double nyHighTop = _nyZone.High + NyAtrBuffer;
            double nyHighBottom = _nyZone.High - NyAtrBuffer;
            double nyLowTop = _nyZone.Low + NyAtrBuffer;
            double nyLowBottom = _nyZone.Low - NyAtrBuffer;

            Color sessionsColor = Color.FromArgb(102, Color.Red);

            string asianHighName = "Asian_Res_" + _asianZone.StartIndex;
            string asianLowName = "Asian_Sup_" + _asianZone.StartIndex;
            string londonHighName = "London_Res_" + _londonZone.StartIndex;
            string londonLowName = "London_Sup_" + _londonZone.StartIndex;
            string nyHighName = "NY_Res_" + _nyZone.StartIndex;
            string nyLowName = "NY_Sup_" + _nyZone.StartIndex;

            double currentPrice = Bars.ClosePrices[_lastProcessedIndex];

            double distToAsianHigh = Math.Abs(_asianZone.High - currentPrice);
            double distToLondonHigh = Math.Abs(_londonZone.High - currentPrice);
            double distToNyHigh = Math.Abs(_nyZone.High - currentPrice);
            double distToAsianLow = Math.Abs(_asianZone.Low - currentPrice);
            double distToLondonLow = Math.Abs(_londonZone.Low - currentPrice);
            double distToNyLow = Math.Abs(_nyZone.Low - currentPrice);

            bool isAsianClosestHigh = (distToAsianHigh < distToLondonHigh) && (distToAsianHigh < distToNyHigh);
            bool isLondonClosestHigh = (distToLondonHigh < distToAsianHigh) && (distToLondonHigh < distToNyHigh);
            bool isNyClosestHigh = (distToNyHigh < distToAsianHigh) && (distToNyHigh < distToLondonHigh);
            bool isAsianClosestLow = (distToAsianLow < distToLondonLow) && (distToAsianLow < distToNyLow);
            bool isLondonClosestLow = (distToLondonLow < distToAsianLow) && (distToLondonLow < distToNyLow);
            bool isNyClosestLow = (distToNyLow < distToAsianLow) && (distToNyLow < distToLondonLow);

            if(ShowAsianSession && _asianZone.High != -1 && _asianZone.Low != -1)
            {
                if(isAsianClosestHigh)
                {
                    var asianHighBox = Chart.DrawRectangle(asianHighName, _asianZone.StartIndex, asianHighTop, _lastProcessedIndex + 1, asianHighBottom, sessionsColor);
                    asianHighBox.IsFilled = true;
                }
                if(isAsianClosestLow)
                {
                    var asianLowBox = Chart.DrawRectangle(asianLowName, _asianZone.StartIndex, asianLowTop, _lastProcessedIndex + 1, asianLowBottom, sessionsColor);
                    asianLowBox.IsFilled = true;
                }
            }
            if(ShowLondonSession && _londonZone.High != -1 && _londonZone.Low != -1)
            {
                if(isLondonClosestHigh)
                {
                    var londonHighBox = Chart.DrawRectangle(londonHighName, _londonZone.StartIndex, londonHighTop, _lastProcessedIndex + 1, londonHighBottom, sessionsColor);
                    londonHighBox.IsFilled = true;
                }
                if(isLondonClosestLow)
                {
                    var londonLowBox = Chart.DrawRectangle(londonLowName, _londonZone.StartIndex, londonLowTop, _lastProcessedIndex + 1, londonLowBottom, sessionsColor);
                    londonLowBox.IsFilled = true;
                }
            }
            if(ShowNySession && _nyZone.High != -1 && _nyZone.Low != -1)
            {   
                if(isNyClosestHigh)
                {
                    var nyHighBox = Chart.DrawRectangle(nyHighName, _nyZone.StartIndex, nyHighTop, _lastProcessedIndex + 1, nyHighBottom, sessionsColor);
                    nyHighBox.IsFilled = true;
                }
                if(isNyClosestLow)
                {
                    var nyLowBox = Chart.DrawRectangle(nyLowName, _nyZone.StartIndex, nyLowTop, _lastProcessedIndex + 1, nyLowBottom, sessionsColor);
                    nyLowBox.IsFilled = true;      
                }
            }       
        }

        private void CalculatePsychLevels()
        {
            double halfStep = PsychLevelStep * 2;
            double centuryStep = halfStep * 2;
            double currentPrice = Bars.ClosePrices[_lastProcessedIndex];

            double quartileAbove = Math.Ceiling(currentPrice / PsychLevelStep) * PsychLevelStep;
            double halfAbove = Math.Ceiling(currentPrice / halfStep) * halfStep;
            double centuryAbove = Math.Ceiling(currentPrice / centuryStep) * centuryStep;

            double quartileBelow = Math.Floor(currentPrice / PsychLevelStep) * PsychLevelStep;
            double halfBelow = Math.Floor(currentPrice / halfStep) * halfStep;
            double centuryBelow = Math.Floor(currentPrice / centuryStep) * centuryStep;

            if (quartileAbove == currentPrice || quartileAbove == halfAbove || quartileAbove == centuryAbove) 
                quartileAbove += PsychLevelStep;
            if (quartileBelow == currentPrice || quartileBelow == halfBelow || quartileBelow == centuryBelow) 
                quartileBelow -= PsychLevelStep;
            if(halfAbove == currentPrice || halfAbove == centuryAbove)
                halfAbove += halfStep;
            if(halfBelow == currentPrice || halfBelow == centuryBelow)
                halfBelow -= halfStep;
            if(centuryAbove == currentPrice)
                centuryAbove += centuryStep;
            if(centuryBelow == currentPrice)
                centuryBelow -= centuryStep;

            _nearestPsychQuartileAbove = quartileAbove;
            _nearestPsychQuartileBelow = quartileBelow;
            _nearestPsychHalfAbove = halfAbove;
            _nearestPsychHalfBelow = halfBelow;
            _nearestPsychCenturyAbove = centuryAbove;
            _nearestPsychCenturyBelow = centuryBelow;

            // --- Update Dictionary for Bot (We only pass the nearest Century and Half levels to the bot as Mid-Tier) ---
            if (_dailyZone.AverageAtr != 0 && !double.IsNaN(_dailyZone.AverageAtr))
            {
                double atrBuffer = _dailyZone.AverageAtr * MacroAtrMultiplier;
                // For simplicity, we create a generic PsychLevel entry covering the closest major line
                double distCentury = Math.Min(Math.Abs(currentPrice - centuryAbove), Math.Abs(currentPrice - centuryBelow));
                double distHalf = Math.Min(Math.Abs(currentPrice - halfAbove), Math.Abs(currentPrice - halfBelow));
                
                double closestPsych = distCentury <= distHalf ? (Math.Abs(currentPrice - centuryAbove) <= Math.Abs(currentPrice - centuryBelow) ? centuryAbove : centuryBelow) : (Math.Abs(currentPrice - halfAbove) <= Math.Abs(currentPrice - halfBelow) ? halfAbove : halfBelow);

                ActiveZonesDict[ZoneType.PsychLevel] = new Zone { Top = closestPsych + atrBuffer, Bottom = closestPsych - atrBuffer, Tier = ZoneTier.Mid };
            }
        }

        private void DrawPsychLevels()
        {
            if (_dailyZone.AverageAtr == 0 || double.IsNaN(_dailyZone.AverageAtr))
                return;

            double atrBuffer = _dailyZone.AverageAtr * MacroAtrMultiplier;
            int startIndex = _multidayZone.StartIndex;
            int endIndex = _lastProcessedIndex + 1;

            Color centColor = Color.FromArgb(204, Color.Green); 
            Color halfColor = Color.FromArgb(153, Color.Green); 
            Color quartColor = Color.FromArgb(102, Color.Green); 

            var centAbove = Chart.DrawRectangle("Psych_Cent_Above", startIndex, _nearestPsychCenturyAbove + atrBuffer, endIndex, _nearestPsychCenturyAbove - atrBuffer, centColor);
            centAbove.IsFilled = true;
            var centBelow = Chart.DrawRectangle("Psych_Cent_Below", startIndex, _nearestPsychCenturyBelow + atrBuffer, endIndex, _nearestPsychCenturyBelow - atrBuffer, centColor);
            centBelow.IsFilled = true;

            var halfAbove = Chart.DrawRectangle("Psych_Half_Above", startIndex, _nearestPsychHalfAbove + atrBuffer, endIndex, _nearestPsychHalfAbove - atrBuffer, halfColor);
            halfAbove.IsFilled = true;
            var halfBelow = Chart.DrawRectangle("Psych_Half_Below", startIndex, _nearestPsychHalfBelow + atrBuffer, endIndex, _nearestPsychHalfBelow - atrBuffer, halfColor);
            halfBelow.IsFilled = true;

            var quartAbove = Chart.DrawRectangle("Psych_Quart_Above", startIndex, _nearestPsychQuartileAbove + atrBuffer, endIndex, _nearestPsychQuartileAbove - atrBuffer, quartColor);
            quartAbove.IsFilled = true;
            var quartBelow = Chart.DrawRectangle("Psych_Quart_Below", startIndex, _nearestPsychQuartileBelow + atrBuffer, endIndex, _nearestPsychQuartileBelow - atrBuffer, quartColor);
            quartBelow.IsFilled = true;
        }

        private void ScanOrderBlocks()
        {
            // 1. CLEANUP (Only manage chart objects if not backtesting)
            for (int i = _activeOrderBlocks.Count - 1; i >= 0; i--)
            {
                var ob = _activeOrderBlocks[i];
                double currentClose = Bars.ClosePrices[_lastProcessedIndex];

                bool broken = (ob.IsBullish && currentClose < ob.Bottom) || (!ob.IsBullish && currentClose > ob.Top);
        
                if (broken)
                {       
                    if (!IsBacktesting) Chart.RemoveObject(ob.Name);
                    _activeOrderBlocks.RemoveAt(i);
                }
            }

            int index = _lastProcessedIndex - 1;
            if (index < 3 || double.IsNaN(_atr.Result[index])) return;

            double open = Bars.OpenPrices[index];
            double close = Bars.ClosePrices[index];
            double bodySize = Math.Abs(close - open);

            // Only look for a new OB if we have an impulse candle (1.5x ATR)
            if (bodySize > (_atr.Result[index] * 1.5))
            {
                bool isBullishImpulse = close > open;
                int traceIndex = -1;

                // 2. UNROLLED LOOP (Direct checks for the 3 preceding candles)
                // We look for the "Opposite" candle that preceded the impulse
                if (isBullishImpulse)
                {
                    if (Bars.ClosePrices[index - 1] < Bars.OpenPrices[index - 1]) traceIndex = index - 1;
                    else if (Bars.ClosePrices[index - 2] < Bars.OpenPrices[index - 2]) traceIndex = index - 2;
                    else if (Bars.ClosePrices[index - 3] < Bars.OpenPrices[index - 3]) traceIndex = index - 3;
                }
                else // Bearish Impulse
                {
                    if (Bars.ClosePrices[index - 1] > Bars.OpenPrices[index - 1]) traceIndex = index - 1;
                    else if (Bars.ClosePrices[index - 2] > Bars.OpenPrices[index - 2]) traceIndex = index - 2;
                    else if (Bars.ClosePrices[index - 3] > Bars.OpenPrices[index - 3]) traceIndex = index - 3;
                }

                // 3. ADD THE ZONE IF FOUND
                if (traceIndex != -1)
                {
                    _obCounter++;
                    string obName = (isBullishImpulse ? "OB_Bull_" : "OB_Bear_") + _obCounter;
            
                    _activeOrderBlocks.Add(new OrderBlock
                    {
                        Top = Bars.HighPrices[traceIndex],
                        Bottom = Bars.LowPrices[traceIndex],
                        StartIndex = traceIndex,
                        IsBullish = isBullishImpulse,
                        Name = obName
                    });

                    ActiveZonesDict[ZoneType.OrderBlock] = new Zone 
                    { 
                        Top = Bars.HighPrices[traceIndex], 
                        Bottom = Bars.LowPrices[traceIndex], 
                        Tier = ZoneTier.Mid 
                    };
                }   
            }
        }

        private void DrawOrderBlocks()
        {
            Color bullColor = Color.FromArgb(179, Color.Blue); 
            Color bearColor = Color.FromArgb(179, Color.Blue);   

            foreach (var ob in _activeOrderBlocks)
            {
                Color obColor = ob.IsBullish ? bullColor : bearColor;
                var box = Chart.DrawRectangle(ob.Name, ob.StartIndex, ob.Top, _lastProcessedIndex + 3, ob.Bottom, obColor);
                box.IsFilled = true;
            }
        }

        private bool ScanDoubles()
        {
            bool newFormationAdded = false;

            for (int i = _activeDoubles.Count - 1; i >= 0; i--)
            {
                var formation = _activeDoubles[i];
                double currentClose = Bars.ClosePrices[_lastProcessedIndex];

                if (currentClose > formation.Top || currentClose < formation.Bottom)
                {
                    Chart.RemoveObject(formation.Name);
                    _activeDoubles.RemoveAt(i);
                }
            }

            int index = _lastProcessedIndex - 1;
            if (index < MinFormationCandles || double.IsNaN(_atr.Result[index])) return false;

            double currentHigh = Bars.HighPrices[index];
            double currentLow = Bars.LowPrices[index];
    
            double microAtrBuffer = _atr.Result[index] * MicroAtrMultiplier;

            for (int i = MinFormationCandles; i <= MaxLookbackCandles; i++)
            {
                int pastIndex = index - i;
                double pastHigh = Bars.HighPrices[pastIndex];
                double pastLow = Bars.LowPrices[pastIndex];
                double pastBodyMax = Math.Max(Bars.OpenPrices[pastIndex], Bars.ClosePrices[pastIndex]);
                double pastBodyMin = Math.Min(Bars.OpenPrices[pastIndex], Bars.ClosePrices[pastIndex]);

                // ==========================================
                // OPTIMIZED DOUBLE TOP LOGIC
                // ==========================================
                double topWickSize = pastHigh - pastBodyMax;
                double zoneMaxTop = pastHigh + topWickSize;
                double zoneMinTop = pastBodyMax; 

                if (currentHigh >= zoneMinTop && currentHigh <= zoneMaxTop)
                {
                    // REPLACEMENT FOR YOUR NESTED LOOP:
                    // This one line replaces the "for (int j = 1; j < i; j++)" block
                    double lowestBetween = Bars.LowPrices.Minimum(i); 

                    // We use a simple ATR-based distance check to ensure it's a "V" shape
                    if (currentHigh - lowestBetween > microAtrBuffer * 2) 
                    {
                        _doubleCounter++;
                        _activeDoubles.Add(new ChartFormation
                        {
                            Top = zoneMaxTop,
                            Bottom = zoneMinTop,
                            StartIndex = pastIndex,
                            Name = "DoubleTop_" + _doubleCounter
                        });

                        ActiveZonesDict[ZoneType.DoubleTop] = new Zone { Top = zoneMaxTop, Bottom = zoneMinTop, Tier = ZoneTier.Minor };
                        newFormationAdded = true;
                        break;
                    }
                }
        
                // ==========================================
                // DOUBLE BOTTOM LOGIC
                // ==========================================
                double bottomWickSize = pastBodyMin - pastLow;
                double zoneMaxBottom = pastBodyMin; 
                double zoneMinBottom = pastLow - bottomWickSize;

                if (currentLow <= zoneMaxBottom && currentLow >= zoneMinBottom)
                {
                    double highestBetween = Bars.LowPrices.Maximum(i);

                    if (highestBetween - currentLow > microAtrBuffer * 2) 
                    {
                        _doubleCounter++;
                        _activeDoubles.Add(new ChartFormation
                        {
                            Top = zoneMaxBottom,
                            Bottom = zoneMinBottom,
                            StartIndex = pastIndex,
                            Name = "DoubleBot_" + _doubleCounter
                        });

                        // --- Update Dictionary for Bot ---
                        ActiveZonesDict[ZoneType.DoubleBottom] = new Zone { Top = zoneMaxBottom, Bottom = zoneMinBottom, Tier = ZoneTier.Minor };
                        
                        newFormationAdded = true;
                        break;
                    }
                }
            }

            return newFormationAdded;
        }

        private void DrawDoubles()
        {
            Color formationColor = Color.FromArgb(128, Color.Blue);

            foreach (var formation in _activeDoubles)
            {
                var box = Chart.DrawRectangle(formation.Name, formation.StartIndex, formation.Top, _lastProcessedIndex + 3, formation.Bottom, formationColor);
                box.IsFilled = true;
            }
        }

        private void ScanConsolidations()
        {
            for (int i = _activeConsolidations.Count - 1; i >= 0; i--)
            {
                var zone = _activeConsolidations[i];
                double currentClose = Bars.ClosePrices[_lastProcessedIndex];

                if (currentClose > zone.Top || currentClose < zone.Bottom)
                {
                    Chart.RemoveObject(zone.Name);
                    _activeConsolidations.RemoveAt(i);
                }
            }

            int index = _lastProcessedIndex - 1;
    
            if (index < MinFormationCandles || double.IsNaN(_atr.Result[index])) return;

            foreach (var zone in _activeConsolidations)
            {
                if (Bars.ClosePrices[index] <= zone.Top && Bars.ClosePrices[index] >= zone.Bottom)
                    return; 
            }

            double maxZoneHeight = _atr.Result[index] * MaxConsolidationAtrWidth; 
            double microAtrBuffer = _atr.Result[index] * MicroAtrMultiplier;

            double highestHigh = double.MinValue;
            double lowestLow = double.MaxValue;

            // Instant lookup of the range extrema
            highestHigh = Bars.HighPrices.Maximum(MinFormationCandles);
            lowestLow = Bars.LowPrices.Minimum(MinFormationCandles);

            if ((highestHigh - lowestLow) <= maxZoneHeight)
            {
                _consolidationCounter++;
                _activeConsolidations.Add(new ChartFormation
                {
                    Top = highestHigh + microAtrBuffer,
                    Bottom = lowestLow - microAtrBuffer,
                    StartIndex = index - MinFormationCandles + 1, 
                    Name = "Consolidation_" + _consolidationCounter
                });

                // --- Update Dictionary for Bot ---
                ActiveZonesDict[ZoneType.Consolidation] = new Zone { Top = highestHigh + microAtrBuffer, Bottom = lowestLow - microAtrBuffer, Tier = ZoneTier.Minor };
            }
        }

        private void DrawConsolidations()
        {
            Color formationColor = Color.FromArgb(77, Color.Blue);

            foreach (var zone in _activeConsolidations)
            {
                var box = Chart.DrawRectangle(zone.Name, zone.StartIndex, zone.Top, _lastProcessedIndex + 3, zone.Bottom, formationColor);
                box.IsFilled = true;
            }
        }

        private void ScanRejections()
        {
            int index = _lastProcessedIndex - 1;
            if (index < 2 || double.IsNaN(_atr.Result[index])) return;

            // 1. HIGH-SPEED CLEANUP
            // We only touch the Chart object if we are NOT in the backtester
            for (int i = _activeRejections.Count - 1; i >= 0; i--)
            {
                var rej = _activeRejections[i];
                double currentClose = Bars.ClosePrices[_lastProcessedIndex]; 

                if (currentClose > rej.Top || currentClose < rej.Bottom)
                {
                    if (!IsBacktesting) Chart.RemoveObject(rej.Name);
                    _activeRejections.RemoveAt(i);
                }
            }

            // 2. STREAMLINED UPGRADES
            // Instead of looping, we check the list specifically for the last few bars
            for (int i = 0; i < _activeRejections.Count; i++)
            {
                var rej = _activeRejections[i];

                // Check if the rejection from 1 bar ago needs a Mid-Tier upgrade
                if (rej.Tier == ZoneTier.Minor && rej.StartIndex == index - 1)
                {
                    if (Bars.ClosePrices[index] > Bars.HighPrices[index - 1] || Bars.ClosePrices[index] < Bars.LowPrices[index - 1])
                    {
                        rej.Tier = ZoneTier.Mid;
                        ActiveZonesDict[ZoneType.Rejection] = new Zone { Top = rej.Top, Bottom = rej.Bottom, Tier = ZoneTier.Mid };
                    }
                }
                // Check if the rejection from 2 bars ago needs a Major-Tier upgrade
                else if (rej.Tier == ZoneTier.Mid && rej.StartIndex == index - 2)
                {
                    if (Bars.ClosePrices[index] > Bars.HighPrices[index - 1] || Bars.ClosePrices[index] < Bars.LowPrices[index - 1])
                    {
                        rej.Tier = ZoneTier.Major;
                        ActiveZonesDict[ZoneType.Rejection] = new Zone { Top = rej.Top, Bottom = rej.Bottom, Tier = ZoneTier.Major };
                    }
                }
            }

            // 3. FASTER PATTERN DETECTION
            double open = Bars.OpenPrices[index];
            double close = Bars.ClosePrices[index];
            double high = Bars.HighPrices[index];
            double low = Bars.LowPrices[index];

            double body = Math.Abs(close - open);
            double totalRange = high - low;
            double lowerWick = Math.Min(open, close) - low;
            double upperWick = high - Math.Max(open, close);

            // Optimized boolean logic
            bool isBullishRejection = lowerWick >= (body * 2) && lowerWick >= (totalRange * 0.5);
            bool isBearishRejection = upperWick >= (body * 2) && upperWick >= (totalRange * 0.5);

            if (isBullishRejection || isBearishRejection)
            {
                // Simple check: is this bar already a rejection?
                bool exists = false;
                if (_activeRejections.Count > 0 && _activeRejections[_activeRejections.Count - 1].StartIndex == index)
                    exists = true;

                if (!exists)
                {
                    _rejectionCounter++;
                    double microAtr = _atr.Result[index] * MicroAtrMultiplier;
                    double top, bottom;

                    if (isBullishRejection)
                    {
                        bottom = low - microAtr;
                        top = close + lowerWick + microAtr;
                    }
                    else
                    {
                        top = high + microAtr;
                        bottom = close - upperWick - microAtr;
                    }

                    _activeRejections.Add(new RejectionFormation
                    {
                        Top = top,
                        Bottom = bottom,
                        StartIndex = index,
                        Name = "Rejection_" + _rejectionCounter,
                        Tier = ZoneTier.Minor
                    });

                    ActiveZonesDict[ZoneType.Rejection] = new Zone { Top = top, Bottom = bottom, Tier = ZoneTier.Minor };
                }
            }
        }

        private void DrawRejections()
        {
            Color minorColor = Color.FromArgb(70, Color.Blue);
            Color midColor = Color.FromArgb(120, Color.Blue);
            Color majorColor = Color.FromArgb(180, Color.Blue);

            foreach (var rej in _activeRejections)
            {
                Color drawColor = minorColor;
                if (rej.Tier == ZoneTier.Mid) drawColor = midColor;
                else if (rej.Tier == ZoneTier.Major) drawColor = majorColor;

                var box = Chart.DrawRectangle(rej.Name, rej.StartIndex, rej.Top, _lastProcessedIndex + 3, rej.Bottom, drawColor);
                box.IsFilled = true;
            }
        }

        // ==========================================
        // BOT HELPER METHODS
        // ==========================================
        private Zone GetClosestZone(ZoneType[] typesToSearch, double currentPrice)
        {
            Zone closestZone = null;
            double smallestDistance = double.MaxValue;

            foreach (var type in typesToSearch)
            {
                if (ActiveZonesDict.ContainsKey(type))
                {
                    Zone zoneToCheck = ActiveZonesDict[type];
                    double zoneCenter = (zoneToCheck.Top + zoneToCheck.Bottom) / 2;
                    double distance = Math.Abs(currentPrice - zoneCenter);

                    if (distance < smallestDistance)
                    {
                        smallestDistance = distance;
                        closestZone = zoneToCheck;
                    }
                }
            }
            return closestZone;
        }

        public void CheckRejection(TradeType tradeType, double currHigh, double currLow, double currClose, double prevClose, RejectionMode mode, out bool rejectedMinor, out bool rejectedMid, out bool rejectedMajor)
        {
            rejectedMinor = false;
            rejectedMid = false;
            rejectedMajor = false;

            List<Zone> closestZonesToTest = new List<Zone>();

            var sessionHigh = GetClosestZone(new[] { ZoneType.AsianHigh, ZoneType.LondonHigh, ZoneType.NyHigh }, currClose);
            if (sessionHigh != null) closestZonesToTest.Add(sessionHigh);

            var sessionLow = GetClosestZone(new[] { ZoneType.AsianLow, ZoneType.LondonLow, ZoneType.NyLow }, currClose);
            if (sessionLow != null) closestZonesToTest.Add(sessionLow);

            var multidayHigh = GetClosestZone(new[] { ZoneType.MultidayHigh }, currClose);
            if (multidayHigh != null) closestZonesToTest.Add(multidayHigh);
            
            var multidayLow = GetClosestZone(new[] { ZoneType.MultidayLow }, currClose);
            if (multidayLow != null) closestZonesToTest.Add(multidayLow);
            
            var dailyHigh = GetClosestZone(new[] { ZoneType.DailyHigh }, currClose);
            if (dailyHigh != null) closestZonesToTest.Add(dailyHigh);
            
            var dailyLow = GetClosestZone(new[] { ZoneType.DailyLow }, currClose);
            if (dailyLow != null) closestZonesToTest.Add(dailyLow);

            var orderBlock = GetClosestZone(new[] { ZoneType.OrderBlock }, currClose);
            if (orderBlock != null) closestZonesToTest.Add(orderBlock);

            var psychLevel = GetClosestZone(new[] { ZoneType.PsychLevel }, currClose);
            if (psychLevel != null) closestZonesToTest.Add(psychLevel);

            var doubleTop = GetClosestZone(new[] { ZoneType.DoubleTop }, currClose);
            if (doubleTop != null) closestZonesToTest.Add(doubleTop);

            var doubleBot = GetClosestZone(new[] { ZoneType.DoubleBottom }, currClose);
            if (doubleBot != null) closestZonesToTest.Add(doubleBot);

            var consolidation = GetClosestZone(new[] { ZoneType.Consolidation }, currClose);
            if (consolidation != null) closestZonesToTest.Add(consolidation);

            var rejectionFormation = GetClosestZone(new[] { ZoneType.Rejection }, currClose);
            if (rejectionFormation != null) closestZonesToTest.Add(rejectionFormation);

            foreach (var zone in closestZonesToTest)
            {
                bool isRejected = false;

                if (mode == RejectionMode.WickInsideCloseOutside)
                {
                    if (tradeType == TradeType.Buy && currHigh >= zone.Bottom && currClose < zone.Bottom)
                        isRejected = true;
                    else if (tradeType == TradeType.Sell && currLow <= zone.Top && currClose > zone.Top)
                        isRejected = true;
                }
                else if (mode == RejectionMode.PrevCloseInsideCurrCloseOutside)
                {
                    bool prevCloseInside = prevClose >= zone.Bottom && prevClose <= zone.Top;
                    if (tradeType == TradeType.Buy && prevCloseInside && currClose < zone.Bottom)
                        isRejected = true;
                    else if (tradeType == TradeType.Sell && prevCloseInside && currClose > zone.Top)
                        isRejected = true;
                }

                if (isRejected)
                {
                    if (zone.Tier == ZoneTier.Minor) rejectedMinor = true;
                    else if (zone.Tier == ZoneTier.Mid) rejectedMid = true;
                    else if (zone.Tier == ZoneTier.Major) rejectedMajor = true;
                }
            }
        }
    }
}