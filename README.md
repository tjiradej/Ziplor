# Ziplor MT5 Expert Advisor

An MT5 Expert Advisor that automatically places buy and sell stop orders at regular intervals and manages profit targets.

## Features

- Places 20 BUY STOP orders at 20-point intervals above the current market price
- Places 20 SELL STOP orders at 20-point intervals below the current market price
- Continuously monitors account profit
- Automatically closes all positions and deletes pending orders when total profit reaches $20 USD or more
- Restarts the process by placing fresh orders after closing

## Installation

1. Copy `Ziplor.mq5` to your MetaTrader 5 `MQL5/Experts` folder
2. Compile the EA in MetaEditor (F7) or it will compile automatically when you first attach it to a chart
3. Attach the EA to any chart in MT5

## Input Parameters

- **PointInterval** (default: 20): The number of points between each order level
- **NumberOfLevels** (default: 20): The number of order levels to place above and below current price
- **ProfitTarget** (default: 20.0): The profit target in USD - when reached, all positions will be closed
- **LotSize** (default: 0.01): The lot size for each order
- **MagicNumber** (default: 123456): Unique identifier for orders placed by this EA

## How It Works

1. **Initialization**: When the EA starts, it initializes with the configured parameters
2. **Order Placement**: On the first tick, the EA places:
   - 20 BUY STOP orders starting 20 points above current price and continuing at 20-point intervals
   - 20 SELL STOP orders starting 20 points below current price and continuing at 20-point intervals
3. **Profit Monitoring**: Every second, the EA calculates the total profit from all open positions
4. **Profit Target**: When total profit reaches $20 or more:
   - All open positions are closed
   - All pending orders are deleted
   - The EA resets and will place fresh orders on the next tick
5. **Continuous Operation**: The cycle repeats indefinitely

## Risk Warning

⚠️ **Important**: This EA is for educational purposes. Trading forex carries substantial risk and may not be suitable for all investors. Please ensure you:
- Test thoroughly on a demo account before using real money
- Understand the risks involved
- Adjust lot sizes according to your account size and risk tolerance
- Monitor the EA's performance regularly

## Technical Details

- Written in MQL5 for MetaTrader 5 platform
- Uses pending orders (BUY STOP and SELL STOP)
- Magic number system to track EA-specific orders
- Automatic profit monitoring and position management

## License

Copyright 2025, Ziplor
