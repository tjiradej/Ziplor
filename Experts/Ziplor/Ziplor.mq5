//+------------------------------------------------------------------+
//|                                                      Ziplor.mq5  |
//|                        Copyright 2026, Ziplor Project            |
//|                        https://github.com/tjiradej/Ziplor       |
//+------------------------------------------------------------------+
//| Multi-Timeframe SMC/ICT Expert Advisor                           |
//| Features:                                                        |
//|   - Smart Money Concepts (Order Blocks, FVG, BOS, CHoCH)        |
//|   - ICT Methodology (Killzones, OTE, Liquidity, AMD)            |
//|   - Anti-Martingale Position Sizing                              |
//|   - Pyramid Order Management                                     |
//|   - Recovery Mode                                                |
//|   - On-Chart Dashboard                                           |
//|   - Executes on M1 timeframe                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor Project"
#property link      "https://github.com/tjiradej/Ziplor"
#property version   "1.00"
#property description "Ziplor - Multi-Timeframe SMC/ICT EA with Anti-Martingale & Pyramid Ordering"
#property strict

//--- Include files
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Ziplor/ZiplorEnums.mqh>
#include <Ziplor/ZiplorStructures.mqh>
#include <Ziplor/ZiplorSMCEngine.mqh>
#include <Ziplor/ZiplorDashboard.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

//--- General Settings
input string           InpGeneral          = "=== GENERAL SETTINGS ===";       // ----
input ulong            InpMagicNumber      = 2026040301;                        // Magic Number
input string           InpTradeComment     = "Ziplor_v1";                       // Trade Comment
input int              InpMaxSpreadPoints  = 30;                                // Max Spread (points)
input bool             InpTradeEnabled     = true;                              // Enable Trading

//--- Timeframe Settings
input string           InpTimeframes       = "=== TIMEFRAME SETTINGS ===";     // ----
input ENUM_TIMEFRAMES  InpHTF              = PERIOD_H4;                         // Higher Timeframe (HTF)
input ENUM_TIMEFRAMES  InpMTF              = PERIOD_H1;                         // Mid Timeframe (MTF)
input ENUM_TIMEFRAMES  InpLTF              = PERIOD_M15;                        // Lower Timeframe (LTF)
// Execution TF is always M1

//--- SMC/ICT Settings
input string           InpSMC              = "=== SMC / ICT SETTINGS ===";     // ----
input int              InpSwingLookback    = 5;                                 // Swing Point Lookback Bars
input int              InpStructureLookback = 100;                              // Structure Analysis Lookback
input int              InpMaxZones         = 20;                                // Max Zones to Track
input int              InpMinConfluence    = 4;                                 // Minimum Confluences for Signal
input double           InpMinRiskReward    = 2.0;                               // Minimum Risk:Reward Ratio

//--- Session / Killzone Settings (in broker server time)
input string           InpSessions         = "=== SESSION SETTINGS ===";       // ----
input int              InpServerGMTOffset  = 2;                                 // Server GMT Offset (hours)
input bool             InpTradeAsian       = false;                             // Trade During Asian Session
input bool             InpTradeLondon      = true;                              // Trade During London Killzone
input bool             InpTradeNY          = true;                              // Trade During NY Killzone
input bool             InpTradeLdnClose    = false;                             // Trade During London Close
input bool             InpTradeSilverBullet = true;                             // Trade During Silver Bullet

//--- Position Sizing / Anti-Martingale
input string           InpSizing           = "=== ANTI-MARTINGALE SIZING ==="; // ----
input double           InpBaseRiskPct      = 1.0;                               // Base Risk % per Trade
input double           InpMaxRiskPct       = 3.0;                               // Maximum Risk % Cap
input double           InpRiskIncrement    = 0.25;                              // Risk Increment per Win
input double           InpMinLotSize       = 0.01;                              // Minimum Lot Size
input double           InpMaxLotSize       = 10.0;                              // Maximum Lot Size

//--- Pyramid Settings
input string           InpPyramid          = "=== PYRAMID SETTINGS ===";       // ----
input bool             InpEnablePyramid    = true;                              // Enable Pyramid Orders
input int              InpMaxPyramidLevels = 3;                                 // Max Pyramid Add-on Levels
input double           InpPyramidSizeMult  = 0.5;                              // Pyramid Size Multiplier (each add)
input bool             InpTrailOnPyramid   = true;                              // Trail SL on Pyramid Add

//--- Recovery Mode Settings
input string           InpRecovery         = "=== RECOVERY MODE ===";          // ----
input bool             InpEnableRecovery   = true;                              // Enable Recovery Mode
input double           InpRecoveryThreshold = 3.0;                             // Recovery Trigger (% drawdown)
input int              InpMaxRecoveryTrades = 5;                                // Max Recovery Trades
input double           InpRecoveryRiskMult = 1.5;                               // Recovery Risk Multiplier
input int              InpRecoveryTimeoutDays = 7;                              // Recovery Timeout (days)
input int              InpPositionTimeoutHours = 48;                            // Position Timeout (hours)

//--- Dashboard Settings
input string           InpDashboard        = "=== DASHBOARD ===";             // ----
input bool             InpShowDashboard    = true;                              // Show Dashboard
input int              InpDashX            = 20;                                // Dashboard X Position
input int              InpDashY            = 30;                                // Dashboard Y Position
input int              InpDashWidth        = 330;                               // Dashboard Width

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CSMCEngine        g_smc;                      // SMC/ICT analysis engine
CDashboard        g_dashboard;                // Dashboard panel
CTrade            g_trade;                    // Trade execution
CPositionInfo     g_position;                 // Position info
CAccountInfo      g_account;                  // Account info
CSymbolInfo       g_symbol_info;              // Symbol info

//--- Market structure per timeframe
MarketStructure   g_htf_structure;            // Higher TF structure
MarketStructure   g_mtf_structure;            // Mid TF structure
MarketStructure   g_ltf_structure;            // Lower TF structure
MarketStructure   g_exec_structure;           // Execution TF (M1) structure

//--- Current signal
TradeSignal       g_current_signal;           // Active trade signal

//--- Anti-martingale state
AntiMartingaleState g_am_state;               // Anti-martingale tracker

//--- Pyramid entries
PyramidEntry      g_pyramids[];               // Active pyramid entries
int               g_pyramid_count = 0;        // Current pyramid level count

//--- Recovery mode
RecoveryModeState g_recovery;                 // Recovery state

//--- Session tracking
ENUM_SESSION_TYPE g_current_session = SESSION_NONE;

//--- Daily tracking
double            g_daily_start_balance = 0;
double            g_weekly_start_balance = 0;
datetime          g_last_daily_reset = 0;
datetime          g_last_weekly_reset = 0;
datetime          g_last_bar_time = 0;         // For new bar detection on M1

//--- Statistics
double            g_total_profit = 0;
double            g_total_loss = 0;
int               g_stat_total_trades = 0;
int               g_stat_wins = 0;
int               g_stat_losses = 0;
double            g_sum_rr = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Validate execution timeframe
   if(Period() != PERIOD_M1)
     {
      Print("WARNING: Ziplor EA is designed to run on M1 timeframe. Current: ", EnumToString(Period()));
      Print("Attaching to M1 for execution. Multi-TF analysis will use configured timeframes.");
     }

   //--- Validate timeframe hierarchy
   if(PeriodSeconds(InpHTF) <= PeriodSeconds(InpMTF) ||
      PeriodSeconds(InpMTF) <= PeriodSeconds(InpLTF) ||
      PeriodSeconds(InpLTF) <= PeriodSeconds(PERIOD_M1))
     {
      Print("ERROR: Timeframes must be in descending order: HTF > MTF > LTF > M1");
      return INIT_PARAMETERS_INCORRECT;
     }

   //--- Validate risk parameters
   if(InpBaseRiskPct <= 0 || InpBaseRiskPct > InpMaxRiskPct)
     {
      Print("ERROR: Base risk must be > 0 and <= max risk");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMaxRiskPct > 10.0)
     {
      Print("ERROR: Maximum risk cannot exceed 10%");
      return INIT_PARAMETERS_INCORRECT;
     }

   //--- Initialize symbol info
   if(!g_symbol_info.Name(_Symbol))
     {
      Print("ERROR: Failed to initialize symbol info for ", _Symbol);
      return INIT_FAILED;
     }

   //--- Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.SetMarginMode();

   //--- Initialize SMC engine
   if(!g_smc.Init(_Symbol, InpSwingLookback, InpStructureLookback, InpMaxZones))
     {
      Print("ERROR: Failed to initialize SMC engine");
      return INIT_FAILED;
     }

   //--- Initialize dashboard
   if(InpShowDashboard)
      g_dashboard.Init(InpDashX, InpDashY, InpDashWidth);

   //--- Initialize anti-martingale state
   g_am_state.streak_type = STREAK_NONE;
   g_am_state.consecutive_wins = 0;
   g_am_state.consecutive_losses = 0;
   g_am_state.current_risk_pct = InpBaseRiskPct;
   g_am_state.base_risk_pct = InpBaseRiskPct;
   g_am_state.max_risk_pct = InpMaxRiskPct;
   g_am_state.risk_increment = InpRiskIncrement;
   g_am_state.total_trades = 0;
   g_am_state.total_wins = 0;
   g_am_state.total_losses = 0;

   //--- Initialize current signal to safe defaults
   g_current_signal.direction = BIAS_NONE;
   g_current_signal.quality = SIGNAL_NONE;
   g_current_signal.entry_price = 0;
   g_current_signal.stop_loss = 0;
   g_current_signal.take_profit = 0;
   g_current_signal.risk_reward = 0;
   g_current_signal.reason = "";
   g_current_signal.signal_time = 0;
   g_current_signal.valid = false;
   g_current_signal.confluence_count = 0;

   //--- Initialize pyramid array
   ArrayResize(g_pyramids, InpMaxPyramidLevels + 1);
   for(int i = 0; i <= InpMaxPyramidLevels; i++)
     {
      g_pyramids[i].ticket = 0;
      g_pyramids[i].level = PYRAMID_BASE;
      g_pyramids[i].lot_size = 0;
      g_pyramids[i].entry_price = 0;
      g_pyramids[i].stop_loss = 0;
      g_pyramids[i].entry_time = 0;
      g_pyramids[i].active = false;
     }
   g_pyramid_count = 0;

   //--- Initialize recovery state
   g_recovery.state = RECOVERY_OFF;
   g_recovery.loss_to_recover = 0;
   g_recovery.recovered = 0;
   g_recovery.recovery_trades = 0;
   g_recovery.max_recovery_trades = InpMaxRecoveryTrades;
   g_recovery.original_risk_pct = InpBaseRiskPct;
   g_recovery.recovery_start = 0;

   //--- Initialize daily/weekly tracking
   g_daily_start_balance = g_account.Balance();
   g_weekly_start_balance = g_account.Balance();
   g_last_daily_reset = TimeCurrent();
   g_last_weekly_reset = TimeCurrent();

   //--- Initialize last bar time to prevent false signal on first tick
   g_last_bar_time = iTime(_Symbol, PERIOD_M1, 0);

   //--- Timer for dashboard updates (every second)
   if(InpShowDashboard)
      EventSetTimer(1);

   Print("Ziplor EA v1.0 initialized successfully on ", _Symbol);
   Print("Timeframes: HTF=", EnumToString(InpHTF), " MTF=", EnumToString(InpMTF),
         " LTF=", EnumToString(InpLTF), " Exec=M1");
   Print("Risk: Base=", InpBaseRiskPct, "% Max=", InpMaxRiskPct, "% Increment=", InpRiskIncrement, "%");

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(InpShowDashboard)
      g_dashboard.Destroy();
   Print("Ziplor EA deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Check if trading is enabled
   if(!InpTradeEnabled)
      return;

   //--- Update symbol info
   g_symbol_info.RefreshRates();

   //--- Check for new M1 bar
   datetime current_bar_time = iTime(_Symbol, PERIOD_M1, 0);
   if(current_bar_time == g_last_bar_time)
      return; // No new bar, skip processing
   g_last_bar_time = current_bar_time;

   //--- Daily/weekly P&L reset check
   CheckDailyWeeklyReset();

   //--- Determine current session/killzone
   g_current_session = DetectSession();

   //--- Multi-timeframe structure analysis
   g_htf_structure = g_smc.AnalyzeStructure(InpHTF);
   g_mtf_structure = g_smc.AnalyzeStructure(InpMTF);
   g_ltf_structure = g_smc.AnalyzeStructure(InpLTF);
   g_exec_structure = g_smc.AnalyzeStructure(PERIOD_M1);

   //--- Find zones on LTF (most relevant for entry)
   g_smc.FindZones(InpLTF);
   g_smc.FindLiquidityPools(InpLTF);

   //--- Always manage existing positions (trail SL, pyramids) regardless of spread
   ManageOpenPositions();

   //--- Evaluate new trade signal (needed before recovery check)
   g_current_signal = g_smc.EvaluateSignal(g_htf_structure, g_mtf_structure,
                                             g_ltf_structure, g_exec_structure,
                                             g_current_session);

   //--- Always check recovery mode (uses current signal)
   CheckRecoveryMode();

   //--- Check spread - only block NEW entries, not position management
   double spread_points = g_symbol_info.Spread();
   if(spread_points > InpMaxSpreadPoints)
      return; // Spread too wide for new entries

   //--- Check if market is open for trading
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
      return;

   //--- Execute trade if signal is valid and no base position exists
   if(g_current_signal.valid && g_current_signal.quality >= SIGNAL_LOW)
     {
      //--- Check if session is allowed
      if(IsSessionAllowed(g_current_session))
        {
         //--- Check if we already have an open position in this direction
         if(!HasOpenPosition(g_current_signal.direction))
           {
            ExecuteBaseEntry(g_current_signal);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Timer function - update dashboard                                |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!InpShowDashboard)
      return;

   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| Trade transaction handler - track closed trades for AM           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   //--- Track deal completion for anti-martingale
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      ulong deal_ticket = trans.deal;
      if(deal_ticket == 0) return;

      //--- Check if this deal belongs to our EA
      if(HistoryDealSelect(deal_ticket))
        {
         ulong deal_magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
         if(deal_magic != InpMagicNumber) return;

         ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
           {
            double deal_profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            double deal_commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double deal_swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            double net_profit = deal_profit + deal_commission + deal_swap;

            //--- Update anti-martingale
            UpdateAntiMartingale(net_profit);

            //--- Update recovery mode
            UpdateRecoveryOnClose(net_profit);

            //--- Update statistics
            g_stat_total_trades++;
            if(net_profit >= 0)
              {
               g_stat_wins++;
               g_total_profit += net_profit;
              }
            else
              {
               g_stat_losses++;
               g_total_loss += MathAbs(net_profit);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Detect current ICT session / killzone                            |
//+------------------------------------------------------------------+
ENUM_SESSION_TYPE DetectSession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   //--- Convert server time to EST (New York)
   //--- EST = GMT - 5, so we need to go from server time to GMT first, then to EST
   int est_hour = dt.hour - InpServerGMTOffset - 5;
   if(est_hour < 0) est_hour += 24;
   if(est_hour >= 24) est_hour -= 24;
   int est_min = dt.min;

   //--- Silver Bullet windows (10:00-11:00 EST and 14:00-15:00 EST)
   if(est_hour == 10)
      return SESSION_SILVER_AM;
   if(est_hour == 14)
      return SESSION_SILVER_PM;

   //--- Asian session: 19:00-02:00 EST
   if(est_hour >= 19 || est_hour < 2)
      return SESSION_ASIAN;

   //--- London Killzone: 02:00-05:00 EST
   if(est_hour >= 2 && est_hour < 5)
      return SESSION_LONDON;

   //--- New York Killzone: 07:00-10:00 EST
   if(est_hour >= 7 && est_hour < 10)
      return SESSION_NY;

   //--- London Close: 10:00-12:00 EST (already handled silver bullet at 10)
   if(est_hour >= 11 && est_hour < 12)
      return SESSION_LONDON_CLOSE;

   return SESSION_NONE;
  }

//+------------------------------------------------------------------+
//| Check if session is allowed for trading                          |
//+------------------------------------------------------------------+
bool IsSessionAllowed(ENUM_SESSION_TYPE session)
  {
   switch(session)
     {
      case SESSION_ASIAN:        return InpTradeAsian;
      case SESSION_LONDON:       return InpTradeLondon;
      case SESSION_NY:           return InpTradeNY;
      case SESSION_LONDON_CLOSE: return InpTradeLdnClose;
      case SESSION_SILVER_AM:    return InpTradeSilverBullet;
      case SESSION_SILVER_PM:    return InpTradeSilverBullet;
      default:                   return false;
     }
  }

//+------------------------------------------------------------------+
//| Check if we have an open position in given direction             |
//+------------------------------------------------------------------+
bool HasOpenPosition(ENUM_MARKET_BIAS direction)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
           {
            if(direction == BIAS_BULLISH && g_position.PositionType() == POSITION_TYPE_BUY)
               return true;
            if(direction == BIAS_BEARISH && g_position.PositionType() == POSITION_TYPE_SELL)
               return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
            count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Calculate lot size using anti-martingale risk                    |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry_price, double stop_loss)
  {
   double risk_pct = g_am_state.current_risk_pct;

   //--- Adjust for recovery mode
   if(g_recovery.state == RECOVERY_ACTIVE)
      risk_pct = MathMin(risk_pct * InpRecoveryRiskMult, g_am_state.max_risk_pct);

   double account_equity = g_account.Equity();
   double risk_amount = account_equity * risk_pct / 100.0;

   double sl_distance = MathAbs(entry_price - stop_loss);
   double point = g_symbol_info.Point();
   double min_sl_distance = point * 10; // Minimum 10 points SL distance
   if(sl_distance < min_sl_distance)
     {
      Print("WARNING: SL distance too small: ", sl_distance, " min=", min_sl_distance);
      return InpMinLotSize;
     }

   double tick_value = g_symbol_info.TickValue();
   double tick_size = g_symbol_info.TickSize();
   if(tick_value <= 0 || tick_size <= 0)
     {
      Print("ERROR: Invalid tick value=", tick_value, " or tick size=", tick_size, " for ", _Symbol);
      return InpMinLotSize;
     }

   double lot_size = risk_amount / (sl_distance / tick_size * tick_value);

   //--- Normalize lot size
   double lot_step = g_symbol_info.LotsStep();
   double min_lot = g_symbol_info.LotsMin();
   double max_lot = g_symbol_info.LotsMax();

   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   lot_size = MathMax(lot_size, MathMax(min_lot, InpMinLotSize));
   lot_size = MathMin(lot_size, MathMin(max_lot, InpMaxLotSize));

   return NormalizeDouble(lot_size, 2);
  }

//+------------------------------------------------------------------+
//| Execute base entry from signal                                   |
//+------------------------------------------------------------------+
void ExecuteBaseEntry(const TradeSignal &signal)
  {
   g_symbol_info.RefreshRates();
   double lot_size = CalculateLotSize(signal.entry_price, signal.stop_loss);

   //--- Validate lot size
   if(lot_size < g_symbol_info.LotsMin())
     {
      Print("Lot size too small: ", lot_size);
      return;
     }

   //--- Validate margin
   double margin_required;
   ENUM_ORDER_TYPE order_type = (signal.direction == BIAS_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(order_type, _Symbol, lot_size,
                       (signal.direction == BIAS_BULLISH) ? g_symbol_info.Ask() : g_symbol_info.Bid(),
                       margin_required))
     {
      Print("Failed to calculate margin requirement");
      return;
     }
   if(margin_required > g_account.FreeMargin() * 0.5) // Keep 50% margin buffer for safety
     {
      Print("Insufficient margin. Required: ", margin_required, " Free: ", g_account.FreeMargin());
      return;
     }

   //--- Normalize SL/TP
   double sl = NormalizeDouble(signal.stop_loss, _Digits);
   double tp = NormalizeDouble(signal.take_profit, _Digits);

   bool result = false;
   if(signal.direction == BIAS_BULLISH)
     {
      double ask = g_symbol_info.Ask();
      result = g_trade.Buy(lot_size, _Symbol, ask, sl, tp, InpTradeComment);
     }
   else if(signal.direction == BIAS_BEARISH)
     {
      double bid = g_symbol_info.Bid();
      result = g_trade.Sell(lot_size, _Symbol, bid, sl, tp, InpTradeComment);
     }

   if(result)
     {
      ulong ticket = g_trade.ResultOrder();
      Print("BASE ENTRY: ", (signal.direction == BIAS_BULLISH ? "BUY" : "SELL"),
            " Lots=", lot_size, " Ticket=", ticket,
            " Quality=", EnumToString(signal.quality),
            " Confluences=", signal.confluence_count,
            " RR=1:", DoubleToString(signal.risk_reward, 1),
            " Risk%=", DoubleToString(g_am_state.current_risk_pct, 2));
      //--- Record pyramid base entry
      g_pyramid_count = 0;
      g_pyramids[0].ticket = ticket;
      g_pyramids[0].level = PYRAMID_BASE;
      g_pyramids[0].lot_size = lot_size;
      g_pyramids[0].entry_price = (signal.direction == BIAS_BULLISH) ? g_symbol_info.Ask() : g_symbol_info.Bid();
      g_pyramids[0].stop_loss = sl;
      g_pyramids[0].entry_time = TimeCurrent();
      g_pyramids[0].active = true;
      g_pyramid_count = 1;
     }
   else
     {
      Print("Trade execution failed: ", g_trade.ResultRetcodeDescription());
     }
  }

//+------------------------------------------------------------------+
//| Manage open positions: pyramid adds, trail SL                    |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   //--- Skip if no positions
   if(CountOpenPositions() == 0)
     {
      g_pyramid_count = 0;
      return;
     }

   //--- Check for stale positions (open > 24 hours without progress)
   CheckPositionTimeout();

   //--- Check for pyramid opportunities
   if(InpEnablePyramid && g_pyramid_count > 0 && g_pyramid_count <= InpMaxPyramidLevels)
     {
      CheckPyramidAdd();
     }

   //--- Trail stop loss if pyramid entries added
   if(InpTrailOnPyramid && g_pyramid_count > 1)
     {
      TrailStopLoss();
     }
  }

//+------------------------------------------------------------------+
//| Check for position timeout - close stale positions               |
//+------------------------------------------------------------------+
void CheckPositionTimeout()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_position.SelectByIndex(i))
         continue;
      if(g_position.Symbol() != _Symbol || g_position.Magic() != InpMagicNumber)
         continue;

      datetime entry_time = (datetime)g_position.Time();
      long seconds_open = (long)(TimeCurrent() - entry_time);

      //--- Close positions open longer than configured timeout
      if(seconds_open > InpPositionTimeoutHours * 3600)
        {
         Print("TIMEOUT: Closing position Ticket=", g_position.Ticket(),
               " open for ", seconds_open / 3600, " hours");
         g_trade.PositionClose(g_position.Ticket());
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if conditions are met for a pyramid add                    |
//+------------------------------------------------------------------+
void CheckPyramidAdd()
  {
   //--- Only add if execution structure confirms continuation
   if(g_exec_structure.last_break != BREAK_BOS)
      return;

   //--- Determine direction from first pyramid entry
   bool is_buy = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
           {
            is_buy = (g_position.PositionType() == POSITION_TYPE_BUY);
            break;
           }
        }
     }

   //--- Verify structure alignment for add
   if(is_buy && g_exec_structure.bias != BIAS_BULLISH)
      return;
   if(!is_buy && g_exec_structure.bias != BIAS_BEARISH)
      return;

   //--- Check that LTF also confirms
   if(is_buy && g_ltf_structure.bias != BIAS_BULLISH)
      return;
   if(!is_buy && g_ltf_structure.bias != BIAS_BEARISH)
      return;

   //--- Check that price is in a valid zone for the add
   double bid = g_symbol_info.Bid();
   double ask = g_symbol_info.Ask();
   bool in_zone = false;

   SDZone demand_zones[], supply_zones[];
   if(is_buy)
     {
      int dz_count = g_smc.GetDemandZones(demand_zones);
      for(int i = 0; i < dz_count; i++)
        {
         if(demand_zones[i].valid && !demand_zones[i].mitigated &&
            bid >= demand_zones[i].lower && bid <= demand_zones[i].upper)
           {
            in_zone = true;
            break;
           }
        }
     }
   else
     {
      int sz_count = g_smc.GetSupplyZones(supply_zones);
      for(int i = 0; i < sz_count; i++)
        {
         if(supply_zones[i].valid && !supply_zones[i].mitigated &&
            bid >= supply_zones[i].lower && bid <= supply_zones[i].upper)
           {
            in_zone = true;
            break;
           }
        }
     }

   if(!in_zone)
      return;

   //--- Check profit condition: existing position must be in profit
   double total_profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
            total_profit += g_position.Profit() + g_position.Swap() + g_position.Commission();
        }
     }
   if(total_profit <= 0)
      return;

   //--- Calculate pyramid lot size (decreasing)
   double base_lot = g_pyramids[0].lot_size;
   double pyramid_lot = base_lot * MathPow(InpPyramidSizeMult, g_pyramid_count);
   double lot_step = g_symbol_info.LotsStep();
   pyramid_lot = MathFloor(pyramid_lot / lot_step) * lot_step;
   pyramid_lot = MathMax(pyramid_lot, g_symbol_info.LotsMin());
   pyramid_lot = MathMin(pyramid_lot, g_symbol_info.LotsMax());

   //--- Use base position's TP, set SL at previous entry level
   double tp = 0;
   double sl = 0;
   if(g_pyramid_count > 0 && g_pyramids[g_pyramid_count - 1].active)
     {
      sl = g_pyramids[g_pyramid_count - 1].entry_price;
     }

   //--- Get TP from the base position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
           {
            tp = g_position.TakeProfit();
            break;
           }
        }
     }

   //--- Execute pyramid add
   bool result = false;
   if(is_buy)
      result = g_trade.Buy(pyramid_lot, _Symbol, ask, NormalizeDouble(sl, _Digits),
                            NormalizeDouble(tp, _Digits), InpTradeComment + "_PYR" + IntegerToString(g_pyramid_count));
   else
      result = g_trade.Sell(pyramid_lot, _Symbol, bid, NormalizeDouble(sl, _Digits),
                             NormalizeDouble(tp, _Digits), InpTradeComment + "_PYR" + IntegerToString(g_pyramid_count));

   if(result)
     {
      ulong ticket = g_trade.ResultOrder();
      g_pyramids[g_pyramid_count].ticket = ticket;
      g_pyramids[g_pyramid_count].level = (ENUM_PYRAMID_LEVEL)g_pyramid_count;
      g_pyramids[g_pyramid_count].lot_size = pyramid_lot;
      g_pyramids[g_pyramid_count].entry_price = is_buy ? ask : bid;
      g_pyramids[g_pyramid_count].stop_loss = sl;
      g_pyramids[g_pyramid_count].entry_time = TimeCurrent();
      g_pyramids[g_pyramid_count].active = true;
      g_pyramid_count++;

      Print("PYRAMID ADD #", g_pyramid_count - 1, ": ", (is_buy ? "BUY" : "SELL"),
            " Lots=", pyramid_lot, " Ticket=", ticket);
     }
  }

//+------------------------------------------------------------------+
//| Trail stop loss for all positions to recent structure            |
//+------------------------------------------------------------------+
void TrailStopLoss()
  {
   //--- Use LTF swing structure for trailing
   if(!g_ltf_structure.valid)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!g_position.SelectByIndex(i))
         continue;
      if(g_position.Symbol() != _Symbol || g_position.Magic() != InpMagicNumber)
         continue;

      double current_sl = g_position.StopLoss();
      double new_sl = 0;
      double point = g_symbol_info.Point();
      double spread = g_symbol_info.Spread() * point;

      if(g_position.PositionType() == POSITION_TYPE_BUY)
        {
         //--- Trail SL to last LTF swing low (with buffer)
         new_sl = g_ltf_structure.last_swing_low.price - spread - point * 3;
         new_sl = NormalizeDouble(new_sl, _Digits);

         //--- Only move SL up, never down
         if(new_sl > current_sl && new_sl < g_symbol_info.Bid())
           {
            g_trade.PositionModify(g_position.Ticket(), new_sl, g_position.TakeProfit());
           }
        }
      else if(g_position.PositionType() == POSITION_TYPE_SELL)
        {
         //--- Trail SL to last LTF swing high (with buffer)
         new_sl = g_ltf_structure.last_swing_high.price + spread + point * 3;
         new_sl = NormalizeDouble(new_sl, _Digits);

         //--- Only move SL down, never up
         if((new_sl < current_sl || current_sl == 0) && new_sl > g_symbol_info.Ask())
           {
            g_trade.PositionModify(g_position.Ticket(), new_sl, g_position.TakeProfit());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Update anti-martingale state after a trade closes                |
//+------------------------------------------------------------------+
void UpdateAntiMartingale(double net_profit)
  {
   g_am_state.total_trades++;

   if(net_profit >= 0)
     {
      g_am_state.total_wins++;

      //--- Win: increment risk
      if(g_am_state.streak_type == STREAK_WINNING)
        {
         g_am_state.consecutive_wins++;
        }
      else
        {
         g_am_state.streak_type = STREAK_WINNING;
         g_am_state.consecutive_wins = 1;
         g_am_state.consecutive_losses = 0;
        }

      //--- Increase risk per consecutive win
      g_am_state.current_risk_pct = g_am_state.base_risk_pct +
                                     g_am_state.risk_increment * g_am_state.consecutive_wins;

      //--- Cap at max risk
      g_am_state.current_risk_pct = MathMin(g_am_state.current_risk_pct, g_am_state.max_risk_pct);
     }
   else
     {
      g_am_state.total_losses++;

      //--- Loss: reset to base risk
      if(g_am_state.streak_type == STREAK_LOSING)
        {
         g_am_state.consecutive_losses++;
        }
      else
        {
         g_am_state.streak_type = STREAK_LOSING;
         g_am_state.consecutive_losses = 1;
         g_am_state.consecutive_wins = 0;
        }

      //--- Reset risk to base on loss
      g_am_state.current_risk_pct = g_am_state.base_risk_pct;
     }

   Print("Anti-Martingale: ", (net_profit >= 0 ? "WIN" : "LOSS"),
         " Streak=", (g_am_state.streak_type == STREAK_WINNING ?
                      IntegerToString(g_am_state.consecutive_wins) + "W" :
                      IntegerToString(g_am_state.consecutive_losses) + "L"),
         " Risk=", DoubleToString(g_am_state.current_risk_pct, 2), "%");
  }

//+------------------------------------------------------------------+
//| Check and manage recovery mode                                   |
//+------------------------------------------------------------------+
void CheckRecoveryMode()
  {
   if(!InpEnableRecovery)
      return;

   double equity = g_account.Equity();
   double balance = g_account.Balance();

   long recovery_timeout_sec = InpRecoveryTimeoutDays * 24 * 3600;

   if(g_recovery.state == RECOVERY_OFF)
     {
      //--- Check if drawdown threshold exceeded
      if(balance > 0)
        {
         double drawdown_pct = (balance - equity) / balance * 100.0;
         if(drawdown_pct >= InpRecoveryThreshold && CountOpenPositions() == 0)
           {
            g_recovery.state = RECOVERY_WATCHING;
            g_recovery.loss_to_recover = balance - equity;
            g_recovery.recovered = 0;
            g_recovery.recovery_trades = 0;
            g_recovery.original_risk_pct = g_am_state.current_risk_pct;
            g_recovery.recovery_start = TimeCurrent();
            Print("RECOVERY MODE ACTIVATED: Loss to recover = ",
                  DoubleToString(g_recovery.loss_to_recover, 2));
           }
        }
     }
   else if(g_recovery.state == RECOVERY_WATCHING)
     {
      //--- Time limit: cancel recovery after configured timeout
      if(TimeCurrent() - g_recovery.recovery_start > recovery_timeout_sec)
        {
         Print("RECOVERY TIMEOUT: ", InpRecoveryTimeoutDays, " days elapsed without recovery completion");
         g_recovery.state = RECOVERY_OFF;
         g_am_state.current_risk_pct = g_am_state.base_risk_pct;
         return;
        }

      //--- Looking for high-quality entry for recovery
      if(g_current_signal.valid && g_current_signal.quality >= SIGNAL_HIGH)
        {
         g_recovery.state = RECOVERY_ACTIVE;
         Print("Recovery: Found HIGH quality signal, entering recovery trade");
        }
     }
   else if(g_recovery.state == RECOVERY_ACTIVE)
     {
      //--- Time limit also applies to active recovery
      if(TimeCurrent() - g_recovery.recovery_start > recovery_timeout_sec)
        {
         Print("RECOVERY TIMEOUT: ", InpRecoveryTimeoutDays, " days elapsed, reverting to normal mode");
         g_recovery.state = RECOVERY_OFF;
         g_am_state.current_risk_pct = g_am_state.base_risk_pct;
        }
     }
  }

//+------------------------------------------------------------------+
//| Update recovery state on trade close                             |
//+------------------------------------------------------------------+
void UpdateRecoveryOnClose(double net_profit)
  {
   if(g_recovery.state == RECOVERY_OFF)
      return;

   g_recovery.recovery_trades++;

   if(net_profit > 0)
      g_recovery.recovered += net_profit;

   //--- Check if recovery complete
   if(g_recovery.recovered >= g_recovery.loss_to_recover)
     {
      Print("RECOVERY COMPLETE: Recovered ", DoubleToString(g_recovery.recovered, 2),
            " / ", DoubleToString(g_recovery.loss_to_recover, 2));
      g_recovery.state = RECOVERY_OFF;
      g_am_state.current_risk_pct = g_am_state.base_risk_pct;
     }
   else if(g_recovery.recovery_trades >= g_recovery.max_recovery_trades)
     {
      Print("RECOVERY MAX TRADES: ", g_recovery.max_recovery_trades,
            " trades used, recovery incomplete. Reverting to normal mode.");
      g_recovery.state = RECOVERY_OFF;
      g_am_state.current_risk_pct = g_am_state.base_risk_pct;
     }
  }

//+------------------------------------------------------------------+
//| Check daily / weekly balance reset                               |
//+------------------------------------------------------------------+
void CheckDailyWeeklyReset()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   MqlDateTime last_daily;
   TimeToStruct(g_last_daily_reset, last_daily);

   //--- Daily reset
   if(now.day != last_daily.day || now.mon != last_daily.mon || now.year != last_daily.year)
     {
      g_daily_start_balance = g_account.Balance();
      g_last_daily_reset = TimeCurrent();
     }

   MqlDateTime last_weekly;
   TimeToStruct(g_last_weekly_reset, last_weekly);

   //--- Weekly reset (Monday = day_of_week 1)
   if(now.day_of_week == 1 && last_weekly.day_of_week != 1)
     {
      g_weekly_start_balance = g_account.Balance();
      g_last_weekly_reset = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Update dashboard with current state                              |
//+------------------------------------------------------------------+
void UpdateDashboard()
  {
   if(!InpShowDashboard)
      return;

   double equity   = g_account.Equity();
   double balance  = g_account.Balance();
   double daily_pl = balance - g_daily_start_balance;
   double weekly_pl= balance - g_weekly_start_balance;

   double win_rate = 0;
   if(g_am_state.total_trades > 0)
      win_rate = (double)g_am_state.total_wins / g_am_state.total_trades * 100.0;

   double avg_rr = 0;
   if(g_stat_wins > 0 && g_total_loss > 0)
      avg_rr = g_total_profit / g_stat_wins / (g_total_loss / g_stat_losses);

   //--- Build DashboardData struct
   DashboardData dash_data;
   dash_data.balance = balance;
   dash_data.equity = equity;
   dash_data.margin_used = g_account.Margin();
   dash_data.free_margin = g_account.FreeMargin();
   dash_data.daily_pnl = daily_pl;
   dash_data.weekly_pnl = weekly_pl;
   dash_data.open_positions = CountOpenPositions();
   dash_data.total_lots = 0;
   dash_data.floating_pnl = 0;
   //--- Compute total lots and floating PnL from open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(g_position.SelectByIndex(i))
        {
         if(g_position.Symbol() == _Symbol && g_position.Magic() == InpMagicNumber)
           {
            dash_data.total_lots += g_position.Volume();
            dash_data.floating_pnl += g_position.Profit() + g_position.Swap() + g_position.Commission();
           }
        }
     }
   dash_data.htf_structure = g_htf_structure;
   dash_data.mtf_structure = g_mtf_structure;
   dash_data.ltf_structure = g_ltf_structure;
   dash_data.exec_structure = g_exec_structure;
   dash_data.current_signal = g_current_signal;
   dash_data.am_state = g_am_state;
   dash_data.recovery = g_recovery;
   dash_data.current_session = g_current_session;
   dash_data.win_rate = win_rate;
   dash_data.avg_rr = avg_rr;
   dash_data.total_trades = g_stat_total_trades;

   g_dashboard.Update(dash_data);
  }//+------------------------------------------------------------------+
