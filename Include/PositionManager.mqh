//+------------------------------------------------------------------+
//|                                              PositionManager.mqh |
//|                                        Copyright 2026, Ziplor   |
//|                Position management, anti-martingale & hedging    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Ziplor"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Position manager class                                           |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   CTrade         m_trade;
   string         m_symbol;
   long           m_magicNumber;
   long           m_hedgeMagic;      // Separate magic for hedge orders
   double         m_baseLot;
   double         m_maxLot;
   double         m_lotStep;
   double         m_antiMartMultiplier;  // Lot increase factor on win
   double         m_antiMartDecrease;    // Lot decrease factor on loss
   double         m_hedgeDrawdownPct;    // Drawdown % to trigger hedge
   int            m_consecutiveWins;
   int            m_consecutiveLosses;
   double         m_currentLot;

   double         CalculateDrawdownPercent(void);
   double         GetNetProfit(void);
   double         GetTotalVolume(ENUM_POSITION_TYPE type);

public:
                  CPositionManager(void);
                 ~CPositionManager(void) {}

   void           Init(string symbol, long magic, double baseLot, double maxLot,
                       double antiMartMultiplier, double antiMartDecrease,
                       double hedgeDrawdownPct, ulong slippage);
   double         GetNextLotSize(void);
   void           UpdateAfterClose(double lastProfit);
   bool           OpenPosition(ENUM_POSITION_TYPE type, double sl, double tp);
   bool           CloseAllPositions(void);
   bool           ClosePositionsByMagic(long magic);
   bool           HasOpenPosition(void);
   bool           HasHedgePosition(void);
   int            CountPositions(ENUM_POSITION_TYPE type);
   bool           CheckAndHedge(void);
   double         CalculateHedgeLot(void);
   bool           CloseHedgeIfRecovered(void);
   double         GetCurrentLot(void) { return m_currentLot; }
   int            GetConsecutiveWins(void) { return m_consecutiveWins; }
   int            GetConsecutiveLosses(void) { return m_consecutiveLosses; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager(void)
   : m_symbol(""), m_magicNumber(0), m_hedgeMagic(0), m_baseLot(0.01),
     m_maxLot(1.0), m_lotStep(0.01), m_antiMartMultiplier(1.5),
     m_antiMartDecrease(0.5), m_hedgeDrawdownPct(5.0),
     m_consecutiveWins(0), m_consecutiveLosses(0), m_currentLot(0.01)
{
}

//+------------------------------------------------------------------+
//| Initialize position manager                                      |
//+------------------------------------------------------------------+
void CPositionManager::Init(string symbol, long magic, double baseLot, double maxLot,
                            double antiMartMultiplier, double antiMartDecrease,
                            double hedgeDrawdownPct, ulong slippage)
{
   m_symbol              = symbol;
   m_magicNumber         = magic;
   m_hedgeMagic          = magic + 1;
   m_baseLot             = baseLot;
   m_maxLot              = maxLot;
   m_antiMartMultiplier  = antiMartMultiplier;
   m_antiMartDecrease    = antiMartDecrease;
   m_hedgeDrawdownPct    = hedgeDrawdownPct;
   m_currentLot          = baseLot;
   m_lotStep             = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetTypeFilling(ORDER_FILLING_IOC);
}

//+------------------------------------------------------------------+
//| Calculate next lot size using anti-martingale                     |
//| Increase on consecutive wins, decrease on losses                 |
//+------------------------------------------------------------------+
double CPositionManager::GetNextLotSize(void)
{
   double lot = m_baseLot;

   // Anti-martingale: increase lot on consecutive wins
   if(m_consecutiveWins > 0)
   {
      lot = m_baseLot * MathPow(m_antiMartMultiplier, m_consecutiveWins);
   }
   // Decrease lot on consecutive losses
   else if(m_consecutiveLosses > 0)
   {
      lot = m_baseLot * MathPow(m_antiMartDecrease, m_consecutiveLosses);
   }

   // Normalize to lot step
   lot = MathFloor(lot / m_lotStep) * m_lotStep;

   // Clamp to min/max
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, m_maxLot);

   m_currentLot = lot;
   return lot;
}

//+------------------------------------------------------------------+
//| Update consecutive win/loss counters after a trade closes        |
//+------------------------------------------------------------------+
void CPositionManager::UpdateAfterClose(double lastProfit)
{
   if(lastProfit > 0)
   {
      m_consecutiveWins++;
      m_consecutiveLosses = 0;
   }
   else if(lastProfit < 0)
   {
      m_consecutiveLosses++;
      m_consecutiveWins = 0;
   }
   // If breakeven (0), keep counters as-is
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CPositionManager::OpenPosition(ENUM_POSITION_TYPE type, double sl, double tp)
{
   double lot = GetNextLotSize();

   m_trade.SetExpertMagicNumber(m_magicNumber);

   if(type == POSITION_TYPE_BUY)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      return m_trade.Buy(lot, m_symbol, ask, sl, tp, "Ziplor Buy");
   }
   else
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      return m_trade.Sell(lot, m_symbol, bid, sl, tp, "Ziplor Sell");
   }
}

//+------------------------------------------------------------------+
//| Check if we have an open position (main EA magic)                |
//+------------------------------------------------------------------+
bool CPositionManager::HasOpenPosition(void)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if we have a hedge position                                |
//+------------------------------------------------------------------+
bool CPositionManager::HasHedgePosition(void)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_hedgeMagic)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Count positions of a given type (main magic only)                |
//+------------------------------------------------------------------+
int CPositionManager::CountPositions(ENUM_POSITION_TYPE type)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber &&
            PositionGetInteger(POSITION_TYPE) == type)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions for our magic number                         |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAllPositions(void)
{
   bool result = true;
   result &= ClosePositionsByMagic(m_magicNumber);
   result &= ClosePositionsByMagic(m_hedgeMagic);
   return result;
}

//+------------------------------------------------------------------+
//| Close positions by magic number                                  |
//+------------------------------------------------------------------+
bool CPositionManager::ClosePositionsByMagic(long magic)
{
   bool result = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if(!m_trade.PositionClose(ticket))
               result = false;
         }
      }
   }
   return result;
}

//+------------------------------------------------------------------+
//| Get net floating profit for all EA positions                     |
//+------------------------------------------------------------------+
double CPositionManager::GetNetProfit(void)
{
   double profit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(magic == m_magicNumber || magic == m_hedgeMagic)
         {
            profit += PositionGetDouble(POSITION_PROFIT)
                    + PositionGetDouble(POSITION_SWAP);
         }
      }
   }
   return profit;
}

//+------------------------------------------------------------------+
//| Calculate drawdown percentage of account                         |
//+------------------------------------------------------------------+
double CPositionManager::CalculateDrawdownPercent(void)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return 0;

   double netProfit = GetNetProfit();
   if(netProfit >= 0) return 0;

   return MathAbs(netProfit) / balance * 100.0;
}

//+------------------------------------------------------------------+
//| Get total volume for a position type across both magics          |
//+------------------------------------------------------------------+
double CPositionManager::GetTotalVolume(ENUM_POSITION_TYPE type)
{
   double volume = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol)
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         if((magic == m_magicNumber || magic == m_hedgeMagic) &&
            PositionGetInteger(POSITION_TYPE) == type)
         {
            volume += PositionGetDouble(POSITION_VOLUME);
         }
      }
   }
   return volume;
}

//+------------------------------------------------------------------+
//| Calculate hedge lot size based on overall drawdown               |
//| The hedge lot covers the losing side to freeze drawdown          |
//+------------------------------------------------------------------+
double CPositionManager::CalculateHedgeLot(void)
{
   double buyVol  = GetTotalVolume(POSITION_TYPE_BUY);
   double sellVol = GetTotalVolume(POSITION_TYPE_SELL);

   // Hedge lot = difference to neutralize net exposure
   double hedgeLot = MathAbs(buyVol - sellVol);

   // Normalize
   hedgeLot = MathFloor(hedgeLot / m_lotStep) * m_lotStep;

   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   hedgeLot = MathMax(hedgeLot, minLot);
   hedgeLot = MathMin(hedgeLot, m_maxLot);

   return hedgeLot;
}

//+------------------------------------------------------------------+
//| Check drawdown and open hedge if threshold is breached           |
//+------------------------------------------------------------------+
bool CPositionManager::CheckAndHedge(void)
{
   if(!HasOpenPosition()) return false;
   if(HasHedgePosition()) return false;

   double dd = CalculateDrawdownPercent();

   if(dd >= m_hedgeDrawdownPct)
   {
      double hedgeLot = CalculateHedgeLot();

      // Determine which side to hedge: opposite of current main position
      double buyVol  = GetTotalVolume(POSITION_TYPE_BUY);
      double sellVol = GetTotalVolume(POSITION_TYPE_SELL);

      m_trade.SetExpertMagicNumber(m_hedgeMagic);

      bool result = false;
      if(buyVol > sellVol)
      {
         // Main is net long, hedge with sell
         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         result = m_trade.Sell(hedgeLot, m_symbol, bid, 0, 0, "Ziplor Hedge Sell");
      }
      else
      {
         // Main is net short, hedge with buy
         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         result = m_trade.Buy(hedgeLot, m_symbol, ask, 0, 0, "Ziplor Hedge Buy");
      }

      // Restore main magic
      m_trade.SetExpertMagicNumber(m_magicNumber);

      if(result)
         PrintFormat("Ziplor: Hedge opened. DD=%.2f%%, HedgeLot=%.2f", dd, hedgeLot);

      return result;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close hedge if account has recovered (net profit >= 0)           |
//+------------------------------------------------------------------+
bool CPositionManager::CloseHedgeIfRecovered(void)
{
   if(!HasHedgePosition()) return false;

   double netProfit = GetNetProfit();

   // Close hedge when overall floating profit recovers above zero
   if(netProfit >= 0)
   {
      PrintFormat("Ziplor: Recovery achieved. NetProfit=%.2f. Closing hedge.", netProfit);
      return ClosePositionsByMagic(m_hedgeMagic);
   }
   return false;
}
//+------------------------------------------------------------------+
