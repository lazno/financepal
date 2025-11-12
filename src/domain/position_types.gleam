import domain/common_types.{
  type Account, type AssetName, type Isin, type OrderReference, type Quantity,
  type RecordDate, type Symbol,
}
import gleam/dict.{type Dict}
import gleam/list

// Domain: Transaction Type (ADT)
pub type PositionRecordType {
  Buy
  Sell
}

pub fn position_record_type_from_string(
  s: String,
) -> Result(PositionRecordType, String) {
  case s {
    "buy" -> Ok(Buy)
    "sell" -> Ok(Sell)
    _ -> Error("Invalid transaction type: " <> s)
  }
}

pub fn position_record_type_to_string(t: PositionRecordType) -> String {
  case t {
    Buy -> "buy"
    Sell -> "sell"
  }
}

pub type PositionRecord {
  PositionRecord(
    date: RecordDate,
    isin: Isin,
    symbol: Symbol,
    asset_name: AssetName,
    position_record_type: PositionRecordType,
    quantity: Quantity,
    account: Account,
    order_reference: OrderReference,
  )
}

// Domain: Position
pub type Position {
  Position(isin: Isin, quantity: Quantity)
}

pub fn calculate_positions(
  records: List(PositionRecord),
) -> Result(Dict(Isin, Quantity), String) {
  records
  |> list.group(fn(r) { r.isin })
  |> dict.map_values(fn(_isin, grouped) { calculate_position_quantity(grouped) })
  |> Ok
}

//
fn calculate_position_quantity(
  records: List(PositionRecord),
) -> common_types.Quantity {
  let buys = list.filter(records, fn(r) { r.position_record_type == Buy })
  let sells = list.filter(records, fn(r) { r.position_record_type == Sell })

  let total_buy_quantity = calculate_total_quantity(buys)
  let total_sell_quantity = calculate_total_quantity(sells)

  case
    common_types.subtract_quantities(total_buy_quantity, total_sell_quantity)
  {
    Ok(quantity) -> quantity
    Error(_) -> {
      // Return zero quantity if result would be negative
      case common_types.quantity(0.0) {
        Ok(q) -> q
        Error(_) -> panic as "Zero quantity should always be valid"
      }
    }
  }
}

//
fn calculate_total_quantity(
  records: List(PositionRecord),
) -> common_types.Quantity {
  let zero_qty = case common_types.quantity(0.0) {
    Ok(q) -> q
    Error(_) -> panic as "Zero quantity should always be valid"
  }

  list.fold(records, zero_qty, fn(acc, t) {
    common_types.add_quantities(acc, t.quantity)
  })
}
