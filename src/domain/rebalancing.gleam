import domain/common_types.{
  type Asset, type Currency, type InstrumentType, type Isin, type MarketValue,
  type Price, type PriceData, type Quantity, type Symbol, instrument_type_value,
  isin_value, market_value, market_value_amount, price_amount, quantity_shares,
}
import domain/policy_types.{
  type Policy, policy_sensitivity_cap_pp, policy_sensitivity_floor_pp,
  policy_sensitivity_rel, policy_target_weights,
}
import domain/position_types.{type Position}
import gleam/dict
import gleam/list
import gleam/result

// Domain: Band - represents allowed drift range for an instrument type
pub opaque type Band {
  Band(lower_bound: Float, upper_bound: Float)
}

pub fn band(lower_bound: Float, upper_bound: Float) -> Result(Band, String) {
  case lower_bound >. upper_bound {
    True -> Error("Lower bound cannot exceed upper bound")
    False -> Ok(Band(lower_bound, upper_bound))
  }
}

pub fn band_lower_bound(band: Band) -> Float {
  band.lower_bound
}

pub fn band_upper_bound(band: Band) -> Float {
  band.upper_bound
}

// Domain: PositionSnapshot - represents a single position with current market data
pub type PositionSnapshot {
  PositionSnapshot(
    isin: Isin,
    symbol: Symbol,
    instrument_type: InstrumentType,
    quantity: Quantity,
    current_price: Price,
    market_value: MarketValue,
    currency: Currency,
  )
}

// Domain: AllocationSnapshot - complete portfolio snapshot for rebalancing analysis
pub type AllocationSnapshot {
  AllocationSnapshot(
    by_instrument_type: dict.Dict(String, Float),
    // instrument_type -> weight (0.0-1.0)
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
  // Build price lookup map (isin -> PriceData)
  let price_map =
    list.fold(price_data, dict.new(), fn(acc, price_data) {
      dict.insert(acc, isin_value(price_data.isin), price_data)
    })

  // Build asset lookup map (isin -> Asset)
  let asset_map =
    list.fold(assets, dict.new(), fn(acc, asset) {
      dict.insert(acc, isin_value(asset.isin), asset)
    })

  // Process each position to create snapshots
  let #(position_snapshots, missing_prices) =
    process_positions(positions, price_map, asset_map, [], [])

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

// Helper function to process positions into snapshots
fn process_positions(
  positions: List(Position),
  price_map: dict.Dict(String, PriceData),
  asset_map: dict.Dict(String, Asset),
  snapshots: List(PositionSnapshot),
  missing: List(Isin),
) -> #(List(PositionSnapshot), List(Isin)) {
  case positions {
    [] -> #(list.reverse(snapshots), list.reverse(missing))
    [position, ..rest] -> {
      let isin_str = isin_value(position.isin)

      case dict.get(price_map, isin_str) {
        Error(_) -> {
          // No price data available
          process_positions(rest, price_map, asset_map, snapshots, [
            position.isin,
            ..missing
          ])
        }

        Ok(price_data) -> {
          case dict.get(asset_map, isin_str) {
            Error(_) -> {
              // No asset registry entry - this should not happen in a consistent system
              // For now, skip this position and log as missing
              process_positions(rest, price_map, asset_map, snapshots, [
                position.isin,
                ..missing
              ])
            }

            Ok(asset) -> {
              let market_value =
                calculate_market_value(position.quantity, price_data.price)

              let snapshot =
                PositionSnapshot(
                  isin: position.isin,
                  symbol: asset.symbol,
                  instrument_type: asset.instrument_type,
                  quantity: position.quantity,
                  current_price: price_data.price,
                  market_value: market_value,
                  currency: price_data.currency,
                )

              process_positions(
                rest,
                price_map,
                asset_map,
                [snapshot, ..snapshots],
                missing,
              )
            }
          }
        }
      }
    }
  }
}

// Calculate market value for a position
fn calculate_market_value(quantity: Quantity, price: Price) -> MarketValue {
  let shares = quantity_shares(quantity)
  let price_amount = price_amount(price)
  market_value(shares *. price_amount)
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
) -> dict.Dict(String, Float) {
  // Group by instrument type and sum values
  let type_totals =
    list.fold(snapshots, dict.new(), fn(acc, snapshot) {
      let type_str = instrument_type_value(snapshot.instrument_type)
      let current_value = case dict.get(acc, type_str) {
        Ok(v) -> v
        Error(_) -> 0.0
      }
      dict.insert(
        acc,
        type_str,
        current_value +. market_value_amount(snapshot.market_value),
      )
    })

  // Convert to weights
  case total_value >. 0.0 {
    True ->
      dict.map_values(type_totals, fn(_type, value) { value /. total_value })
    False -> dict.new()
    // Empty portfolio
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
  let rel = policy_sensitivity_rel(policy.sensitivity)
  let floor_pp = policy_sensitivity_floor_pp(policy.sensitivity)
  let cap_pp = policy_sensitivity_cap_pp(policy.sensitivity)

  let allocation_value = policy_types.allocation_value(target_allocation)
  let band = {
    let raw_width = allocation_value *. rel
    let width = clamp_width(raw_width, floor_pp, cap_pp)
    let lower_bound = allocation_value -. width
    let upper_bound = allocation_value +. width

    case band(lower_bound, upper_bound) {
      Ok(band) -> band
      Error(_) -> Band(0.0, 1.0)
      // Fallback to full range on error
    }
  }

  Ok(band)
}

// Helper function to clamp width between floor and cap
fn clamp_width(raw_width: Float, floor_pp: Float, cap_pp: Float) -> Float {
  case raw_width <. floor_pp {
    True -> floor_pp
    False ->
      case raw_width >. cap_pp {
        True -> cap_pp
        False -> raw_width
      }
  }
}
