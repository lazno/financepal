import domain/common_types.{isin, isin_value, quantity, quantity_shares}
import domain/position_types.{type Position, Position}
import gleam/dynamic/decode
import gleam/result
import gleam/string
import persistence/db_utils.{type TransactionError, db_error}
import sqlight

pub fn insert_positions(
  conn: sqlight.Connection,
  positions: List(Position),
) -> Result(Int, TransactionError(e)) {
  insert_positions_loop(conn, positions, 0)
  |> result.map_error(fn(e) {
    db_utils.db_error("Error inserting position into db", e)
  })
}

fn insert_positions_loop(
  conn: sqlight.Connection,
  records: List(Position),
  count: Int,
) -> Result(Int, sqlight.Error) {
  case records {
    [] -> Ok(count)
    [record, ..rest] -> {
      let sql =
        "INSERT INTO positions (isin, quantity) 
         VALUES (?, ?)
         ON CONFLICT(isin) 
         DO UPDATE SET 
           quantity = excluded.quantity"

      let isin = isin_value(record.isin)
      let quantity = quantity_shares(record.quantity)

      let nil_decoder = decode.success(Nil)

      use _result <- result.try(sqlight.query(
        sql,
        on: conn,
        with: [
          sqlight.text(isin),
          sqlight.float(quantity),
        ],
        expecting: nil_decoder,
      ))

      insert_positions_loop(conn, rest, count + 1)
    }
  }
}

pub fn delete_all(con: sqlight.Connection) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM positions"
  sqlight.exec(sql, con)
  |> result.map_error(fn(e) {
    db_error("Error while clearing table positions", e)
  })
}

pub fn get_all_positions(
  conn: sqlight.Connection,
) -> Result(List(Position), String) {
  let sql =
    "SELECT isin, quantity
     FROM positions 
     ORDER BY symbol ASC"

  sqlight.query(sql, on: conn, with: [], expecting: position_decoder())
  |> result.map_error(fn(e) {
    "Error while fetching positions from database: " <> string.inspect(e)
  })
}

fn position_decoder() -> decode.Decoder(Position) {
  use isin_str <- decode.field(1, decode.string)
  use quantity_float <- decode.field(4, decode.float)

  // Create domain objects
  let isin = isin(isin_str)

  // Parse quantity - default to 0.0 if invalid
  let quantity = case quantity(quantity_float) {
    Ok(q) -> q
    Error(_) ->
      case quantity(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero quantity should be valid"
      }
  }

  decode.success(Position(isin: isin, quantity: quantity))
}
