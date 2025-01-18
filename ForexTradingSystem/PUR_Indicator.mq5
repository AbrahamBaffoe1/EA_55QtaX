//+------------------------------------------------------------------+
//|                                                      PUR_Indicator.mq5  |
//|                        PUR Visualization Indicator               |
//+------------------------------------------------------------------+
#property strict
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_color3 Green
#property indicator_color4 Yellow

// Indicator buffers
double SignalBuffer[];
double TrendBuffer[];
double OverboughtBuffer[];
double OversoldBuffer[];

// Input parameters
input int ShortMAPeriod = 10;       // Short MA period
input int LongMAPeriod = 30;        // Long MA period
input int RSIPeriod = 14;           // RSI period
input double RSIOverbought = 70;    // RSI overbought level
input double RSIOversold = 30;      // RSI oversold level

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set up indicator buffers
    SetIndexBuffer(0, SignalBuffer);
    SetIndexBuffer(1, TrendBuffer);
    SetIndexBuffer(2, OverboughtBuffer);
    SetIndexBuffer(3, OversoldBuffer);
    
    // Set up indicator labels
    IndicatorSetString(INDICATOR_SHORTNAME, "PUR Trading Signals");
    IndicatorSetInteger(INDICATOR_DIGITS, 2);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Calculate indicator values
    for(int i = prev_calculated; i < rates_total; i++)
    {
        double shortMA = iMA(NULL, 0, ShortMAPeriod, 0, MODE_SMA, PRICE_CLOSE, i);
        double longMA = iMA(NULL, 0, LongMAPeriod, 0, MODE_SMA, PRICE_CLOSE, i);
        double rsi = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, i);
        
        // Calculate signal strength
        SignalBuffer[i] = CalculateSignalStrength(shortMA, longMA, rsi);
        
        // Calculate trend direction
        TrendBuffer[i] = CalculateTrendDirection(shortMA, longMA);
        
        // Set overbought/oversold levels
        OverboughtBuffer[i] = RSIOverbought;
        OversoldBuffer[i] = RSIOversold;
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate signal strength                                        |
//+------------------------------------------------------------------+
double CalculateSignalStrength(double shortMA, double longMA, double rsi)
{
    double maDiff = shortMA - longMA;
    double rsiDiff = rsi - 50.0;
    
    // Normalize values between -1 and 1
    double maStrength = MathTanh(maDiff / (longMA * 0.01));
    double rsiStrength = MathTanh(rsiDiff / 50.0);
    
    return (maStrength + rsiStrength) / 2.0;
}

//+------------------------------------------------------------------+
//| Calculate trend direction                                        |
//+------------------------------------------------------------------+
double CalculateTrendDirection(double shortMA, double longMA)
{
    if(shortMA > longMA)
        return 1.0; // Uptrend
    else if(shortMA < longMA)
        return -1.0; // Downtrend
    return 0.0; // No trend
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up resources
    ArrayFree(SignalBuffer);
    ArrayFree(TrendBuffer);
    ArrayFree(OverboughtBuffer);
    ArrayFree(OversoldBuffer);
}
//+------------------------------------------------------------------+
