import gleam/dict
import gleam/float
import gleam/time/timestamp

// Domain: Date
pub opaque type RecordDate {
  RecordDate(value: String)
}

pub fn record_date(value: String) -> RecordDate {
  RecordDate(value)
}

pub fn record_date_value(date: RecordDate) -> String {
  date.value
}

// Domain: Symbol
pub opaque type Symbol {
  Symbol(ticker: String)
}

pub fn symbol(ticker: String) -> Symbol {
  Symbol(ticker)
}

pub fn symbol_ticker(s: Symbol) -> String {
  s.ticker
}

// Domain: Isin
pub opaque type Isin {
  Isin(value: String)
}

pub fn isin(value: String) -> Isin {
  Isin(value)
}

pub fn isin_value(i: Isin) -> String {
  i.value
}

// Domain: AssetName 
pub opaque type AssetName {
  AssetName(value: String)
}

pub fn asset_name(value: String) -> AssetName {
  AssetName(value)
}

pub fn asset_name_value(a: AssetName) -> String {
  a.value
}

// Domain: Asset 
pub type Asset {
  Asset(
    isin: Isin,
    symbol: Symbol,
    name: AssetName,
    instrument_type: InstrumentType,
  )
}

// Domain: Quantity
pub opaque type Quantity {
  Quantity(shares: Float)
}

pub fn quantity(shares: Float) -> Result(Quantity, String) {
  case shares <. 0.0 {
    True -> Error("Quantity cannot be negative " <> float.to_string(shares))
    False -> Ok(Quantity(shares))
  }
}

pub fn quantity_shares(q: Quantity) -> Float {
  q.shares
}

pub fn add_quantities(q1: Quantity, q2: Quantity) -> Quantity {
  Quantity(q1.shares +. q2.shares)
}

pub fn subtract_quantities(
  q1: Quantity,
  q2: Quantity,
) -> Result(Quantity, String) {
  let result = q1.shares -. q2.shares
  case result <. 0.0 {
    True -> Error("Resulting quantity cannot be negative")
    False -> Ok(Quantity(result))
  }
}

pub opaque type InstrumentType {
  InstrumentType(value: String)
}

pub fn instrument_type(value: String) -> InstrumentType {
  InstrumentType(value)
}

pub fn instrument_type_value(instrument_type: InstrumentType) -> String {
  instrument_type.value
}

// Domain: Currency

pub opaque type Currency {
  Currency(name: String)
}

pub fn currency(name: String) -> Currency {
  Currency(name)
}

pub fn currency_name(c: Currency) -> String {
  c.name
}

// Domain: Price
pub opaque type Price {
  Price(amount: Float)
}

pub fn price(amount: Float) -> Result(Price, String) {
  case amount <. 0.0 {
    True -> Error("Price cannot be negative")
    False -> Ok(Price(amount))
  }
}

pub fn price_amount(p: Price) -> Float {
  p.amount
}

// Domain: Fees
pub opaque type Fees {
  Fees(amount: Float)
}

pub fn fees(amount: Float) -> Result(Fees, String) {
  case amount <. 0.0 {
    True -> Error("Fees cannot be negative")
    False -> Ok(Fees(amount))
  }
}

pub fn fees_amount(f: Fees) -> Float {
  f.amount
}

// Domain: Account
pub opaque type Account {
  Account(name: String)
}

pub fn account(name: String) -> Account {
  Account(name)
}

pub fn account_name(a: Account) -> String {
  a.name
}

// Domain: OrderReference
pub opaque type OrderReference {
  OrderReference(value: String)
}

pub fn order_reference(value: String) -> OrderReference {
  OrderReference(value)
}

pub fn order_reference_value(order_reference: OrderReference) -> String {
  order_reference.value
}

pub type PriceData {
  PriceData(
    isin: Isin,
    price: Price,
    currency: Currency,
    timestamp: timestamp.Timestamp,
  )
}

pub opaque type MarketValue {
  MarketValue(amount: Float)
}

pub fn market_value(amount: Float) -> MarketValue {
  MarketValue(amount)
}

pub fn market_value_amount(market_value: MarketValue) -> Float {
  market_value.amount
}

pub opaque type CostBasis {
  CostBasis(amount: Float)
}

pub fn cost_basis(amount: Float) -> CostBasis {
  CostBasis(amount)
}

pub fn cost_basis_amount(cost_basis: CostBasis) -> Float {
  cost_basis.amount
}

pub type UnrealizedProfit {
  UnrealizedProfit(unrealized_profit: Float, unrealized_profit_pct: Float)
}

// Domain: PositionValue
pub type PositionValue {
  PositionValue(
    symbol: Symbol,
    name: AssetName,
    quantity: Quantity,
    avg_price: Price,
    current_price: Price,
    market_value: MarketValue,
    cost_basis: CostBasis,
    unrealized_profit: UnrealizedProfit,
    currency: Currency,
  )
}

// Domain: PortfolioValue
pub type PortfolioValue {
  PortfolioValue(by_currency: dict.Dict(Currency, CurrencyTotal))
}

// Domain: CurrencyTotal
pub type CurrencyTotal {
  CurrencyTotal(
    currency: Currency,
    position_values: List(PositionValue),
    total_market_value: MarketValue,
    total_cost_basis: CostBasis,
    total_unrealized_profit: UnrealizedProfit,
  )
}
