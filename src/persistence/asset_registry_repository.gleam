import domain/common_types.{
  type Asset, type Symbol, Asset, asset_name, asset_name_value, instrument_type,
  instrument_type_value, isin, isin_value, symbol as symbol_fn, symbol_ticker,
}
import gleam/dynamic/decode
import gleam/result
import gleam/string
import persistence/db_utils.{type TransactionError, db_error}
import sqlight

pub fn insert_assets(
  conn: sqlight.Connection,
  positions: List(Asset),
) -> Result(Int, TransactionError(e)) {
  insert_asset_loop(conn, positions, 0)
  |> result.map_error(fn(e) {
    db_utils.db_error("error inserting assets into db", e)
  })
}

fn insert_asset_loop(
  conn: sqlight.Connection,
  assets: List(Asset),
  count: Int,
) -> Result(Int, sqlight.Error) {
  case assets {
    [] -> Ok(count)
    [asset, ..rest] -> {
      let sql =
        "INSERT INTO asset_registry (symbol, isin, instrument_type, asset_name) 
         VALUES (?, ?, ?, ?)
         ON CONFLICT(isin) 
         DO NOTHING"

      let symbol = symbol_ticker(asset.symbol)
      let isin = isin_value(asset.isin)
      let asset_name = asset_name_value(asset.name)
      let instrument_type = instrument_type_value(asset.instrument_type)

      let nil_decoder = decode.success(Nil)

      use _result <- result.try(sqlight.query(
        sql,
        on: conn,
        with: [
          sqlight.text(symbol),
          sqlight.text(isin),
          sqlight.text(instrument_type),
          sqlight.text(asset_name),
        ],
        expecting: nil_decoder,
      ))

      insert_asset_loop(conn, rest, count + 1)
    }
  }
}

pub fn delete_all(con: sqlight.Connection) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM asset_registry"
  sqlight.exec(sql, con)
  |> result.map_error(fn(e) {
    db_error("Error while clearing table asset_registry", e)
  })
}

pub fn get_all_assets(
  conn: sqlight.Connection,
) -> Result(List(Asset), TransactionError(e)) {
  let sql =
    "SELECT symbol, isin, instrument_type, asset_name
     FROM asset_registry 
     ORDER BY symbol ASC"

  sqlight.query(sql, on: conn, with: [], expecting: asset_decoder())
  |> result.map_error(fn(e) {
    db_utils.DbError(
      "Error while fetching assets from database: " <> string.inspect(e),
    )
  })
}

fn asset_decoder() -> decode.Decoder(Asset) {
  use symbol_str <- decode.field(0, decode.string)
  use isin_str <- decode.field(1, decode.string)
  use instrument_type_str <- decode.field(2, decode.string)
  use asset_name_str <- decode.field(3, decode.string)

  // Create domain objects
  let symbol = symbol_fn(symbol_str)
  let isin = isin(isin_str)
  let instrument_type = instrument_type(instrument_type_str)
  let asset_name = asset_name(asset_name_str)

  decode.success(Asset(
    symbol: symbol,
    isin: isin,
    name: asset_name,
    instrument_type: instrument_type,
  ))
}

pub fn get_all_assets_from_db(
  db: sqlight.Connection,
) -> Result(List(Symbol), TransactionError(e)) {
  let decoder = {
    use symbol <- decode.field(0, decode.string)
    decode.success(symbol_fn(symbol))
  }

  sqlight.query(
    "SELECT DISTINCT symbol FROM asset_registry",
    on: db,
    with: [],
    expecting: decoder,
  )
  |> result.map_error(fn(e) {
    db_utils.DbError(
      "Error while fetching assets from db: " <> string.inspect(e),
    )
  })
}
