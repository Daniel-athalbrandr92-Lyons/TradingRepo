using cAlgo.API;
using cAlgo.API.Indicators;
using System;

namespace cAlgo.Indicators
{
    [Indicator(IsOverlay = false, AccessRights = AccessRights.None, TimeZone = TimeZones.UTC)]
    public class MT5ADXEquivalent : Indicator
    {
        [Parameter("Period ADX", DefaultValue = 14, MinValue = 1, MaxValue = 99)]
        public int InpPeriodADX { get; set; }

        [Output("ADX", LineColor = "LightSeaGreen", PlotType = PlotType.Line, Thickness = 1)]
        public IndicatorDataSeries ExtADXBuffer { get; set; }

        [Output("+DI", LineColor = "YellowGreen", PlotType = PlotType.Line, Thickness = 1)]
        public IndicatorDataSeries PDI { get; set; }

        [Output("-DI", LineColor = "Wheat", PlotType = PlotType.Line, Thickness = 1)]
        public IndicatorDataSeries NDI { get; set; }

        private IndicatorDataSeries _pdBuffer;
        private IndicatorDataSeries _ndBuffer;
        private IndicatorDataSeries _tmpBuffer;

        private int _adxPeriod;

        protected override void Initialize()
        {
            _adxPeriod = (InpPeriodADX >= 100 || InpPeriodADX <= 0) ? 14 : InpPeriodADX;

            _pdBuffer = CreateDataSeries();
            _ndBuffer = CreateDataSeries();
            _tmpBuffer = CreateDataSeries();
        }

        public override void Calculate(int index)
        {
            if (index == 0)
            {
                PDI[index] = 0.0;
                NDI[index] = 0.0;
                ExtADXBuffer[index] = 0.0;
                _pdBuffer[index] = 0.0;
                _ndBuffer[index] = 0.0;
                _tmpBuffer[index] = 0.0;
                return;
            }


            double highPrice = Bars.HighPrices[index];
            double prevHigh = Bars.HighPrices[index - 1];
            double lowPrice = Bars.LowPrices[index];
            double prevLow = Bars.LowPrices[index - 1];
            double prevClose = Bars.ClosePrices[index - 1];

            double tmpPos = highPrice - prevHigh;
            double tmpNeg = prevLow - lowPrice;

            if (tmpPos < 0.0)
                tmpPos = 0.0;
            if (tmpNeg < 0.0)
                tmpNeg = 0.0;

            if (tmpPos > tmpNeg)
            {
                tmpNeg = 0.0;
            }
            else if (tmpPos < tmpNeg)
            {
                tmpPos = 0.0;
            }
            else
            {
                tmpPos = 0.0;
                tmpNeg = 0.0;
            }

            double tr = Math.Max(
                Math.Max(Math.Abs(highPrice - lowPrice), Math.Abs(highPrice - prevClose)),
                Math.Abs(lowPrice - prevClose));

            if (tr != 0.0)
            {
                _pdBuffer[index] = 100.0 * tmpPos / tr;
                _ndBuffer[index] = 100.0 * tmpNeg / tr;
            }
            else
            {
                _pdBuffer[index] = 0.0;
                _ndBuffer[index] = 0.0;
            }

            PDI[index] = ExponentialMA(index, _adxPeriod, PDI[index - 1], _pdBuffer);
            NDI[index] = ExponentialMA(index, _adxPeriod, NDI[index - 1], _ndBuffer);

            double tmp = PDI[index] + NDI[index];
            tmp = tmp != 0.0 ? 100.0 * Math.Abs((PDI[index] - NDI[index]) / tmp) : 0.0;
            _tmpBuffer[index] = tmp;

            ExtADXBuffer[index] = ExponentialMA(index, _adxPeriod, ExtADXBuffer[index - 1], _tmpBuffer);
        }

        private static double ExponentialMA(int index, int period, double prevEma, IndicatorDataSeries source)
        {
            if (index <= 0)
                return source[index];

            return ((period - 1.0) * prevEma + source[index]) / period;
        }
    }
}