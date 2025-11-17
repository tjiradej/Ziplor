# Ziplor EA - Technical Documentation

## Architecture Overview

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                        Ziplor EA                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────┐  │
│  │   OnInit()   │───>│   OnTick()   │───>│ PlaceOrders │  │
│  │              │    │              │    │   Module    │  │
│  │ - Load params│    │ - Main loop  │    │             │  │
│  │ - Initialize │    │ - Check      │    │ - 20 BUY    │  │
│  └──────────────┘    │   profit     │    │ - 20 SELL   │  │
│                      │ - Trigger    │    └─────────────┘  │
│                      │   actions    │                      │
│                      └──────┬───────┘                      │
│                             │                              │
│                    ┌────────┴──────────┐                  │
│                    │                   │                  │
│            ┌───────▼────────┐  ┌──────▼───────┐          │
│            │ Profit Monitor │  │ Order Manager│          │
│            │                │  │              │          │
│            │ - Calculate P/L│  │ - Close all  │          │
│            │ - Check $20    │  │ - Delete all │          │
│            │   target       │  │ - Reset flag │          │
│            └────────────────┘  └──────────────┘          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## State Machine

```
┌─────────────┐
│   STARTUP   │
│  (OnInit)   │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  PLACE ORDERS   │<─────────┐
│                 │          │
│ - 20 BUY STOP   │          │
│ - 20 SELL STOP  │          │
└──────┬──────────┘          │
       │                     │
       ▼                     │
┌─────────────────┐          │
│  MONITORING     │          │
│                 │          │
│ Check profit    │          │
│ every second    │          │
└──────┬──────────┘          │
       │                     │
       │ Profit < $20        │
       └─────────────────────┘
       │
       │ Profit >= $20
       ▼
┌─────────────────┐
│  CLOSE & RESET  │
│                 │
│ - Close all pos │
│ - Delete orders │
│ - Reset flag    │
└──────┬──────────┘
       │
       └─────────────────────┘ (Loop back to PLACE ORDERS)
```

## Order Placement Strategy

### Example with EURUSD at 1.10000

```
BUY STOP Orders (Above market):
─────────────────────────────────
1.10400 ← Level 20 (+400 points)
1.10380 ← Level 19 (+380 points)
1.10360 ← Level 18 (+360 points)
   ...
1.10060 ← Level 3 (+60 points)
1.10040 ← Level 2 (+40 points)
1.10020 ← Level 1 (+20 points)
───────────────────────────────── ← Current Price: 1.10000
1.09980 ← Level 1 (-20 points)
1.09960 ← Level 2 (-40 points)
1.09940 ← Level 3 (-60 points)
   ...
1.09640 ← Level 18 (-360 points)
1.09620 ← Level 19 (-380 points)
1.09600 ← Level 20 (-400 points)
─────────────────────────────────
SELL STOP Orders (Below market)
```

### Price Movement Scenarios

**Scenario 1: Upward Movement**
```
Current: 1.10000
Price moves to 1.10050
  → BUY STOP at 1.10020 triggers (now active position)
  → BUY STOP at 1.10040 triggers (now active position)
  → Other BUY STOP orders remain pending
  → All SELL STOP orders remain pending
```

**Scenario 2: Downward Movement**
```
Current: 1.10000
Price moves to 1.09950
  → SELL STOP at 1.09980 triggers (now active position)
  → SELL STOP at 1.09960 triggers (now active position)
  → Other SELL STOP orders remain pending
  → All BUY STOP orders remain pending
```

**Scenario 3: Volatile Market**
```
Price swings between 1.09900 and 1.10100
  → Multiple BUY and SELL STOP orders trigger
  → Several active positions open
  → Profit accumulates from closed positions
  → When total profit reaches $20 → CLOSE ALL
```

## Profit Calculation Flow

```
┌──────────────────────────────────┐
│  GetAccountProfit() Function     │
├──────────────────────────────────┤
│                                  │
│  1. totalProfit = 0              │
│                                  │
│  2. For each open position:      │
│     ┌────────────────────┐       │
│     │ Check if:          │       │
│     │ - Symbol matches   │       │
│     │ - Magic# matches   │       │
│     └────────┬───────────┘       │
│              │                   │
│              ▼                   │
│     Add position profit          │
│     to totalProfit               │
│                                  │
│  3. Return totalProfit           │
│                                  │
└──────────────┬───────────────────┘
               │
               ▼
        ┌──────────────┐
        │ Compare with │
        │ $20 target   │
        └──────┬───────┘
               │
     ┌─────────┴─────────┐
     │                   │
     ▼                   ▼
  < $20              >= $20
  Continue       Close & Restart
```

## Function Call Hierarchy

```
OnTick()
├── PlaceAllOrders()
│   ├── PlaceBuyStop() × 20
│   └── PlaceSellStop() × 20
├── GetAccountProfit()
└── If profit >= target:
    ├── CloseAllPositions()
    └── DeleteAllPendingOrders()
```

## Data Structures

### Input Parameters
```mql5
input int      PointInterval = 20;     // 20 points between orders
input int      NumberOfLevels = 20;    // 20 levels each direction
input double   ProfitTarget = 20.0;    // $20 USD profit target
input double   LotSize = 0.01;         // 0.01 lots per order
input int      MagicNumber = 123456;   // EA identifier
```

### Global Variables
```mql5
bool ordersPlaced = false;      // Track if orders are placed
datetime lastCheckTime = 0;     // Last profit check timestamp
```

### Trade Request Structure
```mql5
MqlTradeRequest request;
├── action        // TRADE_ACTION_PENDING or TRADE_ACTION_DEAL
├── symbol        // Current symbol (_Symbol)
├── volume        // LotSize
├── type          // ORDER_TYPE_BUY_STOP or ORDER_TYPE_SELL_STOP
├── price         // Calculated price level
├── sl            // Stop Loss (0 = none)
├── tp            // Take Profit (0 = none)
├── deviation     // Max price deviation (10 points)
├── magic         // MagicNumber for identification
└── comment       // "Ziplor BUY STOP" or "Ziplor SELL STOP"
```

## Performance Characteristics

### Time Complexity
- Order placement: O(n) where n = NumberOfLevels × 2
- Profit calculation: O(m) where m = number of open positions
- Position closing: O(m) where m = number of open positions
- Order deletion: O(p) where p = number of pending orders

### Memory Usage
- Minimal: Only stores 2 global variables
- Input parameters: Fixed size
- Trade structures: Allocated on stack, automatically freed

### Network Calls
Each operation makes a call to the broker's server:
- PlaceBuyStop(): 1 call per order
- PlaceSellStop(): 1 call per order
- CloseAllPositions(): 1 call per position
- DeleteAllPendingOrders(): 1 call per order

Initial setup: 40 calls (20 buy + 20 sell)
Profit check: No network calls (local calculation)
Reset: ~40 calls to close/delete + 40 calls to place new orders

## Error Handling

The EA includes error handling for:
1. Order placement failures
2. Position closing failures
3. Order deletion failures

All errors are logged to the Experts tab with:
- Error code
- Relevant price/ticket information
- Return code from broker

## Configuration Examples

### Conservative Setup (Smaller Account)
```
PointInterval = 30     // Wider spacing
NumberOfLevels = 10    // Fewer orders
ProfitTarget = 10.0    // Lower target
LotSize = 0.01         // Micro lots
```

### Standard Setup (Medium Account)
```
PointInterval = 20     // Default spacing
NumberOfLevels = 20    // Default levels
ProfitTarget = 20.0    // Default target
LotSize = 0.05         // Small lots
```

### Aggressive Setup (Larger Account)
```
PointInterval = 15     // Tighter spacing
NumberOfLevels = 30    // More levels
ProfitTarget = 50.0    // Higher target
LotSize = 0.10         // Mini lots
```

## Testing Checklist

Before live deployment:
- [ ] Compile EA without errors
- [ ] Test on demo account for 1-2 weeks
- [ ] Verify order placement works correctly
- [ ] Verify profit calculation is accurate
- [ ] Verify close-all function works
- [ ] Verify restart logic works
- [ ] Test with different lot sizes
- [ ] Test with different point intervals
- [ ] Monitor margin requirements
- [ ] Check broker compatibility
- [ ] Review logs for errors

## Maintenance Notes

### Regular Checks
1. Monitor the Experts tab for errors
2. Verify orders are being placed correctly
3. Check margin levels regularly
4. Review profit calculations
5. Ensure EA is running (check for smiley face icon)

### When to Restart
- After changing input parameters
- If EA shows error icon
- After broker disconnect/reconnect
- When starting a new trading session

### Backup Strategy
Always maintain:
1. Original Ziplor.mq5 file
2. Compiled Ziplor.ex5 file
3. Configuration settings documented
4. Trading logs for analysis
