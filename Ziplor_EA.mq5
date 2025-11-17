//+------------------------------------------------------------------+
//|                                                    Ziplor_EA.mq5 |
//|                                  Copyright 2024, Ziplor Trading  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Ziplor Trading"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Trading Strategy Parameters ==="
input int      FastMA_Period = 10;              // Fast Moving Average Period
input int      SlowMA_Period = 30;              // Slow Moving Average Period
input int      RSI_Period = 14;                 // RSI Period
input double   RSI_Overbought = 70.0;           // RSI Overbought Level
input double   RSI_Oversold = 30.0;             // RSI Oversold Level

input group "=== Risk Management ==="
input double   RiskPercent = 1.0;               // Risk Per Trade (%)
input double   MaxSpreadPoints = 20.0;          // Maximum Spread (points)
input double   MinRiskReward = 1.5;             // Minimum Risk:Reward Ratio

input group "=== Position Management ==="
input double   TakeProfitPoints = 100.0;        // Take Profit (points)
input double   StopLossPoints = 50.0;           // Stop Loss (points)
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
   
   if(EnableLogging)
      Print("Ziplor EA initialized successfully on ", _Symbol, " ", EnumToString(PERIOD_CURRENT));
   
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
      Print("ERROR: Invalid MA periods!");
      return false;
   }
   
   if(RSI_Period <= 0 || RSI_Overbought <= RSI_Oversold)
   {
      Print("ERROR: Invalid RSI parameters!");
      return false;
   }
   
   if(RiskPercent <= 0 || RiskPercent > 10)
   {
      Print("ERROR: Risk percent must be between 0 and 10!");
      return false;
   }
   
   if(StopLossPoints <= 0 || TakeProfitPoints <= 0)
   {
      Print("ERROR: Invalid SL/TP values!");
      return false;
   }
   
   return true;
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
//| Check if can open new position                                  |
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
//| Calculate position size                                          |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLossPoints)
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   // Calculate lot size
   double lots = (riskAmount / stopLossPoints) / (tickValue / tickSize);
   
   // Normalize to lot step
   lots = MathFloor(lots / lotStep) * lotStep;
   
   // Apply limits
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   double ask = lastTick.ask;
   double sl = ask - StopLossPoints * _Point;
   double tp = ask + TakeProfitPoints * _Point;
   
   // Calculate position size
   double lots = CalculatePositionSize(StopLossPoints);
   
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
         Print("BUY position opened successfully! Ticket: ", result.order, 
               " Volume: ", lots, " Price: ", ask);
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
   double sl = bid + StopLossPoints * _Point;
   double tp = bid - TakeProfitPoints * _Point;
   
   // Calculate position size
   double lots = CalculatePositionSize(StopLossPoints);
   
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
         Print("SELL position opened successfully! Ticket: ", result.order, 
               " Volume: ", lots, " Price: ", bid);
   }
   else
   {
      if(EnableLogging)
         Print("ERROR: Order failed! Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions (Trailing Stop)                       |
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
