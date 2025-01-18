//+------------------------------------------------------------------+
//|                                                      PUR_EA.mq5  |
//|                        PUR Expert Advisor                        |
//+------------------------------------------------------------------+
#property strict

// Input parameters
input int ShortMAPeriod = 10;       // Short MA period
input int LongMAPeriod = 30;        // Long MA period
input int RSIPeriod = 14;           // RSI period
input double RSIOverbought = 70;    // RSI overbought level
input double RSIOversold = 30;      // RSI oversold level
input int MACDFast = 12;            // MACD fast period
input int MACDSlow = 26;            // MACD slow period
input int MACDSignal = 9;           // MACD signal period
input int ATRPeriod = 14;           // ATR period
input double ATRMultiplier = 2.0;   // ATR multiplier for stop loss
input double MaxDailyLoss = 0.03;   // 3% of total capital
input double MaxPositionSize = 0.15;// 15% of total capital
input int MaxLeverage = 20;         // Maximum leverage
input double RiskPerTrade = 0.015;  // 1.5% risk per trade
input double LotSize = 0.1;         // Default lot size
input bool EnableMonitoring = true; // Enable performance monitoring
input string LogFileName = "PUR_EA_Log.csv"; // Log file name

// Global variables
double ShortMA, LongMA, RSI, MACDMain, MACDSignal, ATR;
double AccountEquity, TotalProfit, TotalTrades;
datetime LastTradeTime;
int FileHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialization
    AccountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    LastTradeTime = 0;
    TotalProfit = 0;
    TotalTrades = 0;
    
    // Initialize monitoring
    if(EnableMonitoring)
    {
        FileHandle = FileOpen(LogFileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup and final reporting
    if(EnableMonitoring && FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountInfoDouble(ACCOUNT_EQUITY));
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//|                                                      PUR_EA.mq5  |
//|                        PUR Trading Algorithm                     |
//|                        Version 2.0 (MQL5 Best Practices)         |
//+------------------------------------------------------------------+
#property strict
#property copyright "PUR Trading Systems"
#property link      "https://www.purtrading.com"
#property version   "2.0"

// Input parameters
input double LotSize = 0.1;            // Trade volume
input int StopLoss = 50;               // Stop loss in points
input int TakeProfit = 100;            // Take profit in points
input int MagicNumber = 123456;        // Expert ID
input int Slippage = 3;                // Maximum price slippage
input double RiskPercent = 2.0;        // Risk percentage per trade
input bool UseTrailingStop = true;     // Enable trailing stop
input int TrailingStopPoints = 30;     // Trailing stop distance
input bool UseBreakeven = true;        // Enable breakeven
input int BreakevenPoints = 20;        // Breakeven activation level

// Global variables
int ticket;
double lastPrice;
datetime lastTradeTime;
MqlTradeRequest request;
MqlTradeResult result;
MqlTick lastTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize trade object
    trade.SetExpertMagicNumber(MagicNumber);
    
    // Initialize logging
    Print("PUR EA initialized successfully");
    Print("Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
    Print("Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
    
    // Check trading conditions
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Alert("Trading is not allowed!");
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup and logging
    Print("PUR EA deinitialized with reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Get latest market data
    if(!SymbolInfoTick(Symbol(), lastTick))
    {
        Print("Failed to get tick data!");
        return;
    }

    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    if(ShouldOpenTrade())
    {
        OpenTrade();
    }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Check trading permissions
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        Print("Trading is not allowed!");
        return false;
    }
    
    // Check account permissions
    if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
    {
        Print("Expert trading is not allowed!");
        return false;
    }
    
    // Check market conditions
    if(!SymbolInfoInteger(Symbol(), SYMBOL_TRADE_MODE))
    {
        Print("Trading is not allowed for ", Symbol());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Trailing stop logic
    if(UseTrailingStop)
    {
        ApplyTrailingStop();
    }
    
    // Breakeven logic
    if(UseBreakeven)
    {
        ApplyBreakeven();
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
    // Implementation of trailing stop logic
}

//+------------------------------------------------------------------+
//| Apply breakeven                                                  |
//+------------------------------------------------------------------+
void ApplyBreakeven()
{
    // Implementation of breakeven logic
}

//+------------------------------------------------------------------+
//| Trade opening condition                                          |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Advanced trade condition logic
    // Implement proper risk management
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
    double lotSize = NormalizeDouble(riskAmount / (StopLoss * Point), 2);
    
    // Check minimum lot size
    if(lotSize < SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN))
    {
        Print("Calculated lot size is below minimum");
        return false;
    }
    
    // Check maximum lot size
    if(lotSize > SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX))
    {
        Print("Calculated lot size is above maximum");
        return false;
    }
    
    // Check time since last trade
    if(TimeCurrent() - lastTradeTime < PeriodSeconds(PERIOD_M1))
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Open trade function                                              |
//+------------------------------------------------------------------+
void OpenTrade()
{
    // Initialize trade request
    ZeroMemory(request);
    ZeroMemory(result);
    
    // Calculate lot size based on risk
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
    double lotSize = NormalizeDouble(riskAmount / (StopLoss * Point), 2);
    
    // Set trade parameters
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = lastTick.ask;
    request.sl = lastTick.ask - StopLoss * Point;
    request.tp = lastTick.ask + TakeProfit * Point;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    
    // Execute trade
    if(!OrderSend(request, result))
    {
        Print("Trade failed: ", result.retcode);
        return;
    }
    
    // Update last trade time
    lastTradeTime = TimeCurrent();
    
    // Log trade details
    Print("Trade opened successfully: ", result.order);
}

//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
{
    // Check if we already have an open position
    if(PositionSelect(Symbol()))
        return;

    // Calculate position size based on risk
    double lotSize = CalculatePositionSize();
    double stopLoss = CalculateStopLoss();
    double takeProfit = stopLoss * 2; // 1:2 risk-reward ratio

    // Execute trade based on signal
    if(signal == 1) // Buy
    {
        trade.Buy(lotSize, stopLoss, takeProfit);
        if(EnableMonitoring)
            LogTrade(ORDER_TYPE_BUY, lotSize, stopLoss, takeProfit);
    }
    else if(signal == -1) // Sell
    {
        trade.Sell(lotSize, stopLoss, takeProfit);
        if(EnableMonitoring)
            LogTrade(ORDER_TYPE_SELL, lotSize, stopLoss, takeProfit);
    }
    
    LastTradeTime = TimeCurrent();
    TotalTrades++;
}

//+------------------------------------------------------------------+
//| Log trade details                                                |
//+------------------------------------------------------------------+
void LogTrade(int tradeType, double volume, double stopLoss, double takeProfit)
{
    if(FileHandle != INVALID_HANDLE)
    {
        double price = (tradeType == ORDER_TYPE_BUY) ? 
            SymbolInfoDouble(Symbol(), SYMBOL_ASK) : 
            SymbolInfoDouble(Symbol(), SYMBOL_BID);
            
        FileWrite(FileHandle, 
            TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            Symbol(),
            (tradeType == ORDER_TYPE_BUY) ? "BUY" : "SELL",
            volume,
            price,
            stopLoss,
            takeProfit,
            0 // Initial profit is 0
        );
    }
}

//+------------------------------------------------------------------+
//| Update trade monitoring                                          |
//+------------------------------------------------------------------+
void UpdateMonitoring()
{
    if(!EnableMonitoring || FileHandle == INVALID_HANDLE)
        return;
        
    if(PositionSelect(Symbol()))
    {
        double profit = PositionGetDouble(POSITION_PROFIT);
        TotalProfit += profit;
        
        // Update the last trade's profit in the log
        FileSeek(FileHandle, 0, SEEK_END);
        long lastPosition = FileTell(FileHandle) - 1;
        FileSeek(FileHandle, lastPosition, SEEK_SET);
        FileWrite(FileHandle, profit);
    }
}

//+------------------------------------------------------------------+
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
    double riskAmount = AccountEquity * RiskPerTrade;
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double stopLoss = CalculateStopLoss();
    
    if(stopLoss == 0)
        return LotSize;
        
    return NormalizeDouble(riskAmount / (stopLoss * tickValue), 2);
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss()
{
    // Calculate stop loss based on ATR
    if(ATR == 0)
        return 0;
        
    return ATR * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Check risk parameters                                            |
//+------------------------------------------------------------------+
bool CheckRiskParameters()
{
    // Check daily loss limit
    double dailyProfit = AccountInfoDouble(ACCOUNT_PROFIT);
    if(dailyProfit < -AccountEquity * MaxDailyLoss)
        return false;

    // Check position size
    if(PositionGetDouble(POSITION_VOLUME) > MaxPositionSize * AccountEquity)
        return false;

    // Check leverage
    if(AccountInfoInteger(ACCOUNT_LEVERAGE) > MaxLeverage)
        return false;

    return true;
}

//+------------------------------------------------------------------+
//| Trade class for order execution                                  |
//+------------------------------------------------------------------+
class CTrade
{
public:
    void Buy(double lotSize, double stopLoss, double takeProfit)
    {
        MqlTradeRequest request;
        MqlTradeResult result;
        
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = lotSize;
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        request.sl = SymbolInfoDouble(Symbol(), SYMBOL_BID) - stopLoss;
        request.tp = SymbolInfoDouble(Symbol(), SYMBOL_BID) + takeProfit;
        request.deviation = 10;
        
        if(!OrderSend(request, result))
            Print("Buy order failed: ", result.retcode);
    }
    
    void Sell(double lotSize, double stopLoss, double takeProfit)
    {
        MqlTradeRequest request;
        MqlTradeResult result;
        
        ZeroMemory(request);
        ZeroMemory(result);
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = Symbol();
        request.volume = lotSize;
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        request.sl = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + stopLoss;
        request.tp = SymbolInfoDouble(Symbol(), SYMBOL_ASK) - takeProfit;
        request.deviation = 10;
        
        if(!OrderSend(request, result))
            Print("Sell order failed: ", result.retcode);
    }
};

CTrade trade;
//+------------------------------------------------------------------+
