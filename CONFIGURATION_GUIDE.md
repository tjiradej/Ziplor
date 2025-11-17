# Ziplor EA - Advanced Configuration Guide

## Parameter Optimization Guide

### Timeframe Recommendations

#### M15 (15-minute charts)
```
FastMA_Period = 8
SlowMA_Period = 21
RSI_Period = 14
TakeProfitPoints = 80
StopLossPoints = 40
TrailingStopPoints = 25
```

#### H1 (1-hour charts)
```
FastMA_Period = 10
SlowMA_Period = 30
RSI_Period = 14
TakeProfitPoints = 150
StopLossPoints = 75
TrailingStopPoints = 50
```

#### H4 (4-hour charts)
```
FastMA_Period = 12
SlowMA_Period = 36
RSI_Period = 14
TakeProfitPoints = 300
StopLossPoints = 150
TrailingStopPoints = 100
```

#### D1 (Daily charts)
```
FastMA_Period = 9
SlowMA_Period = 21
RSI_Period = 14
TakeProfitPoints = 500
StopLossPoints = 250
TrailingStopPoints = 150
```

### Instrument-Specific Settings

#### EUR/USD
- MaxSpreadPoints: 15
- RiskPercent: 1.0
- Use trailing stop: Yes
- Trade only trend: Yes

#### GBP/USD
- MaxSpreadPoints: 20
- RiskPercent: 0.8
- Use trailing stop: Yes
- Trade only trend: Yes

#### Gold (XAU/USD)
- MaxSpreadPoints: 30
- RiskPercent: 0.5
- Use trailing stop: Yes
- TrailingStopPoints: 100
- StopLossPoints: 200
- TakeProfitPoints: 400

#### Crypto (BTC/USD)
- MaxSpreadPoints: 50
- RiskPercent: 0.5
- Use trailing stop: Yes
- TrailingStopPoints: 200
- StopLossPoints: 500
- TakeProfitPoints: 1000

### Risk Profiles

#### Conservative (Capital Preservation)
```
RiskPercent = 0.5
MinRiskReward = 2.0
UseTrailingStop = true
TradeOnlyTrend = true
CheckTradingHours = true (avoid news hours)
```

#### Moderate (Balanced Approach)
```
RiskPercent = 1.0
MinRiskReward = 1.5
UseTrailingStop = true
TradeOnlyTrend = true
CheckTradingHours = false
```

#### Aggressive (Higher Returns, Higher Risk)
```
RiskPercent = 2.0
MinRiskReward = 1.2
UseTrailingStop = true
TradeOnlyTrend = false
CheckTradingHours = false
```

## Advanced Strategies

### Trend Following Strategy
```
FastMA_Period = 12
SlowMA_Period = 26
RSI_Period = 14
RSI_Overbought = 75
RSI_Oversold = 25
TrendMAPeriod = 200
TradeOnlyTrend = true
```

### Range Trading Strategy
```
FastMA_Period = 8
SlowMA_Period = 20
RSI_Period = 14
RSI_Overbought = 65
RSI_Oversold = 35
TradeOnlyTrend = false
```

### Scalping Strategy (M5 charts)
```
FastMA_Period = 5
SlowMA_Period = 15
RSI_Period = 9
TakeProfitPoints = 30
StopLossPoints = 15
TrailingStopPoints = 10
TrailingStepPoints = 5
MaxSpreadPoints = 10
```

## Backtesting Guidelines

### Preparation
1. Use at least 1 year of historical data
2. Include different market conditions (trending, ranging)
3. Test on multiple timeframes
4. Consider transaction costs (spread, commission, slippage)

### Key Metrics to Monitor
- **Win Rate**: Should be > 40% for this strategy
- **Profit Factor**: Target > 1.5
- **Maximum Drawdown**: Should be < 20% of balance
- **Recovery Factor**: Profit / Max Drawdown should be > 3
- **Sharpe Ratio**: Risk-adjusted returns should be > 1.0

### Optimization Process
1. Start with default parameters
2. Optimize one parameter at a time
3. Use walk-forward analysis
4. Validate on out-of-sample data
5. Test robustness with different settings

## Live Trading Checklist

### Before Going Live
- [ ] Backtested with positive results
- [ ] Forward tested on demo account (minimum 1 month)
- [ ] Risk per trade is set appropriately
- [ ] Maximum spread filter is configured
- [ ] Trailing stop settings are tested
- [ ] Magic number is unique
- [ ] VPS or stable connection is available
- [ ] Account has sufficient margin

### Monitoring
- [ ] Check trades daily
- [ ] Review logs for errors
- [ ] Monitor drawdown levels
- [ ] Adjust parameters if market conditions change
- [ ] Keep trading journal
- [ ] Document all changes

### When to Stop
- Maximum drawdown reached (> 20%)
- Multiple consecutive losses (> 5)
- Win rate drops significantly
- Market conditions change drastically
- Technical issues persist

## Troubleshooting

### EA Not Trading
1. Check if AutoTrading is enabled
2. Verify account permissions
3. Check spread filter settings
4. Review trading hours settings
5. Ensure sufficient margin
6. Check Experts tab for error messages

### Frequent Errors
- **Error 130 (Invalid stops)**: Adjust SL/TP to meet broker requirements
- **Error 131 (Invalid volume)**: Check lot size calculation and broker limits
- **Error 133 (Trading disabled)**: Enable trading in terminal settings
- **Error 134 (Not enough money)**: Reduce position size or risk percent
- **Error 138 (Requote)**: Normal in fast markets, EA will retry

### Poor Performance
1. Verify spread is within normal range
2. Check if market conditions changed
3. Review parameter settings
4. Consider reducing risk
5. Check for slippage issues
6. Ensure server latency is low

## Performance Enhancement Tips

### Improve Fill Rates
- Use VPS near broker's server
- Enable both FOK and IOC filling modes
- Reduce slippage tolerance during volatile periods

### Reduce Drawdown
- Lower risk per trade
- Increase minimum risk:reward ratio
- Enable trend filter
- Add trading hours filter during news

### Increase Profitability
- Optimize parameters for specific instruments
- Use appropriate timeframe for market conditions
- Consider multiple instances on correlated pairs
- Review and adjust trailing stop settings

## Multi-Symbol Setup

### Running Multiple Instances
1. Use different magic numbers for each symbol
2. Ensure total risk doesn't exceed account limits
3. Consider correlation between instruments
4. Monitor aggregate exposure
5. Adjust parameters per instrument

### Recommended Combinations
- EUR/USD + GBP/USD + USD/JPY (different correlations)
- Gold + Silver (similar market drivers)
- Major indices (diversification)

## Version History and Updates

### Version 1.00 (Current)
- Initial release
- MT4 and MT5 support
- Moving Average + RSI strategy
- Trailing stop functionality
- Comprehensive error handling
- Dynamic position sizing

### Planned Features
- Additional strategy options
- News filter integration
- Multi-timeframe analysis
- Advanced money management
- Performance statistics dashboard

## Contact and Support

For additional support or custom modifications:
- Review documentation thoroughly
- Check log files for detailed error information
- Test changes on demo account first
- Keep records of all modifications
