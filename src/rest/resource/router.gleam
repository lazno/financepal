import application/types.{type Context}
import gleam/http
import rest/resource/directa_sim_resource
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  case wisp.path_segments(req) {
    ["api", "import"] -> handle_import(req, ctx)
    // ["api", "portfolio"] -> handle_portfolio(req, ctx)
    _ -> wisp.not_found()
  }
}

// fn handle_portfolio(req: Request, ctx: Context) -> Response {
//   case req.method {
//     http.Get -> {
//       let portfolio = {
//         use price_data <- result.try(
//           price_data_repository.get_latest_price_data(ctx.db),
//         )
//         use transactions <- result.try(
//           transaction_repository.get_all_transactions(ctx.db),
//         )
//         use positions <- result.try(calc.calculate_positions(transactions))
//         let price_data_dict = {
//           price_data
//           |> list.map(fn(pd) { #(pd.symbol, pd) })
//           |> dict.from_list
//         }
//         calc.calculate_portfolio_value(positions, price_data_dict)
//       }
//
//       case portfolio {
//         Error(e) -> {
//           let error = error_response("internal error: " <> string.inspect(e))
//           wisp.json_response(json.to_string(error_response_to_json(error)), 500)
//         }
//         Ok(p) -> {
//           let jsonized =
//             p.by_currency
//             |> dict.to_list
//             |> list.map(fn(pair) {
//               let #(currency, currency_total) = pair
//               json.object([
//                 #(
//                   types.currency_name(currency),
//                   json.object([
//                     #(
//                       "total_market_value",
//                       json.float(types.market_value_amount(
//                         currency_total.total_market_value,
//                       )),
//                     ),
//                     #(
//                       "total_cost_basis",
//                       json.float(types.cost_basis_amount(
//                         currency_total.total_cost_basis,
//                       )),
//                     ),
//                     #(
//                       "total_unrealized_profit",
//                       json.object([
//                         #(
//                           "unrealized_profit",
//                           json.float(
//                             currency_total.total_unrealized_profit.unrealized_profit,
//                           ),
//                         ),
//                         #(
//                           "unrealized_profit_pct",
//                           json.float(
//                             currency_total.total_unrealized_profit.unrealized_profit_pct,
//                           ),
//                         ),
//                       ]),
//                     ),
//                   ]),
//                 ),
//               ])
//             })
//           let json =
//             json.object([
//               #("positions_by_currency", json.preprocessed_array(jsonized)),
//             ])
//           wisp.json_response(json.to_string(json), 200)
//         }
//       }
//     }
//     _ -> wisp.method_not_allowed([http.Get])
//   }
// }

fn handle_import(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      directa_sim_resource.handle_post_import_csv(req, ctx)
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}
