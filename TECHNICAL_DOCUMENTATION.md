# Ziplor EA - Technical Documentation

## Architecture Overview

### Design Principles
1. **Minimal Error Handling**: Comprehensive error detection and recovery mechanisms
2. **Profitability Focus**: Uses proven technical indicators with filtering
3. **Solid Order Execution**: Multiple retry mechanisms and order filling modes
4. **Risk Management**: Dynamic position sizing and exposure control
5. **Code Quality**: Clean, documented, and maintainable code structure

## Code Structure

### MT5 Version (Ziplor_EA.mq5)

#### Initialization (OnInit)
```
1. Validate input parameters
2. Create indicator handles
   - Fast EMA (iMA)
   - Slow EMA (iMA)
   - RSI (iRSI)
   - Trend MA (iMA)
3. Set arrays as series
4. Log initialization status
```

#### Main Loop (OnTick)
```
1. Get current tick data
2. Check if new bar formed (performance optimization)
3. Update indicator buffers
4. Validate trading conditions
5. Get trading signal
6. Manage existing positions (trailing stop)
7. Check if new position can be opened
8. Execute trade if signal present
```

#### Trade Execution Flow
```
Signal Generation → Validation → Position Sizing → Order Creation → Error Handling → Logging
```

### MT4 Version (Ziplor_EA.mq4)

Similar structure to MT5 but adapted for MT4 API:
- Uses direct indicator calls instead of handles
- Different order execution methods
- MT4-specific error codes and handling
- Compatible type definitions

## Technical Indicators

### Fast Moving Average (EMA)
- **Purpose**: Identify short-term trend
- **Default Period**: 10
- **Type**: Exponential
- **Applied to**: Close price

### Slow Moving Average (EMA)
- **Purpose**: Identify medium-term trend
- **Default Period**: 30
- **Type**: Exponential
- **Applied to**: Close price

### Relative Strength Index (RSI)
- **Purpose**: Filter overbought/oversold conditions
- **Default Period**: 14
- **Overbought Level**: 70
- **Oversold Level**: 30
- **Applied to**: Close price

### Trend Moving Average (SMA)
- **Purpose**: Identify long-term trend direction
- **Default Period**: 200
- **Type**: Simple
- **Applied to**: Close price

## Signal Generation Logic

### Buy Signal Conditions
All conditions must be TRUE:
1. `fastMA[current] > slowMA[current]` (currently above)
2. `fastMA[previous] <= slowMA[previous]` (previously at or below)
3. `RSI < RSI_Oversold` is FALSE (not oversold)
4. `Price > Trend_MA` (if trend filter enabled)
5. `Spread <= MaxSpread` (acceptable spread)

### Sell Signal Conditions
All conditions must be TRUE:
1. `fastMA[current] < slowMA[current]` (currently below)
2. `fastMA[previous] >= slowMA[previous]` (previously at or above)
3. `RSI > RSI_Overbought` is FALSE (not overbought)
4. `Price < Trend_MA` (if trend filter enabled)
5. `Spread <= MaxSpread` (acceptable spread)

### Signal Flow Diagram
```
New Bar → Update Indicators → Check Filters → Detect Crossover → Validate RSI → 
Check Trend → Verify Spread → Generate Signal
```

## Position Management

### Position Sizing Algorithm
```cpp
Step 1: Calculate risk amount
  riskAmount = accountBalance * (riskPercent / 100)

Step 2: Calculate lot size
  lots = riskAmount / (stopLossPoints * tickValue / tickSize)

Step 3: Normalize to lot step
  lots = floor(lots / lotStep) * lotStep

Step 4: Apply broker limits
  lots = max(minLot, min(lots, maxLot))

Step 5: Return normalized value
  return NormalizeDouble(lots, 2)
```

### Trailing Stop Algorithm
```cpp
For BUY positions:
  trailPrice = currentBid - trailingStopDistance
  if (trailPrice > currentSL + trailingStep) AND (trailPrice > openPrice):
    Update SL to trailPrice

For SELL positions:
  trailPrice = currentAsk + trailingStopDistance
  if (trailPrice < currentSL - trailingStep) AND (trailPrice < openPrice):
    Update SL to trailPrice
```

### Position Limits
- Maximum 1 position per symbol per EA instance
- Can be overridden by modifying `CanOpenNewPosition()` function
- Uses MagicNumber for position identification

## Error Handling

### Critical Errors (Initialization Fails)
```cpp
INIT_PARAMETERS_INCORRECT  // Invalid input parameters
INIT_FAILED                 // Indicator creation failed
```

### Runtime Errors (MT5)
```cpp
TRADE_RETCODE_DONE         // Success
TRADE_RETCODE_PLACED       // Order placed successfully
TRADE_RETCODE_REJECT       // Request rejected
TRADE_RETCODE_ERROR        // Generic error
TRADE_RETCODE_TIMEOUT      // Request timeout
TRADE_RETCODE_INVALID      // Invalid request
```

### Runtime Errors (MT4)
```cpp
ERR_NO_ERROR (0)           // Success
ERR_INVALID_STOPS (130)    // Invalid SL/TP
ERR_INVALID_TRADE_VOLUME (131) // Invalid lot size
ERR_MARKET_CLOSED (132)    // Market closed
ERR_NOT_ENOUGH_MONEY (134) // Insufficient funds
ERR_PRICE_CHANGED (135)    // Price changed (requote)
ERR_OFF_QUOTES (136)       // No quotes
ERR_BROKER_BUSY (137)      // Broker busy
ERR_REQUOTE (138)          // Requote occurred
```

### Error Recovery Strategies

#### Order Sending (MT5)
```cpp
1. Try ORDER_FILLING_FOK first
2. If fails, try ORDER_FILLING_IOC
3. Log error if both fail
4. Return control to main loop
```

#### Order Sending (MT4)
```cpp
1. Send order with 10 point slippage
2. If fails, log detailed error
3. Use ErrorDescription() for readable message
4. Return control to main loop
```

#### Indicator Updates
```cpp
1. Try to copy buffer
2. If fails, return false
3. Main loop skips this iteration
4. Retry on next tick
```

## Performance Optimizations

### New Bar Detection
```cpp
static datetime lastBarTime = 0;
datetime currentBarTime = iTime(...);
if (currentBarTime == lastBarTime) return;
```
**Benefit**: Reduces unnecessary calculations, only acts on new bars

### Array as Series
```cpp
ArraySetAsSeries(array, true);
```
**Benefit**: Direct access to recent data using [0], [1], [2] indexing

### Early Returns
```cpp
if (!CheckCondition()) return;
```
**Benefit**: Avoid unnecessary processing when conditions not met

### Buffer Management (MT5)
- Indicators use handles (created once in OnInit)
- Buffers updated only when needed
- Automatic memory management

## Testing Methodology

### Unit Testing Checklist
- [ ] Parameter validation
- [ ] Indicator initialization
- [ ] Signal generation logic
- [ ] Position sizing calculations
- [ ] Order sending mechanisms
- [ ] Trailing stop logic
- [ ] Error handling paths

### Integration Testing
- [ ] Full trade lifecycle (open → manage → close)
- [ ] Multiple concurrent positions
- [ ] Error scenarios (no connection, insufficient funds)
- [ ] Extreme market conditions (gaps, high volatility)

### Performance Testing
- [ ] CPU usage during execution
- [ ] Memory consumption
- [ ] Response time to market events
- [ ] Indicator calculation speed

## Security Considerations

### Input Validation
```cpp
- MA periods must be positive and logical
- RSI levels must be between 0-100
- Risk percent limited to 0-10%
- SL/TP must be positive
```

### Safe Defaults
- Conservative risk: 1%
- Reasonable spread filter: 20 points
- Proven indicator periods
- Trailing stop enabled

### Protection Mechanisms
- One position per symbol limit
- Spread filter prevents bad fills
- Minimum risk:reward ratio
- Account balance checks before trading

## Customization Points

### Easy Modifications

#### Change Strategy Logic
Location: `GetTradingSignal()` function
```cpp
// Replace MA crossover with custom logic
bool myCustomSignal = [your condition];
if (myCustomSignal && otherFilters) return 1; // Buy
```

#### Add New Filters
Location: `CheckTradingConditions()` function
```cpp
// Add volatility filter
double atr = iATR(...);
if (atr > maxVolatility) return false;
```

#### Modify Position Sizing
Location: `CalculatePositionSize()` function
```cpp
// Use fixed lot size instead
return 0.1; // Fixed 0.1 lots
```

#### Add New Indicator
```cpp
// In OnInit():
int myIndicator_handle = iCustom(...);

// In UpdateIndicators():
CopyBuffer(myIndicator_handle, 0, 0, 3, myBuffer);

// In GetTradingSignal():
bool myCondition = (myBuffer[1] > threshold);
```

### Advanced Modifications

#### Multi-Timeframe Analysis
```cpp
// Get higher timeframe trend
double htfMA = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_SMA, PRICE_CLOSE, 1);
bool htfUptrend = (iClose(Symbol(), PERIOD_CURRENT, 1) > htfMA);

// Use in signal generation
if (bullishSignal && htfUptrend) return 1;
```

#### Partial Close
```cpp
// Close 50% at first target
if (profit > firstTarget)
{
   double halfLots = PositionGetDouble(POSITION_VOLUME) / 2;
   // Send close request for halfLots
}
```

#### Grid Trading
```cpp
// Modify CanOpenNewPosition() to allow multiple positions
bool CanOpenNewPosition()
{
   int totalPositions = CountPositions();
   return (totalPositions < maxGridLevels);
}
```

## Code Maintenance

### Versioning Strategy
- Semantic versioning: MAJOR.MINOR.PATCH
- Current: 1.00 (initial release)
- Track changes in version history

### Code Quality Standards
- Consistent indentation (3 spaces)
- Descriptive variable names
- Comments for complex logic
- Error messages include context
- Input validation on all parameters

### Testing Before Release
1. Compile without errors/warnings
2. Backtest on multiple symbols
3. Forward test on demo (minimum 1 month)
4. Stress test with extreme parameters
5. Verify all error paths

## Future Enhancements

### Planned Features
1. **News Filter**: Avoid trading during high-impact news
2. **Multi-Timeframe Confirmation**: Require alignment across timeframes
3. **Advanced Money Management**: Martingale, anti-martingale options
4. **Performance Dashboard**: Real-time statistics
5. **Risk Manager**: Maximum drawdown protection
6. **Correlation Filter**: Avoid correlated positions

### Architecture Improvements
1. Separate strategy into include file
2. Create base EA class for inheritance
3. Add logging framework
4. Implement event system
5. Add performance analytics

## API Reference

### Main Functions

#### ValidateInputs()
```cpp
bool ValidateInputs()
```
**Purpose**: Validate all input parameters before trading
**Returns**: true if all parameters valid, false otherwise
**Called**: OnInit()

#### UpdateIndicators()
```cpp
bool UpdateIndicators()
```
**Purpose**: Copy indicator buffers from handles
**Returns**: true if successful, false if any buffer copy fails
**Called**: OnTick() on each new bar

#### CheckTradingConditions()
```cpp
bool CheckTradingConditions()
```
**Purpose**: Verify all preconditions for trading
**Returns**: true if can trade, false otherwise
**Called**: OnTick() before signal generation

#### GetTradingSignal()
```cpp
int GetTradingSignal()
```
**Purpose**: Generate trading signal based on indicators
**Returns**: 1 (buy), -1 (sell), 0 (no signal)
**Called**: OnTick() after conditions check

#### CanOpenNewPosition()
```cpp
bool CanOpenNewPosition()
```
**Purpose**: Check if new position can be opened
**Returns**: true if no existing position, false otherwise
**Called**: OnTick() before order sending

#### CalculatePositionSize()
```cpp
double CalculatePositionSize(double stopLossPoints)
```
**Purpose**: Calculate position size based on risk
**Parameters**: stopLossPoints - distance to SL in points
**Returns**: Lot size (normalized)
**Called**: Before opening any position

#### OpenBuyPosition()
```cpp
void OpenBuyPosition()
```
**Purpose**: Open a buy position at market
**Returns**: void
**Called**: When buy signal detected

#### OpenSellPosition()
```cpp
void OpenSellPosition()
```
**Purpose**: Open a sell position at market
**Returns**: void
**Called**: When sell signal detected

#### ManagePositions()
```cpp
void ManagePositions()
```
**Purpose**: Update trailing stops for open positions
**Returns**: void
**Called**: OnTick() every bar

### Global Variables

#### Indicator Handles (MT5)
```cpp
int fastMA_handle    // Fast MA handle
int slowMA_handle    // Slow MA handle
int rsi_handle       // RSI handle
int trendMA_handle   // Trend MA handle
```

#### Indicator Buffers
```cpp
double fastMA[]      // Fast MA values
double slowMA[]      // Slow MA values
double rsi[]         // RSI values
double trendMA[]     // Trend MA values
```

#### Trade Structures (MT5)
```cpp
MqlTick lastTick           // Last tick data
MqlTradeRequest request    // Trade request structure
MqlTradeResult result      // Trade result structure
```

## Glossary

**EA (Expert Advisor)**: Automated trading program for MT4/MT5
**EMA**: Exponential Moving Average
**SMA**: Simple Moving Average
**RSI**: Relative Strength Index
**SL**: Stop Loss
**TP**: Take Profit
**Tick**: Price update from broker
**Bar**: Candlestick on chart (OHLC data)
**Magic Number**: Unique identifier for EA's trades
**Slippage**: Difference between requested and executed price
**Spread**: Difference between bid and ask price
**Fill Mode**: How broker executes orders (FOK, IOC, etc.)
**Trailing Stop**: Stop loss that follows price

## Troubleshooting Guide

### Compilation Errors

#### "Undeclared identifier"
**Cause**: Missing variable declaration or typo
**Solution**: Check variable names and declarations

#### "Invalid parameter type"
**Cause**: Wrong type passed to function
**Solution**: Verify function signature and parameter types

#### "Return value expected"
**Cause**: Function missing return statement
**Solution**: Add appropriate return statement

### Runtime Errors

#### Position not opening
**Cause**: Multiple possible reasons
**Diagnosis**:
1. Check Experts tab for error messages
2. Verify spread filter not blocking
3. Ensure sufficient margin
4. Check if signal being generated

#### Trailing stop not working
**Cause**: Price not moving favorably or step too large
**Diagnosis**:
1. Verify UseTrailingStop = true
2. Check TrailingStopPoints setting
3. Ensure position is in profit
4. Review logs for modification attempts

## Conclusion

This technical documentation provides a comprehensive overview of the Ziplor EA architecture, implementation, and usage. For additional support or custom modifications, refer to the main README and configuration guide.
