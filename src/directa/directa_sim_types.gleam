import gleam/float
import gleam/int
import gleam/result
import gleam/string

/// Raw Directa-sim CSV row data before processing
pub type DirectaSimRow {
  DirectaSimRow(
    transaction_date: String,
    transaction_type: DirectaSimTransactionType,
    ticker: String,
    isin: String,
    description: String,
    quantity: Float,
    order_reference: String,
  )
}

/// Processed Directa-sim transaction for rebalancing
pub type DirectaSimTransaction {
  DirectaSimTransaction(
    date: String,
    // ISO format YYYY-MM-DD
    transaction_type: DirectaSimTransactionType,
    ticker: String,
    quantity: Float,
    isin: String,
    description: String,
  )
}

/// Transaction types for Directa-sim
pub type DirectaSimTransactionType {
  Buy
  Sell
  Comissions
  WireTransferPayment
  DisagioDebtWT
  DisagioCreditWT
  BondAccrdIntWd
  BondAccrdIntWdTax
  BondsCouponPmt
  BondsCouponTax
  BondAccrdIntPmtTax
  BondAccrdIntPmt
  PortfolioStampDuty
  EtfWithholdingTax
  CapGainTax
}

/// Errors specific to Directa-sim import
pub type DirectaSimError {
  EmptyFile
  InvalidFileFormat
  MissingAccountName
  CannotParseAccountName(String)
  InvalidDateFormat(String)
  InvalidTransactionType(String)
  InvalidNumberFormat(String, String)
  InvalidQuantityFormat(String)
  InvalidColumnCount(String)
  InternalError(String)
}

/// Result of Directa-sim import operation
pub type ImportSuccess {
  ImportSuccess(account_name: String, transactions: List(DirectaSimRow))
}

/// Parse transaction type from string
pub fn parse_transaction_type(
  type_str: String,
) -> Result(DirectaSimTransactionType, DirectaSimError) {
  case string.trim(type_str) {
    "Buy" -> Ok(Buy)
    "Sell" -> Ok(Sell)
    "Commissions" -> Ok(Comissions)
    "Wire transfer payment" -> Ok(WireTransferPayment)
    "Disagio debt w/t" -> Ok(DisagioDebtWT)
    "Disagio credit w/t" -> Ok(DisagioCreditWT)
    "Bond accrd int wd" -> Ok(BondAccrdIntWd)
    "Bond accrd int wd tax" -> Ok(BondAccrdIntWdTax)
    "Bonds coupon pmt" -> Ok(BondsCouponPmt)
    "Bonds coupon tax" -> Ok(BondsCouponTax)
    "Bond accrd int pmt tax" -> Ok(BondAccrdIntPmtTax)
    "Bond accrd int pmt" -> Ok(BondAccrdIntPmt)
    "Portfolio stamp duty*" -> Ok(PortfolioStampDuty)
    "Etf withholding tax" -> Ok(EtfWithholdingTax)
    "Cap.gain tax" -> Ok(CapGainTax)
    _ -> Error(InvalidTransactionType(type_str))
  }
}

/// Parse float with error handling
fn parse_float_field(
  field_name: String,
  value: String,
) -> Result(Float, DirectaSimError) {
  let s =
    value
    |> string.trim

  let via_int = result.map(int.parse(s), int.to_float)
  let via_float = float.parse(s)

  result.or(via_float, via_int)
  |> result.map_error(fn(_) { InvalidNumberFormat(field_name, value) })
}

/// Parse quantity with sign handling (positive for buy, negative for sell)
pub fn parse_quantity(quantity_str: String) -> Result(Float, DirectaSimError) {
  parse_float_field("quantity", string.trim(quantity_str))
}

/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(
  italian_date: String,
) -> Result(String, DirectaSimError) {
  let split = string.split(string.trim(italian_date), "-")

  case split {
    [day, month, year] ->
      case string.length(day), string.length(month), string.length(year) {
        2, 2, 4 -> Ok(year <> "-" <> month <> "-" <> day)
        _, _, _ -> Error(InvalidDateFormat(italian_date))
      }
    _ -> Error(InvalidDateFormat(italian_date))
  }
}
