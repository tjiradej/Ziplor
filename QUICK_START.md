# Ziplor EA - Quick Start Guide

## 5-Minute Setup

### Step 1: Installation (1 minute)

**For MT5:**
1. Open MetaTrader 5
2. Go to File → Open Data Folder
3. Navigate to MQL5 → Experts
4. Copy `Ziplor_EA.mq5` to this folder
5. Close and reopen MT5 (or press F5 in Navigator)

**For MT4:**
1. Open MetaTrader 4
2. Go to File → Open Data Folder
3. Navigate to MQL4 → Experts
4. Copy `Ziplor_EA.mq4` to this folder
5. Close and reopen MT4 (or press Ctrl+N)

### Step 2: Attach to Chart (1 minute)

1. Open a chart (recommended: EUR/USD, H1 timeframe)
2. Navigate to Navigator panel (Ctrl+N if not visible)
3. Expand "Expert Advisors" section
4. Drag "Ziplor_EA" onto the chart
5. A settings window will appear

### Step 3: Basic Configuration (2 minutes)

#### Beginner Settings (Conservative)
```
Risk Management:
  RiskPercent = 0.5  (risk 0.5% per trade)

Position Management:
  StopLossPoints = 50
  TakeProfitPoints = 100
  UseTrailingStop = true

Trade Filtering:
  TradeOnlyTrend = true
  MaxSpreadPoints = 15
```

#### Intermediate Settings (Moderate)
```
Risk Management:
  RiskPercent = 1.0  (risk 1% per trade)

Position Management:
  StopLossPoints = 75
  TakeProfitPoints = 150
  UseTrailingStop = true

Trade Filtering:
  TradeOnlyTrend = true
  MaxSpreadPoints = 20
```

### Step 4: Enable Auto Trading (30 seconds)

1. Click "Allow Algorithmic Trading" in the EA settings
2. Click "OK" to close settings
3. Enable "AutoTrading" button in the toolbar (should turn green)
4. Verify a smiley face appears in top-right corner of chart

### Step 5: Verify Operation (30 seconds)

1. Open the "Experts" tab at the bottom of MT4/MT5
2. Look for the message: "Ziplor EA initialized successfully"
3. If you see this, the EA is running correctly!

## First Trade Checklist

Before the EA places its first trade, make sure:

- [ ] **AutoTrading is enabled** (green button in toolbar)
- [ ] **Account balance is sufficient** (recommended minimum $100 for demo)
- [ ] **Internet connection is stable**
- [ ] **Spread is reasonable** (< 2 pips for EUR/USD)
- [ ] **Risk per trade is set conservatively** (start with 0.5% or less)
- [ ] **You understand the strategy** (read the main README)

## What to Expect

### First Few Days
- The EA waits for new bars to form before checking for signals
- Signals occur when Fast MA crosses Slow MA with favorable RSI
- On H1 timeframe, expect 2-5 signals per week on EUR/USD
- Not all signals result in trades (filters may prevent entry)

### Trade Entry
When conditions align, you'll see:
1. Log message: "BUY signal detected!" or "SELL signal detected!"
2. Order placed with automatic SL and TP
3. Log message: "Position opened successfully! Ticket: XXXXX"

### Position Management
- Trailing stop activates when price moves favorably
- Position closes automatically at TP or SL
- All actions are logged in the Experts tab

## Common Issues

### EA Not Trading
**Problem:** EA is running but not opening trades
**Solutions:**
- Wait longer (strategy is selective)
- Check spread filter (reduce MaxSpreadPoints)
- Verify trading hours (disable CheckTradingHours)
- Review Experts tab for error messages

### Error 133 (Trading Disabled)
**Problem:** "Trading is disabled" message
**Solutions:**
- Click AutoTrading button (make it green)
- Check "Allow Algorithmic Trading" in EA settings
- Verify account allows automated trading
- Contact broker if issue persists

### Error 134 (Not Enough Money)
**Problem:** "Not enough money" error
**Solutions:**
- Reduce RiskPercent (try 0.5% or lower)
- Ensure account has sufficient free margin
- Check minimum lot size requirements
- Deposit more funds or use demo account

### No Smiley Face on Chart
**Problem:** EA icon not showing on chart
**Solutions:**
- Enable AutoTrading (toolbar button)
- Check "Allow Algorithmic Trading" in settings
- Reattach EA to chart
- Restart MT4/MT5

## Demo Trading First

**IMPORTANT:** Always test on a demo account first!

### How to Open Demo Account
1. File → Open an Account
2. Select your broker's server
3. Choose "Demo Account"
4. Fill in details (use real email)
5. Remember login and password

### Demo Testing Period
- Minimum: 2 weeks
- Recommended: 1 month
- Monitor: Win rate, drawdown, overall profit
- Goal: Confirm EA works as expected

## Going Live

Only proceed to live trading after:
- [ ] Successful demo testing (minimum 1 month)
- [ ] Profitable results in demo
- [ ] You understand the strategy completely
- [ ] You're comfortable with the risk
- [ ] You have stable internet/VPS

### Live Trading Tips
1. **Start Small:** Use minimum risk (0.5%)
2. **Monitor Closely:** Check daily for first week
3. **Be Patient:** Don't change settings frequently
4. **Keep Records:** Document all trades
5. **Respect Risk:** Never risk money you can't afford to lose

## Daily Monitoring Routine

### Morning Check (2 minutes)
- [ ] Verify EA is running (smiley face visible)
- [ ] Check for any error messages
- [ ] Review open positions (if any)
- [ ] Verify account balance

### Evening Review (5 minutes)
- [ ] Review trades executed today
- [ ] Check profit/loss
- [ ] Review Experts tab logs
- [ ] Verify spread is normal

### Weekly Review (15 minutes)
- [ ] Calculate win rate
- [ ] Check total profit/loss
- [ ] Review maximum drawdown
- [ ] Assess if parameters need adjustment

## Getting Help

### Before Asking for Help
1. Check the Experts tab for error messages
2. Review this Quick Start Guide
3. Read the main README.md
4. Check CONFIGURATION_GUIDE.md for advanced settings

### Information to Provide
When seeking help, include:
- MT4 or MT5 version
- Broker name
- Symbol and timeframe
- Error messages from Experts tab
- Screenshot of EA settings
- Description of the issue

## Next Steps

After successful setup:
1. Read the full README.md for detailed information
2. Review CONFIGURATION_GUIDE.md for optimization tips
3. Keep a trading journal
4. Join trading communities for support
5. Consider running on a VPS for 24/7 operation

## Success Tips

### Do's ✓
- Test thoroughly on demo first
- Start with conservative settings
- Monitor regularly
- Keep detailed records
- Be patient with the strategy
- Use appropriate risk management

### Don'ts ✗
- Don't change settings constantly
- Don't risk more than you can afford to lose
- Don't expect to win every trade
- Don't run without understanding the strategy
- Don't disable important filters (spread, trend)
- Don't go live without demo testing

## Emergency Procedures

### Stop Trading Immediately If:
- Drawdown exceeds 20%
- Multiple consecutive losses (> 5)
- Technical issues occur
- Abnormal market conditions

### How to Stop EA:
1. Click AutoTrading button (turn it red)
2. Remove EA from chart (right-click chart → Expert Advisors → Remove)
3. Close all open positions manually if needed

## Conclusion

You're now ready to start using Ziplor EA! Remember:
- **Start with demo trading**
- **Use conservative risk settings**
- **Monitor regularly**
- **Be patient and disciplined**

Happy trading! 🚀
