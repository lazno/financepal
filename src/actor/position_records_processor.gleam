import domain/calc
import domain/common_types
import domain/position_types
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/string
import persistence/asset_registry_repository
import persistence/database.{type Connection}
import persistence/db_utils
import persistence/position_records_repository
import persistence/position_repository
import rest/client/yahoo

pub type Message {
  PositionRecordsUpdated
  Shutdown
}

pub type State {
  State(db: Connection)
}

pub fn start(db: Connection) {
  actor.new(State(db: db))
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    PositionRecordsUpdated -> {
      let processing_result =
        db_utils.wrap_in_transaction(
          fn() {
            use records <- result.try(
              position_records_repository.get_all_position_records(state.db),
            )
            use isin_to_quantities <- result.try(
              calc.calculate_positions(records)
              |> result.map_error(fn(e) { db_utils.UserError(e) }),
            )

            // Get unique assets from records for enrichment
            let isin_to_identifiers =
              records
              |> list.group(fn(r) { #(r.isin, r.asset_name, r.symbol) })
              |> dict.keys
              |> list.map(fn(t) {
                let #(isin, _, _) = t
                #(isin, t)
              })
              |> dict.from_list

            use instrument_types <- result.try(
              yahoo_info(dict.keys(isin_to_identifiers))
              |> result.map_error(fn(e) { db_utils.UserError(e) }),
            )

            use positions <- result.try(
              build_positions(isin_to_quantities)
              |> result.map_error(fn(e) { db_utils.UserError(e) }),
            )
            use positions_num <- result.try(
              position_repository.insert_positions(state.db, positions),
            )

            use assets <- result.try(
              build_assets(dict.values(isin_to_identifiers), instrument_types)
              |> result.map_error(fn(e) { db_utils.UserError(e) }),
            )

            asset_registry_repository.insert_assets(state.db, assets)
            |> result.map(fn(asset_num) { #(positions_num, asset_num) })
          },
          state.db,
        )

      case processing_result {
        Ok(#(positions_num, assets_num)) -> {
          io.println(
            "inserted "
            <> int.to_string(positions_num)
            <> " entries into positions",
          )
          io.println(
            "inserted " <> int.to_string(assets_num) <> " entries into assets",
          )
        }
        Error(e) ->
          io.print_error(
            "error while inserting positions " <> string.inspect(e),
          )
      }

      actor.continue(state)
    }

    Shutdown -> actor.stop()
  }
}

fn yahoo_info(
  isins: List(common_types.Isin),
) -> Result(dict.Dict(common_types.Isin, common_types.InstrumentType), String) {
  isins
  |> list.map(fn(isin) {
    yahoo.fetch_quote_from_yahoo(isin)
    |> result.map(fn(yi) { #(isin, yi.instrument_type) })
  })
  |> result.all
  |> result.map(fn(l) { dict.from_list(l) })
}

fn build_assets(
  assets: List(
    #(common_types.Isin, common_types.AssetName, common_types.Symbol),
  ),
  instrument_types: dict.Dict(common_types.Isin, common_types.InstrumentType),
) -> Result(List(common_types.Asset), String) {
  assets
  |> list.map(fn(asset) {
    let #(isin, asset_name, symbol) = asset
    use instrument_type <- result.try(
      dict.get(instrument_types, isin)
      |> result.map_error(fn(_) { "Could not find instrument type for " }),
    )

    Ok(common_types.Asset(isin, symbol, asset_name, instrument_type))
  })
  |> result.all
}

fn build_positions(
  isin_quantities: dict.Dict(common_types.Isin, common_types.Quantity),
) -> Result(List(position_types.Position), String) {
  isin_quantities
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(isin, quantity) = pair

    Ok(position_types.Position(isin, quantity))
  })
  |> result.all
}
