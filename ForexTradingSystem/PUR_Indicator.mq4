#property strict
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_color1 Blue
#property indicator_color2 Red
#property indicator_width1 2
#property indicator_width2 2

// Indicator buffers
double Buffer1[];
double Buffer2[];

// Input parameters
input int Period = 14;
input double Deviation = 2.0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set up indicator buffers
   IndicatorBuffers(2);
   SetIndexBuffer(0, Buffer1);
   SetIndexBuffer(1, Buffer2);
   
   // Set up indicator labels
   IndicatorShortName("PUR Indicator");
   SetIndexLabel(0, "Main Line");
   SetIndexLabel(1, "Signal Line");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup code
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
      Buffer1[i] = CalculateMainLine(i, close);
      Buffer2[i] = CalculateSignalLine(i);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate main indicator line                                    |
//+------------------------------------------------------------------+
double CalculateMainLine(int index, const double &close[])
{
   // Add your main line calculation here
   return iMA(NULL, 0, Period, 0, MODE_SMA, PRICE_CLOSE, index);
}

//+------------------------------------------------------------------+
//| Calculate signal line                                            |
//+------------------------------------------------------------------+
double CalculateSignalLine(int index)
{
   // Add your signal line calculation here
   return Buffer1[index] + Deviation;
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle chart events
}
