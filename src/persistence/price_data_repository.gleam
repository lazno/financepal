import domain/common_types.{
  type PriceData, PriceData, currency, currency_name, isin, isin_value, price,
  price_amount,
}
import gleam/dynamic/decode
import gleam/float
import gleam/result
import gleam/string
import gleam/time/timestamp
import persistence/db_utils.{type TransactionError, db_error}
import sqlight
import youid/uuid

pub fn get_latest_price_data(
  conn: sqlight.Connection,
) -> Result(List(PriceData), String) {
  let sql =
    "SELECT symbol, price, currency, fetched_at
    FROM prices
    WHERE (symbol, fetched_at) IN (
      SELECT symbol, MAX(fetched_at)
      FROM prices
      GROUP BY symbol
    )"

  sqlight.query(sql, on: conn, with: [], expecting: price_data_decoder())
  |> result.map_error(fn(e) {
    "error while fetching latest price data: " <> string.inspect(e)
  })
}

fn price_data_decoder() -> decode.Decoder(PriceData) {
  use isin_str <- decode.field(0, decode.string)
  use price_float <- decode.field(1, decode.float)
  use currency_str <- decode.field(2, decode.string)
  use fetched_at_f <- decode.field(3, decode.float)

  let isin = isin(isin_str)
  let currency = currency(currency_str)
  let price = case price(price_float) {
    Ok(p) -> p
    Error(_) ->
      case price(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero price should be valid"
      }
  }
  let fetched_at = timestamp.from_unix_seconds(float.round(fetched_at_f))

  decode.success(PriceData(isin, price, currency, fetched_at))
}

pub fn delete_all(con: sqlight.Connection) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM prices"
  sqlight.exec(sql, con)
  |> result.map_error(fn(e) { db_error("Error while clearing table prices", e) })
}

pub fn insert_price_data(
  conn: sqlight.Connection,
  price_data: List(PriceData),
) -> Result(Int, String) {
  insert_price_data_loop(conn, price_data, 0)
  |> result.map_error(fn(e) {
    "error while inserting price_data" <> string.inspect(e)
  })
}

fn insert_price_data_loop(
  conn: sqlight.Connection,
  price_data: List(PriceData),
  count: Int,
) -> Result(Int, sqlight.Error) {
  case price_data {
    [] -> Ok(count)
    [first, ..rest] -> {
      let sql =
        "INSERT INTO prices (id, isin, price, currency, fetched_at) 
         VALUES (?, ?, ?, ?, ?)"

      let id = uuid.v7_string()
      let isin = isin_value(first.isin)
      let price = price_amount(first.price)
      let currency = currency_name(first.currency)
      let fetched_at = timestamp.to_unix_seconds(first.timestamp)

      let nil_decoder = decode.success(Nil)

      use _result <- result.try(sqlight.query(
        sql,
        on: conn,
        with: [
          sqlight.text(id),
          sqlight.text(isin),
          sqlight.float(price),
          sqlight.text(currency),
          sqlight.float(fetched_at),
        ],
        expecting: nil_decoder,
      ))

      insert_price_data_loop(conn, rest, count + 1)
    }
  }
}
