import domain/common_types.{
  type Asset, type InstrumentType, type Isin, type PriceData, instrument_type,
  market_value_amount,
}
import domain/policy_types.{
  type Policy, InstrumentType, allocation_bps, policy_sensitivity_cap_bps,
  policy_sensitivity_floor_bps, policy_sensitivity_rel_bps,
  policy_target_key_value, policy_target_type, policy_target_weights,
}
import domain/portfolio.{type PositionSnapshot}
import domain/position_types.{type Position}
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

// Domain: DriftStatus - indicates whether allocation is within allowed bands
pub type DriftStatus {
  InBand
  OutOfBand
}

// Domain: DriftAnalysis - analysis for a single target key
pub type DriftAnalysis {
  DriftAnalysis(
    target_key_type: policy_types.PolicyTargetType,
    target_key: policy_types.PolicyTargetKey,
    current_weight_bps: Int,
    target_weight_bps: Int,
    status: DriftStatus,
    delta_to_edge_bps: Int,
    lower_bound_bps: Int,
    upper_bound_bps: Int,
    // percentage points from nearest boundary
  )
}

// Domain: DriftReport - complete drift analysis for portfolio
pub type DriftReport {
  DriftReport(analyses: List(DriftAnalysis))
}

// Domain: Band - represents allowed drift range for an instrument type
pub opaque type Band {
  Band(lower_bound_bps: Int, upper_bound_bps: Int)
}

pub fn band(lower_bound_bps: Int, upper_bound_bps: Int) -> Result(Band, String) {
  case lower_bound_bps > upper_bound_bps {
    True -> Error("Lower bound cannot exceed upper bound")
    False -> Ok(Band(lower_bound_bps, upper_bound_bps))
  }
}

pub fn band_lower_bound(band: Band) -> Int {
  band.lower_bound_bps
}

pub fn band_upper_bound(band: Band) -> Int {
  band.upper_bound_bps
}

// Domain: AllocationSnapshot - complete portfolio snapshot for rebalancing analysis
pub type AllocationSnapshot {
  AllocationSnapshot(
    by_instrument_type: dict.Dict(InstrumentType, Int),
    // instrument_type -> weight (0-10_000)
    total_value: Float,
    positions: List(PositionSnapshot),
    missing_prices: List(Isin),
    // positions without price data
  )
}

// Main snapshot function - builds current portfolio state for rebalancing analysis
// Takes data as parameters for testability (no database dependencies)
pub fn build_snapshot(
  positions: List(Position),
  price_data: List(PriceData),
  assets: List(Asset),
) -> AllocationSnapshot {
  let #(position_snapshots, missing_prices) =
    portfolio.enrich_positions(positions, price_data, assets)

  // Calculate total market value
  let total_value = calculate_total_value(position_snapshots)

  // Calculate allocations by instrument type
  let allocations = calculate_allocations(position_snapshots, total_value)

  AllocationSnapshot(
    by_instrument_type: allocations,
    total_value: total_value,
    positions: position_snapshots,
    missing_prices: missing_prices,
  )
}

// Calculate total portfolio value
fn calculate_total_value(snapshots: List(PositionSnapshot)) -> Float {
  list.fold(snapshots, 0.0, fn(total, snapshot) {
    total +. market_value_amount(snapshot.market_value)
  })
}

// Calculate allocations by instrument type
fn calculate_allocations(
  snapshots: List(PositionSnapshot),
  total_value: Float,
) -> dict.Dict(InstrumentType, Int) {
  // Group by instrument type and sum values
  let type_totals =
    list.fold(snapshots, dict.new(), fn(acc, snapshot) {
      let current_value = case dict.get(acc, snapshot.instrument_type) {
        Ok(v) -> v
        Error(_) -> 0.0
      }
      dict.insert(
        acc,
        snapshot.instrument_type,
        current_value +. market_value_amount(snapshot.market_value),
      )
    })

  // Convert to weights with largest remainder method
  case total_value >. 0.0 {
    True -> {
      let entries = dict.to_list(type_totals)

      case list.is_empty(entries) {
        True -> dict.new()
        False -> {
          // Calculate exact bps values and use round instead of truncate
          let with_remainders =
            list.map(entries, fn(pair) {
              let #(instrument_type, value) = pair
              let exact_bps = { value /. total_value } *. 10_000.0
              let rounded = float.round(exact_bps)
              let remainder = exact_bps -. int.to_float(rounded)
              #(instrument_type, rounded, remainder, exact_bps)
            })

          // Calculate adjustment needed
          let total_rounded =
            list.fold(with_remainders, 0, fn(sum, item) {
              let #(_, rounded, _, _) = item
              sum + rounded
            })
          let adjustment_needed = 10_000 - total_rounded

          // Sort by remainder
          let sorted = case adjustment_needed >= 0 {
            // Need to add bps: sort by remainder descending (largest first)
            True ->
              list.sort(with_remainders, fn(a, b) {
                let #(_, _, rem_a, _) = a
                let #(_, _, rem_b, _) = b
                float.compare(rem_b, rem_a)
              })
            // Need to subtract bps: sort by remainder ascending (smallest/most negative first)
            False ->
              list.sort(with_remainders, fn(a, b) {
                let #(_, _, rem_a, _) = a
                let #(_, _, rem_b, _) = b
                float.compare(rem_a, rem_b)
              })
          }

          // Distribute adjustment (handles both positive and negative)
          let adjusted =
            list.index_map(sorted, fn(item, idx) {
              let #(instrument_type, rounded, _, _) = item
              let absolute_adjustment_needed =
                int.absolute_value(adjustment_needed)
              let delta = case adjustment_needed {
                n if n > 0 && idx < n -> 1
                n if n < 0 && idx < absolute_adjustment_needed -> -1
                _ -> 0
              }

              let final_value = rounded + delta
              #(instrument_type, final_value)
            })

          dict.from_list(adjusted)
        }
      }
    }
    False -> dict.new()
  }
}

pub fn get_band(
  policy: Policy,
  key: policy_types.PolicyTargetKey,
) -> Result(Band, String) {
  use target_allocation <- result.try(
    dict.get(policy_target_weights(policy.targets), key)
    |> result.map_error(fn(_) {
      "Could not find a policytarget for key "
      <> policy_types.policy_target_key_value(key)
    }),
  )
  let rel = policy_sensitivity_rel_bps(policy.sensitivity)
  let floor = policy_sensitivity_floor_bps(policy.sensitivity)
  let cap = policy_sensitivity_cap_bps(policy.sensitivity)

  let allocation = policy_types.allocation_bps(target_allocation)
  let band = {
    let rel_half_bps = round_div_bps(allocation, rel)
    let half_bps = clamp(rel_half_bps, floor, cap)
    let lower_bound = max(0, allocation - half_bps)
    let upper_bound = min(10_000, allocation + half_bps)
    case band(lower_bound, upper_bound) {
      Ok(band) -> band
      Error(_) -> Band(0, 10_000)
    }
  }

  Ok(band)
}

fn max(a: Int, b: Int) -> Int {
  case a > b {
    True -> a
    False -> b
  }
}

fn min(a: Int, b: Int) -> Int {
  case a < b {
    True -> a
    False -> b
  }
}

fn round_div_bps(a_bps: Int, b_bps: Int) -> Int {
  { { a_bps * b_bps } + 5000 } / 10_000
}

// Helper function to clamp width between floor and cap
fn clamp(value: Int, floor: Int, cap: Int) -> Int {
  case value < floor {
    True -> floor
    False ->
      case value > cap {
        True -> cap
        False -> value
      }
  }
}

// Detect drift by comparing current allocations against policy bands
pub fn detect_drift(
  snapshot: AllocationSnapshot,
  policy: Policy,
) -> Result(DriftReport, String) {
  let targets = policy_target_weights(policy.targets)

  let analyses =
    dict.fold(targets, Ok([]), fn(acc, target_key, target_allocation) {
      use analyses_list <- result.try(acc)

      let key_value = policy_target_key_value(target_key)
      let target_weight = allocation_bps(target_allocation)

      // Get current weight based on target type
      let current_weight_bps: Int = case policy_target_type(policy.targets) {
        InstrumentType -> {
          let instrument_type = instrument_type(key_value)
          case dict.get(snapshot.by_instrument_type, instrument_type) {
            Ok(weight) -> weight
            Error(_) -> {
              io.println(
                "WARN: could not find any weight for instrument_type: "
                <> string.inspect(instrument_type)
                <> ". defaulting to 0",
              )
              0
            }
          }
        }
      }

      // Get band for this target key - propagate errors
      use band <- result.try(get_band(policy, target_key))

      let lower_bound = band_lower_bound(band)
      let upper_bound = band_upper_bound(band)

      // Determine status and delta
      let #(status, delta_to_edge) = case current_weight_bps {
        w if w < lower_bound -> #(OutOfBand, lower_bound - w)
        w if w > upper_bound -> #(OutOfBand, w - upper_bound)
        _ -> #(InBand, 0)
      }

      let analysis =
        DriftAnalysis(
          target_key_type: policy_target_type(policy.targets),
          target_key: target_key,
          current_weight_bps: current_weight_bps,
          target_weight_bps: target_weight,
          status: status,
          delta_to_edge_bps: delta_to_edge,
          lower_bound_bps: lower_bound,
          upper_bound_bps: upper_bound,
        )

      Ok([analysis, ..analyses_list])
    })

  case analyses {
    Ok(analyses_list) -> Ok(DriftReport(analyses: list.reverse(analyses_list)))
    Error(e) -> Error(e)
  }
}
