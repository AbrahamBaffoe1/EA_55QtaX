//+------------------------------------------------------------------+
//|                                                      PUR_TradeAnalyzer.mq5  |
//|                        PUR Trade Analysis Utility                |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

// Input parameters
input bool GenerateReport = true;       // Generate trade report
input bool ExportToCSV = true;          // Export to CSV file
input string ReportPath = "Reports/";   // Report directory
input string ReportName = "TradeReport";// Report name
input bool ShowCharts = true;           // Show analysis charts
input bool ShowCorrelations = true;     // Show currency correlations
input bool ShowHeatmap = true;          // Show performance heatmap

// Global variables
string CurrencyPairs[];
int TotalTrades;
double TotalProfit;
double TotalLoss;
double MaxDrawdown;
double MaxProfit;
double MaxLoss;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    // Initialize variables
    ArrayResize(CurrencyPairs, 0);
    TotalTrades = 0;
    TotalProfit = 0;
    TotalLoss = 0;
    MaxDrawdown = 0;
    MaxProfit = 0;
    MaxLoss = 0;
    
    // Collect trade data
    CollectTradeData();
    
    // Generate report if requested
    if(GenerateReport)
    {
        GenerateTradeReport();
    }
    
    // Export to CSV if requested
    if(ExportToCSV)
    {
        ExportTradeDataToCSV();
    }
    
    // Display visualizations
    if(ShowCharts)
    {
        DisplayAnalysisCharts();
    }
    
    if(ShowCorrelations)
    {
        DisplayCurrencyCorrelations();
    }
    
    if(ShowHeatmap)
    {
        DisplayPerformanceHeatmap();
    }
}

//+------------------------------------------------------------------+
//| Collect trade data                                               |
//+------------------------------------------------------------------+
void CollectTradeData()
{
    // Initialize variables
    double currentDrawdown = 0;
    double peakEquity = 0;
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Process all trades
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            // Update currency pairs array
            UpdateCurrencyPairs(OrderSymbol());
            
            // Update trade statistics
            double profit = OrderProfit();
            if(profit > 0)
            {
                TotalProfit += profit;
                if(profit > MaxProfit)
                    MaxProfit = profit;
            }
            else
            {
                TotalLoss += profit;
                if(profit < MaxLoss)
                    MaxLoss = profit;
            }
            
            TotalTrades++;
            
            // Update drawdown calculations
            currentEquity += profit;
            if(currentEquity > peakEquity)
            {
                peakEquity = currentEquity;
            }
            else
            {
                double drawdown = peakEquity - currentEquity;
                if(drawdown > MaxDrawdown)
                {
                    MaxDrawdown = drawdown;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update currency pairs array                                      |
//+------------------------------------------------------------------+
void UpdateCurrencyPairs(string symbol)
{
    bool exists = false;
    for(int i = 0; i < ArraySize(CurrencyPairs); i++)
    {
        if(CurrencyPairs[i] == symbol)
        {
            exists = true;
            break;
        }
    }
    
    if(!exists)
    {
        int size = ArraySize(CurrencyPairs);
        ArrayResize(CurrencyPairs, size + 1);
        CurrencyPairs[size] = symbol;
    }
}

//+------------------------------------------------------------------+
//| Generate trade report                                            |
//+------------------------------------------------------------------+
void GenerateTradeReport()
{
    Print("=== Trade Analysis Report ===");
    Print("Total Trades: ", TotalTrades);
    Print("Total Profit: ", TotalProfit);
    Print("Total Loss: ", TotalLoss);
    Print("Net Profit: ", TotalProfit + TotalLoss);
    Print("Max Profit: ", MaxProfit);
    Print("Max Loss: ", MaxLoss);
    Print("Max Drawdown: ", MaxDrawdown);
    Print("Win Rate: ", (TotalTrades > 0) ? (TotalProfit / (TotalProfit + MathAbs(TotalLoss)) * 100) : 0, "%");
    Print("Profit Factor: ", (TotalLoss != 0) ? (TotalProfit / MathAbs(TotalLoss)) : 0);
    Print("Average Profit: ", (TotalTrades > 0) ? (TotalProfit / TotalTrades) : 0);
    Print("Average Loss: ", (TotalTrades > 0) ? (TotalLoss / TotalTrades) : 0);
    Print("Risk/Reward Ratio: ", CalculateRiskRewardRatio());
}

//+------------------------------------------------------------------+
//| Export trade data to CSV                                         |
//+------------------------------------------------------------------+
void ExportTradeDataToCSV()
{
    string filename = ReportPath + ReportName + "_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
    int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_COMMON, ",");
    
    if(handle != INVALID_HANDLE)
    {
        // Write header
        FileWrite(handle, "Ticket", "Symbol", "Type", "Lots", "Open Time", 
            "Close Time", "Open Price", "Close Price", "Profit", "Swap", 
            "Commission", "Comment");
        
        // Write trade data
        for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
        {
            if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            {
                FileWrite(handle, 
                    OrderTicket(), 
                    OrderSymbol(), 
                    OrderType(), 
                    OrderLots(), 
                    TimeToString(OrderOpenTime(), TIME_DATE|TIME_MINUTES), 
                    TimeToString(OrderCloseTime(), TIME_DATE|TIME_MINUTES), 
                    OrderOpenPrice(), 
                    OrderClosePrice(), 
                    OrderProfit(), 
                    OrderSwap(), 
                    OrderCommission(), 
                    OrderComment());
            }
        }
        
        FileClose(handle);
        Print("Trade data exported to: ", filename);
    }
    else
    {
        Print("Failed to create CSV file: ", filename);
    }
}

//+------------------------------------------------------------------+
//| Display analysis charts                                          |
//+------------------------------------------------------------------+
void DisplayAnalysisCharts()
{
    // Create chart objects
    ObjectCreate(0, "ProfitChart", OBJ_CHART, 0, 0, 0);
    ObjectSetInteger(0, "ProfitChart", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "ProfitChart", OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, "ProfitChart", OBJPROP_XSIZE, 800);
    ObjectSetInteger(0, "ProfitChart", OBJPROP_YSIZE, 400);
    
    // Add profit/loss series
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            ObjectSetDouble(0, "ProfitChart", OBJPROP_PRICE, i, OrderProfit());
        }
    }
}

//+------------------------------------------------------------------+
//| Display currency correlations                                    |
//+------------------------------------------------------------------+
void DisplayCurrencyCorrelations()
{
    // Calculate and display currency correlations
    int count = ArraySize(CurrencyPairs);
    double correlationMatrix[][];
    ArrayResize(correlationMatrix, count);
    ArrayInitialize(correlationMatrix, 0);
    
    // Calculate correlation matrix
    for(int i = 0; i < count; i++)
    {
        for(int j = 0; j < count; j++)
        {
            if(i == j)
            {
                correlationMatrix[i][j] = 1.0;
            }
            else
            {
                correlationMatrix[i][j] = CalculateCorrelation(CurrencyPairs[i], CurrencyPairs[j]);
            }
        }
    }
    
    // Display correlation matrix
    Print("=== Currency Correlation Matrix ===");
    for(int i = 0; i < count; i++)
    {
        string row = CurrencyPairs[i] + ": ";
        for(int j = 0; j < count; j++)
        {
            row += StringFormat("%.2f ", correlationMatrix[i][j]);
        }
        Print(row);
    }
}

//+------------------------------------------------------------------+
//| Calculate correlation between two currency pairs                 |
//+------------------------------------------------------------------+
double CalculateCorrelation(string pair1, string pair2)
{
    // Implementation of correlation calculation
    return 0.0; // Placeholder
}

//+------------------------------------------------------------------+
//| Display performance heatmap                                      |
//+------------------------------------------------------------------+
void DisplayPerformanceHeatmap()
{
    // Create heatmap visualization
    // Implementation would depend on specific visualization requirements
}

//+------------------------------------------------------------------+
//| Calculate risk/reward ratio                                      |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio()
{
    double totalRisk = 0;
    double totalReward = 0;
    
    for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
            double sl = OrderStopLoss();
            double tp = OrderTakeProfit();
            double price = OrderOpenPrice();
            
            if(sl > 0 && tp > 0)
            {
                double risk = MathAbs(price - sl);
                double reward = MathAbs(tp - price);
                totalRisk += risk;
                totalReward += reward;
            }
        }
    }
    
    return (totalRisk > 0) ? totalReward / totalRisk : 0;
}
//+------------------------------------------------------------------+
