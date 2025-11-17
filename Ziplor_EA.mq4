//+------------------------------------------------------------------+
//|                                                    Ziplor_EA.mq4 |
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
input string   Section1 = "=== Trading Strategy Parameters ==="; // -----
input int      FastMA_Period = 10;              // Fast Moving Average Period
input int      SlowMA_Period = 30;              // Slow Moving Average Period
input int      RSI_Period = 14;                 // RSI Period
input double   RSI_Overbought = 70.0;           // RSI Overbought Level
input double   RSI_Oversold = 30.0;             // RSI Oversold Level

input string   Section2 = "=== Risk Management ==="; // -----
input double   RiskPercent = 1.0;               // Risk Per Trade (%)
input double   MaxSpreadPoints = 20.0;          // Maximum Spread (points)
input double   MinRiskReward = 1.5;             // Minimum Risk:Reward Ratio

input string   Section3 = "=== Position Management ==="; // -----
input double   TakeProfitPoints = 100.0;        // Take Profit (points)
input double   StopLossPoints = 50.0;           // Stop Loss (points)
input bool     UseTrailingStop = true;          // Use Trailing Stop
input double   TrailingStopPoints = 30.0;       // Trailing Stop (points)
input double   TrailingStepPoints = 10.0;       // Trailing Step (points)

input string   Section4 = "=== Trade Filtering ==="; // -----
input bool     TradeOnlyTrend = true;           // Trade Only in Trend
input int      TrendMAPeriod = 200;             // Trend MA Period
input bool     CheckTradingHours = false;       // Check Trading Hours
input int      StartHour = 8;                   // Start Trading Hour
input int      EndHour = 20;                    // End Trading Hour

input string   Section5 = "=== General Settings ==="; // -----
input string   TradeComment = "Ziplor_EA";      // Trade Comment
input int      MagicNumber = 123456;            // Magic Number
input bool     EnableLogging = true;            // Enable Detailed Logging

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
datetime lastBarTime = 0;

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
   
   // Check if trading is allowed
   if(!IsTradeAllowed())
   {
      Print("ERROR: Trading is not allowed! Check settings.");
      return(INIT_FAILED);
   }
   
   if(EnableLogging)
      Print("Ziplor EA initialized successfully on ", Symbol(), " ", PeriodToString(Period()));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(EnableLogging)
      Print("Ziplor EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if new bar formed
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   
   if(currentBarTime == lastBarTime)
      return; // Wait for new bar
   
   lastBarTime = currentBarTime;
   
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
//| Check trading conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
   // Check spread
   double spread = MarketInfo(Symbol(), MODE_SPREAD);
   if(spread > MaxSpreadPoints)
   {
      if(EnableLogging) Print("Spread too high: ", spread, " points");
      return false;
   }
   
   // Check trading hours
   if(CheckTradingHours)
   {
      int currentHour = Hour();
      if(currentHour < StartHour || currentHour >= EndHour)
      {
         return false;
      }
   }
   
   // Check if account allows trading
   if(!IsTradeAllowed())
   {
      if(EnableLogging) Print("Trading not allowed!");
      return false;
   }
   
   // Check if connected
   if(!IsConnected())
   {
      if(EnableLogging) Print("No connection to trade server!");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get trading signal                                               |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // Get indicator values
   double fastMA_current = iMA(Symbol(), Period(), FastMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fastMA_previous = iMA(Symbol(), Period(), FastMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slowMA_current = iMA(Symbol(), Period(), SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowMA_previous = iMA(Symbol(), Period(), SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   double rsi_current = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE, 1);
   
   double trendMA = iMA(Symbol(), Period(), TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   
   // Check for errors
   if(fastMA_current == 0 || slowMA_current == 0 || rsi_current == 0)
   {
      if(EnableLogging) Print("ERROR: Failed to get indicator values!");
      return 0;
   }
   
   // MA Crossover detection
   bool bullishCross = (fastMA_current > slowMA_current && fastMA_previous <= slowMA_previous);
   bool bearishCross = (fastMA_current < slowMA_current && fastMA_previous >= slowMA_previous);
   
   // RSI Filter
   bool rsiNotOverbought = rsi_current < RSI_Overbought;
   bool rsiNotOversold = rsi_current > RSI_Oversold;
   
   // Trend Filter
   bool uptrend = true;
   bool downtrend = true;
   
   if(TradeOnlyTrend)
   {
      uptrend = (Bid > trendMA);
      downtrend = (Bid < trendMA);
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
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
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
   double accountBalance = AccountBalance();
   double riskAmount = accountBalance * RiskPercent / 100.0;
   
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   // Calculate lot size
   double lots = riskAmount / (stopLossPoints * tickValue);
   
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
   double ask = Ask;
   double sl = ask - StopLossPoints * Point;
   double tp = ask + TakeProfitPoints * Point;
   
   // Calculate position size
   double lots = CalculatePositionSize(StopLossPoints);
   
   // Normalize prices
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   
   // Open order
   int ticket = OrderSend(Symbol(), OP_BUY, lots, ask, 10, sl, tp, TradeComment, MagicNumber, 0, clrGreen);
   
   if(ticket > 0)
   {
      if(EnableLogging)
         Print("BUY position opened successfully! Ticket: ", ticket, 
               " Volume: ", lots, " Price: ", ask, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      int error = GetLastError();
      if(EnableLogging)
         Print("ERROR: Failed to open BUY position! Error: ", error, " - ", ErrorDescription(error));
   }
}

//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   double bid = Bid;
   double sl = bid + StopLossPoints * Point;
   double tp = bid - TakeProfitPoints * Point;
   
   // Calculate position size
   double lots = CalculatePositionSize(StopLossPoints);
   
   // Normalize prices
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   
   // Open order
   int ticket = OrderSend(Symbol(), OP_SELL, lots, bid, 10, sl, tp, TradeComment, MagicNumber, 0, clrRed);
   
   if(ticket > 0)
   {
      if(EnableLogging)
         Print("SELL position opened successfully! Ticket: ", ticket, 
               " Volume: ", lots, " Price: ", bid, " SL: ", sl, " TP: ", tp);
   }
   else
   {
      int error = GetLastError();
      if(EnableLogging)
         Print("ERROR: Failed to open SELL position! Error: ", error, " - ", ErrorDescription(error));
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions (Trailing Stop)                       |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!UseTrailingStop) return;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      
      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();
      double newSL = 0;
      bool modifyNeeded = false;
      
      if(OrderType() == OP_BUY)
      {
         double trailPrice = Bid - TrailingStopPoints * Point;
         if(trailPrice > currentSL + TrailingStepPoints * Point && trailPrice > openPrice)
         {
            newSL = NormalizeDouble(trailPrice, Digits);
            modifyNeeded = true;
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double trailPrice = Ask + TrailingStopPoints * Point;
         if((currentSL == 0 || trailPrice < currentSL - TrailingStepPoints * Point) && 
            trailPrice < openPrice)
         {
            newSL = NormalizeDouble(trailPrice, Digits);
            modifyNeeded = true;
         }
      }
      
      if(modifyNeeded)
      {
         bool result = OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrBlue);
         
         if(result)
         {
            if(EnableLogging)
               Print("Trailing stop updated for ticket: ", OrderTicket(), " New SL: ", newSL);
         }
         else
         {
            if(EnableLogging)
            {
               int error = GetLastError();
               Print("ERROR: Failed to update trailing stop! Error: ", error, " - ", ErrorDescription(error));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get error description                                            |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode)
{
   switch(errorCode)
   {
      case 0:    return "No error";
      case 1:    return "No error, but result is unknown";
      case 2:    return "Common error";
      case 3:    return "Invalid trade parameters";
      case 4:    return "Trade server is busy";
      case 5:    return "Old version of the client terminal";
      case 6:    return "No connection with trade server";
      case 7:    return "Not enough rights";
      case 8:    return "Too frequent requests";
      case 9:    return "Malfunctional trade operation";
      case 64:   return "Account disabled";
      case 65:   return "Invalid account";
      case 128:  return "Trade timeout";
      case 129:  return "Invalid price";
      case 130:  return "Invalid stops";
      case 131:  return "Invalid trade volume";
      case 132:  return "Market is closed";
      case 133:  return "Trade is disabled";
      case 134:  return "Not enough money";
      case 135:  return "Price changed";
      case 136:  return "Off quotes";
      case 137:  return "Broker is busy";
      case 138:  return "Requote";
      case 139:  return "Order is locked";
      case 140:  return "Long positions only allowed";
      case 141:  return "Too many requests";
      case 145:  return "Modification denied because order too close to market";
      case 146:  return "Trade context is busy";
      case 147:  return "Expirations are denied by broker";
      case 148:  return "Amount of open and pending orders has reached the limit";
      case 149:  return "Hedging is prohibited";
      case 150:  return "Prohibited by FIFO rules";
      default:   return "Unknown error";
   }
}

//+------------------------------------------------------------------+
//| Period to string                                                 |
//+------------------------------------------------------------------+
string PeriodToString(int period)
{
   switch(period)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}
//+------------------------------------------------------------------+
