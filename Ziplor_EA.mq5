//+------------------------------------------------------------------+
//|                                                    Ziplor_EA.mq5 |
//|                                  Copyright 2024, Ziplor Trading  |
//|                             Risk Per Trade Position Sizing System |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Ziplor Trading"
#property link      ""
#property version   "2.00"
#property description "Ziplor EA with Advanced Risk Per Trade Management"
#property strict

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_RISK_BASE
{
   RISK_BASE_BALANCE = 0,   // Account Balance
   RISK_BASE_EQUITY  = 1,   // Account Equity
   RISK_BASE_FREE_MARGIN = 2 // Free Margin
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Risk Per Trade ==="
input double         RiskPercent = 1.0;            // Risk Per Trade (%)
input ENUM_RISK_BASE RiskBase = RISK_BASE_BALANCE; // Risk Calculation Base
input double         MaxRiskPercent = 5.0;         // Maximum Risk Per Trade (%)
input double         MaxDailyLossPercent = 3.0;    // Maximum Daily Loss (%)
input double         MaxDrawdownPercent = 10.0;    // Maximum Drawdown (%)

input group "=== Trading Strategy Parameters ==="
input int      FastMA_Period = 10;              // Fast Moving Average Period
input int      SlowMA_Period = 30;              // Slow Moving Average Period
input int      RSI_Period = 14;                 // RSI Period
input double   RSI_Overbought = 70.0;           // RSI Overbought Level
input double   RSI_Oversold = 30.0;             // RSI Oversold Level

input group "=== Position Management ==="
input double   TakeProfitPoints = 100.0;        // Take Profit (points)
input double   StopLossPoints = 50.0;           // Stop Loss (points)
input double   MaxSpreadPoints = 20.0;          // Maximum Spread (points)
input double   MinRiskReward = 1.5;             // Minimum Risk:Reward Ratio
input bool     UseTrailingStop = true;          // Use Trailing Stop
input double   TrailingStopPoints = 30.0;       // Trailing Stop (points)
input double   TrailingStepPoints = 10.0;       // Trailing Step (points)

input group "=== Trade Filtering ==="
input bool     TradeOnlyTrend = true;           // Trade Only in Trend
input int      TrendMAPeriod = 200;             // Trend MA Period
input bool     CheckTradingHours = false;       // Check Trading Hours
input int      StartHour = 8;                   // Start Trading Hour
input int      EndHour = 20;                    // End Trading Hour

input group "=== General Settings ==="
input string   TradeComment = "Ziplor_EA";      // Trade Comment
input int      MagicNumber = 123456;            // Magic Number
input bool     EnableLogging = true;            // Enable Detailed Logging

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int fastMA_handle;
int slowMA_handle;
int rsi_handle;
int trendMA_handle;

double fastMA[], slowMA[], rsi[], trendMA[];
MqlTick lastTick;
MqlTradeRequest request;
MqlTradeResult result;

// Risk tracking
double dailyStartBalance;
double peakBalance;
datetime lastDayChecked;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate input parameters
   if(!ValidateInputs())
   {
      Print("ERROR: Invalid input parameters!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Initialize indicators
   fastMA_handle = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   slowMA_handle = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   trendMA_handle = iMA(_Symbol, PERIOD_CURRENT, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   // Check if indicators initialized successfully
   if(fastMA_handle == INVALID_HANDLE || slowMA_handle == INVALID_HANDLE ||
      rsi_handle == INVALID_HANDLE || trendMA_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   // Set array as series
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(trendMA, true);

   // Initialize risk tracking
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   peakBalance = dailyStartBalance;
   lastDayChecked = 0;

   if(EnableLogging)
   {
      Print("=== Ziplor EA Initialized ===");
      Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(PERIOD_CURRENT));
      Print("Risk Per Trade: ", RiskPercent, "% of ", EnumToString(RiskBase));
      Print("Max Daily Loss: ", MaxDailyLossPercent, "% | Max Drawdown: ", MaxDrawdownPercent, "%");
      Print("Stop Loss: ", StopLossPoints, " pts | Take Profit: ", TakeProfitPoints, " pts");
      Print("Min Risk:Reward = ", MinRiskReward);
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(fastMA_handle != INVALID_HANDLE) IndicatorRelease(fastMA_handle);
   if(slowMA_handle != INVALID_HANDLE) IndicatorRelease(slowMA_handle);
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
   if(trendMA_handle != INVALID_HANDLE) IndicatorRelease(trendMA_handle);

   if(EnableLogging)
      Print("Ziplor EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current tick
   if(!SymbolInfoTick(_Symbol, lastTick))
   {
      if(EnableLogging) Print("ERROR: Failed to get tick data!");
      return;
   }

   // Update daily tracking on new day
   UpdateDailyTracking();

   // Update peak balance for drawdown tracking
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > peakBalance)
      peakBalance = currentBalance;

   // Check if new bar formed
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(currentBarTime == lastBarTime)
      return; // Wait for new bar

   lastBarTime = currentBarTime;

   // Update indicator buffers
   if(!UpdateIndicators())
   {
      if(EnableLogging) Print("ERROR: Failed to update indicators!");
      return;
   }

   // Check trading conditions
   if(!CheckTradingConditions())
      return;

   // Check risk limits before proceeding
   if(!CheckRiskLimits())
      return;

   // Get signal
   int signal = GetTradingSignal();

   // Manage existing positions
   ManagePositions();

   // Check if we can open new position
   if(!CanOpenNewPosition())
      return;

   // Execute trades based on signal
   if(signal == 1) // Buy signal
   {
      OpenBuyPosition();
   }
   else if(signal == -1) // Sell signal
   {
      OpenSellPosition();
   }
}

//+------------------------------------------------------------------+
//| Validate input parameters                                        |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(FastMA_Period <= 0 || SlowMA_Period <= 0 || FastMA_Period >= SlowMA_Period)
   {
      Print("ERROR: Invalid MA periods! Fast=", FastMA_Period, " Slow=", SlowMA_Period);
      return false;
   }

   if(RSI_Period <= 0 || RSI_Overbought <= RSI_Oversold)
   {
      Print("ERROR: Invalid RSI parameters!");
      return false;
   }

   if(RiskPercent <= 0 || RiskPercent > MaxRiskPercent)
   {
      Print("ERROR: RiskPercent must be between 0 and ", MaxRiskPercent, "!");
      return false;
   }

   if(MaxRiskPercent <= 0 || MaxRiskPercent > 10)
   {
      Print("ERROR: MaxRiskPercent must be between 0 and 10!");
      return false;
   }

   if(MaxDailyLossPercent <= 0 || MaxDailyLossPercent > 50)
   {
      Print("ERROR: MaxDailyLossPercent must be between 0 and 50!");
      return false;
   }

   if(MaxDrawdownPercent <= 0 || MaxDrawdownPercent > 50)
   {
      Print("ERROR: MaxDrawdownPercent must be between 0 and 50!");
      return false;
   }

   if(StopLossPoints <= 0 || TakeProfitPoints <= 0)
   {
      Print("ERROR: Invalid SL/TP values!");
      return false;
   }

   if(MinRiskReward > 0 && TakeProfitPoints / StopLossPoints < MinRiskReward)
   {
      Print("WARNING: TP/SL ratio (", NormalizeDouble(TakeProfitPoints / StopLossPoints, 2),
            ") is below minimum R:R (", MinRiskReward, ")");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Update daily P&L tracking                                        |
//+------------------------------------------------------------------+
void UpdateDailyTracking()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                                 IntegerToString(dt.mon) + "." +
                                 IntegerToString(dt.day));

   if(today != lastDayChecked)
   {
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lastDayChecked = today;

      if(EnableLogging)
         Print("New trading day. Starting balance: ", dailyStartBalance);
   }
}

//+------------------------------------------------------------------+
//| Check risk limits (daily loss, drawdown)                         |
//+------------------------------------------------------------------+
bool CheckRiskLimits()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Check daily loss limit
   double dailyLoss = dailyStartBalance - currentBalance;
   double dailyLossPercent = 0;
   if(dailyStartBalance > 0)
      dailyLossPercent = (dailyLoss / dailyStartBalance) * 100.0;

   if(dailyLossPercent >= MaxDailyLossPercent)
   {
      if(EnableLogging)
         Print("RISK LIMIT: Daily loss limit reached! Loss: ",
               NormalizeDouble(dailyLossPercent, 2), "% (Max: ", MaxDailyLossPercent, "%)");
      return false;
   }

   // Check maximum drawdown from peak balance
   double drawdown = peakBalance - currentEquity;
   double drawdownPercent = 0;
   if(peakBalance > 0)
      drawdownPercent = (drawdown / peakBalance) * 100.0;

   if(drawdownPercent >= MaxDrawdownPercent)
   {
      if(EnableLogging)
         Print("RISK LIMIT: Maximum drawdown reached! DD: ",
               NormalizeDouble(drawdownPercent, 2), "% (Max: ", MaxDrawdownPercent, "%)");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get the account value for risk calculation                       |
//+------------------------------------------------------------------+
double GetRiskBaseValue()
{
   switch(RiskBase)
   {
      case RISK_BASE_EQUITY:
         return AccountInfoDouble(ACCOUNT_EQUITY);
      case RISK_BASE_FREE_MARGIN:
         return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      default: // RISK_BASE_BALANCE
         return AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk per trade                  |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossPoints)
{
   // Get risk base value (balance, equity, or free margin)
   double riskBaseValue = GetRiskBaseValue();

   if(riskBaseValue <= 0)
   {
      if(EnableLogging) Print("ERROR: Risk base value is zero or negative!");
      return 0;
   }

   // Calculate risk amount in account currency
   double riskAmount = riskBaseValue * RiskPercent / 100.0;

   // Get symbol properties for lot calculation
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   // Validate symbol properties
   if(tickValue <= 0 || tickSize <= 0 || lotStep <= 0)
   {
      if(EnableLogging)
         Print("ERROR: Invalid symbol properties! TickValue=", tickValue,
               " TickSize=", tickSize, " LotStep=", lotStep);
      return 0;
   }

   // Calculate stop loss in price
   double stopLossPrice = stopLossPoints * _Point;

   // Calculate lot size: Risk Amount / (Stop Loss Price × (Tick Value / Tick Size))
   double lots = riskAmount / (stopLossPrice * (tickValue / tickSize));

   // Normalize to lot step (floor to avoid exceeding risk)
   lots = MathFloor(lots / lotStep) * lotStep;

   // Apply broker limits
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   // Final normalization
   lots = NormalizeDouble(lots, 2);

   if(EnableLogging)
   {
      Print("--- Position Size Calculation ---");
      Print("  Risk Base (", EnumToString(RiskBase), "): ", NormalizeDouble(riskBaseValue, 2));
      Print("  Risk Amount: ", NormalizeDouble(riskAmount, 2), " (", RiskPercent, "%)");
      Print("  Stop Loss: ", stopLossPoints, " points (", NormalizeDouble(stopLossPrice, _Digits), " price)");
      Print("  Tick Value: ", tickValue, " | Tick Size: ", tickSize);
      Print("  Calculated Lots: ", lots);
   }

   return lots;
}

//+------------------------------------------------------------------+
//| Update indicator buffers                                         |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(fastMA_handle, 0, 0, 3, fastMA) <= 0) return false;
   if(CopyBuffer(slowMA_handle, 0, 0, 3, slowMA) <= 0) return false;
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi) <= 0) return false;
   if(CopyBuffer(trendMA_handle, 0, 0, 3, trendMA) <= 0) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check trading conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
   // Check spread
   double spread = (lastTick.ask - lastTick.bid) / _Point;
   if(spread > MaxSpreadPoints)
   {
      if(EnableLogging) Print("Spread too high: ", spread, " points");
      return false;
   }

   // Check trading hours
   if(CheckTradingHours)
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      if(dt.hour < StartHour || dt.hour >= EndHour)
      {
         return false;
      }
   }

   // Check if account allows trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      if(EnableLogging) Print("Trading not allowed in terminal!");
      return false;
   }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      if(EnableLogging) Print("Automated trading is forbidden!");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get trading signal                                               |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // Check if we have enough data
   if(ArraySize(fastMA) < 3 || ArraySize(slowMA) < 3 || ArraySize(rsi) < 3)
      return 0;

   // MA Crossover detection
   bool bullishCross = (fastMA[1] > slowMA[1] && fastMA[2] <= slowMA[2]);
   bool bearishCross = (fastMA[1] < slowMA[1] && fastMA[2] >= slowMA[2]);

   // RSI Filter
   bool rsiNotOverbought = rsi[1] < RSI_Overbought;
   bool rsiNotOversold = rsi[1] > RSI_Oversold;

   // Trend Filter
   bool uptrend = true;
   bool downtrend = true;

   if(TradeOnlyTrend)
   {
      uptrend = (lastTick.bid > trendMA[1]);
      downtrend = (lastTick.bid < trendMA[1]);
   }

   // Buy Signal
   if(bullishCross && rsiNotOversold && uptrend)
   {
      if(EnableLogging) Print("BUY signal detected!");
      return 1;
   }

   // Sell Signal
   if(bearishCross && rsiNotOverbought && downtrend)
   {
      if(EnableLogging) Print("SELL signal detected!");
      return -1;
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Check if can open new position                                   |
//+------------------------------------------------------------------+
bool CanOpenNewPosition()
{
   int totalPositions = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         totalPositions++;
      }
   }

   // Allow only one position at a time per symbol
   return (totalPositions == 0);
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = lastTick.ask;
   double sl = NormalizeDouble(ask - StopLossPoints * _Point, _Digits);
   double tp = NormalizeDouble(ask + TakeProfitPoints * _Point, _Digits);

   // Calculate position size based on risk per trade
   double lots = CalculatePositionSize(StopLossPoints);
   if(lots <= 0)
   {
      if(EnableLogging) Print("ERROR: Position size is zero! Cannot open BUY.");
      return;
   }

   // Prepare request
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = ORDER_FILLING_FOK;

   // Try to send order
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
      {
         if(EnableLogging)
            Print("ERROR: Failed to open BUY position! Error: ", GetLastError(),
                  " Retcode: ", result.retcode);
         return;
      }
   }

   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      if(EnableLogging)
         Print("BUY position opened! Ticket: ", result.order,
               " Volume: ", lots, " Price: ", ask,
               " SL: ", sl, " TP: ", tp,
               " Risk: ", RiskPercent, "% of ", EnumToString(RiskBase));
   }
   else
   {
      if(EnableLogging)
         Print("ERROR: Order failed! Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = lastTick.bid;
   double sl = NormalizeDouble(bid + StopLossPoints * _Point, _Digits);
   double tp = NormalizeDouble(bid - TakeProfitPoints * _Point, _Digits);

   // Calculate position size based on risk per trade
   double lots = CalculatePositionSize(StopLossPoints);
   if(lots <= 0)
   {
      if(EnableLogging) Print("ERROR: Position size is zero! Cannot open SELL.");
      return;
   }

   // Prepare request
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lots;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = ORDER_FILLING_FOK;

   // Try to send order
   if(!OrderSend(request, result))
   {
      request.type_filling = ORDER_FILLING_IOC;
      if(!OrderSend(request, result))
      {
         if(EnableLogging)
            Print("ERROR: Failed to open SELL position! Error: ", GetLastError(),
                  " Retcode: ", result.retcode);
         return;
      }
   }

   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      if(EnableLogging)
         Print("SELL position opened! Ticket: ", result.order,
               " Volume: ", lots, " Price: ", bid,
               " SL: ", sl, " TP: ", tp,
               " Risk: ", RiskPercent, "% of ", EnumToString(RiskBase));
   }
   else
   {
      if(EnableLogging)
         Print("ERROR: Order failed! Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions (Trailing Stop)                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!UseTrailingStop) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      long positionType = PositionGetInteger(POSITION_TYPE);

      double newSL = 0;
      bool modifyNeeded = false;

      if(positionType == POSITION_TYPE_BUY)
      {
         double trailPrice = lastTick.bid - TrailingStopPoints * _Point;
         if(trailPrice > currentSL + TrailingStepPoints * _Point && trailPrice > positionOpenPrice)
         {
            newSL = trailPrice;
            modifyNeeded = true;
         }
      }
      else if(positionType == POSITION_TYPE_SELL)
      {
         double trailPrice = lastTick.ask + TrailingStopPoints * _Point;
         if((currentSL == 0 || trailPrice < currentSL - TrailingStepPoints * _Point) &&
            trailPrice < positionOpenPrice)
         {
            newSL = trailPrice;
            modifyNeeded = true;
         }
      }

      if(modifyNeeded)
      {
         ZeroMemory(request);
         ZeroMemory(result);

         request.action = TRADE_ACTION_SLTP;
         request.symbol = _Symbol;
         request.position = ticket;
         request.sl = NormalizeDouble(newSL, _Digits);
         request.tp = PositionGetDouble(POSITION_TP);

         if(OrderSend(request, result))
         {
            if(EnableLogging)
               Print("Trailing stop updated for ticket: ", ticket, " New SL: ", newSL);
         }
         else
         {
            if(EnableLogging)
               Print("ERROR: Failed to update trailing stop! Error: ", GetLastError());
         }
      }
   }
}
//+------------------------------------------------------------------+
