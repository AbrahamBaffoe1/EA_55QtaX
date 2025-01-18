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
input double MaxDailyLoss = 0.03;   // 3% of total capital
input double MaxPositionSize = 0.15;// 15% of total capital
input int MaxLeverage = 20;         // Maximum leverage
input double RiskPerTrade = 0.015;  // 1.5% risk per trade
input double LotSize = 0.1;         // Default lot size

// Global variables
double ShortMA, LongMA, RSI, MACDMain, MACDSignal;
double AccountEquity;
datetime LastTradeTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialization
    AccountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    LastTradeTime = 0;
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Cleanup
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check risk parameters
    if(!CheckRiskParameters())
        return;

    // Calculate indicators
    CalculateIndicators();

    // Generate trading signals
    int signal = GenerateSignal();

    // Execute trades
    ExecuteTrade(signal);
}

//+------------------------------------------------------------------+
//| Calculate indicators                                             |
//+------------------------------------------------------------------+
void CalculateIndicators()
{
    ShortMA = iMA(NULL, 0, ShortMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
    LongMA = iMA(NULL, 0, LongMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
    RSI = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, 0);
    MACDMain = iMACD(NULL, 0, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_MAIN, 0);
    MACDSignal = iMACD(NULL, 0, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE, MODE_SIGNAL, 0);
}

//+------------------------------------------------------------------+
//| Generate trading signal                                          |
//+------------------------------------------------------------------+
int GenerateSignal()
{
    // MA Crossover signal
    bool maBuySignal = ShortMA > LongMA && ShortMA[1] <= LongMA[1];
    bool maSellSignal = ShortMA < LongMA && ShortMA[1] >= LongMA[1];
    
    // RSI signal
    bool rsiBuySignal = RSI < RSIOversold;
    bool rsiSellSignal = RSI > RSIOverbought;
    
    // MACD signal
    bool macdBuySignal = MACDMain > MACDSignal && MACDMain[1] <= MACDSignal[1];
    bool macdSellSignal = MACDMain < MACDSignal && MACDMain[1] >= MACDSignal[1];
    
    // Combined signal
    if(maBuySignal && rsiBuySignal && macdBuySignal)
        return 1; // Buy signal
    else if(maSellSignal && rsiSellSignal && macdSellSignal)
        return -1; // Sell signal
        
    return 0; // No signal
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal)
{
    // Check if we already have an open position
    if(PositionSelect(Symbol()))
        return;

    // Calculate position size based on risk
    double lotSize = CalculatePositionSize();

    // Execute trade based on signal
    if(signal == 1) // Buy
    {
        trade.Buy(lotSize);
    }
    else if(signal == -1) // Sell
    {
        trade.Sell(lotSize);
    }
    
    LastTradeTime = TimeCurrent();
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
    // Calculate stop loss based on ATR or other method
    return 50; // Placeholder value
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
    void Buy(double lotSize)
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
        request.deviation = 10;
        
        if(!OrderSend(request, result))
            Print("Buy order failed: ", result.retcode);
    }
    
    void Sell(double lotSize)
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
        request.deviation = 10;
        
        if(!OrderSend(request, result))
            Print("Sell order failed: ", result.retcode);
    }
};

CTrade trade;
//+------------------------------------------------------------------+
