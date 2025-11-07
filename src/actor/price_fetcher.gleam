import domain/common_types
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import persistence/asset_registry_repository
import persistence/database.{type Connection}
import persistence/price_data_repository
import rest/client/yahoo

pub type Message {
  FetchAllPrices(subject: process.Subject(Message))
  Shutdown
}

pub type State {
  State(db: Connection, interval_ms: Int, rate_limit_delay_ms: Int)
}

pub fn start(db: Connection) {
  actor.new(State(db: db, interval_ms: 10_000, rate_limit_delay_ms: 1000))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    FetchAllPrices(subject) -> {
      io.println("now fetching prices")
      let prices = {
        use assets <- result.try(
          asset_registry_repository.get_all_assets(state.db)
          |> result.map_error(fn(e) { string.inspect(e) }),
        )
        fetch_all_prices(assets, state.rate_limit_delay_ms)
      }
      let inserted =
        result.try(prices, fn(p) {
          price_data_repository.insert_price_data(state.db, p)
        })
      case inserted {
        Ok(n) ->
          io.println(
            "inserted " <> int.to_string(n) <> " entries into price data",
          )
        Error(e) ->
          io.print_error(
            "error while inserting price data " <> string.inspect(e),
          )
      }

      process.send_after(subject, state.interval_ms, FetchAllPrices(subject))
      actor.continue(state)
    }

    Shutdown -> actor.stop()
  }
}

fn fetch_all_prices(
  assets: List(common_types.Asset),
  rate_limit_delay_ms: Int,
) -> Result(List(common_types.PriceData), String) {
  let fetch_price = fn(asset: common_types.Asset) {
    let res = yahoo.fetch_price_from_yahoo(asset.isin)
    process.sleep(rate_limit_delay_ms)
    res
  }

  list.map(assets, fetch_price)
  |> result.all
}
