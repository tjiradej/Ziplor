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

//+------------------------------------------------------------------+
//| Enumerations for SMC / ICT concepts                              |
//+------------------------------------------------------------------+

//--- Market structure bias
enum ENUM_MARKET_BIAS
  {
   BIAS_NONE    = 0,   // No clear bias
   BIAS_BULLISH = 1,   // Bullish bias
   BIAS_BEARISH = -1   // Bearish bias
  };

//--- Structure break type
enum ENUM_STRUCTURE_BREAK
  {
   BREAK_NONE  = 0,  // No break
   BREAK_BOS   = 1,  // Break of Structure (trend continuation)
   BREAK_CHOCH = 2   // Change of Character (trend reversal)
  };

//--- Zone type
enum ENUM_ZONE_TYPE
  {
   ZONE_NONE         = 0,  // No zone
   ZONE_ORDER_BLOCK  = 1,  // Order Block
   ZONE_FVG          = 2,  // Fair Value Gap
   ZONE_BREAKER      = 3   // Breaker Block
  };

//--- Zone direction
enum ENUM_ZONE_DIRECTION
  {
   ZONE_DIR_NONE    = 0,  // Undefined
   ZONE_DIR_BULLISH = 1,  // Bullish (demand)
   ZONE_DIR_BEARISH = 2   // Bearish (supply)
  };

//--- Trade signal quality
enum ENUM_SIGNAL_QUALITY
  {
   SIGNAL_NONE   = 0,  // No signal
   SIGNAL_LOW    = 1,  // Low quality (1 confluence)
   SIGNAL_MEDIUM = 2,  // Medium quality (2 confluences)
   SIGNAL_HIGH   = 3   // High quality (3+ confluences)
  };

//--- ICT Session / Killzone
enum ENUM_SESSION_TYPE
  {
   SESSION_NONE         = 0,  // No active session
   SESSION_ASIAN        = 1,  // Asian session
   SESSION_LONDON       = 2,  // London Killzone
   SESSION_NY           = 3,  // New York Killzone
   SESSION_LONDON_CLOSE = 4,  // London Close
   SESSION_SILVER_AM    = 5,  // Silver Bullet AM (10:00-11:00 EST)
   SESSION_SILVER_PM    = 6   // Silver Bullet PM (14:00-15:00 EST)
  };

//--- Recovery mode state
enum ENUM_RECOVERY_STATE
  {
   RECOVERY_OFF      = 0,  // Recovery mode disabled / not active
   RECOVERY_WATCHING = 1,  // Watching for recovery entry
   RECOVERY_ACTIVE   = 2   // Recovery trade active
  };

//--- Pyramid level
enum ENUM_PYRAMID_LEVEL
  {
   PYRAMID_BASE   = 0,  // Base entry
   PYRAMID_ADD_1  = 1,  // First add
   PYRAMID_ADD_2  = 2,  // Second add
   PYRAMID_ADD_3  = 3   // Third add (max)
  };

//--- Anti-martingale state
enum ENUM_STREAK_TYPE
  {
   STREAK_NONE    = 0,  // No streak
   STREAK_WINNING = 1,  // Winning streak
   STREAK_LOSING  = 2   // Losing streak
  };


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


//+------------------------------------------------------------------+
//| SMC / ICT Analysis Engine                                        |
//+------------------------------------------------------------------+
class CSMCEngine
  {
private:
   string            m_symbol;
   int               m_swing_lookback;      // Bars to look back for swing detection
   int               m_structure_lookback;   // Bars for structure analysis
   int               m_max_zones;            // Maximum zones to track
   int               m_min_confluence;       // Minimum confluences for signal
   double            m_min_risk_reward;      // Minimum risk:reward ratio

   //--- Internal zone arrays
   SDZone            m_demand_zones[];
   SDZone            m_supply_zones[];
   LiquidityPool     m_liquidity_pools[];
   int               m_demand_count;
   int               m_supply_count;
   int               m_liquidity_count;

   //--- Helper: detect swing high
   bool              IsSwingHigh(const double &high[], int index, int lookback);
   //--- Helper: detect swing low
   bool              IsSwingLow(const double &low[], int index, int lookback);
   //--- Helper: detect order block (last opposing candle before impulse)
   bool              DetectOrderBlock(ENUM_TIMEFRAMES tf, int impulse_bar, ENUM_ZONE_DIRECTION dir, SDZone &zone);
   //--- Helper: detect fair value gap
   bool              DetectFVG(ENUM_TIMEFRAMES tf, int bar, ENUM_ZONE_DIRECTION dir, SDZone &zone);
   //--- Helper: check if price is in zone
   bool              IsPriceInZone(double price, const SDZone &zone);
   //--- Helper: check zone mitigation
   void              UpdateZoneMitigation(SDZone &zones[], int count, double current_price);

public:
                     CSMCEngine(void);
                    ~CSMCEngine(void);

   //--- Initialization
   bool              Init(string symbol, int swing_lookback, int structure_lookback, int max_zones,
                         int min_confluence = 4, double min_risk_reward = 2.0);

   //--- Core analysis functions
   MarketStructure   AnalyzeStructure(ENUM_TIMEFRAMES tf);
   void              FindZones(ENUM_TIMEFRAMES tf);
   void              FindLiquidityPools(ENUM_TIMEFRAMES tf);

   //--- Signal generation
   TradeSignal       EvaluateSignal(MarketStructure &htf, MarketStructure &mtf, MarketStructure &ltf,
                                    MarketStructure &exec, ENUM_SESSION_TYPE session);

   //--- Zone access
   int               GetDemandZones(SDZone &zones[]);
   int               GetSupplyZones(SDZone &zones[]);
   int               GetLiquidityPools(LiquidityPool &pools[]);

   //--- Utility
   double            GetFibLevel(double high, double low, double level);
   bool              IsInPremium(double price, double range_high, double range_low);
   bool              IsInDiscount(double price, double range_high, double range_low);
   bool              IsInOTE(double price, double swing_high, double swing_low, ENUM_MARKET_BIAS bias);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSMCEngine::CSMCEngine(void)
   : m_symbol(""),
     m_swing_lookback(5),
     m_structure_lookback(50),
     m_max_zones(20),
     m_min_confluence(4),
     m_min_risk_reward(2.0),
     m_demand_count(0),
     m_supply_count(0),
     m_liquidity_count(0)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSMCEngine::~CSMCEngine(void)
  {
  }

//+------------------------------------------------------------------+
//| Initialize the engine                                            |
//+------------------------------------------------------------------+
bool CSMCEngine::Init(string symbol, int swing_lookback, int structure_lookback, int max_zones,
                      int min_confluence, double min_risk_reward)
  {
   m_symbol = symbol;
   m_swing_lookback = MathMax(swing_lookback, 2);
   m_structure_lookback = MathMax(structure_lookback, 20);
   m_max_zones = MathMax(max_zones, 5);
   m_min_confluence = MathMax(min_confluence, 1);
   m_min_risk_reward = MathMax(min_risk_reward, 1.0);

   ArrayResize(m_demand_zones, m_max_zones);
   ArrayResize(m_supply_zones, m_max_zones);
   ArrayResize(m_liquidity_pools, m_max_zones * 2);

   m_demand_count = 0;
   m_supply_count = 0;
   m_liquidity_count = 0;

   return true;
  }

//+------------------------------------------------------------------+
//| Detect swing high                                                |
//+------------------------------------------------------------------+
bool CSMCEngine::IsSwingHigh(const double &high[], int index, int lookback)
  {
   if(index < lookback || index >= ArraySize(high) - lookback)
      return false;

   double pivot = high[index];
   for(int i = 1; i <= lookback; i++)
     {
      if(high[index - i] >= pivot || high[index + i] >= pivot)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Detect swing low                                                 |
//+------------------------------------------------------------------+
bool CSMCEngine::IsSwingLow(const double &low[], int index, int lookback)
  {
   if(index < lookback || index >= ArraySize(low) - lookback)
      return false;

   double pivot = low[index];
   for(int i = 1; i <= lookback; i++)
     {
      if(low[index - i] <= pivot || low[index + i] <= pivot)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Analyze market structure for a given timeframe                   |
//+------------------------------------------------------------------+
MarketStructure CSMCEngine::AnalyzeStructure(ENUM_TIMEFRAMES tf)
  {
   MarketStructure ms;
   ms.timeframe = tf;
   ms.bias = BIAS_NONE;
   ms.last_break = BREAK_NONE;
   ms.valid = false;

   //--- Copy price data
   double high[], low[], close[], open[];
   datetime time[];
   int bars_needed = m_structure_lookback + m_swing_lookback + 5;
   int copied_h = CopyHigh(m_symbol, tf, 0, bars_needed, high);
   int copied_l = CopyLow(m_symbol, tf, 0, bars_needed, low);
   int copied_c = CopyClose(m_symbol, tf, 0, bars_needed, close);
   int copied_o = CopyOpen(m_symbol, tf, 0, bars_needed, open);
   int copied_t = CopyTime(m_symbol, tf, 0, bars_needed, time);

   if(copied_h < bars_needed || copied_l < bars_needed || copied_c < bars_needed ||
      copied_o < bars_needed || copied_t < bars_needed)
      return ms;

   //--- Find swing points (scan from oldest to newest)
   SwingPoint swing_highs[];
   SwingPoint swing_lows[];
   ArrayResize(swing_highs, 0);
   ArrayResize(swing_lows, 0);

   for(int i = m_swing_lookback; i < bars_needed - m_swing_lookback; i++)
     {
      if(IsSwingHigh(high, i, m_swing_lookback))
        {
         SwingPoint sp;
         sp.price = high[i];
         sp.time = time[i];
         sp.bar_index = i;
         sp.is_high = true;
         sp.broken = false;
         sp.swept = false;
         int sz = ArraySize(swing_highs);
         ArrayResize(swing_highs, sz + 1);
         swing_highs[sz] = sp;
        }
      if(IsSwingLow(low, i, m_swing_lookback))
        {
         SwingPoint sp;
         sp.price = low[i];
         sp.time = time[i];
         sp.bar_index = i;
         sp.is_high = false;
         sp.broken = false;
         sp.swept = false;
         int sz = ArraySize(swing_lows);
         ArrayResize(swing_lows, sz + 1);
         swing_lows[sz] = sp;
        }
     }

   int sh_count = ArraySize(swing_highs);
   int sl_count = ArraySize(swing_lows);

   if(sh_count < 2 || sl_count < 2)
      return ms;

   //--- Assign last and previous swings
   ms.last_swing_high = swing_highs[sh_count - 1];
   ms.prev_swing_high = swing_highs[sh_count - 2];
   ms.last_swing_low = swing_lows[sl_count - 1];
   ms.prev_swing_low = swing_lows[sl_count - 2];

   //--- Determine current price relative to structure
   double current_close = close[bars_needed - 1];

   //--- Determine bias: higher highs + higher lows = bullish, lower highs + lower lows = bearish
   bool higher_high = ms.last_swing_high.price > ms.prev_swing_high.price;
   bool higher_low = ms.last_swing_low.price > ms.prev_swing_low.price;
   bool lower_high = ms.last_swing_high.price < ms.prev_swing_high.price;
   bool lower_low = ms.last_swing_low.price < ms.prev_swing_low.price;

   //--- BOS: continuation of existing trend
   //--- CHoCH: first break against prevailing trend
   if(higher_high && higher_low)
     {
      ms.bias = BIAS_BULLISH;
      //--- Check if this is a new BOS or CHoCH
      if(ms.prev_swing_high.price < ms.last_swing_high.price)
         ms.last_break = BREAK_BOS;
     }
   else if(lower_high && lower_low)
     {
      ms.bias = BIAS_BEARISH;
      if(ms.prev_swing_low.price > ms.last_swing_low.price)
         ms.last_break = BREAK_BOS;
     }
   else if(higher_high && lower_low)
     {
      //--- Mixed signals - check last break direction
      if(current_close > ms.prev_swing_high.price)
        {
         ms.bias = BIAS_BULLISH;
         ms.last_break = BREAK_CHOCH;
        }
      else if(current_close < ms.prev_swing_low.price)
        {
         ms.bias = BIAS_BEARISH;
         ms.last_break = BREAK_CHOCH;
        }
     }
   else if(lower_high && higher_low)
     {
      //--- Consolidation / ranging
      ms.bias = BIAS_NONE;
      ms.last_break = BREAK_NONE;
     }

   //--- Calculate premium / discount levels
   double range_high = MathMax(ms.last_swing_high.price, ms.prev_swing_high.price);
   double range_low = MathMin(ms.last_swing_low.price, ms.prev_swing_low.price);
   ms.premium_level = range_low + (range_high - range_low) * 0.5;
   ms.discount_level = ms.premium_level; // Same as equilibrium

   ms.valid = true;
   return ms;
  }

//+------------------------------------------------------------------+
//| Detect an order block                                            |
//+------------------------------------------------------------------+
bool CSMCEngine::DetectOrderBlock(ENUM_TIMEFRAMES tf, int impulse_bar, ENUM_ZONE_DIRECTION dir, SDZone &zone)
  {
   double open[], close[], high[], low[];
   datetime time[];
   int need = impulse_bar + 5;
   if(CopyOpen(m_symbol, tf, 0, need, open) < need) return false;
   if(CopyClose(m_symbol, tf, 0, need, close) < need) return false;
   if(CopyHigh(m_symbol, tf, 0, need, high) < need) return false;
   if(CopyLow(m_symbol, tf, 0, need, low) < need) return false;
   if(CopyTime(m_symbol, tf, 0, need, time) < need) return false;

   //--- For bullish OB: find last bearish candle before bullish impulse
   //--- For bearish OB: find last bullish candle before bearish impulse
   if(impulse_bar < 2) return false;

   int ob_bar = impulse_bar - 1;
   if(dir == ZONE_DIR_BULLISH)
     {
      //--- Impulse bar should be strongly bullish
      double impulse_body = close[impulse_bar] - open[impulse_bar];
      if(impulse_body <= 0) return false;

      //--- OB bar should be bearish (last opposing candle)
      if(close[ob_bar] >= open[ob_bar])
        {
         //--- Try one more bar back
         ob_bar = impulse_bar - 2;
         if(ob_bar < 0 || close[ob_bar] >= open[ob_bar]) return false;
        }

      zone.type = ZONE_ORDER_BLOCK;
      zone.direction = ZONE_DIR_BULLISH;
      zone.timeframe = tf;
      zone.upper = high[ob_bar];
      zone.lower = low[ob_bar];
      zone.time_start = time[ob_bar];
      zone.time_end = 0;
      zone.touch_count = 0;
      zone.mitigated = false;
      zone.valid = true;
      return true;
     }
   else if(dir == ZONE_DIR_BEARISH)
     {
      double impulse_body = open[impulse_bar] - close[impulse_bar];
      if(impulse_body <= 0) return false;

      if(close[ob_bar] <= open[ob_bar])
        {
         ob_bar = impulse_bar - 2;
         if(ob_bar < 0 || close[ob_bar] <= open[ob_bar]) return false;
        }

      zone.type = ZONE_ORDER_BLOCK;
      zone.direction = ZONE_DIR_BEARISH;
      zone.timeframe = tf;
      zone.upper = high[ob_bar];
      zone.lower = low[ob_bar];
      zone.time_start = time[ob_bar];
      zone.time_end = 0;
      zone.touch_count = 0;
      zone.mitigated = false;
      zone.valid = true;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Detect Fair Value Gap                                            |
//+------------------------------------------------------------------+
bool CSMCEngine::DetectFVG(ENUM_TIMEFRAMES tf, int bar, ENUM_ZONE_DIRECTION dir, SDZone &zone)
  {
   double high[], low[];
   datetime time[];
   int need = bar + 3;
   if(CopyHigh(m_symbol, tf, 0, need, high) < need) return false;
   if(CopyLow(m_symbol, tf, 0, need, low) < need) return false;
   if(CopyTime(m_symbol, tf, 0, need, time) < need) return false;

   if(bar < 2) return false;

   //--- Bullish FVG: candle[bar-2] high < candle[bar] low (gap up)
   if(dir == ZONE_DIR_BULLISH)
     {
      if(high[bar - 2] < low[bar])
        {
         zone.type = ZONE_FVG;
         zone.direction = ZONE_DIR_BULLISH;
         zone.timeframe = tf;
         zone.upper = low[bar];
         zone.lower = high[bar - 2];
         zone.time_start = time[bar - 1];
         zone.time_end = 0;
         zone.touch_count = 0;
         zone.mitigated = false;
         zone.valid = true;
         return true;
        }
     }
   //--- Bearish FVG: candle[bar-2] low > candle[bar] high (gap down)
   else if(dir == ZONE_DIR_BEARISH)
     {
      if(low[bar - 2] > high[bar])
        {
         zone.type = ZONE_FVG;
         zone.direction = ZONE_DIR_BEARISH;
         zone.timeframe = tf;
         zone.upper = low[bar - 2];
         zone.lower = high[bar];
         zone.time_start = time[bar - 1];
         zone.time_end = 0;
         zone.touch_count = 0;
         zone.mitigated = false;
         zone.valid = true;
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Find all valid zones for a timeframe                             |
//+------------------------------------------------------------------+
void CSMCEngine::FindZones(ENUM_TIMEFRAMES tf)
  {
   double high[], low[], open[], close[];
   datetime time[];
   int bars_needed = m_structure_lookback;

   if(CopyHigh(m_symbol, tf, 0, bars_needed, high) < bars_needed) return;
   if(CopyLow(m_symbol, tf, 0, bars_needed, low) < bars_needed) return;
   if(CopyOpen(m_symbol, tf, 0, bars_needed, open) < bars_needed) return;
   if(CopyClose(m_symbol, tf, 0, bars_needed, close) < bars_needed) return;
   if(CopyTime(m_symbol, tf, 0, bars_needed, time) < bars_needed) return;

   double current_price = close[bars_needed - 1];

   //--- Reset zone counts
   m_demand_count = 0;
   m_supply_count = 0;

   //--- Scan for impulse moves and identify OBs and FVGs
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double avg_range = 0;
   for(int i = 0; i < bars_needed; i++)
      avg_range += high[i] - low[i];
   avg_range /= bars_needed;
   double impulse_threshold = avg_range * 2.0; // 2x average range = impulse

   for(int i = 3; i < bars_needed - 1; i++)
     {
      double body = MathAbs(close[i] - open[i]);

      //--- Bullish impulse
      if(close[i] > open[i] && body > impulse_threshold)
        {
         SDZone ob_zone;
         if(DetectOrderBlock(tf, i, ZONE_DIR_BULLISH, ob_zone))
           {
            if(m_demand_count < m_max_zones && !ob_zone.mitigated)
              {
               //--- Check if zone hasn't been mitigated by subsequent price action
               bool still_valid = true;
               for(int j = i + 1; j < bars_needed; j++)
                 {
                  if(low[j] < ob_zone.lower)
                    {
                     still_valid = false;
                     break;
                    }
                 }
               if(still_valid)
                 {
                  m_demand_zones[m_demand_count] = ob_zone;
                  m_demand_count++;
                 }
              }
           }

         //--- Check for FVG
         SDZone fvg_zone;
         if(DetectFVG(tf, i, ZONE_DIR_BULLISH, fvg_zone))
           {
            if(m_demand_count < m_max_zones)
              {
               bool still_valid = true;
               for(int j = i + 1; j < bars_needed; j++)
                 {
                  if(low[j] < fvg_zone.lower)
                    {
                     still_valid = false;
                     break;
                    }
                 }
               if(still_valid)
                 {
                  m_demand_zones[m_demand_count] = fvg_zone;
                  m_demand_count++;
                 }
              }
           }
        }
      //--- Bearish impulse
      else if(close[i] < open[i] && body > impulse_threshold)
        {
         SDZone ob_zone;
         if(DetectOrderBlock(tf, i, ZONE_DIR_BEARISH, ob_zone))
           {
            if(m_supply_count < m_max_zones && !ob_zone.mitigated)
              {
               bool still_valid = true;
               for(int j = i + 1; j < bars_needed; j++)
                 {
                  if(high[j] > ob_zone.upper)
                    {
                     still_valid = false;
                     break;
                    }
                 }
               if(still_valid)
                 {
                  m_supply_zones[m_supply_count] = ob_zone;
                  m_supply_count++;
                 }
              }
           }

         SDZone fvg_zone;
         if(DetectFVG(tf, i, ZONE_DIR_BEARISH, fvg_zone))
           {
            if(m_supply_count < m_max_zones)
              {
               bool still_valid = true;
               for(int j = i + 1; j < bars_needed; j++)
                 {
                  if(high[j] > fvg_zone.upper)
                    {
                     still_valid = false;
                     break;
                    }
                 }
               if(still_valid)
                 {
                  m_supply_zones[m_supply_count] = fvg_zone;
                  m_supply_count++;
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Find liquidity pools (clusters of equal highs/lows)              |
//+------------------------------------------------------------------+
void CSMCEngine::FindLiquidityPools(ENUM_TIMEFRAMES tf)
  {
   double high[], low[];
   datetime time[];
   int bars_needed = m_structure_lookback;

   if(CopyHigh(m_symbol, tf, 0, bars_needed, high) < bars_needed) return;
   if(CopyLow(m_symbol, tf, 0, bars_needed, low) < bars_needed) return;
   if(CopyTime(m_symbol, tf, 0, bars_needed, time) < bars_needed) return;

   m_liquidity_count = 0;
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double tolerance = point * 10; // Equal level tolerance

   //--- Find swing highs and lows for liquidity
   for(int i = m_swing_lookback; i < bars_needed - m_swing_lookback; i++)
     {
      //--- Buy-side liquidity (above swing highs)
      if(IsSwingHigh(high, i, m_swing_lookback))
        {
         //--- Count how many nearby highs are at similar level
         int touches = 1;
         for(int j = i + 1; j < bars_needed - m_swing_lookback; j++)
           {
            if(IsSwingHigh(high, j, m_swing_lookback) &&
               MathAbs(high[j] - high[i]) < tolerance)
              {
               touches++;
              }
           }

         if(m_liquidity_count < m_max_zones * 2)
           {
            m_liquidity_pools[m_liquidity_count].price = high[i];
            m_liquidity_pools[m_liquidity_count].time = time[i];
            m_liquidity_pools[m_liquidity_count].is_buyside = true;
            m_liquidity_pools[m_liquidity_count].swept = false;
            m_liquidity_pools[m_liquidity_count].strength = touches;
            m_liquidity_count++;
           }
        }

      //--- Sell-side liquidity (below swing lows)
      if(IsSwingLow(low, i, m_swing_lookback))
        {
         int touches = 1;
         for(int j = i + 1; j < bars_needed - m_swing_lookback; j++)
           {
            if(IsSwingLow(low, j, m_swing_lookback) &&
               MathAbs(low[j] - low[i]) < tolerance)
              {
               touches++;
              }
           }

         if(m_liquidity_count < m_max_zones * 2)
           {
            m_liquidity_pools[m_liquidity_count].price = low[i];
            m_liquidity_pools[m_liquidity_count].time = time[i];
            m_liquidity_pools[m_liquidity_count].is_buyside = false;
            m_liquidity_pools[m_liquidity_count].swept = false;
            m_liquidity_pools[m_liquidity_count].strength = touches;
            m_liquidity_count++;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if price is inside a zone                                  |
//+------------------------------------------------------------------+
bool CSMCEngine::IsPriceInZone(double price, const SDZone &zone)
  {
   return (price >= zone.lower && price <= zone.upper && zone.valid && !zone.mitigated);
  }

//+------------------------------------------------------------------+
//| Update zone mitigation status                                    |
//+------------------------------------------------------------------+
void CSMCEngine::UpdateZoneMitigation(SDZone &zones[], int count, double current_price)
  {
   for(int i = 0; i < count; i++)
     {
      if(!zones[i].valid || zones[i].mitigated)
         continue;

      //--- If price has passed through the zone, mark it mitigated
      if(zones[i].direction == ZONE_DIR_BULLISH && current_price < zones[i].lower)
        {
         zones[i].mitigated = true;
         zones[i].valid = false;
        }
      else if(zones[i].direction == ZONE_DIR_BEARISH && current_price > zones[i].upper)
        {
         zones[i].mitigated = true;
         zones[i].valid = false;
        }
      //--- If price touches zone, increment touch count
      else if(current_price >= zones[i].lower && current_price <= zones[i].upper)
        {
         zones[i].touch_count++;
         //--- Zones lose effectiveness after 3 touches
         if(zones[i].touch_count > 3)
           {
            zones[i].mitigated = true;
            zones[i].valid = false;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Get Fibonacci level between two prices                           |
//+------------------------------------------------------------------+
double CSMCEngine::GetFibLevel(double high_price, double low_price, double level)
  {
   return low_price + (high_price - low_price) * level;
  }

//+------------------------------------------------------------------+
//| Check if price is in premium zone (above 50% of range)           |
//+------------------------------------------------------------------+
bool CSMCEngine::IsInPremium(double price, double range_high, double range_low)
  {
   double equilibrium = (range_high + range_low) / 2.0;
   return (price > equilibrium);
  }

//+------------------------------------------------------------------+
//| Check if price is in discount zone (below 50% of range)          |
//+------------------------------------------------------------------+
bool CSMCEngine::IsInDiscount(double price, double range_high, double range_low)
  {
   double equilibrium = (range_high + range_low) / 2.0;
   return (price < equilibrium);
  }

//+------------------------------------------------------------------+
//| Check if price is in OTE zone (62-79% retracement)               |
//+------------------------------------------------------------------+
bool CSMCEngine::IsInOTE(double price, double swing_high, double swing_low, ENUM_MARKET_BIAS bias)
  {
   double fib_62 = GetFibLevel(swing_high, swing_low, 0.62);
   double fib_79 = GetFibLevel(swing_high, swing_low, 0.79);

   if(bias == BIAS_BULLISH)
     {
      //--- For bullish OTE: price should retrace to 62-79% from swing high down to swing low
      double ote_upper = swing_high - (swing_high - swing_low) * 0.62;
      double ote_lower = swing_high - (swing_high - swing_low) * 0.79;
      return (price >= ote_lower && price <= ote_upper);
     }
   else if(bias == BIAS_BEARISH)
     {
      //--- For bearish OTE: price should retrace to 62-79% from swing low up to swing high
      double ote_lower = swing_low + (swing_high - swing_low) * 0.62;
      double ote_upper = swing_low + (swing_high - swing_low) * 0.79;
      return (price >= ote_lower && price <= ote_upper);
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Evaluate trade signal with multi-timeframe confluence            |
//+------------------------------------------------------------------+
TradeSignal CSMCEngine::EvaluateSignal(MarketStructure &htf, MarketStructure &mtf,
                                       MarketStructure &ltf, MarketStructure &exec,
                                       ENUM_SESSION_TYPE session)
  {
   TradeSignal signal;
   signal.direction = BIAS_NONE;
   signal.quality = SIGNAL_NONE;
   signal.entry_price = 0;
   signal.stop_loss = 0;
   signal.take_profit = 0;
   signal.risk_reward = 0;
   signal.reason = "";
   signal.signal_time = TimeCurrent();
   signal.valid = false;
   signal.confluence_count = 0;

   //--- Validation: all structures must be valid
   if(!htf.valid || !mtf.valid || !ltf.valid || !exec.valid)
      return signal;

   //--- Only trade during killzones
   if(session == SESSION_NONE || session == SESSION_ASIAN)
      return signal;

   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double spread = ask - bid;

   //--- BULLISH SIGNAL EVALUATION ---
   int bull_confluence = 0;
   string bull_reasons = "";

   //--- 1. HTF bias must be bullish
   if(htf.bias == BIAS_BULLISH)
     {
      bull_confluence++;
      bull_reasons += "HTF Bullish|";
     }

   //--- 2. MTF structure bullish with BOS
   if(mtf.bias == BIAS_BULLISH && mtf.last_break == BREAK_BOS)
     {
      bull_confluence++;
      bull_reasons += "MTF BOS|";
     }
   else if(mtf.bias == BIAS_BULLISH && mtf.last_break == BREAK_CHOCH)
     {
      bull_confluence++;
      bull_reasons += "MTF CHoCH|";
     }

   //--- 3. LTF showing bullish CHoCH or BOS
   if(ltf.bias == BIAS_BULLISH && (ltf.last_break == BREAK_BOS || ltf.last_break == BREAK_CHOCH))
     {
      bull_confluence++;
      bull_reasons += "LTF Confirm|";
     }

   //--- 4. Execution TF alignment
   if(exec.bias == BIAS_BULLISH)
     {
      bull_confluence++;
      bull_reasons += "M1 Aligned|";
     }

   //--- 5. Price in discount zone on HTF
   double htf_range_high = MathMax(htf.last_swing_high.price, htf.prev_swing_high.price);
   double htf_range_low = MathMin(htf.last_swing_low.price, htf.prev_swing_low.price);
   if(IsInDiscount(bid, htf_range_high, htf_range_low))
     {
      bull_confluence++;
      bull_reasons += "Discount|";
     }

   //--- 6. Price in OTE zone
   if(IsInOTE(bid, ltf.last_swing_high.price, ltf.last_swing_low.price, BIAS_BULLISH))
     {
      bull_confluence++;
      bull_reasons += "OTE|";
     }

   //--- 7. Price in a demand zone (OB or FVG)
   for(int i = 0; i < m_demand_count; i++)
     {
      if(IsPriceInZone(bid, m_demand_zones[i]))
        {
         bull_confluence++;
         if(m_demand_zones[i].type == ZONE_ORDER_BLOCK)
            bull_reasons += "DemandOB|";
         else
            bull_reasons += "BullFVG|";
         break;
        }
     }

   //--- 8. Session confluence
   if(session == SESSION_LONDON || session == SESSION_NY || session == SESSION_SILVER_AM)
     {
      bull_confluence++;
      bull_reasons += "Killzone|";
     }

   //--- BEARISH SIGNAL EVALUATION ---
   int bear_confluence = 0;
   string bear_reasons = "";

   if(htf.bias == BIAS_BEARISH)
     {
      bear_confluence++;
      bear_reasons += "HTF Bearish|";
     }

   if(mtf.bias == BIAS_BEARISH && mtf.last_break == BREAK_BOS)
     {
      bear_confluence++;
      bear_reasons += "MTF BOS|";
     }
   else if(mtf.bias == BIAS_BEARISH && mtf.last_break == BREAK_CHOCH)
     {
      bear_confluence++;
      bear_reasons += "MTF CHoCH|";
     }

   if(ltf.bias == BIAS_BEARISH && (ltf.last_break == BREAK_BOS || ltf.last_break == BREAK_CHOCH))
     {
      bear_confluence++;
      bear_reasons += "LTF Confirm|";
     }

   if(exec.bias == BIAS_BEARISH)
     {
      bear_confluence++;
      bear_reasons += "M1 Aligned|";
     }

   if(IsInPremium(bid, htf_range_high, htf_range_low))
     {
      bear_confluence++;
      bear_reasons += "Premium|";
     }

   if(IsInOTE(bid, ltf.last_swing_high.price, ltf.last_swing_low.price, BIAS_BEARISH))
     {
      bear_confluence++;
      bear_reasons += "OTE|";
     }

   for(int i = 0; i < m_supply_count; i++)
     {
      if(IsPriceInZone(bid, m_supply_zones[i]))
        {
         bear_confluence++;
         if(m_supply_zones[i].type == ZONE_ORDER_BLOCK)
            bear_reasons += "SupplyOB|";
         else
            bear_reasons += "BearFVG|";
         break;
        }
     }

   if(session == SESSION_LONDON || session == SESSION_NY || session == SESSION_SILVER_PM)
     {
      bear_confluence++;
      bear_reasons += "Killzone|";
     }

   //--- Choose the stronger signal
   int min_confluence = m_min_confluence; // Use configured minimum
   if(bull_confluence >= min_confluence && bull_confluence > bear_confluence)
     {
      signal.direction = BIAS_BULLISH;
      signal.confluence_count = bull_confluence;
      signal.reason = bull_reasons;

      //--- Entry at ask, SL below last LTF swing low, TP at nearest sell-side liquidity
      signal.entry_price = ask;
      signal.stop_loss = ltf.last_swing_low.price - spread - point * 5;

      //--- Validate SL is below entry for BUY
      if(signal.stop_loss >= signal.entry_price)
        {
         signal.valid = false;
         return signal;
        }

      double sl_distance = signal.entry_price - signal.stop_loss;
      if(sl_distance < point * 10) // Minimum 10 points SL distance
        {
         signal.valid = false;
         return signal;
        }

      //--- Find nearest buy-side liquidity pool for TP
      double best_tp = signal.entry_price + sl_distance * 3.0; // Default 3:1 RR
      for(int i = 0; i < m_liquidity_count; i++)
        {
         if(m_liquidity_pools[i].is_buyside &&
            m_liquidity_pools[i].price > signal.entry_price &&
            !m_liquidity_pools[i].swept)
           {
            double potential_tp = m_liquidity_pools[i].price;
            double potential_rr = (potential_tp - signal.entry_price) / sl_distance;
            if(potential_rr >= 2.0 && potential_rr <= 10.0)
              {
               best_tp = potential_tp;
               break;
              }
           }
        }
      signal.take_profit = best_tp;
      signal.risk_reward = (signal.take_profit - signal.entry_price) / sl_distance;
     }
   else if(bear_confluence >= min_confluence && bear_confluence > bull_confluence)
     {
      signal.direction = BIAS_BEARISH;
      signal.confluence_count = bear_confluence;
      signal.reason = bear_reasons;

      signal.entry_price = bid;
      signal.stop_loss = ltf.last_swing_high.price + spread + point * 5;

      //--- Validate SL is above entry for SELL
      if(signal.stop_loss <= signal.entry_price)
        {
         signal.valid = false;
         return signal;
        }

      double sl_distance = signal.stop_loss - signal.entry_price;
      if(sl_distance < point * 10) // Minimum 10 points SL distance
        {
         signal.valid = false;
         return signal;
        }

      double best_tp = signal.entry_price - sl_distance * 3.0;
      for(int i = 0; i < m_liquidity_count; i++)
        {
         if(!m_liquidity_pools[i].is_buyside &&
            m_liquidity_pools[i].price < signal.entry_price &&
            !m_liquidity_pools[i].swept)
           {
            double potential_tp = m_liquidity_pools[i].price;
            double potential_rr = (signal.entry_price - potential_tp) / sl_distance;
            if(potential_rr >= 2.0 && potential_rr <= 10.0)
              {
               best_tp = potential_tp;
               break;
              }
           }
        }
      signal.take_profit = best_tp;
      signal.risk_reward = (signal.entry_price - signal.take_profit) / sl_distance;
     }

   //--- Determine signal quality
   if(signal.direction != BIAS_NONE)
     {
      //--- Final TP sanity check
      if(signal.direction == BIAS_BULLISH && signal.take_profit <= signal.entry_price)
        {
         signal.valid = false;
         return signal;
        }
      if(signal.direction == BIAS_BEARISH && signal.take_profit >= signal.entry_price)
        {
         signal.valid = false;
         return signal;
        }

      if(signal.confluence_count >= 6)
         signal.quality = SIGNAL_HIGH;
      else if(signal.confluence_count >= 5)
         signal.quality = SIGNAL_MEDIUM;
      else
         signal.quality = SIGNAL_LOW;

      //--- Only mark valid if risk:reward is acceptable
      signal.valid = (signal.risk_reward >= m_min_risk_reward && signal.risk_reward <= 15.0);
     }

   return signal;
  }

//+------------------------------------------------------------------+
//| Get demand zones                                                 |
//+------------------------------------------------------------------+
int CSMCEngine::GetDemandZones(SDZone &zones[])
  {
   ArrayResize(zones, m_demand_count);
   for(int i = 0; i < m_demand_count; i++)
      zones[i] = m_demand_zones[i];
   return m_demand_count;
  }

//+------------------------------------------------------------------+
//| Get supply zones                                                 |
//+------------------------------------------------------------------+
int CSMCEngine::GetSupplyZones(SDZone &zones[])
  {
   ArrayResize(zones, m_supply_count);
   for(int i = 0; i < m_supply_count; i++)
      zones[i] = m_supply_zones[i];
   return m_supply_count;
  }

//+------------------------------------------------------------------+
//| Get liquidity pools                                              |
//+------------------------------------------------------------------+
int CSMCEngine::GetLiquidityPools(LiquidityPool &pools[])
  {
   ArrayResize(pools, m_liquidity_count);
   for(int i = 0; i < m_liquidity_count; i++)
      pools[i] = m_liquidity_pools[i];
   return m_liquidity_count;
  }


//+------------------------------------------------------------------+
//| Dashboard Panel - On-chart information display                   |
//+------------------------------------------------------------------+
class CDashboard
  {
private:
   string            m_prefix;        // Object name prefix
   int               m_x;             // Panel X position
   int               m_y;             // Panel Y position
   int               m_width;         // Panel width
   int               m_line_height;   // Line height
   color             m_bg_color;      // Background color
   color             m_text_color;    // Default text color
   color             m_header_color;  // Header text color
   color             m_bull_color;    // Bullish color
   color             m_bear_color;    // Bearish color
   color             m_neutral_color; // Neutral color
   color             m_warning_color; // Warning color
   int               m_font_size;     // Font size
   string            m_font_name;     // Font name

   //--- Helper: create a label object on chart
   void              CreateLabel(string name, int x, int y, string text,
                                 color clr, int font_size, string font = "Consolas");
   //--- Helper: create a rectangle background
   void              CreateRectangle(string name, int x, int y, int width, int height, color clr);
   //--- Helper: update existing label text
   void              UpdateLabel(string name, string text, color clr);
   //--- Helper: format number with specified decimals
   string            FormatNumber(double value, int decimals);
   //--- Helper: get bias string
   string            BiasToString(ENUM_MARKET_BIAS bias);
   //--- Helper: get bias color
   color             BiasToColor(ENUM_MARKET_BIAS bias);
   //--- Helper: get break type string
   string            BreakToString(ENUM_STRUCTURE_BREAK brk);
   //--- Helper: get session string
   string            SessionToString(ENUM_SESSION_TYPE session);
   //--- Helper: get signal quality string
   string            QualityToString(ENUM_SIGNAL_QUALITY quality);
   //--- Helper: get recovery state string
   string            RecoveryToString(ENUM_RECOVERY_STATE state);
   //--- Helper: get streak string
   string            StreakToString(ENUM_STREAK_TYPE streak);
   //--- Helper: get timeframe string
   string            TFToString(ENUM_TIMEFRAMES tf);

public:
                     CDashboard(void);
                    ~CDashboard(void);

   //--- Initialization and destruction
   bool              Init(int x, int y, int width, string prefix = "ZPL_");
   void              Destroy(void);

   //--- Update the dashboard with current data
   void              Update(const DashboardData &data);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDashboard::CDashboard(void)
   : m_prefix("ZPL_"),
     m_x(20),
     m_y(30),
     m_width(320),
     m_line_height(16),
     m_bg_color(C'20,20,30'),
     m_text_color(C'200,200,200'),
     m_header_color(C'0,180,255'),
     m_bull_color(C'0,200,100'),
     m_bear_color(C'255,80,80'),
     m_neutral_color(C'180,180,180'),
     m_warning_color(C'255,200,0'),
     m_font_size(8),
     m_font_name("Consolas")
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDashboard::~CDashboard(void)
  {
   Destroy();
  }

//+------------------------------------------------------------------+
//| Initialize dashboard                                             |
//+------------------------------------------------------------------+
bool CDashboard::Init(int x, int y, int width, string prefix)
  {
   m_x = x;
   m_y = y;
   m_width = width;
   m_prefix = prefix;
   return true;
  }

//+------------------------------------------------------------------+
//| Destroy all dashboard objects                                    |
//+------------------------------------------------------------------+
void CDashboard::Destroy(void)
  {
   ObjectsDeleteAll(0, m_prefix);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Create a text label on the chart                                 |
//+------------------------------------------------------------------+
void CDashboard::CreateLabel(string name, int x, int y, string text,
                              color clr, int font_size, string font)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
   ObjectSetString(0, obj_name, OBJPROP_FONT, font);
   ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
  }

//+------------------------------------------------------------------+
//| Create a rectangle background                                    |
//+------------------------------------------------------------------+
void CDashboard::CreateRectangle(string name, int x, int y, int width, int height, color clr)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) < 0)
     {
      ObjectCreate(0, obj_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj_name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, obj_name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, obj_name, OBJPROP_BORDER_COLOR, C'40,40,60');
   ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
  }

//+------------------------------------------------------------------+
//| Update an existing label                                         |
//+------------------------------------------------------------------+
void CDashboard::UpdateLabel(string name, string text, color clr)
  {
   string obj_name = m_prefix + name;
   if(ObjectFind(0, obj_name) >= 0)
     {
      ObjectSetString(0, obj_name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
     }
  }

//+------------------------------------------------------------------+
//| Format number                                                    |
//+------------------------------------------------------------------+
string CDashboard::FormatNumber(double value, int decimals)
  {
   return DoubleToString(value, decimals);
  }

//+------------------------------------------------------------------+
//| Convert bias enum to string                                      |
//+------------------------------------------------------------------+
string CDashboard::BiasToString(ENUM_MARKET_BIAS bias)
  {
   switch(bias)
     {
      case BIAS_BULLISH: return "BULLISH";
      case BIAS_BEARISH: return "BEARISH";
      default:           return "NEUTRAL";
     }
  }

//+------------------------------------------------------------------+
//| Convert bias enum to color                                       |
//+------------------------------------------------------------------+
color CDashboard::BiasToColor(ENUM_MARKET_BIAS bias)
  {
   switch(bias)
     {
      case BIAS_BULLISH: return m_bull_color;
      case BIAS_BEARISH: return m_bear_color;
      default:           return m_neutral_color;
     }
  }

//+------------------------------------------------------------------+
//| Convert structure break to string                                |
//+------------------------------------------------------------------+
string CDashboard::BreakToString(ENUM_STRUCTURE_BREAK brk)
  {
   switch(brk)
     {
      case BREAK_BOS:   return "BOS";
      case BREAK_CHOCH: return "CHoCH";
      default:          return "---";
     }
  }

//+------------------------------------------------------------------+
//| Convert session to string                                        |
//+------------------------------------------------------------------+
string CDashboard::SessionToString(ENUM_SESSION_TYPE session)
  {
   switch(session)
     {
      case SESSION_ASIAN:        return "ASIAN";
      case SESSION_LONDON:       return "LONDON KZ";
      case SESSION_NY:           return "NEW YORK KZ";
      case SESSION_LONDON_CLOSE: return "LONDON CLOSE";
      case SESSION_SILVER_AM:    return "SILVER AM";
      case SESSION_SILVER_PM:    return "SILVER PM";
      default:                   return "OFF-SESSION";
     }
  }

//+------------------------------------------------------------------+
//| Convert signal quality to string                                 |
//+------------------------------------------------------------------+
string CDashboard::QualityToString(ENUM_SIGNAL_QUALITY quality)
  {
   switch(quality)
     {
      case SIGNAL_HIGH:   return "HIGH";
      case SIGNAL_MEDIUM: return "MEDIUM";
      case SIGNAL_LOW:    return "LOW";
      default:            return "NONE";
     }
  }

//+------------------------------------------------------------------+
//| Convert recovery state to string                                 |
//+------------------------------------------------------------------+
string CDashboard::RecoveryToString(ENUM_RECOVERY_STATE state)
  {
   switch(state)
     {
      case RECOVERY_WATCHING: return "WATCHING";
      case RECOVERY_ACTIVE:   return "ACTIVE";
      default:                return "OFF";
     }
  }

//+------------------------------------------------------------------+
//| Convert streak type to string                                    |
//+------------------------------------------------------------------+
string CDashboard::StreakToString(ENUM_STREAK_TYPE streak)
  {
   switch(streak)
     {
      case STREAK_WINNING: return "WINNING";
      case STREAK_LOSING:  return "LOSING";
      default:             return "---";
     }
  }

//+------------------------------------------------------------------+
//| Convert timeframe to short string                                |
//+------------------------------------------------------------------+
string CDashboard::TFToString(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "??";
     }
  }

//+------------------------------------------------------------------+
//| Update the entire dashboard                                      |
//+------------------------------------------------------------------+
void CDashboard::Update(const DashboardData &data)
  {
   int row = 0;
   int col1 = m_x + 8;            // Label column
   int col2 = m_x + 145;          // Value column
   int section_gap = 4;            // Extra pixels between sections
   int total_rows = 38;            // Estimated total rows

   //--- Background panel
   int panel_height = total_rows * m_line_height + 40;
   CreateRectangle("BG", m_x, m_y, m_width, panel_height, m_bg_color);

   //--- Title
   int cy = m_y + 6;
   CreateLabel("Title", m_x + 8, cy, "=== ZIPLOR EA v1.0 ===", m_header_color, m_font_size + 1, "Consolas Bold");
   cy += m_line_height + 4;

   //=== ACCOUNT SECTION ===
   CreateLabel("AccHdr", col1, cy, "--- ACCOUNT ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("BalLbl", col1, cy, "Balance:", m_text_color, m_font_size);
   CreateLabel("BalVal", col2, cy, FormatNumber(data.balance, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("EqLbl", col1, cy, "Equity:", m_text_color, m_font_size);
   color eq_clr = (data.equity >= data.balance) ? m_bull_color : m_bear_color;
   CreateLabel("EqVal", col2, cy, FormatNumber(data.equity, 2), eq_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("MarLbl", col1, cy, "Margin Used:", m_text_color, m_font_size);
   CreateLabel("MarVal", col2, cy, FormatNumber(data.margin_used, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("FreeLbl", col1, cy, "Free Margin:", m_text_color, m_font_size);
   CreateLabel("FreeVal", col2, cy, FormatNumber(data.free_margin, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("DPnlLbl", col1, cy, "Daily P&L:", m_text_color, m_font_size);
   color dpnl_clr = (data.daily_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("DPnlVal", col2, cy, FormatNumber(data.daily_pnl, 2), dpnl_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("WPnlLbl", col1, cy, "Weekly P&L:", m_text_color, m_font_size);
   color wpnl_clr = (data.weekly_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("WPnlVal", col2, cy, FormatNumber(data.weekly_pnl, 2), wpnl_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== POSITIONS SECTION ===
   CreateLabel("PosHdr", col1, cy, "--- POSITIONS ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("OpenLbl", col1, cy, "Open Positions:", m_text_color, m_font_size);
   CreateLabel("OpenVal", col2, cy, IntegerToString(data.open_positions), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("LotsLbl", col1, cy, "Total Lots:", m_text_color, m_font_size);
   CreateLabel("LotsVal", col2, cy, FormatNumber(data.total_lots, 2), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("FltLbl", col1, cy, "Floating P&L:", m_text_color, m_font_size);
   color flt_clr = (data.floating_pnl >= 0) ? m_bull_color : m_bear_color;
   CreateLabel("FltVal", col2, cy, FormatNumber(data.floating_pnl, 2), flt_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== MARKET STRUCTURE SECTION ===
   CreateLabel("MsHdr", col1, cy, "--- MARKET STRUCTURE ---", m_header_color, m_font_size);
   cy += m_line_height;

   //--- HTF
   string htf_str = TFToString(data.htf_structure.timeframe) + ":";
   CreateLabel("HtfLbl", col1, cy, htf_str, m_text_color, m_font_size);
   string htf_val = BiasToString(data.htf_structure.bias) + " " + BreakToString(data.htf_structure.last_break);
   CreateLabel("HtfVal", col2, cy, htf_val, BiasToColor(data.htf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- MTF
   string mtf_str = TFToString(data.mtf_structure.timeframe) + ":";
   CreateLabel("MtfLbl", col1, cy, mtf_str, m_text_color, m_font_size);
   string mtf_val = BiasToString(data.mtf_structure.bias) + " " + BreakToString(data.mtf_structure.last_break);
   CreateLabel("MtfVal", col2, cy, mtf_val, BiasToColor(data.mtf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- LTF
   string ltf_str = TFToString(data.ltf_structure.timeframe) + ":";
   CreateLabel("LtfLbl", col1, cy, ltf_str, m_text_color, m_font_size);
   string ltf_val = BiasToString(data.ltf_structure.bias) + " " + BreakToString(data.ltf_structure.last_break);
   CreateLabel("LtfVal", col2, cy, ltf_val, BiasToColor(data.ltf_structure.bias), m_font_size);
   cy += m_line_height;

   //--- Execution TF
   string exec_str = TFToString(data.exec_structure.timeframe) + ":";
   CreateLabel("ExecLbl", col1, cy, exec_str, m_text_color, m_font_size);
   string exec_val = BiasToString(data.exec_structure.bias) + " " + BreakToString(data.exec_structure.last_break);
   CreateLabel("ExecVal", col2, cy, exec_val, BiasToColor(data.exec_structure.bias), m_font_size);
   cy += m_line_height + section_gap;

   //=== SESSION SECTION ===
   CreateLabel("SesHdr", col1, cy, "--- SESSION ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("SesLbl", col1, cy, "Current:", m_text_color, m_font_size);
   color ses_clr = (data.current_session == SESSION_LONDON || data.current_session == SESSION_NY) ? m_bull_color : m_neutral_color;
   CreateLabel("SesVal", col2, cy, SessionToString(data.current_session), ses_clr, m_font_size);
   cy += m_line_height + section_gap;

   //=== SIGNAL SECTION ===
   CreateLabel("SigHdr", col1, cy, "--- SIGNAL ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("SigDirLbl", col1, cy, "Direction:", m_text_color, m_font_size);
   CreateLabel("SigDirVal", col2, cy, BiasToString(data.current_signal.direction),
               BiasToColor(data.current_signal.direction), m_font_size);
   cy += m_line_height;
   CreateLabel("SigQLbl", col1, cy, "Quality:", m_text_color, m_font_size);
   color q_clr = (data.current_signal.quality == SIGNAL_HIGH) ? m_bull_color :
                 (data.current_signal.quality == SIGNAL_MEDIUM) ? m_warning_color : m_neutral_color;
   CreateLabel("SigQVal", col2, cy, QualityToString(data.current_signal.quality) +
               " (" + IntegerToString(data.current_signal.confluence_count) + " conf)", q_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("SigRRLbl", col1, cy, "Risk:Reward:", m_text_color, m_font_size);
   CreateLabel("SigRRVal", col2, cy, "1:" + FormatNumber(data.current_signal.risk_reward, 1),
               m_text_color, m_font_size);
   cy += m_line_height + section_gap;

   //=== ANTI-MARTINGALE SECTION ===
   CreateLabel("AmHdr", col1, cy, "--- ANTI-MARTINGALE ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("AmStrkLbl", col1, cy, "Streak:", m_text_color, m_font_size);
   color strk_clr = (data.am_state.streak_type == STREAK_WINNING) ? m_bull_color :
                    (data.am_state.streak_type == STREAK_LOSING) ? m_bear_color : m_neutral_color;
   int streak_num = (data.am_state.streak_type == STREAK_WINNING) ? data.am_state.consecutive_wins :
                    data.am_state.consecutive_losses;
   CreateLabel("AmStrkVal", col2, cy, StreakToString(data.am_state.streak_type) + " x" +
               IntegerToString(streak_num), strk_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("AmRskLbl", col1, cy, "Current Risk:", m_text_color, m_font_size);
   CreateLabel("AmRskVal", col2, cy, FormatNumber(data.am_state.current_risk_pct, 2) + "%", m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("AmWRLbl", col1, cy, "Win/Loss:", m_text_color, m_font_size);
   CreateLabel("AmWRVal", col2, cy, IntegerToString(data.am_state.total_wins) + "/" +
               IntegerToString(data.am_state.total_losses), m_text_color, m_font_size);
   cy += m_line_height + section_gap;

   //=== RECOVERY SECTION ===
   CreateLabel("RecHdr", col1, cy, "--- RECOVERY MODE ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("RecStLbl", col1, cy, "Status:", m_text_color, m_font_size);
   color rec_clr = (data.recovery.state == RECOVERY_ACTIVE) ? m_warning_color :
                   (data.recovery.state == RECOVERY_WATCHING) ? m_bear_color : m_neutral_color;
   CreateLabel("RecStVal", col2, cy, RecoveryToString(data.recovery.state), rec_clr, m_font_size);
   cy += m_line_height;
   if(data.recovery.state != RECOVERY_OFF)
     {
      CreateLabel("RecLossLbl", col1, cy, "To Recover:", m_text_color, m_font_size);
      CreateLabel("RecLossVal", col2, cy, FormatNumber(data.recovery.loss_to_recover - data.recovery.recovered, 2),
                  m_bear_color, m_font_size);
      cy += m_line_height;
      CreateLabel("RecTrdLbl", col1, cy, "Recovery Trades:", m_text_color, m_font_size);
      CreateLabel("RecTrdVal", col2, cy, IntegerToString(data.recovery.recovery_trades) + "/" +
                  IntegerToString(data.recovery.max_recovery_trades), m_text_color, m_font_size);
      cy += m_line_height;
     }
   cy += section_gap;

   //=== STATISTICS SECTION ===
   CreateLabel("StatHdr", col1, cy, "--- STATISTICS ---", m_header_color, m_font_size);
   cy += m_line_height;
   CreateLabel("WinRLbl", col1, cy, "Win Rate:", m_text_color, m_font_size);
   color wr_clr = (data.win_rate >= 50.0) ? m_bull_color : m_bear_color;
   CreateLabel("WinRVal", col2, cy, FormatNumber(data.win_rate, 1) + "%", wr_clr, m_font_size);
   cy += m_line_height;
   CreateLabel("AvgRRLbl", col1, cy, "Avg R:R:", m_text_color, m_font_size);
   CreateLabel("AvgRRVal", col2, cy, "1:" + FormatNumber(data.avg_rr, 1), m_text_color, m_font_size);
   cy += m_line_height;
   CreateLabel("TotTLbl", col1, cy, "Total Trades:", m_text_color, m_font_size);
   CreateLabel("TotTVal", col2, cy, IntegerToString(data.total_trades), m_text_color, m_font_size);
   cy += m_line_height + 6;

   //--- Resize background to actual content
   panel_height = cy - m_y + 6;
   CreateRectangle("BG", m_x, m_y, m_width, panel_height, m_bg_color);

   ChartRedraw(0);
  }


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
   if(!g_smc.Init(_Symbol, InpSwingLookback, InpStructureLookback, InpMaxZones,
                  InpMinConfluence, InpMinRiskReward))
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
