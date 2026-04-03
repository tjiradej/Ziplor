# Ziplor EA v1.0

**Multi-Timeframe SMC/ICT Expert Advisor for MetaTrader 5**

A professional-grade EA that combines Smart Money Concepts (SMC) and ICT methodology with anti-martingale position sizing, pyramid order management, recovery mode, and a real-time on-chart dashboard.

## Features

### Core Trading Logic
- **Multi-Timeframe Market Structure Analysis**: Analyzes 4 timeframes simultaneously (HTF → MTF → LTF → M1 execution)
- **Smart Money Concepts (SMC)**: Order Blocks, Fair Value Gaps, Break of Structure (BOS), Change of Character (CHoCH), Liquidity Pools
- **ICT Methodology**: Killzone timing (London, New York, Silver Bullet), Optimal Trade Entry (OTE) zones, Premium/Discount analysis
- **Confluence-Based Signals**: Requires 4+ confluences from multiple timeframes, zones, and session timing before entry

### Position Management
- **Anti-Martingale Sizing**: Increases risk on winning streaks, resets to base on loss. Configurable increment and maximum cap.
- **Pyramid Ordering**: Adds to winning positions at valid SMC zones with decreasing lot sizes. Trails SL to structure.
- **Recovery Mode**: Activates on drawdown threshold, seeks high-quality entries with adjusted risk to recover losses.

### Monitoring
- **On-Chart Dashboard**: Real-time display of account data, market structure per TF, session status, signal quality, anti-martingale state, recovery status, and trade statistics.

## File Structure

```
Ziplor/
├── README.md
├── Experts/
│   └── Ziplor/
│       └── Ziplor.mq5              # Main EA (entry point)
└── Include/
    └── Ziplor/
        ├── ZiplorEnums.mqh          # Enumerations (bias, zones, sessions, etc.)
        ├── ZiplorStructures.mqh     # Data structures (SwingPoint, SDZone, etc.)
        ├── ZiplorSMCEngine.mqh      # SMC/ICT analysis engine class
        └── ZiplorDashboard.mqh      # On-chart dashboard panel class
```

## Installation

1. Copy `Experts/Ziplor/` folder into your MT5 `MQL5/Experts/` directory
2. Copy `Include/Ziplor/` folder into your MT5 `MQL5/Include/` directory
3. Compile `Ziplor.mq5` in MetaEditor
4. Attach to any chart on **M1 timeframe**

## Configuration

### Timeframes
| Parameter | Default | Description |
|-----------|---------|-------------|
| Higher TF (HTF) | H4 | Trend direction and bias |
| Mid TF (MTF) | H1 | Structure confirmation |
| Lower TF (LTF) | M15 | Entry zone identification |
| Execution TF | M1 | Precise entry timing |

### Risk Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| Base Risk % | 1.0% | Starting risk per trade |
| Max Risk % | 3.0% | Maximum risk cap |
| Risk Increment | 0.25% | Added per consecutive win |
| Min Lot Size | 0.01 | Floor lot size |
| Max Lot Size | 10.0 | Ceiling lot size |

### Pyramid Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Enable Pyramid | true | Allow adding to winners |
| Max Pyramid Levels | 3 | Maximum add-on entries |
| Size Multiplier | 0.5 | Each add is 50% of previous |
| Trail on Pyramid | true | Move SL to structure on add |

### Recovery Mode
| Parameter | Default | Description |
|-----------|---------|-------------|
| Enable Recovery | true | Activate recovery on drawdown |
| Threshold | 3.0% | Drawdown % to trigger recovery |
| Max Recovery Trades | 5 | Cap on recovery attempts |
| Risk Multiplier | 1.5x | Risk increase during recovery |

### Session Filters
| Parameter | Default | Description |
|-----------|---------|-------------|
| Trade Asian | false | Allow Asian session trades |
| Trade London KZ | true | Allow London killzone trades |
| Trade NY KZ | true | Allow New York killzone trades |
| Trade London Close | false | Allow London close trades |
| Trade Silver Bullet | true | Allow Silver Bullet window trades |

## How It Works

### Signal Generation Flow
1. **HTF Analysis** (H4): Determines overall market bias (bullish/bearish)
2. **MTF Confirmation** (H1): Confirms structure with BOS or CHoCH
3. **LTF Entry Zones** (M15): Identifies Order Blocks, FVGs, and OTE zones
4. **M1 Execution**: Waits for execution TF alignment and precise entry timing
5. **Killzone Filter**: Only trades during configured institutional time windows
6. **Confluence Score**: Counts all confirming factors; minimum 4 required

### Anti-Martingale Flow
- **Win** → Risk increases by increment (e.g., 1.0% → 1.25% → 1.50%)
- **Loss** → Risk resets to base (e.g., back to 1.0%)
- Risk never exceeds the configured maximum cap

### Pyramid Flow
1. Base entry at full calculated size
2. On BOS continuation + price in valid zone + position in profit → add 50% of base
3. Second add → 25% of base (50% × 50%)
4. Trail all stops to last LTF swing structure

## Disclaimer

**This EA is for educational and research purposes only.** Trading forex and CFDs involves substantial risk of loss. Past performance is not indicative of future results. Always test thoroughly on a demo account before considering live trading. The authors accept no liability for financial losses.
