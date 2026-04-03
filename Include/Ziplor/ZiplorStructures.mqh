//+------------------------------------------------------------------+
//|                                            ZiplorStructures.mqh  |
//|                        Copyright 2026, Ziplor Project            |
//|                        https://github.com/tjiradej/Ziplor       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor Project"
#property link      "https://github.com/tjiradej/Ziplor"
#property strict

#include "ZiplorEnums.mqh"

//+------------------------------------------------------------------+
//| Data structures for SMC / ICT analysis                           |
//+------------------------------------------------------------------+

//--- Swing point
struct SwingPoint
  {
   double            price;       // Price level
   datetime          time;        // Time of the swing
   int               bar_index;   // Bar index at detection
   bool              is_high;     // true = swing high, false = swing low
   bool              broken;      // Has this swing been broken?
   bool              swept;       // Liquidity swept but not broken structurally?
  };

//--- Market structure state per timeframe
struct MarketStructure
  {
   ENUM_TIMEFRAMES   timeframe;           // Timeframe
   ENUM_MARKET_BIAS  bias;                // Current bias
   ENUM_STRUCTURE_BREAK last_break;       // Last structure break type
   SwingPoint        last_swing_high;     // Most recent swing high
   SwingPoint        last_swing_low;      // Most recent swing low
   SwingPoint        prev_swing_high;     // Previous swing high
   SwingPoint        prev_swing_low;      // Previous swing low
   double            premium_level;       // Premium zone lower boundary (50% equilibrium)
   double            discount_level;      // Discount zone upper boundary
   bool              valid;               // Is the structure analysis valid?
  };

//--- Supply / Demand zone (Order Block, FVG, Breaker)
struct SDZone
  {
   ENUM_ZONE_TYPE    type;         // Zone type
   ENUM_ZONE_DIRECTION direction;  // Bullish or bearish
   ENUM_TIMEFRAMES   timeframe;    // Timeframe of origin
   double            upper;        // Upper boundary
   double            lower;        // Lower boundary
   datetime          time_start;   // Start time
   datetime          time_end;     // End time (0 = still valid)
   int               touch_count;  // Number of times price has tested this zone
   bool              mitigated;    // Has the zone been fully mitigated?
   bool              valid;        // Is zone still valid for trading?
  };

//--- Liquidity pool
struct LiquidityPool
  {
   double            price;      // Price level of the liquidity
   datetime          time;       // Time reference
   bool              is_buyside; // true = buy-side (above highs), false = sell-side (below lows)
   bool              swept;      // Has liquidity been swept?
   int               strength;   // Number of touches / equal highs/lows
  };

//--- Trade signal
struct TradeSignal
  {
   ENUM_MARKET_BIAS     direction;     // Signal direction
   ENUM_SIGNAL_QUALITY  quality;       // Signal quality
   double               entry_price;   // Suggested entry
   double               stop_loss;     // Suggested SL
   double               take_profit;   // Suggested TP
   double               risk_reward;   // Risk:Reward ratio
   string               reason;        // Description of confluences
   datetime             signal_time;   // When signal was generated
   bool                 valid;         // Is signal still valid?
   int                  confluence_count; // Number of confluences
  };

//--- Pyramid position entry
struct PyramidEntry
  {
   ulong             ticket;       // Position ticket
   ENUM_PYRAMID_LEVEL level;       // Pyramid level
   double            lot_size;     // Position size for this entry
   double            entry_price;  // Entry price
   double            stop_loss;    // Current stop loss
   datetime          entry_time;   // Entry time
   bool              active;       // Is this entry still open?
  };

//--- Anti-martingale tracker
struct AntiMartingaleState
  {
   ENUM_STREAK_TYPE  streak_type;       // Current streak type
   int               consecutive_wins;  // Consecutive wins count
   int               consecutive_losses;// Consecutive losses count
   double            current_risk_pct;  // Current risk percentage
   double            base_risk_pct;     // Base risk percentage
   double            max_risk_pct;      // Maximum allowed risk percentage
   double            risk_increment;    // Increment per consecutive win
   int               total_trades;      // Total trades taken
   int               total_wins;        // Total winning trades
   int               total_losses;      // Total losing trades
  };

//--- Recovery mode state
struct RecoveryModeState
  {
   ENUM_RECOVERY_STATE state;          // Current recovery state
   double              loss_to_recover; // Amount to recover
   double              recovered;       // Amount recovered so far
   int                 recovery_trades; // Trades taken in recovery
   int                 max_recovery_trades; // Max allowed recovery trades
   double              original_risk_pct;   // Risk before recovery adjustment
   datetime            recovery_start;      // When recovery started
  };

//--- Dashboard data (aggregated for display)
struct DashboardData
  {
   //--- Account
   double            balance;
   double            equity;
   double            margin_used;
   double            free_margin;
   double            daily_pnl;
   double            weekly_pnl;
   //--- Position
   int               open_positions;
   double            total_lots;
   double            floating_pnl;
   //--- Structure per TF
   MarketStructure   htf_structure;   // Higher timeframe (H4/D1)
   MarketStructure   mtf_structure;   // Mid timeframe (H1)
   MarketStructure   ltf_structure;   // Lower timeframe (M15/M5)
   MarketStructure   exec_structure;  // Execution timeframe (M1)
   //--- Signal
   TradeSignal       current_signal;
   //--- Anti-martingale
   AntiMartingaleState am_state;
   //--- Recovery
   RecoveryModeState recovery;
   //--- Session
   ENUM_SESSION_TYPE current_session;
   //--- Stats
   double            win_rate;
   double            avg_rr;
   int               total_trades;
  };
