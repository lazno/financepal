# Rebalancing Feature – Design Brief for AI Agent

## Purpose
Add an **automated rebalancing engine** to the existing personal-finance tracker.  
The engine must:

1. Detect when the current allocation drifts beyond user-defined bands.  
2. Propose a minimal set of trades to bring the portfolio back to target.  
3. Explain **why** each trade is needed.  
4. Allow the user to accept, tweak, or reject the plan.

No UI is required; the agent will surface the plan via CLI, logs, or API.

---

## Core Concepts (non-negotiable)

| Concept        | Meaning in this project | Notes |
|----------------|-------------------------|-------|
| **Sleeve**     | Teilportfolio / segment  | A budgeted slice of the portfolio (e.g., Core 70 %, Satellite 30 %). Positions are assigned to exactly one sleeve. |
| **Target**     | Desired weight per sleeve or asset class | Sum of targets in a scope must equal 100 %. |
| **Band**       | Allowed drift around target | Relative (%) with floor/cap, or absolute (pp). |
| **Trigger**    | When to act               | Hybrid: check on schedule, only act if outside band. |
| **Min trade**  | Smallest € value to execute | Prevents noise. |
| **Turnover cap** | Max % of portfolio to trade per event | Keeps churn low. |

---

## Data Model (minimal delta)

```
asset_registry
  isin PK
  symbol
  asset_name
  instrument_type   ← from Yahoo quoteType
  asset_class       ← inferred (Equity|Bond|Cash|MultiAsset|Other)
  asset_class_confidence
  tags JSON         ← flexible metadata

positions
  isin FK → asset_registry
  quantity
  sleeve_id         ← default 'Total' until multi-sleeve is enabled

prices
  isin FK → asset_registry
  ts
  price

policy
  version
  targets JSON      { "Equity":0.60, "Bond":0.30, "Cash":0.10 }
  sensitivity JSON  { "rel":0.20, "floor_pp":0.02, "cap_pp":0.08 }
  min_trade_value
  turnover_cap
```

---

## Rebalancing Flow (pseudo-steps)

```
1. snapshot = build_snapshot()
   - positions × latest_prices → market values
   - group by sleeve & asset_class → current_weights

2. bands = compute_bands(policy, targets)
   - width = clamp(target × rel, floor, cap)
   - allowed = [target − width, target + width]

3. drift = detect_drift(current_weights, bands)
   - status = in_band | near_edge | out_of_band
   - delta_to_edge = $ needed to reach nearest boundary

4. plan = generate_plan(drift, policy)
   - use cashflows first
   - respect min_trade_value & turnover_cap
   - round to broker capabilities (fractional vs integer)

5. output = {
     total_value,
     per_class: { target, allowed, current, status, delta_value },
     trades: [ {isin, side, qty, est_value, reason} ],
     warnings: [ "missing price for XYZ", "band relaxed for US" ]
   }
```

---

## Extensibility Hooks

- **Multi-account**: add `account_id` to positions; keep one DB per account or unify later.  
- **Multi-sleeve**: add `sleeves` table and `positions.sleeve_id`.  
- **Corporate actions**: add `status` and `successor_isin` to assets; handle reactively.  
- **Cost basis / lots**: optional table `lots` for future tax-aware rebalancing.  
- **Look-through ETFs**: store ETF holdings in `tags` or separate table when needed.

---

## Acceptance Criteria (for the agent)

1. Given positions + prices + policy, produce a **drift report** (no trades yet).  
2. Given drift report, produce a **trade plan** with rationale.  
3. Handle missing/stale prices gracefully (skip asset, flag issue).  
4. Allow manual override of any classification or rule via `asset_class_overrides` or policy JSON.
