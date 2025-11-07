import domain/common_types.{
  type Symbol, Asset, asset_name, asset_name_value, isin, isin_value, quantity,
  quantity_shares, symbol as symbol_fn, symbol_ticker,
}
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
        "INSERT INTO positions (symbol, isin, asset_name, quantity) 
         VALUES (?, ?, ?, ?)
         ON CONFLICT(isin) 
         DO UPDATE SET 
           symbol = excluded.symbol,
           asset_name = excluded.asset_name,
           quantity = excluded.quantity"

      let symbol = symbol_ticker(record.asset.symbol)
      let isin = isin_value(record.asset.isin)
      let asset_name = asset_name_value(record.asset.name)
      let quantity = quantity_shares(record.quantity)

      let nil_decoder = decode.success(Nil)

      use _result <- result.try(sqlight.query(
        sql,
        on: conn,
        with: [
          sqlight.text(symbol),
          sqlight.text(isin),
          sqlight.text(asset_name),
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
    "SELECT symbol, isin, asset_name, quantity
     FROM positions 
     ORDER BY symbol ASC"

  sqlight.query(sql, on: conn, with: [], expecting: transaction_decoder())
  |> result.map_error(fn(e) {
    "Error while fetching positions from database: " <> string.inspect(e)
  })
}

fn transaction_decoder() -> decode.Decoder(Position) {
  use symbol_str <- decode.field(0, decode.string)
  use isin_str <- decode.field(1, decode.string)
  use asset_name_str <- decode.field(2, decode.string)
  use quantity_float <- decode.field(3, decode.float)

  // Create domain objects
  let symbol = symbol_fn(symbol_str)
  let isin = isin(isin_str)
  let asset_name = asset_name(asset_name_str)

  // Parse quantity - default to 0.0 if invalid
  let quantity = case quantity(quantity_float) {
    Ok(q) -> q
    Error(_) ->
      case quantity(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero quantity should be valid"
      }
  }

  decode.success(Position(
    asset: Asset(isin, symbol, asset_name),
    quantity: quantity,
  ))
}

pub fn get_all_symbols_from_db(
  db: sqlight.Connection,
) -> Result(List(Symbol), sqlight.Error) {
  let decoder = {
    use symbol <- decode.field(0, decode.string)
    decode.success(symbol_fn(symbol))
  }

  sqlight.query(
    "SELECT DISTINCT symbol FROM positions",
    on: db,
    with: [],
    expecting: decoder,
  )
}
