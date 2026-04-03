//+------------------------------------------------------------------+
//|                                                SwingDetector.mqh |
//|                                        Copyright 2026, Ziplor   |
//|                          Swing point detection for Dow Theory    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor"
#property strict

//+------------------------------------------------------------------+
//| Swing point structure                                            |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isHigh;  // true = swing high, false = swing low
};

//+------------------------------------------------------------------+
//| Trend type enumeration                                           |
//+------------------------------------------------------------------+
enum ENUM_DOW_TREND
{
   DOW_TREND_UP,       // Uptrend: HH + HL
   DOW_TREND_DOWN,     // Downtrend: LL + LH
   DOW_TREND_NEUTRAL   // No clear trend
};

//+------------------------------------------------------------------+
//| Swing detector class                                             |
//+------------------------------------------------------------------+
class CSwingDetector
{
private:
   int            m_swingStrength;  // Bars on each side to confirm swing
   string         m_symbol;
   ENUM_TIMEFRAMES m_timeframe;

public:
                  CSwingDetector(void);
                 ~CSwingDetector(void) {}

   void           Init(string symbol, ENUM_TIMEFRAMES tf, int swingStrength);
   bool           FindSwingHighs(SwingPoint &highs[], int maxPoints, int startBar = 1);
   bool           FindSwingLows(SwingPoint &lows[], int maxPoints, int startBar = 1);
   ENUM_DOW_TREND DetermineTrend(int maxSwingPoints = 4);
   bool           IsSwingHigh(int bar);
   bool           IsSwingLow(int bar);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSwingDetector::CSwingDetector(void)
   : m_swingStrength(3), m_symbol(""), m_timeframe(PERIOD_CURRENT)
{
}

//+------------------------------------------------------------------+
//| Initialize detector                                              |
//+------------------------------------------------------------------+
void CSwingDetector::Init(string symbol, ENUM_TIMEFRAMES tf, int swingStrength)
{
   m_symbol        = symbol;
   m_timeframe     = tf;
   m_swingStrength = swingStrength;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing high                                     |
//+------------------------------------------------------------------+
bool CSwingDetector::IsSwingHigh(int bar)
{
   double high[];
   int total = m_swingStrength * 2 + 1;
   int startBar = bar - m_swingStrength;
   if(startBar < 0) return false;

   if(CopyHigh(m_symbol, m_timeframe, startBar, total, high) != total)
      return false;

   int centerIdx = m_swingStrength;
   double centerHigh = high[centerIdx];

   for(int i = 0; i < total; i++)
   {
      if(i == centerIdx) continue;
      if(high[i] >= centerHigh) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing low                                      |
//+------------------------------------------------------------------+
bool CSwingDetector::IsSwingLow(int bar)
{
   double low[];
   int total = m_swingStrength * 2 + 1;
   int startBar = bar - m_swingStrength;
   if(startBar < 0) return false;

   if(CopyLow(m_symbol, m_timeframe, startBar, total, low) != total)
      return false;

   int centerIdx = m_swingStrength;
   double centerLow = low[centerIdx];

   for(int i = 0; i < total; i++)
   {
      if(i == centerIdx) continue;
      if(low[i] <= centerLow) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Find recent swing highs                                          |
//+------------------------------------------------------------------+
bool CSwingDetector::FindSwingHighs(SwingPoint &highs[], int maxPoints, int startBar = 1)
{
   ArrayResize(highs, 0);
   int found = 0;

   for(int bar = startBar + m_swingStrength; found < maxPoints && bar < 500; bar++)
   {
      if(IsSwingHigh(bar))
      {
         SwingPoint sp;
         double h[];
         datetime t[];
         if(CopyHigh(m_symbol, m_timeframe, bar, 1, h) == 1 &&
            CopyTime(m_symbol, m_timeframe, bar, 1, t) == 1)
         {
            sp.price    = h[0];
            sp.time     = t[0];
            sp.barIndex = bar;
            sp.isHigh   = true;
            ArrayResize(highs, found + 1);
            highs[found] = sp;
            found++;
         }
      }
   }
   return (found >= 2);
}

//+------------------------------------------------------------------+
//| Find recent swing lows                                           |
//+------------------------------------------------------------------+
bool CSwingDetector::FindSwingLows(SwingPoint &lows[], int maxPoints, int startBar = 1)
{
   ArrayResize(lows, 0);
   int found = 0;

   for(int bar = startBar + m_swingStrength; found < maxPoints && bar < 500; bar++)
   {
      if(IsSwingLow(bar))
      {
         SwingPoint sp;
         double l[];
         datetime t[];
         if(CopyLow(m_symbol, m_timeframe, bar, 1, l) == 1 &&
            CopyTime(m_symbol, m_timeframe, bar, 1, t) == 1)
         {
            sp.price    = l[0];
            sp.time     = t[0];
            sp.barIndex = bar;
            sp.isHigh   = false;
            ArrayResize(lows, found + 1);
            lows[found] = sp;
            found++;
         }
      }
   }
   return (found >= 2);
}

//+------------------------------------------------------------------+
//| Determine trend using Dow Theory (HH/HL = up, LL/LH = down)     |
//+------------------------------------------------------------------+
ENUM_DOW_TREND CSwingDetector::DetermineTrend(int maxSwingPoints = 4)
{
   SwingPoint highs[];
   SwingPoint lows[];

   bool hasHighs = FindSwingHighs(highs, maxSwingPoints);
   bool hasLows  = FindSwingLows(lows, maxSwingPoints);

   if(!hasHighs || !hasLows)
      return DOW_TREND_NEUTRAL;

   // highs[0] is the most recent swing high, highs[1] is the previous one
   // Check for Higher Highs (HH): most recent high > previous high
   bool higherHigh = (highs[0].price > highs[1].price);
   // Check for Lower Lows (LL): most recent low < previous low
   bool lowerLow   = (lows[0].price < lows[1].price);
   // Check for Higher Lows (HL): most recent low > previous low
   bool higherLow  = (lows[0].price > lows[1].price);
   // Check for Lower Highs (LH): most recent high < previous high
   bool lowerHigh  = (highs[0].price < highs[1].price);

   // Uptrend: Higher Highs AND Higher Lows
   if(higherHigh && higherLow)
      return DOW_TREND_UP;

   // Downtrend: Lower Lows AND Lower Highs
   if(lowerLow && lowerHigh)
      return DOW_TREND_DOWN;

   return DOW_TREND_NEUTRAL;
}
//+------------------------------------------------------------------+
