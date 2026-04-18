```markdown
---
name: btc-trading-since-2020
description: Work with the BTC-Trading-Since-2020 open dataset of real Bitcoin trading history (43k+ orders, 173k+ executions, 2020–2026) from a BitMEX account.
triggers:
  - analyze BTC trading dataset
  - load bitmex execution history
  - parse trading ledger CSV
  - reconstruct equity curve from wallet history
  - work with btc trading since 2020
  - analyze bitcoin trade executions
  - process bitmex wallet history
  - calculate trading performance from ledger
---

# BTC-Trading-Since-2020 Dataset Skill

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What This Project Is

A public, continuously updated mirror of a real BitMEX BTC trading account spanning **2020-05-01 → 2026-04-17**. It contains:

- **43,214** orders (`api-v1-order.csv`)
- **173,058** execution rows (`api-v1-execution-tradeHistory.csv`)
- **17,099** wallet events (`api-v1-user-walletHistory.csv`)
- Derived equity curve, terminal snapshots, instrument dictionaries

Primary use: discretionary manual trading analysis — regime detection, position sizing, drawdown study, long-term compounding. **Not** an HFT/microstructure dataset.

---

## Getting the Data

### Clone the repo
```bash
git clone https://github.com/bwjoke/BTC-Trading-Since-2020.git
cd BTC-Trading-Since-2020
```

### Or download a tagged release
```bash
# Latest tagged build (replace date as needed)
gh release download data-2026-04-17 --repo bwjoke/BTC-Trading-Since-2020
```

### File inventory
```
api-v1-execution-tradeHistory.csv   # primary execution ledger (balance-affecting)
api-v1-order.csv                    # order intent + lifecycle
api-v1-user-walletHistory.csv       # deposits, withdrawals, funding, realised PnL
api-v1-position.snapshot.csv        # terminal position anchor
api-v1-user-wallet.snapshot-all.csv # terminal wallet anchor
api-v1-user-margin.snapshot-all.csv # terminal margin/equity anchor
api-v1-user-walletSummary.all.csv   # BitMEX summary cross-check
api-v1-instrument.all.csv           # instrument dictionary + contract specs
api-v1-wallet-assets.csv            # asset scale + wallet metadata
derived-equity-curve.csv            # XBT-equivalent wealth curve
manifest.json                       # checksums, row counts, time ranges
```

---

## Loading the Data (Python)

### Basic setup
```python
import pandas as pd
import numpy as np

DATA_DIR = "./BTC-Trading-Since-2020"  # adjust to your clone path

def load_executions():
    df = pd.read_csv(f"{DATA_DIR}/api-v1-execution-tradeHistory.csv", low_memory=False)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    return df

def load_orders():
    df = pd.read_csv(f"{DATA_DIR}/api-v1-order.csv", low_memory=False)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    df["transactTime"] = pd.to_datetime(df["transactTime"], utc=True)
    return df

def load_wallet_history():
    df = pd.read_csv(f"{DATA_DIR}/api-v1-user-walletHistory.csv", low_memory=False)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    df["transactTime"] = pd.to_datetime(df["transactTime"], utc=True)
    return df

def load_equity_curve():
    df = pd.read_csv(f"{DATA_DIR}/derived-equity-curve.csv", low_memory=False)
    df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True)
    return df

def load_instruments():
    return pd.read_csv(f"{DATA_DIR}/api-v1-instrument.all.csv", low_memory=False)
```

### Scale note — XBT amounts are in satoshis (1e-8 XBT)
```python
SATOSHI = 1e8  # BitMEX stores XBT amounts as integer satoshis

def to_xbt(satoshi_series):
    """Convert BitMEX integer satoshi column to XBT float."""
    return satoshi_series / SATOSHI
```

---

## Key Data Structures

### Execution ledger columns (tradeHistory)
```python
executions = load_executions()
print(executions.columns.tolist())
# Relevant fields:
# timestamp, symbol, side, lastQty, lastPx, execType,
# execCost, execComm, realizedPnl, homeNotional,
# foreignNotional, settlCurrency, text
```

### Order ledger columns
```python
orders = load_orders()
# Relevant fields:
# timestamp, transactTime, symbol, side, orderQty, price,
# stopPx, ordType, ordStatus, cumQty, avgPx, leavesQty,
# triggered, workingIndicator, currency, settlCurrency
```

### Wallet history transactTypes
```python
wallet = load_wallet_history()
print(wallet["transactType"].value_counts())
# Common types:
# RealisedPNL    — closed position profit/loss
# Funding        — perpetual swap funding payments
# Deposit        — external inbound
# Withdrawal     — external outbound
# Transfer       — internal wallet move (neutralize in PnL)
# Conversion     — XBT <-> USDt swap (treat as internal)
# SpotTrade      — spot pair trade (treat as internal)
```

---

## Common Analysis Patterns

### 1. Filter to BTC-only executions
```python
def btc_executions(df):
    """Return rows where symbol contains XBTUSD, XBTUSDT, or BTC."""
    mask = df["symbol"].str.contains("XBT|BTC", case=False, na=False)
    return df[mask].copy()

execs = load_executions()
btc = btc_executions(execs)
print(f"BTC executions: {len(btc):,} / {len(execs):,} total")
```

### 2. Compute realized PnL by year
```python
def annual_realised_pnl(wallet_df):
    """Aggregate RealisedPNL wallet events by year in XBT."""
    pnl = wallet_df[wallet_df["transactType"] == "RealisedPNL"].copy()
    pnl["xbt"] = to_xbt(pnl["amount"])
    pnl["year"] = pnl["timestamp"].dt.year
    return pnl.groupby("year")["xbt"].sum()

wallet = load_wallet_history()
print(annual_realised_pnl(wallet))
```

### 3. Reconstruct the adjusted equity curve (matches repo methodology)
```python
def build_equity_curve(wallet_df, baseline_xbt=1.83953943):
    """
    Replicate the repo's adjusted-wealth methodology:
    - Start from baseline (first funded XBT balance after final deposit)
    - Add back completed Withdrawals
    - Subtract completed Deposits after baseline
    - Neutralize Transfer, Conversion, SpotTrade rows
    Returns a DataFrame with timestamp and adjusted_xbt columns.
    """
    relevant_types = {"RealisedPNL", "Funding", "Deposit", "Withdrawal"}
    df = wallet_df[
        (wallet_df["transactType"].isin(relevant_types)) &
        (wallet_df["currency"] == "XBt")  # XBt = satoshi-denominated XBT
    ].copy().sort_values("timestamp")

    baseline_time = pd.Timestamp("2020-05-01T14:39:40.387Z", tz="UTC")
    df = df[df["timestamp"] >= baseline_time]

    df["xbt_delta"] = to_xbt(df["amount"])

    # Flip sign: withdrawals increase adjusted wealth, deposits after baseline decrease it
    df.loc[df["transactType"] == "Withdrawal", "xbt_delta"] *= 1   # add back
    df.loc[df["transactType"] == "Deposit",    "xbt_delta"] *= -1  # subtract

    df["cumulative_xbt"] = baseline_xbt + df["xbt_delta"].cumsum()
    return df[["timestamp", "transactType", "xbt_delta", "cumulative_xbt"]]

wallet = load_wallet_history()
curve = build_equity_curve(wallet)
print(curve.tail())
```

### 4. Load the pre-built equity curve (simplest approach)
```python
equity = load_equity_curve()
print(equity.tail(3))
# columns include timestamp, wallet_xbt (or similar), adjusted_xbt
# Always check actual column names:
print(equity.columns.tolist())
```

### 5. Plot cumulative performance
```python
import matplotlib.pyplot as plt

equity = load_equity_curve()

# Adapt column names to what's actually in the file
time_col = equity.columns[0]
val_col  = equity.columns[1]

fig, ax = plt.subplots(figsize=(14, 5))
ax.plot(equity[time_col], equity[val_col], linewidth=1.2)
ax.set_title("BTC-Trading-Since-2020 — Adjusted XBT Wealth")
ax.set_ylabel("XBT")
ax.set_xlabel("Date")
plt.tight_layout()
plt.savefig("my_equity_curve.png", dpi=150)
plt.show()
```

### 6. Funding payment analysis
```python
def funding_summary(wallet_df):
    funding = wallet_df[wallet_df["transactType"] == "Funding"].copy()
    funding["xbt"] = to_xbt(funding["amount"])
    funding["year_month"] = funding["timestamp"].dt.to_period("M")
    monthly = funding.groupby("year_month")["xbt"].sum()
    print(f"Total funding paid/received: {funding['xbt'].sum():.6f} XBT")
    print(f"Net funding (positive = received): {funding['xbt'].sum():.6f} XBT")
    return monthly

wallet = load_wallet_history()
funding_monthly = funding_summary(wallet)
print(funding_monthly)
```

### 7. Win rate and average trade by side
```python
def trade_win_rate(exec_df):
    """
    Calculate win rate on closed fills.
    Uses realizedPnl column; only rows with non-null realizedPnl.
    """
    filled = exec_df[
        (exec_df["execType"] == "Trade") &
        (exec_df["realizedPnl"].notna())
    ].copy()
    filled["pnl_xbt"] = to_xbt(filled["realizedPnl"])
    filled["win"] = filled["pnl_xbt"] > 0

    by_side = filled.groupby("side").agg(
        trades=("pnl_xbt", "count"),
        win_rate=("win", "mean"),
        avg_pnl_xbt=("pnl_xbt", "mean"),
        total_pnl_xbt=("pnl_xbt", "sum"),
    )
    return by_side

execs = load_executions()
print(trade_win_rate(execs))
```

### 8. Drawdown calculation on equity curve
```python
def max_drawdown(series):
    """Maximum peak-to-trough drawdown on a wealth series."""
    rolling_max = series.cummax()
    drawdown = (series - rolling_max) / rolling_max
    return drawdown.min(), drawdown

equity = load_equity_curve()
val_col = equity.columns[1]  # adjust if needed

mdd, dd_series = max_drawdown(equity[val_col])
print(f"Maximum drawdown: {mdd:.2%}")
```

### 9. Symbol concentration by notional
```python
def symbol_concentration(exec_df):
    """Breakdown of executed notional by symbol."""
    trades = exec_df[exec_df["execType"] == "Trade"].copy()
    trades["abs_notional"] = trades["homeNotional"].abs()
    by_sym = (
        trades.groupby("symbol")["abs_notional"]
        .sum()
        .sort_values(ascending=False)
    )
    total = by_sym.sum()
    pct = (by_sym / total * 100).round(2)
    return pd.DataFrame({"notional_xbt": by_sym, "pct": pct})

execs = load_executions()
print(symbol_concentration(execs).head(10))
```

### 10. Cross-reference order intent to fills
```python
def merge_orders_executions(orders_df, exec_df):
    """Join order metadata to execution fills on orderID."""
    return exec_df.merge(
        orders_df[["orderID", "ordType", "ordStatus", "avgPx", "cumQty"]],
        on="orderID",
        how="left",
        suffixes=("_exec", "_order"),
    )

orders = load_orders()
execs  = load_executions()
merged = merge_orders_executions(orders, execs)
print(merged.shape)
```

---

## Verify Data Integrity with manifest.json

```python
import json, hashlib

with open(f"{DATA_DIR}/manifest.json") as f:
    manifest = json.load(f)

print(json.dumps(manifest, indent=2))

# Spot-check row counts
def count_rows(path):
    with open(path) as f:
        return sum(1 for _ in f) - 1  # minus header

for entry in manifest.get("files", []):
    fname = entry["filename"]
    expected = entry.get("row_count")
    if expected is None:
        continue
    actual = count_rows(f"{DATA_DIR}/{fname}")
    status = "✓" if actual == expected else f"MISMATCH (got {actual})"
    print(f"{fname}: {expected} rows {status}")
```

---

## Time-Range Filtering Helpers

```python
def slice_by_year(df, year, time_col="timestamp"):
    return df[df[time_col].dt.year == year].copy()

def slice_date_range(df, start, end, time_col="timestamp"):
    """start/end as 'YYYY-MM-DD' strings."""
    s = pd.Timestamp(start, tz="UTC")
    e = pd.Timestamp(end, tz="UTC")
    return df[(df[time_col] >= s) & (df[time_col] <= e)].copy()

# Example: 2024 BTC executions only
execs = load_executions()
btc   = btc_executions(execs)
y2024 = slice_by_year(btc, 2024)
print(f"2024 BTC executions: {len(y2024):,}")
```

---

## Instrument Reference Lookups

```python
def get_instrument_spec(symbol, instruments_df=None):
    """Look up contract spec for a given symbol."""
    if instruments_df is None:
        instruments_df = load_instruments()
    row = instruments_df[instruments_df["symbol"] == symbol]
    if row.empty:
        return None
    return row.iloc[0].to_dict()

instruments = load_instruments()
spec = get_instrument_spec("XBTUSD", instruments)
print(spec["settlCurrency"], spec["lotSize"], spec["tickSize"])
```

---

## Terminology Quick Reference

| Term | Meaning |
|------|---------|
| `XBT` | Bitcoin ticker used by BitMEX (same as BTC) |
| `XBt` | Satoshi-denominated XBT column (divide by 1e8) |
| `execType == "Trade"` | Actual fill row (balance-affecting) |
| `execType == "Funding"` | Perpetual swap funding settlement |
| `homeNotional` | Contract value in settlement currency (XBT) |
| `foreignNotional` | Contract value in quote currency (USD) |
| `realizedPnl` | Closed P&L on that fill, in satoshis |
| `transactType == "Transfer"` | Internal; neutralize in PnL math |
| `transactType == "Conversion"` | XBT↔USDt swap; treat as internal |
| Adjusted wealth | Wallet curve with deposits subtracted and withdrawals added back |
| Marked wealth | Adjusted wealth + unrealized PnL from open positions |

---

## Troubleshooting

### Mixed satoshi / non-satoshi columns
Some columns (`lastPx`, `avgPx`, `price`) are already in USD or XBT price terms — do **not** divide these by 1e8. Only integer-amount columns (`amount`, `walletBalance`, `execCost`, `execComm`, `realizedPnl`, `realisedPnl`) need the satoshi conversion when `currency == "XBt"`.

### USDt rows mixed in
Filter by `currency` or `settlCurrency`:
```python
xbt_wallet = wallet[wallet["currency"] == "XBt"]
usdt_wallet = wallet[wallet["currency"] == "USDt"]
```

### Timestamp ordering
Use `timestamp` (exchange-confirmed event time) as the primary sort key. `transactTime` is preserved from the exchange but may differ slightly; the repo's methodology prefers `timestamp`.

### Large file performance
```python
# Use dtype hints and only load needed columns
execs = pd.read_csv(
    f"{DATA_DIR}/api-v1-execution-tradeHistory.csv",
    usecols=["timestamp", "symbol", "side", "lastQty", "lastPx",
             "execType", "realizedPnl", "homeNotional", "settlCurrency"],
    parse_dates=["timestamp"],
    low_memory=False,
)
```

### `account` column missing
Expected — it is intentionally redacted in the public release per the privacy policy.
```
```
