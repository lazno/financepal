import application/types.{type Context}
import domain/common_types.{
  currency_name, market_value_amount, price_amount, quantity_shares,
  symbol_ticker,
}
import domain/portfolio
import gleam/dict
import gleam/http.{Get}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import persistence/asset_registry_repository
import persistence/position_repository
import persistence/price_data_repository
import rest/resource/common.{internal_error, ok}
import wisp.{type Request, type Response}

pub fn handle_get_portfolio(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> {
      let result = {
        use positions <- result.try(
          position_repository.get_all_positions(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch positions: " <> string.inspect(e)
          }),
        )

        use price_data <- result.try(
          price_data_repository.get_latest_price_data(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch prices: " <> string.inspect(e)
          }),
        )

        use assets <- result.try(
          asset_registry_repository.get_all_assets(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch assets: " <> string.inspect(e)
          }),
        )

        let #(position_snapshots, _missing_prices) =
          portfolio.enrich_positions(positions, price_data, assets)

        let portfolio_value =
          portfolio.calculate_portfolio_value(position_snapshots)

        Ok(portfolio_value)
      }

      case result {
        Ok(p) -> {
          let jsonized =
            p.by_currency
            |> dict.to_list
            |> list.map(fn(pair) {
              let #(currency, currency_total) = pair
              json.object([
                #(
                  currency_name(currency),
                  json.object([
                    #(
                      "total_market_value",
                      json.float(market_value_amount(
                        currency_total.total_market_value,
                      )),
                    ),
                    #(
                      "positions",
                      json.preprocessed_array(
                        list.map(currency_total.position_values, fn(pos) {
                          json.object([
                            #("symbol", json.string(symbol_ticker(pos.symbol))),
                            #(
                              "quantity",
                              json.float(quantity_shares(pos.quantity)),
                            ),
                            #(
                              "price",
                              json.float(price_amount(pos.current_price)),
                            ),
                            #(
                              "market_value",
                              json.float(market_value_amount(pos.market_value)),
                            ),
                          ])
                        }),
                      ),
                    ),
                  ]),
                ),
              ])
            })
          let json =
            json.object([
              #("positions_by_currency", json.preprocessed_array(jsonized)),
            ])
          ok(json)
        }
        Error(e) -> internal_error(e)
      }
    }
    _ -> wisp.method_not_allowed([Get])
  }
}
