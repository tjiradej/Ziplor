//+------------------------------------------------------------------+
//|                                                       Ziplor.mq5 |
//|                                        Copyright 2026, Ziplor    |
//|   EA using Dow Theory multi-timeframe trend detection            |
//|   Anti-martingale position sizing + Hedging recovery             |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Ziplor"
#property link        "https://github.com/tjiradej/Ziplor"
#property version     "1.00"
#property description "Dow Theory multi-timeframe EA with anti-martingale and hedge recovery"

//--- Include files
#include "../Include/SwingDetector.mqh"
#include "../Include/PositionManager.mqh"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES InpTF_High    = PERIOD_H4;    // Higher timeframe (trend)
input ENUM_TIMEFRAMES InpTF_Mid     = PERIOD_H1;    // Middle timeframe (confirmation)
input ENUM_TIMEFRAMES InpTF_Entry   = PERIOD_M15;   // Entry timeframe (timing)

input group "=== Swing Detection ==="
input int             InpSwingStrength = 3;          // Swing strength (bars each side)

input group "=== Trade Settings ==="
input double          InpBaseLot       = 0.01;       // Base lot size
input double          InpMaxLot        = 1.0;        // Maximum lot size
input double          InpSL_ATR_Multi  = 2.0;        // SL ATR multiplier
input double          InpTP_ATR_Multi  = 3.0;        // TP ATR multiplier
input int             InpATR_Period    = 14;          // ATR period
input long            InpMagicNumber   = 202604;     // Magic number
input ulong           InpSlippage      = 10;         // Slippage (points)

input group "=== Anti-Martingale ==="
input double          InpAntiMartMult  = 1.5;        // Lot multiplier on win
input double          InpAntiMartDec   = 0.5;        // Lot reduction on loss

input group "=== Hedge Recovery ==="
input double          InpHedgeDD_Pct   = 5.0;        // Drawdown % to trigger hedge
input bool            InpEnableHedge   = true;        // Enable hedging recovery

//+------------------------------------------------------------------+
//| Global objects                                                   |
//+------------------------------------------------------------------+
CSwingDetector   g_swingHigh;     // Higher timeframe detector
CSwingDetector   g_swingMid;      // Middle timeframe detector
CSwingDetector   g_swingEntry;    // Entry timeframe detector
CPositionManager g_posMgr;        // Position manager

int              g_atrHandle;     // ATR indicator handle
datetime         g_lastBarTime;   // Track new bar on entry TF
int              g_lastDealCount; // Track closed deals for profit tracking

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize swing detectors for each timeframe
   g_swingHigh.Init(_Symbol, InpTF_High, InpSwingStrength);
   g_swingMid.Init(_Symbol, InpTF_Mid, InpSwingStrength);
   g_swingEntry.Init(_Symbol, InpTF_Entry, InpSwingStrength);

   // Initialize position manager
   g_posMgr.Init(_Symbol, InpMagicNumber, InpBaseLot, InpMaxLot,
                  InpAntiMartMult, InpAntiMartDec, InpHedgeDD_Pct, InpSlippage);

   // Create ATR handle on entry timeframe for SL/TP calculation
   g_atrHandle = iATR(_Symbol, InpTF_Entry, InpATR_Period);
   if(g_atrHandle == INVALID_HANDLE)
   {
      PrintFormat("Ziplor: Failed to create ATR indicator. Error %d", GetLastError());
      return INIT_FAILED;
   }

   g_lastBarTime  = 0;
   g_lastDealCount = 0;

   // Count existing closed deals at startup
   HistorySelect(0, TimeCurrent());
   g_lastDealCount = HistoryDealsTotal();

   PrintFormat("Ziplor EA initialized. TFs: %s/%s/%s | BaseLot: %.2f | HedgeDD: %.1f%%",
               EnumToString(InpTF_High), EnumToString(InpTF_Mid),
               EnumToString(InpTF_Entry), InpBaseLot, InpHedgeDD_Pct);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   PrintFormat("Ziplor EA deinitialized. Reason: %d", reason);
}

//+------------------------------------------------------------------+
//| Check for newly closed deals and update anti-martingale          |
//+------------------------------------------------------------------+
void CheckClosedDeals()
{
   HistorySelect(0, TimeCurrent());
   int totalDeals = HistoryDealsTotal();

   if(totalDeals <= g_lastDealCount)
      return;

   // Process new deals
   for(int i = g_lastDealCount; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Only process our magic number deals that are exits
      long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(magic == InpMagicNumber && entry == DEAL_ENTRY_OUT)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         g_posMgr.UpdateAfterClose(profit);

         PrintFormat("Ziplor: Deal closed. Profit=%.2f | ConsWins=%d | ConsLosses=%d | NextLot=%.2f",
                     profit, g_posMgr.GetConsecutiveWins(),
                     g_posMgr.GetConsecutiveLosses(), g_posMgr.GetNextLotSize());
      }
   }

   g_lastDealCount = totalDeals;
}

//+------------------------------------------------------------------+
//| Check if a new bar has formed on the entry timeframe             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime barTime[];
   if(CopyTime(_Symbol, InpTF_Entry, 0, 1, barTime) != 1)
      return false;

   if(barTime[0] != g_lastBarTime)
   {
      g_lastBarTime = barTime[0];
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get ATR value for SL/TP calculation                              |
//+------------------------------------------------------------------+
double GetATR()
{
   double atr[];
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atr) != 1)
      return 0;
   return atr[0];
}

//+------------------------------------------------------------------+
//| Determine multi-timeframe trend alignment                        |
//|                                                                  |
//| Returns: 1 = all bullish, -1 = all bearish, 0 = no alignment    |
//+------------------------------------------------------------------+
int GetMultiTimeframeTrend()
{
   ENUM_DOW_TREND trendHigh  = g_swingHigh.DetermineTrend();
   ENUM_DOW_TREND trendMid   = g_swingMid.DetermineTrend();
   ENUM_DOW_TREND trendEntry = g_swingEntry.DetermineTrend();

   // All three timeframes must agree for a strong signal
   if(trendHigh == DOW_TREND_UP && trendMid == DOW_TREND_UP && trendEntry == DOW_TREND_UP)
      return 1;   // Bullish alignment

   if(trendHigh == DOW_TREND_DOWN && trendMid == DOW_TREND_DOWN && trendEntry == DOW_TREND_DOWN)
      return -1;  // Bearish alignment

   return 0;      // No alignment
}

//+------------------------------------------------------------------+
//| Check for entry signal near swing level on entry TF              |
//| Price must be pulling back toward a swing level                  |
//+------------------------------------------------------------------+
bool CheckEntryTiming(int direction)
{
   SwingPoint lows[];
   SwingPoint highs[];
   double close[];

   if(CopyClose(_Symbol, InpTF_Entry, 0, 1, close) != 1)
      return false;

   double atr = GetATR();
   if(atr <= 0) return false;

   if(direction == 1)  // Looking for buy entry near a higher low
   {
      if(!g_swingEntry.FindSwingLows(lows, 2))
         return false;

      // Price should be near the most recent swing low (within 1 ATR)
      double recentLow = lows[0].price;
      if(close[0] <= recentLow + atr && close[0] >= recentLow - atr * 0.5)
         return true;
   }
   else if(direction == -1)  // Looking for sell entry near a lower high
   {
      if(!g_swingEntry.FindSwingHighs(highs, 2))
         return false;

      // Price should be near the most recent swing high (within 1 ATR)
      double recentHigh = highs[0].price;
      if(close[0] >= recentHigh - atr && close[0] <= recentHigh + atr * 0.5)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Check for closed deals (anti-martingale tracking) ---
   CheckClosedDeals();

   // --- Hedge recovery management ---
   if(InpEnableHedge)
   {
      g_posMgr.CheckAndHedge();
      g_posMgr.CloseHedgeIfRecovered();
   }

   // --- Only trade on new bars of the entry timeframe ---
   if(!IsNewBar())
      return;

   // --- Skip if we already have a position ---
   if(g_posMgr.HasOpenPosition())
      return;

   // --- Multi-timeframe trend analysis ---
   int trend = GetMultiTimeframeTrend();
   if(trend == 0)
      return;  // No aligned trend

   // --- Check entry timing on the entry timeframe ---
   if(!CheckEntryTiming(trend))
      return;

   // --- Calculate SL/TP using ATR ---
   double atr = GetATR();
   if(atr <= 0) return;

   double sl = 0, tp = 0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(trend == 1)  // Buy
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(ask - atr * InpSL_ATR_Multi, digits);
      tp = NormalizeDouble(ask + atr * InpTP_ATR_Multi, digits);

      if(g_posMgr.OpenPosition(POSITION_TYPE_BUY, sl, tp))
         PrintFormat("Ziplor: BUY opened at %.5f | SL=%.5f | TP=%.5f | Lot=%.2f",
                     ask, sl, tp, g_posMgr.GetCurrentLot());
   }
   else if(trend == -1)  // Sell
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(bid + atr * InpSL_ATR_Multi, digits);
      tp = NormalizeDouble(bid - atr * InpTP_ATR_Multi, digits);

      if(g_posMgr.OpenPosition(POSITION_TYPE_SELL, sl, tp))
         PrintFormat("Ziplor: SELL opened at %.5f | SL=%.5f | TP=%.5f | Lot=%.2f",
                     bid, sl, tp, g_posMgr.GetCurrentLot());
   }
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Additional logging for trade events
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      PrintFormat("Ziplor: Trade transaction - Deal #%d added", trans.deal);
   }
}
//+------------------------------------------------------------------+
