//+------------------------------------------------------------------+
//|                                                 ZiplorEnums.mqh  |
//|                        Copyright 2026, Ziplor Project            |
//|                        https://github.com/tjiradej/Ziplor       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor Project"
#property link      "https://github.com/tjiradej/Ziplor"
#property strict

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
