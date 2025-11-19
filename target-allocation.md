### Goal
Let the user set group-level targets for “Instrument type” while bands are computed as relative-to-target with an absolute floor and cap. Basic mode hides band controls but shows the computed bounds.

### What the user sees (Basic mode)
- Header chips: “Sum must be 100%”, “Ex‑cash”, “Band: ±20% of target (floor 2 pp, cap 10 pp)”.
- Table rows: Equity, Bonds, Crypto, Other (read‑only at 0%).
  - Columns:
    - Current Weight (read‑only)
    - Target % (editable)
    - Band (read‑only lower–upper; recomputes when target changes)
    - Drift (read‑only; in/out-of-band indicator)
- Footer: “Remaining: X%” and Save (disabled until sum = 100%). Optional “Normalize” and “Copy from current”.

### How bands behave (always-on, derived)
- Per row, band half‑width = clamp(20% of target, min 2 pp, max 10 pp).
- Bounds = [max(0, target − half‑width), min(100, target + half‑width)].
- Bands update live as you change targets (e.g., 70% → [60, 80]; 20% → [16, 24]; 2% → [0, 4]).
- Display is read‑only in Basic mode; user cannot change r/floor/cap.

### User stories

1) Seed and tweak targets quickly
- I click “Copy from current weights” to prefill targets.
- I change Equity to 70.0%. Bonds/Crypto auto‑redistribute to keep total = 100%.
- Band for Equity shows [60, 80] automatically. Save is enabled.

2) Protect a group while adjusting others
- I pin Bonds.
- I increase Equity to 72.0%; only unpinned rows adjust.
- If totals drift from 100%, I click “Normalize” to scale unpinned rows back to 100%, then Save.

3) Understand in/out-of-band at a glance
- For each row I see Current, Target, Band, and Drift.
- If Current is outside Band, the row shows a clear warning (e.g., red badge). No settings needed.

4) Handle “Other” and edge cases
- “Other” is fixed at 0% and read‑only (collects unassigned holdings).
- Near 0%/100% targets, bands are safely clipped to [0, 100] and respect floor/cap automatically.

### Defaults (Basic mode)
- Targets: group level only; sum must be 100%.
- Band scheme: relative ±20% of target, floor 2 pp, cap 10 pp (global, fixed).
- Auto‑redistribute: ON by default; per‑row Pin available.
- Storage: integer bps; display with 2 decimals.
- Drift: ex‑cash.

### What the user won’t see (MVP)
- No controls to change band parameters (relative %, floor, cap).
- No asset‑level targets, no custom per‑group bands, no versioning/publish workflow.

### Expert mode (later)
- Optional panel to adjust: global relative %, floor pp, cap pp; optional per‑group overrides.
- Toggle to switch band scheme (relative vs absolute) if ever needed.
- Same UI otherwise; Band column becomes editable where overrides apply.
