import domain/common_types.{
  type Account, type AssetName, type Isin, type OrderReference, type Quantity,
  type RecordDate, type Symbol,
}

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
