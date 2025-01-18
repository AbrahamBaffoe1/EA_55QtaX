#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Get technical indicators
    double maFast = iMA(NULL, 0, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maSlow = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    double macd = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Calculate technical signal strength
    double techSignal = 0;
    
    // Moving average crossover
    if(maFast > maSlow)
        techSignal += 0.3;
    else
        techSignal -= 0.3;
        
    // RSI overbought/oversold
    if(rsi > 70)
        techSignal -= 0.2;
    else if(rsi < 30)
        techSignal += 0.2;
        
    // MACD direction
    if(macd > 0)
        techSignal += 0.1;
    else
        techSignal -= 0.1;
        
    // Combine all signals with weights
    double combinedSignal = 
        (techSignal * 0.4) + 
        (mlPrediction * 0.4) + 
        (higherTFSignal * 0.2);
        
    // Apply confidence threshold
    if(combinedSignal > 0.6)
    {
        // Strong buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.6)
    {
        // Strong sell signal
        return OP_SELL;
    }
    else if(combinedSignal > 0.4 && combinedSignal <= 0.6)
    {
        // Moderate buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.4 && combinedSignal >= -0.6)
    {
        // Moderate sell signal
        return OP_SELL;
    }
    
    // No clear signal
    return 0;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    // Check trading session hours (avoid trading during low liquidity)
    int hour = Hour();
    if(hour < 2 || hour > 22)  // Only trade between 2am-10pm GMT
        return false;
        
    // Check volatility using ATR
    double atr = iATR(NULL, 0, 14, 0);
    if(atr < 10 * Point)  // Avoid trading in low volatility conditions
        return false;
        
    // Check recent trade history
    HistorySelect(TimeCurrent() - 3600, TimeCurrent());
    int recentTrades = HistoryDealsTotal();
    if(recentTrades > 5)  // Limit to 5 trades per hour
        return false;
        
    // Check account drawdown
    double drawdown = (AccountEquity() - AccountBalance()) / AccountBalance() * 100;
    if(drawdown > 10)  // Stop trading if drawdown exceeds 10%
        return false;
        
    // Check news impact
    if(UseNewsFilter && IsHighImpactNews())
        return false;
        
    // Check if enough time has passed since last trade
    if(TimeCurrent() - LastTradeTime < 300)  // 5 minute cooldown
        return false;
        
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Get technical indicators
    double maFast = iMA(NULL, 0, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maSlow = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    double macd = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Calculate technical signal strength
    double techSignal = 0;
    
    // Moving average crossover
    if(maFast > maSlow)
        techSignal += 0.3;
    else
        techSignal -= 0.3;
        
    // RSI overbought/oversold
    if(rsi > 70)
        techSignal -= 0.2;
    else if(rsi < 30)
        techSignal += 0.2;
        
    // MACD direction
    if(macd > 0)
        techSignal += 0.1;
    else
        techSignal -= 0.1;
        
    // Combine all signals with weights
    double combinedSignal = 
        (techSignal * 0.4) + 
        (mlPrediction * 0.4) + 
        (higherTFSignal * 0.2);
        
    // Apply confidence threshold
    if(combinedSignal > 0.6)
    {
        // Strong buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.6)
    {
        // Strong sell signal
        return OP_SELL;
    }
    else if(combinedSignal > 0.4 && combinedSignal <= 0.6)
    {
        // Moderate buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.4 && combinedSignal >= -0.6)
    {
        // Moderate sell signal
        return OP_SELL;
    }
    
    // No clear signal
    return 0;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Calculate position size based on risk
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    lotSize = MathFloor(lotSize / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
    
    // Calculate price and SL/TP levels
    double price = (signal == OP_BUY) ? Ask : Bid;
    double sl = (signal == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (signal == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    
    // Prepare order request
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = (signal == OP_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = "PUR EA Trade";
    
    // Send order
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("OrderSend failed: ", result.retcode);
        if(EnableTelegram)
            SendTelegramMessage(StringFormat("Trade failed: %d", result.retcode));
        return;
    }
    
    // Log successful trade
    TotalTrades++;
    LogTrade(signal, lotSize, price, sl, tp);
    
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade executed: %s %.2f lots at %s",
            (signal == OP_BUY) ? "BUY" : "SELL",
            lotSize,
            DoubleToString(price, Digits));
        SendTelegramMessage(message);
    }
    
    // Update last trade time
    LastTradeTime = TimeCurrent();
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Calculate position size based on risk
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    lotSize = MathFloor(lotSize / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
    
    // Calculate price and SL/TP levels
    double price = (signal == OP_BUY) ? Ask : Bid;
    double sl = (signal == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (signal == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    
    // Prepare order request
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = (signal == OP_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = "PUR EA Trade";
    
    // Send order
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("OrderSend failed: ", result.retcode);
        if(EnableTelegram)
            SendTelegramMessage(StringFormat("Trade failed: %d", result.retcode));
        return;
    }
    
    // Log successful trade
    TotalTrades++;
    LogTrade(signal, lotSize, price, sl, tp);
    
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade executed: %s %.2f lots at %s",
            (signal == OP_BUY) ? "BUY" : "SELL",
            lotSize,
            DoubleToString(price, Digits));
        SendTelegramMessage(message);
    }
    
    // Update last trade time
    LastTradeTime = TimeCurrent();
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Get technical indicators
    double maFast = iMA(NULL, 0, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maSlow = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    double macd = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Calculate technical signal strength
    double techSignal = 0;
    
    // Moving average crossover
    if(maFast > maSlow)
        techSignal += 0.3;
    else
        techSignal -= 0.3;
        
    // RSI overbought/oversold
    if(rsi > 70)
        techSignal -= 0.2;
    else if(rsi < 30)
        techSignal += 0.2;
        
    // MACD direction
    if(macd > 0)
        techSignal += 0.1;
    else
        techSignal -= 0.1;
        
    // Combine all signals with weights
    double combinedSignal = 
        (techSignal * 0.4) + 
        (mlPrediction * 0.4) + 
        (higherTFSignal * 0.2);
        
    // Apply confidence threshold
    if(combinedSignal > 0.6)
    {
        // Strong buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.6)
    {
        // Strong sell signal
        return OP_SELL;
    }
    else if(combinedSignal > 0.4 && combinedSignal <= 0.6)
    {
        // Moderate buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.4 && combinedSignal >= -0.6)
    {
        // Moderate sell signal
        return OP_SELL;
    }
    
    // No clear signal
    return 0;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    // Check trading session hours (avoid trading during low liquidity)
    int hour = Hour();
    if(hour < 2 || hour > 22)  // Only trade between 2am-10pm GMT
        return false;
        
    // Check volatility using ATR
    double atr = iATR(NULL, 0, 14, 0);
    if(atr < 10 * Point)  // Avoid trading in low volatility conditions
        return false;
        
    // Check recent trade history
    HistorySelect(TimeCurrent() - 3600, TimeCurrent());
    int recentTrades = HistoryDealsTotal();
    if(recentTrades > 5)  // Limit to 5 trades per hour
        return false;
        
    // Check account drawdown
    double drawdown = (AccountEquity() - AccountBalance()) / AccountBalance() * 100;
    if(drawdown > 10)  // Stop trading if drawdown exceeds 10%
        return false;
        
    // Check news impact
    if(UseNewsFilter && IsHighImpactNews())
        return false;
        
    // Check if enough time has passed since last trade
    if(TimeCurrent() - LastTradeTime < 300)  // 5 minute cooldown
        return false;
        
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Get technical indicators
    double maFast = iMA(NULL, 0, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double maSlow = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    double macd = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Calculate technical signal strength
    double techSignal = 0;
    
    // Moving average crossover
    if(maFast > maSlow)
        techSignal += 0.3;
    else
        techSignal -= 0.3;
        
    // RSI overbought/oversold
    if(rsi > 70)
        techSignal -= 0.2;
    else if(rsi < 30)
        techSignal += 0.2;
        
    // MACD direction
    if(macd > 0)
        techSignal += 0.1;
    else
        techSignal -= 0.1;
        
    // Combine all signals with weights
    double combinedSignal = 
        (techSignal * 0.4) + 
        (mlPrediction * 0.4) + 
        (higherTFSignal * 0.2);
        
    // Apply confidence threshold
    if(combinedSignal > 0.6)
    {
        // Strong buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.6)
    {
        // Strong sell signal
        return OP_SELL;
    }
    else if(combinedSignal > 0.4 && combinedSignal <= 0.6)
    {
        // Moderate buy signal
        return OP_BUY;
    }
    else if(combinedSignal < -0.4 && combinedSignal >= -0.6)
    {
        // Moderate sell signal
        return OP_SELL;
    }
    
    // No clear signal
    return 0;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Calculate position size based on risk
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    lotSize = MathFloor(lotSize / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
    
    // Calculate price and SL/TP levels
    double price = (signal == OP_BUY) ? Ask : Bid;
    double sl = (signal == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (signal == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    
    // Prepare order request
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = (signal == OP_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = "PUR EA Trade";
    
    // Send order
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("OrderSend failed: ", result.retcode);
        if(EnableTelegram)
            SendTelegramMessage(StringFormat("Trade failed: %d", result.retcode));
        return;
    }
    
    // Log successful trade
    TotalTrades++;
    LogTrade(signal, lotSize, price, sl, tp);
    
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade executed: %s %.2f lots at %s",
            (signal == OP_BUY) ? "BUY" : "SELL",
            lotSize,
            DoubleToString(price, Digits));
        SendTelegramMessage(message);
    }
    
    // Update last trade time
    LastTradeTime = TimeCurrent();
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Implementation for trade execution
}

//+------------------------------------------------------------------+
//| Optimize parameters                                              |
//+------------------------------------------------------------------+
void OptimizeParameters()
{
    // Get recent performance data
    double recentProfit = 0;
    int recentTrades = 0;
    double recentWinRate = 0;
    double recentDrawdown = 0;
    
    // Analyze last N trades
    HistorySelect(TimeCurrent() - OptimizationPeriod * 86400, TimeCurrent());
    int total = HistoryDealsTotal();
    int wins = 0;
    double maxDrawdown = 0;
    double equityPeak = AccountEquity();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
            continue;
            
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        recentProfit += profit;
        recentTrades++;
        
        if(profit > 0)
            wins++;
            
        // Calculate drawdown
        double equity = AccountEquity();
        if(equity > equityPeak)
            equityPeak = equity;
            
        double drawdown = (equityPeak - equity) / equityPeak * 100;
        if(drawdown > maxDrawdown)
            maxDrawdown = drawdown;
    }
    
    if(recentTrades > 0)
    {
        recentWinRate = (double)wins / recentTrades * 100;
        recentDrawdown = maxDrawdown;
    }
    
    // Adjust parameters based on performance
    if(recentWinRate < 40)
    {
        // Reduce risk if win rate is low
        RiskPercent = MathMax(RiskPercent * 0.8, 1.0);
        TakeProfit = (int)MathMax(TakeProfit * 0.9, StopLoss * 1.5);
    }
    else if(recentWinRate > 60)
    {
        // Increase risk if win rate is high
        RiskPercent = MathMin(RiskPercent * 1.2, 5.0);
        TakeProfit = (int)MathMin(TakeProfit * 1.1, StopLoss * 3.0);
    }
    
    if(recentDrawdown > 10)
    {
        // Reduce risk if drawdown is high
        RiskPercent = MathMax(RiskPercent * 0.7, 1.0);
        StopLoss = (int)MathMax(StopLoss * 0.8, 20);
    }
    
    // Adjust trailing stop based on volatility
    double atr = iATR(NULL, 0, 14, 0);
    TrailingStopPoints = (int)MathRound(atr / Point * 0.5);
    TrailingStopPoints = MathMax(TrailingStopPoints, 10);
    TrailingStopPoints = MathMin(TrailingStopPoints, 50);
    
    // Adjust breakeven based on performance
    if(recentWinRate > 50)
    {
        BreakevenPoints = (int)MathRound(TrailingStopPoints * 0.75);
    }
    else
    {
        BreakevenPoints = (int)MathRound(TrailingStopPoints * 0.5);
    }
    
    // Send optimization report
    if(EnableTelegram)
    {
        string message = StringFormat("Optimization complete:\n" +
            "Win Rate: %.1f%%\n" +
            "Drawdown: %.1f%%\n" +
            "New Risk: %.1f%%\n" +
            "New SL: %d\n" +
            "New TP: %d\n" +
            "New Trailing: %d\n" +
            "New Breakeven: %d",
            recentWinRate,
            recentDrawdown,
            RiskPercent,
            StopLoss,
            TakeProfit,
            TrailingStopPoints,
            BreakevenPoints);
        SendTelegramMessage(message);
    }
    
    // Save optimization results
    if(FileHandle != INVALID_HANDLE)
    {
        FileWrite(FileHandle, "Optimization", 
            TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            recentWinRate,
            recentDrawdown,
            RiskPercent,
            StopLoss,
            TakeProfit,
            TrailingStopPoints,
            BreakevenPoints);
        FileFlush(FileHandle);
    }
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionGetTicket(i))
            continue;
            
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        
        // Calculate profit in points
        double profitPoints = (type == POSITION_TYPE_BUY) ? 
            (currentPrice - openPrice) / Point : 
            (openPrice - currentPrice) / Point;
            
        // Trailing stop logic
        if(UseTrailingStop)
        {
            double newSl = (type == POSITION_TYPE_BUY) ?
                currentPrice - TrailingStopPoints * Point :
                currentPrice + TrailingStopPoints * Point;
                
            // Only move SL in profit direction
            if((type == POSITION_TYPE_BUY && newSl > sl) ||
               (type == POSITION_TYPE_SELL && newSl < sl))
            {
                ModifyPosition(ticket, newSl, tp);
            }
        }
        
        // Breakeven logic
        if(UseBreakeven && profitPoints >= BreakevenPoints && sl == 0)
        {
            double breakevenPrice = (type == POSITION_TYPE_BUY) ?
                openPrice + BreakevenPoints * Point :
                openPrice - BreakevenPoints * Point;
                
            ModifyPosition(ticket, breakevenPrice, tp);
        }
        
        // Check for TP/SL hit
        if((type == POSITION_TYPE_BUY && currentPrice >= tp) ||
           (type == POSITION_TYPE_SELL && currentPrice <= tp) ||
           (type == POSITION_TYPE_BUY && currentPrice <= sl) ||
           (type == POSITION_TYPE_SELL && currentPrice >= sl))
        {
            ClosePosition(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = Symbol();
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ModifyPosition failed: ", result.retcode);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = Symbol();
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
        ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? Bid : Ask;
    request.deviation = Slippage;
    
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("ClosePosition failed: ", result.retcode);
        return false;
    }
    
    // Log closed trade
    double profit = PositionGetDouble(POSITION_PROFIT);
    TotalProfit += profit;
    LogTrade(-1, PositionGetDouble(POSITION_VOLUME), 
        PositionGetDouble(POSITION_PRICE_CURRENT), 
        PositionGetDouble(POSITION_SL), 
        PositionGetDouble(POSITION_TP));
        
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade closed: %s %.2f lots at %s (P/L: %.2f)",
            (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL",
            PositionGetDouble(POSITION_VOLUME),
            DoubleToString(PositionGetDouble(POSITION_PRICE_CURRENT), Digits),
            profit);
        SendTelegramMessage(message);
    }
    
    return true;
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Calculate position size based on risk
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    lotSize = MathFloor(lotSize / MarketInfo(Symbol(), MODE_LOTSTEP)) * MarketInfo(Symbol(), MODE_LOTSTEP);
    
    // Calculate price and SL/TP levels
    double price = (signal == OP_BUY) ? Ask : Bid;
    double sl = (signal == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (signal == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    
    // Prepare order request
    MqlTradeRequest request;
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = Symbol();
    request.volume = lotSize;
    request.type = (signal == OP_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = Slippage;
    request.magic = MagicNumber;
    request.comment = "PUR EA Trade";
    
    // Send order
    MqlTradeResult result;
    ZeroMemory(result);
    if(!OrderSend(request, result))
    {
        Print("OrderSend failed: ", result.retcode);
        if(EnableTelegram)
            SendTelegramMessage(StringFormat("Trade failed: %d", result.retcode));
        return;
    }
    
    // Log successful trade
    TotalTrades++;
    LogTrade(signal, lotSize, price, sl, tp);
    
    // Send Telegram notification
    if(EnableTelegram)
    {
        string message = StringFormat("Trade executed: %s %.2f lots at %s",
            (signal == OP_BUY) ? "BUY" : "SELL",
            lotSize,
            DoubleToString(price, Digits));
        SendTelegramMessage(message);
    }
    
    // Update last trade time
    LastTradeTime = TimeCurrent();
}
#property strict
#property version   "2.0"
#property description "PUR Expert Advisor for MT4 with Advanced Features"

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

// Advanced Features
input bool EnableML = false;           // Enable Machine Learning
input string MLModelPath = "";         // Path to ML model
input bool UseNewsFilter = true;       // Enable News Event Filter
input int NewsImpactLevel = 2;         // Minimum news impact level (1-3)
input bool EnableTelegram = false;     // Enable Telegram Notifications
input string TelegramToken = "";       // Telegram Bot Token
input string TelegramChatID = "";      // Telegram Chat ID
input bool MultiTimeframe = true;      // Enable Multi-Timeframe Analysis
input int HigherTF = PERIOD_H1;        // Higher timeframe for analysis
input bool AutoOptimize = false;       // Enable Auto Optimization
input int OptimizationPeriod = 14;     // Optimization lookback period (days)

// Global variables
int LastError = 0;
datetime LastTradeTime = 0;
double AccountEquity = 0;
double TotalProfit = 0;
int TotalTrades = 0;
int FileHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize account information
    AccountEquity = AccountEquity();
    
    // Initialize logging
    if(EnableMonitoring)
    {
        FileHandle = FileOpen("PUR_EA_Log.csv", FILE_WRITE|FILE_CSV);
        if(FileHandle != INVALID_HANDLE)
        {
            FileWrite(FileHandle, "Time", "Symbol", "Type", "Volume", "Price", "Stop Loss", "Take Profit", "Profit");
        }
    }
    
    // Initialize advanced features
    if(EnableML && MLModelPath != "")
    {
        if(!InitializeMLModel())
        {
            Print("Failed to initialize ML model");
            return(INIT_FAILED);
        }
    }
    
    if(EnableTelegram)
    {
        if(!InitializeTelegram())
        {
            Print("Failed to initialize Telegram");
            return(INIT_FAILED);
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
    if(FileHandle != INVALID_HANDLE)
    {
        // Write summary
        FileWrite(FileHandle, "Total Trades:", TotalTrades);
        FileWrite(FileHandle, "Total Profit:", TotalProfit);
        FileWrite(FileHandle, "Final Equity:", AccountEquity());
        FileClose(FileHandle);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check trading conditions
    if(!IsTradeAllowed())
        return;

    // Check for high impact news events
    if(UseNewsFilter && IsHighImpactNews())
    {
        if(EnableTelegram)
            SendTelegramMessage("High impact news detected - trading paused");
        return;
    }

    // Get multi-timeframe analysis
    double higherTFSignal = 0;
    if(MultiTimeframe)
    {
        higherTFSignal = GetHigherTimeframeSignal();
    }

    // Get ML prediction if enabled
    double mlPrediction = 0;
    if(EnableML && MLModelPath != "")
    {
        double features[];
        if(PrepareFeatures(features))
        {
            mlPrediction = PredictWithML(features);
        }
    }

    // Manage open positions
    ManageOpenTrades();

    // Execute trading logic
    int signal = GetTradeSignal(higherTFSignal, mlPrediction);
    if(signal != 0 && ShouldOpenTrade())
    {
        OpenTrade(signal);
        
        // Send Telegram notification
        if(EnableTelegram)
        {
            string message = StringFormat("Trade opened: %s %s at %s",
                signal > 0 ? "BUY" : "SELL",
                Symbol(),
                DoubleToString(Close[0], Digits));
            SendTelegramMessage(message);
        }
    }

    // Run auto-optimization
    if(AutoOptimize && TimeCurrent() - LastOptimization > 3600)
    {
        OptimizeParameters();
        LastOptimization = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Initialize ML model                                              |
//+------------------------------------------------------------------+
bool InitializeMLModel()
{
    if(MLModelPath == "")
    {
        Print("ML model path not specified");
        return false;
    }
    
    // Check if model file exists
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file: ", MLModelPath);
        return false;
    }
    FileClose(handle);
    
    // Initialize ML model (implementation depends on specific ML library)
    // This is a placeholder for actual ML initialization code
    Print("ML model loaded successfully from: ", MLModelPath);
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Telegram                                              |
//+------------------------------------------------------------------+
bool InitializeTelegram()
{
    if(TelegramToken == "" || TelegramChatID == "")
    {
        Print("Telegram token or chat ID not set");
        return false;
    }
    
    // Test connection
    string url = "https://api.telegram.org/bot" + TelegramToken + "/getMe";
    string headers = "Content-Type: application/json";
    string result;
    int response = WebRequest("GET", url, headers, 0, result);
    
    if(response != 200)
    {
        Print("Failed to connect to Telegram API: ", response);
        return false;
    }
    
    Print("Telegram connection established successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Check for high impact news                                       |
//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
    // Get current time
    datetime currentTime = TimeCurrent();
    
    // Define news impact levels
    enum ENUM_NEWS_IMPACT {
        NEWS_IMPACT_LOW = 1,
        NEWS_IMPACT_MEDIUM = 2,
        NEWS_IMPACT_HIGH = 3
    };
    
    // Example news events (replace with actual news feed integration)
    struct NewsEvent {
        datetime time;
        string currency;
        string event;
        int impact;
    };
    
    static NewsEvent newsEvents[] = {
        {D'2023.10.15 14:00', "USD", "FOMC Statement", NEWS_IMPACT_HIGH},
        {D'2023.10.20 12:30', "EUR", "ECB Press Conference", NEWS_IMPACT_HIGH},
        {D'2023.10.25 08:30', "GBP", "CPI y/y", NEWS_IMPACT_MEDIUM}
    };
    
    // Check if current time is within news window
    for(int i = 0; i < ArraySize(newsEvents); i++)
    {
        // Check if news affects current symbol
        string symbolCurrency = StringSubstr(Symbol(), 0, 3);
        if(newsEvents[i].currency == symbolCurrency || 
           newsEvents[i].currency == StringSubstr(Symbol(), 3, 3))
        {
            // Check if news impact level meets threshold
            if(newsEvents[i].impact >= NewsImpactLevel)
            {
                // Check if current time is within 15 minutes of news
                if(MathAbs(currentTime - newsEvents[i].time) <= 900)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                      |
//+------------------------------------------------------------------+
double GetHigherTimeframeSignal()
{
    // Implementation for multi-timeframe analysis
    return 0;
}

//+------------------------------------------------------------------+
//| Prepare features for ML prediction                               |
//+------------------------------------------------------------------+
bool PrepareFeatures(double &features[])
{
    // Define feature array size (adjust based on your model's requirements)
    ArrayResize(features, 10);
    
    // Technical indicators as features
    features[0] = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
    features[1] = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
    features[2] = iMACD(NULL, 0, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0);
    features[3] = iATR(NULL, 0, 14, 0);
    features[4] = iBands(NULL, 0, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 0);
    
    // Price action features
    features[5] = (Close[0] - Open[0]) / Point;
    features[6] = (High[0] - Low[0]) / Point;
    features[7] = Volume[0];
    
    // Time-based features
    features[8] = (double)Hour();
    features[9] = (double)DayOfWeek();
    
    // Normalize features if needed
    for(int i = 0; i < ArraySize(features); i++)
    {
        if(MathIsValidNumber(features[i]) == 0)
        {
            Print("Invalid feature value at index: ", i);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Predict with ML model                                            |
//+------------------------------------------------------------------+
double PredictWithML(double &features[])
{
    // Load model file
    int handle = FileOpen(MLModelPath, FILE_READ|FILE_BIN);
    if(handle == INVALID_HANDLE)
    {
        Print("Failed to open ML model file for prediction");
        return 0;
    }
    
    // Read model data (implementation depends on specific ML library)
    // This is a placeholder for actual prediction code
    // In practice, you would:
    // 1. Load the model weights/parameters
    // 2. Preprocess the features
    // 3. Run the prediction
    // 4. Return the prediction result
    
    // Example prediction logic (replace with actual ML prediction)
    double prediction = 0;
    for(int i = 0; i < ArraySize(features); i++)
    {
        prediction += features[i] * (i + 1); // Simple weighted sum
    }
    
    // Normalize prediction to [-1, 1] range
    prediction = MathTanh(prediction);
    
    FileClose(handle);
    
    // Return prediction strength (-1 to 1)
    // Where -1 = strong sell, 0 = neutral, 1 = strong buy
    return prediction;
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    // Implementation for position management
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
int GetTradeSignal(double higherTFSignal, double mlPrediction)
{
    // Basic signal combination
    double combinedSignal = (mlPrediction * 0.6) + (higherTFSignal * 0.4);
    
    if(combinedSignal > 0.5)
        return OP_BUY;
    else if(combinedSignal < -0.5)
        return OP_SELL;
        
    return 0;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
    // Implementation for trade permission checking
    return true;
}

//+------------------------------------------------------------------+
//| Check if should open trade                                       |
//+------------------------------------------------------------------+
bool ShouldOpenTrade()
{
    // Check if we already have an open position
    if(PositionsTotal() > 0)
        return false;
        
    // Check account equity and risk parameters
    double equity = AccountEquity();
    double balance = AccountBalance();
    double maxRisk = balance * (RiskPercent / 100.0);
    
    // Calculate position size based on stop loss
    double pointValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = maxRisk / (StopLoss * pointValue);
    lotSize = MathMin(lotSize, LotSize);
    
    // Check if lot size is valid
    if(lotSize < MarketInfo(Symbol(), MODE_MINLOT))
        return false;
        
    // Check margin requirements
    double marginRequired = AccountMarginRequired(Symbol(), lotSize);
    if(marginRequired > AccountFreeMargin())
        return false;
        
    // Check spread
    double spread = MarketInfo(Symbol(), MODE_SPREAD);
    if(spread > MaxSpread)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Open trade                                                       |
//+------------------------------------------------------------------+
void OpenTrade(int signal)
{
    // Implementation for trade execution
}

//+------------------------------------------------------------------+
//| Optimize parameters                                              |
//+------------------------------------------------------------------+
void OptimizeParameters()
{
    // Implementation for auto-optimization
}

//+------------------------------------------------------------------+
//| Send Telegram message                                            |
//+------------------------------------------------------------------+
void SendTelegramMessage(string message)
{
    if(!EnableTelegram || TelegramToken == "" || TelegramChatID == "")
        return;
        
    // Format message with timestamp and symbol
    string formattedMessage = StringFormat("[%s] %s: %s", 
        TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
        Symbol(),
        message);
    
    // Prepare API request
    string url = "https://api.telegram.org/bot" + TelegramToken + "/sendMessage";
    string headers = "Content-Type: application/json";
    string data = StringFormat("{\"chat_id\":\"%s\",\"text\":\"%s\"}", 
        TelegramChatID, 
        formattedMessage);
    
    // Send request
    string result;
    int response = WebRequest("POST", url, headers, data, result);
    
    if(response != 200)
    {
        Print("Failed to send Telegram message: ", response);
        Print("Response: ", result);
    }
    else
    {
        Print("Telegram message sent successfully");
    }
}

//+------------------------------------------------------------------+
//| Log trade                                                        |
//+------------------------------------------------------------------+
void LogTrade(int type, double volume, double price, double sl, double tp)
{
    if(FileHandle != INVALID_HANDLE)
    {
        FileWrite(FileHandle, 
            TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            Symbol(),
            (type == OP_BUY) ? "BUY" : "SELL",
            volume,
            price,
            sl,
            tp,
            0 // Initial profit is 0
        );
        FileFlush(FileHandle);
    }
}
