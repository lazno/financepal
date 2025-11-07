import domain/calc
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
            use positions <- result.try(
              calc.calculate_positions(records)
              |> result.map_error(fn(e) { db_utils.UserError(e) }),
            )
            use positions_num <- result.try(
              position_repository.insert_positions(state.db, positions),
            )

            list.map(positions, fn(r) { r.asset })
            |> asset_registry_repository.insert_assets(state.db, _)
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
