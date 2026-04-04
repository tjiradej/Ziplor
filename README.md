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

**Normalized OBV × SMA crossover** with **Stochastic (26,3,3)** confirmation and optional 200 SMA trend filter.

### Signal Logic

- **Buy**: Normalized OBV crosses above its SMA, confirmed by Stochastic (either %K in oversold zone or %K crossing above %D), price above trend MA
- **Sell**: Normalized OBV crosses below its SMA, confirmed by Stochastic (either %K in overbought zone or %K crossing below %D), price below trend MA

### Normalized OBV
Raw OBV is normalized to a 0–100 scale using a rolling min/max lookback window (`OBV_Norm_Period`). A simple moving average (`OBV_SMA_Period`) is calculated on the normalized values. Crossovers between normalized OBV and its SMA generate entry signals.

### Stochastic Filter
The Stochastic oscillator (26,3,3) acts as a confirmation filter to avoid false entries. Buy signals require the stochastic to show oversold conditions or a bullish %K/%D crossover. Sell signals require overbought conditions or a bearish %K/%D crossover.

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
| `OBV_SMA_Period` | 20 | SMA period for normalized OBV crossover |
| `OBV_Norm_Period` | 50 | Lookback period for OBV min/max normalization |
| `Stoch_K_Period` | 26 | Stochastic %K period |
| `Stoch_D_Period` | 3 | Stochastic %D period |
| `Stoch_Slowing` | 3 | Stochastic slowing |
| `Stoch_Overbought` | 80.0 | Stochastic overbought level |
| `Stoch_Oversold` | 20.0 | Stochastic oversold level |

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
