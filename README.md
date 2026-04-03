# Ziplor

An Expert Advisor (EA) for MetaTrader 5 implementing Dow Theory with multi-timeframe analysis, anti-martingale position sizing, and hedge-based recovery.

## Strategy Overview

### Dow Theory Multi-Timeframe Trend Detection

The EA analyzes **three timeframes** simultaneously to identify high-probability trend trades:

| Timeframe | Default | Role |
|-----------|---------|------|
| Higher    | H4      | Determines the primary trend direction |
| Middle    | H1      | Confirms the trend |
| Entry     | M15     | Times the entry near swing levels |

**Trend identification** uses swing point analysis:
- **Uptrend**: Higher Highs (HH) + Higher Lows (HL) across all three timeframes
- **Downtrend**: Lower Lows (LL) + Lower Highs (LH) across all three timeframes
- Trades are only taken when **all three timeframes agree** on trend direction

### Anti-Martingale Position Sizing

Unlike martingale (which increases lot size after losses), anti-martingale **increases lot size during winning streaks** to capitalize on favorable trends:

- On consecutive wins: `lot = baseLot × multiplier^consecutiveWins`
- On consecutive losses: `lot = baseLot × reduction^consecutiveLosses`
- Lot size is always clamped between the minimum and maximum allowed

This approach maximizes profit during trending conditions while reducing risk during drawdowns.

### Hedge Recovery System

When floating drawdown exceeds a configurable threshold (default 5% of balance):

1. The EA opens a **hedge position** in the opposite direction to freeze the drawdown
2. The hedge lot is calculated to **neutralize net exposure** (covers the volume difference between buy and sell positions)
3. When the account recovers (net floating profit ≥ 0), the hedge is automatically closed
4. Hedge orders use a separate magic number for independent management

## File Structure

```
Ziplor/
├── Experts/
│   └── Ziplor.mq5              # Main EA file
├── Include/
│   ├── SwingDetector.mqh        # Swing point detection & Dow Theory trend analysis
│   └── PositionManager.mqh      # Position management, anti-martingale & hedging
└── README.md
```

## Installation

1. Copy `Experts/Ziplor.mq5` to your MT5 `MQL5/Experts/` directory
2. Copy `Include/SwingDetector.mqh` and `Include/PositionManager.mqh` to your MT5 `MQL5/Include/` directory (or adjust include paths)
3. Compile `Ziplor.mq5` in MetaEditor
4. Attach the EA to a chart

## Input Parameters

### Timeframes
| Parameter | Default | Description |
|-----------|---------|-------------|
| Higher TF | H4 | Primary trend timeframe |
| Middle TF | H1 | Confirmation timeframe |
| Entry TF | M15 | Entry timing timeframe |

### Trade Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Base Lot | 0.01 | Starting lot size |
| Max Lot | 1.0 | Maximum allowed lot size |
| SL ATR Multiplier | 2.0 | Stop loss = ATR × this value |
| TP ATR Multiplier | 3.0 | Take profit = ATR × this value |
| ATR Period | 14 | ATR indicator period |

### Anti-Martingale
| Parameter | Default | Description |
|-----------|---------|-------------|
| Win Multiplier | 1.5 | Lot increase factor per consecutive win |
| Loss Reduction | 0.5 | Lot decrease factor per consecutive loss |

### Hedge Recovery
| Parameter | Default | Description |
|-----------|---------|-------------|
| Drawdown % | 5.0 | Account drawdown threshold to trigger hedge |
| Enable Hedge | true | Toggle hedging on/off |

## Requirements

- MetaTrader 5 platform
- Hedge account type (required for simultaneous buy/sell positions)
- Broker that supports the `ORDER_FILLING_IOC` fill policy

## Risk Disclaimer

This EA is provided for educational purposes. Trading involves substantial risk. Always test thoroughly in a demo account before using real funds.
