//+------------------------------------------------------------------+
//|                                            ZiplorSMCEngine.mqh   |
//|                        Copyright 2026, Ziplor Project            |
//|                        https://github.com/tjiradej/Ziplor       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor Project"
#property link      "https://github.com/tjiradej/Ziplor"
#property strict

#include "ZiplorStructures.mqh"

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
   bool              Init(string symbol, int swing_lookback, int structure_lookback, int max_zones);

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
bool CSMCEngine::Init(string symbol, int swing_lookback, int structure_lookback, int max_zones)
  {
   m_symbol = symbol;
   m_swing_lookback = MathMax(swing_lookback, 2);
   m_structure_lookback = MathMax(structure_lookback, 20);
   m_max_zones = MathMax(max_zones, 5);

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
   int min_confluence = 4; // Minimum confluences required
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
      signal.valid = (signal.risk_reward >= 2.0 && signal.risk_reward <= 15.0);
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
