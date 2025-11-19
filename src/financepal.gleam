import actor/position_records_processor
import actor/price_fetcher
import application/types.{Context}
import gleam/erlang/process
import gleam/io
import mist
import persistence/database
import rest/resource/router
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let db_path = "financepal.db"

  let assert Ok(db) = database.connect(db_path)
  let assert Ok(_) = database.init_schema(db)

  io.println("Database initialized at: " <> db_path)

  // clear_db(db)

  //start actors
  let assert Ok(position_records_actor) = position_records_processor.start(db)
  let assert Ok(subject) = price_fetcher.start(db)
  process.send(subject.data, price_fetcher.FetchAllPrices(subject.data))

  // application context
  let ctx =
    Context(db: db, position_records_processor: position_records_actor.data)

  let handler = fn(req) { router.handle_request(req, ctx) }

  // TODO manage secret key
  let assert Ok(_) =
    wisp_mist.handler(handler, "financepal_secret_key")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  io.println("Server started on http://localhost:8080")

  process.sleep_forever()
}
// fn clear_db(db: sqlight.Connection) -> Nil {
// let assert Ok(_) = {
//   use _ <- result.try(position_repository.delete_all(db))
//   use _ <- result.try(position_records_repository.delete_all(db))
//   use _ <- result.try(price_data_repository.delete_all(db))
//   asset_registry_repository.delete_all(db)
// }
//   io.println("Successfully cleared db")
// }
