#property strict
#property version   "1.00"
#property description "PUR Trade Analyzer for MT4"

// Input parameters
input int MagicNumber = 123456;

// Global variables
double TotalProfit = 0;
int TotalTrades = 0;
double MaxDrawdown = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialization code
   AnalyzeTrades();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup code
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update trade analysis
   AnalyzeTrades();
}

//+------------------------------------------------------------------+
//| Analyze trades                                                   |
//+------------------------------------------------------------------+
void AnalyzeTrades()
{
   double currentProfit = 0;
   double currentDrawdown = 0;
   int currentTrades = 0;
   
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MagicNumber)
      {
         currentProfit += OrderProfit();
         currentTrades++;
      }
   }
   
   TotalProfit = currentProfit;
   TotalTrades = currentTrades;
   MaxDrawdown = CalculateMaxDrawdown();
}

//+------------------------------------------------------------------+
//| Calculate maximum drawdown                                       |
//+------------------------------------------------------------------+
double CalculateMaxDrawdown()
{
   double maxBalance = 0;
   double maxDrawdown = 0;
   
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) && OrderMagicNumber() == MagicNumber)
      {
         double balance = AccountBalance() + OrderProfit();
         if(balance > maxBalance)
         {
            maxBalance = balance;
         }
         else
         {
            double drawdown = maxBalance - balance;
            if(drawdown > maxDrawdown)
            {
               maxDrawdown = drawdown;
            }
         }
      }
   }
   
   return maxDrawdown;
}

//+------------------------------------------------------------------+
//| Generate report                                                  |
//+------------------------------------------------------------------+
string GenerateReport()
{
   string report = "Trade Analysis Report\n";
   report += "----------------------\n";
   report += "Total Trades: " + IntegerToString(TotalTrades) + "\n";
   report += "Total Profit: " + DoubleToString(TotalProfit, 2) + "\n";
   report += "Max Drawdown: " + DoubleToString(MaxDrawdown, 2) + "\n";
   
   return report;
}

//+------------------------------------------------------------------+
//| Show report                                                      |
//+------------------------------------------------------------------+
void ShowReport()
{
   string report = GenerateReport();
   Comment(report);
}
