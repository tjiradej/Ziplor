//+------------------------------------------------------------------+
//|                                                       Ziplor.mq5 |
//|                                          Copyright 2025, Ziplor  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Ziplor"
#property link      ""
#property version   "1.00"
#property strict

//--- Input parameters
input int      PointInterval = 20;        // Points interval between orders
input int      NumberOfLevels = 20;       // Number of levels above and below
input double   ProfitTarget = 20.0;       // Profit target in USD
input double   LotSize = 0.01;            // Lot size for each order
input int      MagicNumber = 123456;      // Magic number for order identification

//--- Global variables
bool ordersPlaced = false;
datetime lastCheckTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Ziplor EA initialized successfully");
   Print("Point Interval: ", PointInterval);
   Print("Number of Levels: ", NumberOfLevels);
   Print("Profit Target: $", ProfitTarget);
   Print("Lot Size: ", LotSize);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Ziplor EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we need to place orders
   if(!ordersPlaced)
   {
      PlaceAllOrders();
      ordersPlaced = true;
   }
   
   // Check profit every second to avoid excessive calculations
   if(TimeCurrent() - lastCheckTime >= 1)
   {
      lastCheckTime = TimeCurrent();
      
      // Check account profit
      double accountProfit = GetAccountProfit();
      
      if(accountProfit >= ProfitTarget)
      {
         Print("Profit target reached: $", accountProfit);
         CloseAllPositions();
         DeleteAllPendingOrders();
         ordersPlaced = false; // Will place new orders on next tick
      }
   }
}

//+------------------------------------------------------------------+
//| Place all buy and sell stop orders                               |
//+------------------------------------------------------------------+
void PlaceAllOrders()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pointsInPrice = PointInterval * point;
   
   Print("Placing orders. Current price: ", currentPrice);
   
   // Place BUY STOP orders above current price
   for(int i = 1; i <= NumberOfLevels; i++)
   {
      double price = NormalizeDouble(currentPrice + (i * pointsInPrice), digits);
      PlaceBuyStop(price);
   }
   
   // Place SELL STOP orders below current price
   for(int i = 1; i <= NumberOfLevels; i++)
   {
      double price = NormalizeDouble(currentPrice - (i * pointsInPrice), digits);
      PlaceSellStop(price);
   }
   
   Print("All orders placed successfully");
}

//+------------------------------------------------------------------+
//| Place a BUY STOP order                                           |
//+------------------------------------------------------------------+
void PlaceBuyStop(double price)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY_STOP;
   request.price = price;
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Ziplor BUY STOP";
   
   if(!OrderSend(request, result))
   {
      Print("BUY STOP order failed. Error: ", GetLastError(), 
            ", Price: ", price, ", ResultRetcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Place a SELL STOP order                                          |
//+------------------------------------------------------------------+
void PlaceSellStop(double price)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = ORDER_TYPE_SELL_STOP;
   request.price = price;
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Ziplor SELL STOP";
   
   if(!OrderSend(request, result))
   {
      Print("SELL STOP order failed. Error: ", GetLastError(), 
            ", Price: ", price, ", ResultRetcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Calculate total account profit from our positions                |
//+------------------------------------------------------------------+
double GetAccountProfit()
{
   double totalProfit = 0.0;
   
   // Check all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   Print("Closing all positions...");
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = _Symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                          ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            request.deviation = 10;
            request.magic = MagicNumber;
            
            if(!OrderSend(request, result))
            {
               Print("Failed to close position. Ticket: ", ticket, 
                     ", Error: ", GetLastError());
            }
         }
      }
   }
   
   Print("All positions closed");
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   Print("Deleting all pending orders...");
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
            OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         {
            MqlTradeRequest request;
            MqlTradeResult result;
            
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = ticket;
            
            if(!OrderSend(request, result))
            {
               Print("Failed to delete order. Ticket: ", ticket, 
                     ", Error: ", GetLastError());
            }
         }
      }
   }
   
   Print("All pending orders deleted");
}
//+------------------------------------------------------------------+
