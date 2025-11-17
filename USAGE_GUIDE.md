# Ziplor EA - Usage Guide

## Quick Start

### Step 1: Installation
1. Open MetaTrader 5
2. Open the data folder: File → Open Data Folder
3. Navigate to `MQL5/Experts/`
4. Copy `Ziplor.mq5` into this folder
5. Return to MetaTrader 5
6. Open MetaEditor (Tools → MetaQuotes Language Editor or press F4)
7. In MetaEditor, find `Ziplor.mq5` in the Navigator panel
8. Right-click on `Ziplor.mq5` and select "Compile" (or press F7)
9. Check the "Toolbox" panel at the bottom for compilation results

### Step 2: Attaching to Chart
1. In MetaTrader 5, open a chart for the currency pair you want to trade
2. In the Navigator panel, expand "Expert Advisors"
3. Drag and drop `Ziplor` onto your chart
4. A settings window will appear

### Step 3: Configure Parameters
Configure the following parameters in the EA settings:

- **PointInterval**: Set to 20 (default) - Orders will be placed every 20 points
- **NumberOfLevels**: Set to 20 (default) - 20 levels above and 20 levels below
- **ProfitTarget**: Set to 20.0 (default) - EA will close all positions when profit reaches $20
- **LotSize**: Set according to your risk tolerance (default: 0.01)
  - 0.01 = micro lot (1,000 units)
  - 0.1 = mini lot (10,000 units)
  - 1.0 = standard lot (100,000 units)
- **MagicNumber**: Leave as default (123456) unless you're running multiple instances

### Step 4: Enable Automated Trading
1. Click the "AutoTrading" button in the toolbar (or press Ctrl+E)
2. The button should be highlighted/pressed
3. Check that the EA shows a smiling face icon in the top-right corner of your chart
4. If you see a sad face or X, check your settings and ensure AutoTrading is enabled

## How the EA Works

### Initial Order Placement
When you first attach the EA to a chart:
- It reads the current market price
- Places 20 BUY STOP orders at: current price + 20 points, + 40 points, + 60 points, ..., up to + 400 points
- Places 20 SELL STOP orders at: current price - 20 points, - 40 points, - 60 points, ..., down to - 400 points

### During Operation
- The EA monitors your account every second
- As the market moves, stop orders may be triggered and become active positions
- When positions are active, the EA continuously calculates total profit

### Profit Target Reached
When total profit from all positions reaches $20 or more:
1. All open positions are immediately closed
2. All pending orders (not yet triggered) are deleted
3. The EA resets and starts fresh on the next tick
4. New orders are placed based on the new current market price

## Example Scenario

Let's say EURUSD is trading at 1.10000:

**BUY STOP Orders placed at:**
- 1.10020 (20 points above)
- 1.10040 (40 points above)
- 1.10060 (60 points above)
- ... continues up to
- 1.10400 (400 points above)

**SELL STOP Orders placed at:**
- 1.09980 (20 points below)
- 1.09960 (40 points below)
- 1.09940 (60 points below)
- ... continues down to
- 1.09600 (400 points below)

If price moves up and triggers some BUY STOP orders, and the total profit reaches $20, all positions close and the process restarts.

## Important Notes

### Risk Management
⚠️ **Warning**: This EA can open multiple positions simultaneously. Key considerations:

1. **Account Balance**: Ensure you have sufficient margin for multiple positions
2. **Lot Size**: Start with the smallest lot size (0.01) when testing
3. **Broker Requirements**: Check your broker's minimum margin requirements
4. **Demo Testing**: ALWAYS test on a demo account first

### Points vs Pips
- For 4-digit quotes (e.g., USDJPY): 1 pip = 1 point
- For 5-digit quotes (e.g., EURUSD): 1 pip = 10 points
- Default setting of 20 points = 2 pips for 5-digit pairs

### Monitoring
Monitor these aspects regularly:
- Number of open positions
- Total profit/loss
- Margin level
- Order placement and execution

## Troubleshooting

### EA Not Placing Orders
- Check that AutoTrading is enabled (green button in toolbar)
- Verify you have sufficient margin in your account
- Check the "Experts" tab for error messages
- Ensure your broker allows pending orders

### Orders Being Rejected
- Verify lot size meets broker minimums
- Check that prices are within broker's maximum distance from current price
- Ensure you have enough free margin

### EA Not Closing Positions
- Check the "Experts" tab for error messages
- Verify that positions belong to this EA (check Magic Number)
- Ensure you're not in trading hours restrictions

## Advanced Configuration

### Adjusting Point Intervals
You can modify `PointInterval` to change the spacing between orders:
- Smaller values (e.g., 10) = more orders closer together
- Larger values (e.g., 50) = fewer orders spread further apart

### Adjusting Profit Target
Modify `ProfitTarget` based on your trading goals:
- Lower values (e.g., 10) = more frequent but smaller profits
- Higher values (e.g., 50) = less frequent but larger profits

### Multiple Instances
To run the EA on multiple charts:
1. Use a different `MagicNumber` for each instance
2. Ensure sufficient margin for all instances combined
3. Consider the combined risk

## Support and Logs

### Viewing EA Logs
1. Open the "Toolbox" panel (View → Toolbox or Ctrl+T)
2. Click the "Experts" tab
3. All EA messages and errors will appear here

### Common Log Messages
- "Ziplor EA initialized successfully" - EA started correctly
- "Placing orders. Current price: X" - EA is placing new orders
- "Profit target reached: $X" - Target profit reached, closing all
- "All positions closed" - Positions successfully closed
- "All pending orders deleted" - Pending orders removed

## Best Practices

1. **Start Small**: Begin with 0.01 lot size
2. **Demo First**: Test for at least a week on demo account
3. **Monitor Regularly**: Check the EA at least daily
4. **Understand Risks**: Know that losses can exceed your initial investment
5. **Keep Logs**: Review the "Experts" tab logs regularly
6. **Broker Compatibility**: Ensure your broker supports this type of trading
7. **Market Conditions**: Be aware that volatile markets may trigger many orders quickly

## Disclaimer

This EA is provided for educational purposes. Trading forex carries substantial risk and is not suitable for all investors. The past performance of any trading system does not guarantee future results. Always:
- Test thoroughly on demo accounts
- Understand the risks involved
- Never trade with money you cannot afford to lose
- Seek professional financial advice if needed
