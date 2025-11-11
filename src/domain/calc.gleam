import domain/common_types
import domain/position_types
import gleam/dict.{type Dict}
import gleam/list

//
// pub fn calculate_portfolio_value(
//   positions: List(common_types.Position),
//   prices: Dict(common_types.Symbol, common_types.PriceData),
// ) -> Result(common_types.PortfolioValue, String) {
//   positions
//   |> list.group(fn(p) { p.currency })
//   |> dict.to_list
//   |> list.map(fn(pair) {
//     let #(currency, grouped_positions) = pair
//     let position_values =
//       grouped_positions
//       |> list.map(fn(p) { calculate_position_value(p, prices) })
//       |> result.all
//
//     result.map(position_values, fn(pvs) {
//       #(currency, calculate_currency_totals(currency, pvs))
//     })
//   })
//   |> result.all
//   |> result.map(dict.from_list)
//   |> result.map(common_types.PortfolioValue)
// }
//
// fn calculate_currency_totals(
//   currency: common_types.Currency,
//   position_values: List(common_types.PositionValue),
// ) {
//   let total_market_value_f =
//     sum_float(position_values, fn(pv) {
//       common_types.market_value_amount(pv.market_value)
//     })
//   let total_cost_basis_f =
//     sum_float(position_values, fn(pv) {
//       common_types.cost_basis_amount(pv.cost_basis)
//     })
//   let total_unrealized_profit_f =
//     sum_float(position_values, fn(pv) { pv.unrealized_profit.unrealized_profit })
//   let total_unrealized_profit_pct_f = case total_cost_basis_f {
//     0.0 -> 0.0
//     _ -> 100.0 *. { total_unrealized_profit_f /. total_cost_basis_f }
//   }
//
//   common_types.CurrencyTotal(
//     currency,
//     position_values,
//     common_types.market_value(total_market_value_f),
//     common_types.cost_basis(total_cost_basis_f),
//     common_types.UnrealizedProfit(
//       total_unrealized_profit_f,
//       total_unrealized_profit_pct_f,
//     ),
//   )
// }
//
// fn sum_float(data: List(a), extract: fn(a) -> Float) {
//   list.fold(data, 0.0, fn(a, b) { a +. extract(b) })
// }
//
// fn calculate_position_value(
//   position: common_types.Position,
//   price_data: Dict(common_types.Symbol, common_types.PriceData),
// ) -> Result(common_types.PositionValue, String) {
//   let symbol = position.symbol
//   let currency = position.currency
//   case dict.get(price_data, symbol) {
//     Error(e) ->
//       Error(
//         "No price data for symbol "
//         <> common_types.symbol_ticker(symbol)
//         <> ". "
//         <> string.inspect(e),
//       )
//     Ok(current_price) -> {
//       let current_price_f = common_types.price_amount(current_price.price)
//       let quantity_f = common_types.quantity_shares(position.quantity)
//       let avg_price_f = common_types.price_amount(position.avg_price)
//       let cost_basis_f = avg_price_f *. quantity_f
//       let market_value_f = current_price_f *. quantity_f
//       let unrealized_profit_f = market_value_f -. cost_basis_f
//       let unrealized_profit_pct_f = case cost_basis_f {
//         0.0 -> 0.0
//         _ -> 100.0 *. { unrealized_profit_f /. cost_basis_f }
//       }
//
//       Ok(common_types.PositionValue(
//         symbol: symbol,
//         quantity: position.quantity,
//         avg_price: position.avg_price,
//         current_price: current_price.price,
//         market_value: common_types.market_value(market_value_f),
//         cost_basis: common_types.cost_basis(cost_basis_f),
//         unrealized_profit: common_types.UnrealizedProfit(
//           unrealized_profit: unrealized_profit_f,
//           unrealized_profit_pct: unrealized_profit_pct_f,
//         ),
//         currency: currency,
//       ))
//     }
//   }
// }
//

pub fn calculate_positions(
  records: List(position_types.PositionRecord),
) -> Result(Dict(common_types.Isin, common_types.Quantity), String) {
  records
  |> list.group(fn(r) { r.isin })
  |> dict.map_values(fn(_isin, grouped) { calculate_position_quantity(grouped) })
  |> Ok
}

//
fn calculate_position_quantity(
  records: List(position_types.PositionRecord),
) -> common_types.Quantity {
  let buys =
    list.filter(records, fn(r) { r.position_record_type == position_types.Buy })
  let sells =
    list.filter(records, fn(r) { r.position_record_type == position_types.Sell })

  let total_buy_quantity = calculate_total_quantity(buys)
  let total_sell_quantity = calculate_total_quantity(sells)

  case
    common_types.subtract_quantities(total_buy_quantity, total_sell_quantity)
  {
    Ok(quantity) -> quantity
    Error(_) -> {
      // Return zero quantity if result would be negative
      case common_types.quantity(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero quantity should always be valid"
      }
    }
  }
}

//
fn calculate_total_quantity(
  records: List(position_types.PositionRecord),
) -> common_types.Quantity {
  let zero_qty = case common_types.quantity(0.0) {
    Ok(q) -> q
    Error(_) -> panic as "Zero quantity should always be valid"
  }

  list.fold(records, zero_qty, fn(acc, t) {
    common_types.add_quantities(acc, t.quantity)
  })
}
//
// fn calculate_weighted_average_price(
//   buys: List(common_types.Transaction),
// ) -> common_types.Price {
//   let weighted_sum =
//     list.fold(buys, 0.0, fn(acc, t) {
//       let qty = common_types.quantity_shares(t.quantity)
//       let prc = common_types.price_amount(t.price)
//       acc +. qty *. prc
//     })
//
//   let total_quantity =
//     list.fold(buys, 0.0, fn(acc, t) {
//       acc +. common_types.quantity_shares(t.quantity)
//     })
//
//   let avg = weighted_sum /. total_quantity
//   case common_types.price(avg) {
//     Ok(p) -> p
//     Error(_) -> panic as "Average price should always be valid"
//   }
// }
