import domain/common_types.{
  type OrderReference, account, account_name, asset_name,
  asset_name_value, isin, isin_value, order_reference, order_reference_value,
  quantity, quantity_shares, record_date, record_date_value, symbol as symbol_fn,
  symbol_ticker,
}
import domain/position_types.{
  type PositionRecord, Buy, PositionRecord, position_record_type_from_string,
  position_record_type_to_string,
}
import gleam/dict
import gleam/dynamic/decode
import gleam/list
import gleam/result
import persistence/db_utils.{type TransactionError, db_error}
import sqlight
import youid/uuid

pub fn insert_position_records(
  con: sqlight.Connection,
  records: List(PositionRecord),
) -> Result(Int, TransactionError(e)) {
  records
  |> list.group(fn(r) { r.order_reference })
  |> dict.keys
  |> list.map(fn(or) { delete_by_order_reference(con, or) })

  insert_position_records_loop(con, records, 0)
  |> result.map_error(fn(e) {
    db_error("Error inserting position records into db", e)
  })
}

pub fn delete_by_order_reference(
  con: sqlight.Connection,
  order_reference: OrderReference,
) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM position_records where order_reference = ?"

  sqlight.query(
    sql,
    con,
    [sqlight.text(order_reference_value(order_reference))],
    decode.success(Nil),
  )
  |> result.replace(Nil)
  |> result.map_error(fn(e) {
    db_error("error while deleting records by order_reference", e)
  })
}

fn insert_position_records_loop(
  conn: sqlight.Connection,
  records: List(PositionRecord),
  count: Int,
) -> Result(Int, sqlight.Error) {
  case records {
    [] -> Ok(count)
    [record, ..rest] -> {
      let sql =
        " 
          INSERT INTO position_records (id, date, symbol, isin, asset_name, type, quantity, account, order_reference) 
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        "

      let id = uuid.v7_string()
      let date = record_date_value(record.date)
      let symbol = symbol_ticker(record.symbol)
      let isin = isin_value(record.isin)
      let asset_name = asset_name_value(record.asset_name)

      let record_type =
        position_record_type_to_string(record.position_record_type)
      let quantity = quantity_shares(record.quantity)
      let account = account_name(record.account)
      let order_reference = order_reference_value(record.order_reference)

      let nil_decoder = decode.success(Nil)

      use _result <- result.try(sqlight.query(
        sql,
        on: conn,
        with: [
          sqlight.text(id),
          sqlight.text(date),
          sqlight.text(symbol),
          sqlight.text(isin),
          sqlight.text(asset_name),
          sqlight.text(record_type),
          sqlight.float(quantity),
          sqlight.text(account),
          sqlight.text(order_reference),
        ],
        expecting: nil_decoder,
      ))

      insert_position_records_loop(conn, rest, count + 1)
    }
  }
}

pub fn delete_all(con: sqlight.Connection) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM position_records"
  sqlight.exec(sql, con)
  |> result.map_error(fn(e) {
    db_error("Error while clearing table position_records", e)
  })
}

pub fn get_all_position_records(
  conn: sqlight.Connection,
) -> Result(List(PositionRecord), TransactionError(e)) {
  let sql =
    "SELECT date, symbol, isin, asset_name, type, quantity, account, order_reference
     FROM position_records 
     ORDER BY date ASC"

  sqlight.query(sql, on: conn, with: [], expecting: record_decoder())
  |> result.map_error(fn(e) {
    db_error("Error while fetching position records from database", e)
  })
}

fn record_decoder() -> decode.Decoder(PositionRecord) {
  use date_str <- decode.field(0, decode.string)
  use symbol_str <- decode.field(1, decode.string)
  use isin_str <- decode.field(2, decode.string)
  use asset_name_str <- decode.field(3, decode.string)
  use type_str <- decode.field(4, decode.string)
  use quantity_float <- decode.field(5, decode.float)
  use account_str <- decode.field(6, decode.string)
  use order_ref_str <- decode.field(7, decode.string)

  // Create domain objects
  let date = record_date(date_str)
  let symbol = symbol_fn(symbol_str)
  let isin = isin(isin_str)
  let asset_name = asset_name(asset_name_str)
  let account = account(account_str)
  let order_reference = order_reference(order_ref_str)

  // Parse record type - default to Buy if invalid
  let position_record_type = case position_record_type_from_string(type_str) {
    Ok(t) -> t
    Error(_) -> Buy
  }

  // Parse quantity - default to 0.0 if invalid
  let quantity = case quantity(quantity_float) {
    Ok(q) -> q
    Error(_) ->
      case quantity(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero quantity should be valid"
      }
  }

  decode.success(PositionRecord(
    date: date,
    isin: isin,
    symbol: symbol,
    asset_name: asset_name,
    position_record_type: position_record_type,
    quantity: quantity,
    account: account,
    order_reference: order_reference,
  ))
}
