# Ziplor EA — Risk Per Trade

A MetaTrader 5 Expert Advisor with advanced **Risk Per Trade** position sizing.

## Risk Per Trade Features

### Dynamic Position Sizing
Automatically calculates lot size so that each trade risks a fixed percentage of your account. The formula:

```
Lot Size = (Account Value × Risk%) / (Stop Loss in Price × Tick Value / Tick Size)
```

### Risk Calculation Base
Choose what the risk percentage is applied to:

| Mode | Description |
|------|-------------|
| **Account Balance** | Risk % of realized account balance (default) |
| **Account Equity** | Risk % of equity (balance + floating P&L) |
| **Free Margin** | Risk % of available free margin |

### Risk Protection
- **Maximum Risk Per Trade Cap** — hard limit on risk % per single trade (default: 5%)
- **Maximum Daily Loss** — stops trading when daily losses exceed threshold (default: 3%)
- **Maximum Drawdown** — stops trading when drawdown from peak balance exceeds limit (default: 10%)

## Trading Strategy

MA Crossover + RSI filter with optional 200 SMA trend confirmation.

- **Buy**: Fast EMA crosses above Slow EMA, RSI not oversold, price above trend MA
- **Sell**: Fast EMA crosses below Slow EMA, RSI not overbought, price below trend MA

## Configuration

### Risk Per Trade Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `RiskPercent` | 1.0 | Risk per trade as % of account |
| `RiskBase` | Balance | Base for risk calculation (Balance/Equity/Free Margin) |
| `MaxRiskPercent` | 5.0 | Maximum allowed risk per trade (%) |
| `MaxDailyLossPercent` | 3.0 | Maximum daily loss before stopping (%) |
| `MaxDrawdownPercent` | 10.0 | Maximum drawdown from peak (%) |

### Strategy Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastMA_Period` | 10 | Fast EMA period |
| `SlowMA_Period` | 30 | Slow EMA period |
| `RSI_Period` | 14 | RSI period |
| `RSI_Overbought` | 70.0 | RSI overbought level |
| `RSI_Oversold` | 30.0 | RSI oversold level |

### Position Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| `TakeProfitPoints` | 100.0 | Take profit distance (points) |
| `StopLossPoints` | 50.0 | Stop loss distance (points) |
| `MaxSpreadPoints` | 20.0 | Maximum spread to trade (points) |
| `MinRiskReward` | 1.5 | Minimum risk:reward ratio |
| `UseTrailingStop` | true | Enable trailing stop |
| `TrailingStopPoints` | 30.0 | Trailing stop distance (points) |
| `TrailingStepPoints` | 10.0 | Minimum step to trail (points) |

### Recommended Risk Settings

**Conservative** (Capital Preservation):
```
RiskPercent = 0.5
MaxDailyLossPercent = 2.0
MaxDrawdownPercent = 5.0
```

**Moderate** (Balanced):
```
RiskPercent = 1.0
MaxDailyLossPercent = 3.0
MaxDrawdownPercent = 10.0
```

**Aggressive** (Higher Returns):
```
RiskPercent = 2.0
MaxDailyLossPercent = 5.0
MaxDrawdownPercent = 15.0
```

## Installation

1. Copy `Ziplor_EA.mq5` to your MT5 `Experts` folder
2. Compile in MetaEditor
3. Attach to a chart and configure risk parameters
4. Enable AutoTrading

## How Position Size is Calculated

Example with $10,000 balance, 1% risk, 50-point stop loss on EURUSD (standard lot, 5-digit broker):

1. **Risk Amount** = $10,000 × 1% = $100
2. **Stop Loss Price** = 50 × 0.00001 = 0.0005
3. **Lot Size** = $100 / (0.0005 × $10 / 0.00001) = $100 / $500 = 0.20 lots
4. Normalized to broker lot step, respecting min/max limits

If the stop loss is hit, you lose approximately $100 (1% of balance).
