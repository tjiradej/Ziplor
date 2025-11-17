# Ziplor Expert Advisor

A professional Expert Advisor (EA) for MetaTrader 4 and MetaTrader 5 platforms, designed for automated trading with robust error handling, comprehensive risk management, and proven trading strategies.

## Features

### Core Functionality
- **Multi-Platform Support**: Works on both MT4 and MT5
- **Proven Trading Strategy**: Moving Average crossover with RSI filter
- **Robust Error Handling**: Comprehensive error detection and recovery
- **Risk Management**: Dynamic position sizing based on account balance
- **Position Management**: Trailing stop functionality for profit protection

### Trading Strategy
The EA uses a combination of technical indicators for trade signals:
- **Fast/Slow EMA Crossover**: Identifies trend changes
- **RSI Filter**: Prevents trading in overbought/oversold conditions
- **Trend Filter**: Optional long-term MA to trade only with the trend
- **Spread Control**: Avoids trading during high spread conditions

### Risk Management
- **Percentage-Based Risk**: Risk a fixed percentage of account balance per trade
- **Dynamic Lot Sizing**: Automatically calculates position size based on stop loss
- **Maximum Spread Filter**: Prevents trading during unfavorable market conditions
- **Position Limits**: Controls maximum number of simultaneous positions

### Position Management
- **Automatic Stop Loss/Take Profit**: Every trade has defined risk/reward
- **Trailing Stop**: Optional trailing stop to lock in profits
- **Multiple Filling Modes**: Supports FOK and IOC order filling
- **Magic Number**: Allows multiple instances on different symbols

## Installation

### For MT5:
1. Copy `Ziplor_EA.mq5` to your MT5 data folder: `MQL5/Experts/`
2. Restart MT5 or refresh the Navigator panel
3. Drag the EA onto a chart
4. Configure the input parameters
5. Enable Auto Trading

### For MT4:
1. Copy `Ziplor_EA.mq4` to your MT4 data folder: `MQL4/Experts/`
2. Restart MT4 or refresh the Navigator panel
3. Drag the EA onto a chart
4. Configure the input parameters
5. Enable Auto Trading

## Configuration

### Trading Strategy Parameters
- **FastMA_Period** (default: 10): Fast moving average period
- **SlowMA_Period** (default: 30): Slow moving average period
- **RSI_Period** (default: 14): RSI indicator period
- **RSI_Overbought** (default: 70): RSI overbought level
- **RSI_Oversold** (default: 30): RSI oversold level

### Risk Management
- **RiskPercent** (default: 1.0): Risk per trade as percentage of account balance
- **MaxSpreadPoints** (default: 20.0): Maximum allowed spread in points
- **MinRiskReward** (default: 1.5): Minimum risk:reward ratio

### Position Management
- **TakeProfitPoints** (default: 100.0): Take profit in points
- **StopLossPoints** (default: 50.0): Stop loss in points
- **UseTrailingStop** (default: true): Enable trailing stop
- **TrailingStopPoints** (default: 30.0): Trailing stop distance in points
- **TrailingStepPoints** (default: 10.0): Minimum price movement to trail

### Trade Filtering
- **TradeOnlyTrend** (default: true): Only trade in direction of long-term trend
- **TrendMAPeriod** (default: 200): Period for trend identification MA
- **CheckTradingHours** (default: false): Enable trading hours filter
- **StartHour** (default: 8): Start of trading hours
- **EndHour** (default: 20): End of trading hours

### General Settings
- **TradeComment** (default: "Ziplor_EA"): Comment for trades
- **MagicNumber** (default: 123456): Unique identifier for EA trades
- **EnableLogging** (default: true): Enable detailed logging

## Usage Recommendations

### Getting Started
1. **Backtest First**: Always backtest on historical data before live trading
2. **Start Small**: Begin with minimum risk percentage (0.5-1%)
3. **Monitor Initial Trades**: Watch the first few trades closely
4. **Optimize Parameters**: Adjust settings based on your instrument and timeframe

### Best Practices
- Use on liquid markets with low spreads (Forex majors, popular indices)
- Recommended timeframes: M15, H1, H4
- Keep risk per trade between 0.5% - 2%
- Ensure stable internet connection
- Monitor the EA regularly, especially during high-impact news

### Risk Warning
- Past performance does not guarantee future results
- Trading involves substantial risk of loss
- Only trade with money you can afford to lose
- The EA should be used with proper risk management
- Always monitor your account and the EA's performance

## Error Handling

The EA includes comprehensive error handling:
- Invalid parameter validation at initialization
- Connection status checks before trading
- Order send retry logic with multiple filling modes
- Detailed error logging for troubleshooting
- Graceful handling of indicator calculation failures

## Technical Details

### Trade Entry Conditions
**Buy Signal:**
- Fast MA crosses above Slow MA
- RSI is not in oversold territory
- Price is above trend MA (if trend filter enabled)
- Spread is within acceptable range

**Sell Signal:**
- Fast MA crosses below Slow MA
- RSI is not in overbought territory
- Price is below trend MA (if trend filter enabled)
- Spread is within acceptable range

### Position Sizing
The EA calculates position size using the formula:
```
Lot Size = (Account Balance × Risk%) / (Stop Loss Points × Tick Value)
```

The calculated size is then:
- Normalized to the broker's lot step
- Limited by minimum and maximum lot sizes
- Rounded appropriately for the instrument

### Trailing Stop Logic
- Only activates when in profit
- Moves stop loss by TrailingStepPoints when price moves favorably
- Maintains minimum distance of TrailingStopPoints from current price
- Never moves stop loss in unfavorable direction

## Support

For issues, questions, or suggestions:
- Review the Experts tab logs in MT4/MT5 for detailed information
- Ensure EnableLogging is set to true for debugging
- Check that all prerequisites are met (account permissions, connection, etc.)

## License

Copyright 2024, Ziplor Trading

## Disclaimer

This Expert Advisor is provided for educational and research purposes. Trading financial instruments carries a high level of risk and may not be suitable for all investors. The developer is not responsible for any financial losses incurred through the use of this software. Always test thoroughly on a demo account before using real money.
