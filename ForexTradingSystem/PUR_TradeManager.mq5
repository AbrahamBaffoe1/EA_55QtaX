//+------------------------------------------------------------------+
//|                                                      PUR_TradeManager.mq5  |
//|                        PUR Trade Management Utility              |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

// Input parameters
input double RiskPercentage = 1.5;      // Risk percentage per trade
input double MaxDailyLoss = 3.0;        // Max daily loss percentage
input double MaxPositionSize = 15.0;    // Max position size percentage
input int MaxLeverage = 20;             // Maximum leverage
input bool CloseAllTrades = false;      // Close all trades
input bool ShowTradeStats = true;       // Show trade statistics
input bool ResetDailyStats = false;     // Reset daily statistics

// Global variables
double DailyProfit;
double DailyLoss;
int DailyTrades;
datetime LastTradeTime;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    // Initialize variables
    DailyProfit = 0;
    DailyLoss = 0;
    DailyTrades = 0;
    LastTradeTime = 0;
    
    // Execute requested actions
    if(CloseAllTrades)
    {
        CloseAllOpenTrades();
    }
    
    if(ShowTradeStats)
    {
        DisplayTradeStatistics();
    }
    
    if(ResetDailyStats)
    {
        ResetDailyStatistics();
    }
    
    // Check risk parameters
    CheckRiskParameters();
}

//+------------------------------------------------------------------+
//| Close all open trades                                            |
//+------------------------------------------------------------------+
void CloseAllOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            trade.PositionClose(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Display trade statistics                                         |
//+------------------------------------------------------------------+
void DisplayTradeStatistics()
{
    double totalProfit = 0;
    double totalLoss = 0;
    int totalTrades = 0;
    
    // Calculate statistics
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit > 0)
                totalProfit += profit;
            else
                totalLoss += profit;
            totalTrades++;
        }
    }
    
    // Display statistics
    Print("=== Trade Statistics ===");
    Print("Total Trades: ", totalTrades);
    Print("Total Profit: ", totalProfit);
    Print("Total Loss: ", totalLoss);
    Print("Net Profit: ", totalProfit + totalLoss);
    Print("Win Rate: ", (totalTrades > 0) ? (totalProfit / (totalProfit + MathAbs(totalLoss)) * 100) : 0, "%");
    Print("Risk/Reward Ratio: ", CalculateRiskRewardRatio());
}

//+------------------------------------------------------------------+
//| Calculate risk/reward ratio                                      |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio()
{
    double totalRisk = 0;
    double totalReward = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            
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
//| Reset daily statistics                                           |
//+------------------------------------------------------------------+
void ResetDailyStatistics()
{
    DailyProfit = 0;
    DailyLoss = 0;
    DailyTrades = 0;
    LastTradeTime = 0;
    Print("Daily statistics have been reset");
}

//+------------------------------------------------------------------+
//| Check risk parameters                                            |
//+------------------------------------------------------------------+
void CheckRiskParameters()
{
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    // Check daily loss limit
    if(DailyLoss < -accountEquity * (MaxDailyLoss / 100.0))
    {
        Print("Daily loss limit reached. Closing all trades.");
        CloseAllOpenTrades();
    }
    
    // Check position size
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            double positionSize = PositionGetDouble(POSITION_VOLUME);
            if(positionSize > accountEquity * (MaxPositionSize / 100.0))
            {
                Print("Position size limit exceeded. Closing trade #", ticket);
                trade.PositionClose(ticket);
            }
        }
    }
    
    // Check leverage
    if(AccountInfoInteger(ACCOUNT_LEVERAGE) > MaxLeverage)
    {
        Print("Leverage limit exceeded. Current leverage: ", AccountInfoInteger(ACCOUNT_LEVERAGE));
    }
}

//+------------------------------------------------------------------+
//| Trade class for order execution                                  |
//+------------------------------------------------------------------+
class CTrade
{
public:
    void PositionClose(ulong ticket)
    {
        MqlTradeRequest request;
        MqlTradeResult result;
        
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_DEAL;
        request.position = ticket;
        request.symbol = PositionGetString(POSITION_SYMBOL);
        request.volume = PositionGetDouble(POSITION_VOLUME);
        request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
            ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(request.symbol, 
            (request.type == ORDER_TYPE_SELL) ? SYMBOL_BID : SYMBOL_ASK);
        request.deviation = 10;
        
        if(!OrderSend(request, result))
            Print("Failed to close position #", ticket, ": ", result.retcode);
    }
};

CTrade trade;
//+------------------------------------------------------------------+
