import domain/common_types.{
  type Asset, type AssetName, type Currency, type InstrumentType, type Isin,
  type MarketValue, type PortfolioValue, type Price, type PriceData,
  type Quantity, type Symbol, CurrencyTotal, PortfolioValue, PositionValue,
  UnrealizedProfit, cost_basis, isin_value, market_value, market_value_amount,
  price, price_amount, quantity_shares,
}
import domain/position_types.{type Position}
import gleam/dict
import gleam/list

// Domain: PositionSnapshot - represents a single position with current market data
pub type PositionSnapshot {
  PositionSnapshot(
    isin: Isin,
    symbol: Symbol,
    name: AssetName,
    instrument_type: InstrumentType,
    quantity: Quantity,
    current_price: Price,
    market_value: MarketValue,
    currency: Currency,
  )
}

// Main snapshot function - builds current portfolio state for rebalancing analysis
// Takes data as parameters for testability (no database dependencies)
pub fn enrich_positions(
  positions: List(Position),
  price_data: List(PriceData),
  assets: List(Asset),
) -> #(List(PositionSnapshot), List(Isin)) {
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
  process_positions(positions, price_map, asset_map, [], [])
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
                  name: asset.name,
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

pub fn calculate_portfolio_value(
  snapshots: List(PositionSnapshot),
) -> PortfolioValue {
  let by_currency =
    list.group(snapshots, fn(s) { common_types.currency_name(s.currency) })

  let currency_totals =
    dict.map_values(by_currency, fn(_currency_name, currency_snapshots) {
      let position_values =
        list.map(currency_snapshots, fn(s) {
          // For now, we don't have cost basis, so we set it to 0
          // In the future, we would look up cost basis from transaction history
          let cost_basis = cost_basis(0.0)
          let unrealized_profit = UnrealizedProfit(0.0, 0.0)
          // We also don't have avg price yet
          let assert Ok(avg_price) = price(0.0)

          PositionValue(
            symbol: s.symbol,
            name: s.name,
            quantity: s.quantity,
            avg_price: avg_price,
            current_price: s.current_price,
            market_value: s.market_value,
            cost_basis: cost_basis,
            unrealized_profit: unrealized_profit,
            currency: s.currency,
          )
        })

      let total_market_value =
        list.fold(currency_snapshots, 0.0, fn(acc, s) {
          acc +. market_value_amount(s.market_value)
        })
        |> market_value

      let total_cost_basis = cost_basis(0.0)
      let total_unrealized_profit = UnrealizedProfit(0.0, 0.0)

      // We can safely take the currency from the first snapshot because we grouped by it
      let assert [first, ..] = currency_snapshots

      CurrencyTotal(
        currency: first.currency,
        position_values: position_values,
        total_market_value: total_market_value,
        total_cost_basis: total_cost_basis,
        total_unrealized_profit: total_unrealized_profit,
      )
    })

  // Convert string keys back to Currency type for the final Dict
  let final_dict =
    dict.fold(currency_totals, dict.new(), fn(acc, _k, v) {
      dict.insert(acc, v.currency, v)
    })

  PortfolioValue(by_currency: final_dict)
}
