//+------------------------------------------------------------------+
//|                                          Ziplor_RPT_STOBV.mq5    |
//|                                  Copyright 2024, Ziplor Trading  |
//|                             Risk Per Trade Position Sizing System |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Ziplor Trading"
#property link      ""
#property version   "2.00"
#property description "Ziplor RPT STOBV - Risk Per Trade with Stochastic OBV Strategy"
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
input int      OBV_SMA_Period = 20;             // OBV SMA Period (for crossover)
input int      OBV_Norm_Period = 50;            // OBV Normalization Lookback Period
input int      Stoch_K_Period = 26;             // Stochastic %K Period
input int      Stoch_D_Period = 3;              // Stochastic %D Period
input int      Stoch_Slowing = 3;               // Stochastic Slowing
input double   Stoch_Overbought = 80.0;         // Stochastic Overbought Level
input double   Stoch_Oversold = 20.0;           // Stochastic Oversold Level

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
input bool     EnableRecoveryTrading = true;    // Allow Recovery Trading Below EMA200
input int      RecoveryLookbackBars = 50;       // Recovery Lookback (bars to check last loss)
input bool     CheckTradingHours = false;       // Check Trading Hours
input int      StartHour = 8;                   // Start Trading Hour
input int      EndHour = 20;                    // End Trading Hour

input group "=== General Settings ==="
input string   TradeComment = "Ziplor";           // Trade Comment (prefix for order comments)
input int      MagicNumber = 123456;            // Magic Number
input bool     EnableLogging = true;            // Enable Detailed Logging

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int obv_handle;
int stoch_handle;
int trendMA_handle;

// OBV and Stochastic buffers
double obvBuffer[];
double stochK[], stochD[];
double trendMA[];

// Normalized OBV SMA crossover state
double normOBV_current, normOBV_prev;
double normOBV_SMA_current, normOBV_SMA_prev;
MqlTick lastTick;
MqlTradeRequest request;
MqlTradeResult result;

// Risk tracking
double dailyStartBalance;
double peakBalance;
datetime lastDayChecked;

// Recovery trading state
bool isRecoveryMode = false;

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
   obv_handle = iOBV(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
   trendMA_handle = iMA(_Symbol, PERIOD_CURRENT, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   // Check if indicators initialized successfully
   if(obv_handle == INVALID_HANDLE || stoch_handle == INVALID_HANDLE ||
      trendMA_handle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   // Set array as series
   ArraySetAsSeries(obvBuffer, true);
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   ArraySetAsSeries(trendMA, true);

   // Initialize risk tracking
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   peakBalance = dailyStartBalance;
   lastDayChecked = 0;

   if(EnableLogging)
   {
      Print("=== Ziplor RPT STOBV Initialized ===");
      Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(PERIOD_CURRENT));
      Print("Strategy: Normalized OBV (", OBV_Norm_Period, ") x SMA(", OBV_SMA_Period, ") + Stochastic(", Stoch_K_Period, ",", Stoch_D_Period, ",", Stoch_Slowing, ")");
      Print("Risk Per Trade: ", RiskPercent, "% of ", EnumToString(RiskBase));
      Print("Max Daily Loss: ", MaxDailyLossPercent, "% | Max Drawdown: ", MaxDrawdownPercent, "%");
      Print("Stop Loss: ", StopLossPoints, " pts | Take Profit: ", TakeProfitPoints, " pts");
      Print("Min Risk:Reward = ", MinRiskReward);
      Print("Recovery Trading: ", EnableRecoveryTrading ? "Enabled" : "Disabled",
            " | Lookback: ", RecoveryLookbackBars, " bars");
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(obv_handle != INVALID_HANDLE) IndicatorRelease(obv_handle);
   if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
   if(trendMA_handle != INVALID_HANDLE) IndicatorRelease(trendMA_handle);

   if(EnableLogging)
      Print("Ziplor RPT STOBV deinitialized. Reason: ", reason);
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

   // Update recovery mode state
   UpdateRecoveryMode();

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
      if(isRecoveryMode)
         OpenBuyPosition(true);  // Recovery trade
      else
         OpenBuyPosition(false); // Normal trade
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
   if(OBV_SMA_Period <= 0 || OBV_Norm_Period <= 1)
   {
      Print("ERROR: Invalid OBV parameters! SMA_Period=", OBV_SMA_Period, " Norm_Period=", OBV_Norm_Period);
      return false;
   }

   if(OBV_SMA_Period >= OBV_Norm_Period)
   {
      Print("ERROR: OBV SMA Period must be less than Normalization Period!");
      return false;
   }

   if(Stoch_K_Period <= 0 || Stoch_D_Period <= 0 || Stoch_Slowing <= 0)
   {
      Print("ERROR: Invalid Stochastic parameters!");
      return false;
   }

   if(Stoch_Overbought <= Stoch_Oversold || Stoch_Overbought > 100 || Stoch_Oversold < 0)
   {
      Print("ERROR: Invalid Stochastic levels!");
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
            ") is below minimum R:R (", MinRiskReward, ");");
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
//| Update recovery mode state                                       |
//| Recovery mode activates when the last closed position for this    |
//| EA was a loss, allowing a BUY trade below EMA200 to recover.     |
//+------------------------------------------------------------------+
void UpdateRecoveryMode()
{
   isRecoveryMode = false;

   if(!EnableRecoveryTrading)
      return;

   // Scan recent deal history for the last closed position by this EA
   datetime fromTime = iTime(_Symbol, PERIOD_CURRENT, RecoveryLookbackBars);
   datetime toTime = TimeCurrent();

   if(!HistorySelect(fromTime, toTime))
      return;

   int totalDeals = HistoryDealsTotal();
   double lastProfit = 0;
   bool foundDeal = false;

   // Iterate backwards to find the most recent exit deal for this EA
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= 0) continue;

      // Only consider deals for this symbol and magic number
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;

      // Only consider exit deals (DEAL_ENTRY_OUT or DEAL_ENTRY_INOUT)
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_INOUT) continue;

      lastProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                 + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                 + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      foundDeal = true;
      break;
   }

   if(foundDeal && lastProfit < 0)
   {
      isRecoveryMode = true;
      if(EnableLogging)
         Print("RECOVERY MODE: Last trade was a loss (",
               NormalizeDouble(lastProfit, 2),
               "). Recovery trading below EMA200 allowed.");
   }
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
      Print("  Risk Amount: ", NormalizeDouble(riskAmount, 2), " (", RiskPercent, "%);");
      Print("  Stop Loss: ", stopLossPoints, " points (", NormalizeDouble(stopLossPrice, _Digits), " price);");
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
   // Need enough bars: OBV_SMA_Period + 2 normalized values starting from bar[1],
   // each needing OBV_Norm_Period bars for min/max lookback
   int barsNeeded = OBV_Norm_Period + OBV_SMA_Period + 2;
   if(CopyBuffer(obv_handle, 0, 0, barsNeeded, obvBuffer) < barsNeeded) return false;
   if(CopyBuffer(stoch_handle, 0, 0, 3, stochK) <= 0) return false;
   if(CopyBuffer(stoch_handle, 1, 0, 3, stochD) <= 0) return false;
   if(CopyBuffer(trendMA_handle, 0, 0, 3, trendMA) <= 0) return false;

   // Calculate normalized OBV and its SMA for current and previous bars
   if(!CalcNormalizedOBVCross())
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate normalized OBV and its SMA crossover state             |
//| Normalized OBV = (OBV - min) / (max - min) * 100                |
//| Computes values for bar[1] (current closed) and bar[2] (prev)   |
//+------------------------------------------------------------------+
bool CalcNormalizedOBVCross()
{
   int totalBars = ArraySize(obvBuffer);
   // We need at least OBV_Norm_Period + OBV_SMA_Period + 2 bars
   if(totalBars < OBV_Norm_Period + OBV_SMA_Period + 2)
      return false;

   // Build normalized OBV series for enough bars to compute SMA at bar[1] and bar[2]
   // We need OBV_SMA_Period + 2 normalized values (indices 1..OBV_SMA_Period+1)
   int normCount = OBV_SMA_Period + 2;
   double normOBV[];
   ArrayResize(normOBV, normCount);

   for(int i = 0; i < normCount; i++)
   {
      // bar index in the obvBuffer (which is set as series: [0]=newest)
      int barIdx = i + 1; // start from bar[1] (last closed bar)

      // Find min/max of raw OBV over lookback window ending at barIdx
      double obvMin = obvBuffer[barIdx];
      double obvMax = obvBuffer[barIdx];
      for(int j = barIdx; j < barIdx + OBV_Norm_Period; j++)
      {
         if(obvBuffer[j] < obvMin) obvMin = obvBuffer[j];
         if(obvBuffer[j] > obvMax) obvMax = obvBuffer[j];
      }

      double range = obvMax - obvMin;
      if(range == 0)
         normOBV[i] = 50.0; // No price movement: default to midpoint of 0-100 scale
      else
         normOBV[i] = ((obvBuffer[barIdx] - obvMin) / range) * 100.0;
   }

   // normOBV[0] = bar[1] (current closed), normOBV[1] = bar[2], etc.
   normOBV_current = normOBV[0];
   normOBV_prev = normOBV[1];

   // Calculate SMA of normalized OBV at bar[1] and bar[2]
   double sum1 = 0, sum2 = 0;
   for(int i = 0; i < OBV_SMA_Period; i++)
   {
      sum1 += normOBV[i];       // SMA ending at bar[1]
      sum2 += normOBV[i + 1];   // SMA ending at bar[2]
   }
   normOBV_SMA_current = sum1 / OBV_SMA_Period;
   normOBV_SMA_prev = sum2 / OBV_SMA_Period;

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
//| Buy:  Normalized OBV crosses above its SMA                       |
//|       + Stochastic %K < Oversold (or %K crosses above %D)        |
//|       + Price above EMA200 (or recovery mode active)             |
//| Sell: Normalized OBV crosses below its SMA                       |
//|       + Stochastic %K > Overbought (or %K crosses below %D)      |
//|       + SELL disabled (long-only strategy)                       |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // Check if we have enough stochastic data
   if(ArraySize(stochK) < 3 || ArraySize(stochD) < 3)
      return 0;

   // Normalized OBV crossover detection (bar[1] vs bar[2])
   bool obvBullishCross = (normOBV_current > normOBV_SMA_current && normOBV_prev <= normOBV_SMA_prev);
   bool obvBearishCross = (normOBV_current < normOBV_SMA_current && normOBV_prev >= normOBV_SMA_prev);

   // Stochastic filter (26,3,3)
   // Either condition alone is sufficient for confirmation:
   // Buy: %K in oversold zone (momentum exhaustion) OR %K crosses above %D (bullish turn)
   bool stochBuyOK = (stochK[1] < Stoch_Oversold) ||
                        (stochK[1] > stochD[1] && stochK[2] <= stochD[2]);
   
   // Sell: %K in overbought zone (momentum exhaustion) OR %K crosses below %D (bearish turn)
   bool stochSellOK = (stochK[1] > Stoch_Overbought) ||
                         (stochK[1] < stochD[1] && stochK[2] >= stochD[2]);
   
   // Trend Filter: No trade below EMA200 except for recovery trading
   // BUY trades allowed above EMA200, or below EMA200 if recovery mode is active.
   // SELL trades are never taken (long-only strategy).
   bool uptrend = true;
   bool downtrend = false; // SELL trades permanently disabled
   
   if(TradeOnlyTrend)
   {
      bool aboveEMA200 = (lastTick.bid > trendMA[1]);
      if(aboveEMA200)
      {
         uptrend = true;
      }
      else if(isRecoveryMode)
      {
         // Allow BUY below EMA200 for recovery trading
         uptrend = true;
         if(EnableLogging)
            Print("RECOVERY: Price below EMA200 (", NormalizeDouble(trendMA[1], _Digits),
                  ") but recovery trading allowed.");
      }
      else
      {
         uptrend = false;
         if(EnableLogging)
            Print("FILTER: Price below EMA200 (", NormalizeDouble(trendMA[1], _Digits),
                  "). No trades allowed (recovery not active).");
      }
      downtrend = false;  // SELL trades are never allowed
   }

   // Buy Signal: Normalized OBV crosses above SMA + Stochastic confirms + trend/recovery OK
   if(obvBullishCross && stochBuyOK && uptrend)
   {
      if(EnableLogging)
         Print(isRecoveryMode && lastTick.bid <= trendMA[1] ? "RECOVERY BUY" : "BUY",
               " signal! NormOBV: ", NormalizeDouble(normOBV_current, 2),
               " > SMA: ", NormalizeDouble(normOBV_SMA_current, 2),
               " | Stoch K: ", NormalizeDouble(stochK[1], 2),
               " D: ", NormalizeDouble(stochD[1], 2));
      return 1;
   }

   // Sell Signal: disabled (long-only strategy)
   if(obvBearishCross && stochSellOK && downtrend)
   {
      if(EnableLogging)
         Print("SELL signal! NormOBV: ", NormalizeDouble(normOBV_current, 2),
               " < SMA: ", NormalizeDouble(normOBV_SMA_current, 2),
               " | Stoch K: ", NormalizeDouble(stochK[1], 2),
               " D: ", NormalizeDouble(stochD[1], 2));
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
void OpenBuyPosition(bool recovery = false)
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
   request.comment = recovery ? TradeComment + " RECOVERY BUY" : TradeComment + " BUY";
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
         Print(recovery ? "RECOVERY BUY" : "BUY", " position opened! Ticket: ", result.order,
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
   request.comment = TradeComment + " SELL";
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