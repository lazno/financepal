import domain/common_types.{
  Asset, PriceData, asset_name, currency, instrument_type, isin, price, quantity,
  symbol,
}
import domain/position_types.{Position}
import domain/rebalancing.{build_snapshot}
import gleam/dict
import gleam/float
import gleam/list
import gleam/time/timestamp
import gleeunit/should

// Test 1: Normal portfolio with multiple positions (80% use case)
pub fn normal_portfolio_snapshot_test() {
  // Setup: 4 positions with realistic data
  let assert Ok(qty_aapl) = quantity(50.0)
  let assert Ok(qty_msft) = quantity(25.0)
  let assert Ok(qty_bond) = quantity(100.0)
  let assert Ok(qty_etf) = quantity(200.0)

  let assert Ok(price_aapl) = price(175.5)
  let assert Ok(price_msft) = price(380.25)
  let assert Ok(price_bond) = price(98.75)
  let assert Ok(price_etf) = price(85.4)

  let positions = [
    Position(isin: isin("US0378331005"), quantity: qty_aapl),
    Position(isin: isin("US5949181045"), quantity: qty_msft),
    Position(isin: isin("US9128284X36"), quantity: qty_bond),
    Position(isin: isin("IE00B4L5Y983"), quantity: qty_etf),
  ]

  let assets = [
    Asset(
      isin: isin("US0378331005"),
      symbol: symbol("AAPL"),
      name: asset_name("Apple Inc."),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US5949181045"),
      symbol: symbol("MSFT"),
      name: asset_name("Microsoft Corp."),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US9128284X36"),
      symbol: symbol("T10Y"),
      name: asset_name("US 10-Year Treasury"),
      instrument_type: instrument_type("BOND"),
    ),
    Asset(
      isin: isin("IE00B4L5Y983"),
      symbol: symbol("IWDA"),
      name: asset_name("iShares Core MSCI World"),
      instrument_type: instrument_type("EQUITY"),
    ),
  ]

  let price_data = [
    PriceData(
      isin: isin("US0378331005"),
      price: price_aapl,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
    PriceData(
      isin: isin("US5949181045"),
      price: price_msft,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
    PriceData(
      isin: isin("US9128284X36"),
      price: price_bond,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
    PriceData(
      isin: isin("IE00B4L5Y983"),
      price: price_etf,
      currency: currency("EUR"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
  ]

  // Execute
  let snapshot = build_snapshot(positions, price_data, assets)

  // Verify: All positions processed, no missing prices
  should.equal(list.length(snapshot.positions), 4)
  should.equal(snapshot.missing_prices, [])
  // Verify: Market values calculated correctly
  let aapl_value = 50.0 *. 175.5
  // 8775.0
  let msft_value = 25.0 *. 380.25
  // 9506.25
  let bond_value = 100.0 *. 98.75
  // 9875.0
  let etf_value = 200.0 *. 85.4
  // 17080.0
  let total_expected = aapl_value +. msft_value +. bond_value +. etf_value

  should.be_true(
    float.absolute_value(snapshot.total_value -. total_expected) <. 0.01,
  )

  // Verify: Allocations sum to 100%
  let total_weight =
    dict.fold(snapshot.by_instrument_type, 0.0, fn(acc, _type, weight) {
      acc +. weight
    })
  should.be_true(float.absolute_value(total_weight -. 1.0) <. 0.001)

  // Verify: Equity allocation is roughly (AAPL + MSFT + ETF) / total
  let equity_weight = case
    dict.get(snapshot.by_instrument_type, instrument_type("EQUITY"))
  {
    Ok(w) -> w
    Error(_) -> 0.0
  }
  let bond_weight = case
    dict.get(snapshot.by_instrument_type, instrument_type("BOND"))
  {
    Ok(w) -> w
    Error(_) -> 0.0
  }

  let expected_equity =
    { aapl_value +. msft_value +. etf_value } /. total_expected
  let expected_bond = bond_value /. total_expected

  should.be_true(
    float.absolute_value(equity_weight -. expected_equity) <. 0.001,
  )
  should.be_true(float.absolute_value(bond_weight -. expected_bond) <. 0.001)
}

// Test 2: Missing prices scenario (15% use case)
pub fn missing_prices_snapshot_test() {
  // Setup: Same as normal but missing price for MSFT
  let assert Ok(qty_aapl) = quantity(50.0)
  let assert Ok(qty_msft) = quantity(25.0)
  let assert Ok(qty_bond) = quantity(100.0)

  let assert Ok(price_aapl) = price(175.5)
  let assert Ok(price_bond) = price(98.75)

  let positions = [
    Position(isin: isin("US0378331005"), quantity: qty_aapl),
    Position(isin: isin("US5949181045"), quantity: qty_msft),
    Position(isin: isin("US9128284X36"), quantity: qty_bond),
  ]

  let assets = [
    Asset(
      isin: isin("US0378331005"),
      symbol: symbol("AAPL"),
      name: asset_name("Apple Inc."),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US5949181045"),
      symbol: symbol("MSFT"),
      name: asset_name("Microsoft Corp."),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US9128284X36"),
      symbol: symbol("T10Y"),
      name: asset_name("US 10-Year Treasury"),
      instrument_type: instrument_type("BOND"),
    ),
  ]

  // Note: No price data for MSFT
  let price_data = [
    PriceData(
      isin: isin("US0378331005"),
      price: price_aapl,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
    PriceData(
      isin: isin("US9128284X36"),
      price: price_bond,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
  ]

  // Execute
  let snapshot = build_snapshot(positions, price_data, assets)

  // Verify: Only 2 positions processed (AAPL and BOND), MSFT is missing
  should.be_true(list.length(snapshot.positions) == 2)
  should.be_true(list.length(snapshot.missing_prices) == 1)

  // Verify: Missing price is for MSFT
  let missing_isin = isin("US5949181045")
  should.be_true(list.contains(snapshot.missing_prices, missing_isin))

  // Verify: Total value only includes positions with prices
  let expected_total = { 50.0 *. 175.5 } +. { 100.0 *. 98.75 }
  // 8775.0 + 9875.0 = 18650.0
  should.be_true(
    float.absolute_value(snapshot.total_value -. expected_total) <. 0.01,
  )

  // Verify: Allocations still sum to 100% (only for available positions)
  let total_weight =
    dict.fold(snapshot.by_instrument_type, 0.0, fn(acc, _type, weight) {
      acc +. weight
    })
  should.be_true(float.absolute_value(total_weight -. 1.0) <. 0.001)
}

// Test 3: Empty portfolio (5% use case)
pub fn empty_portfolio_snapshot_test() {
  let positions = []
  let assets = []
  let price_data = []

  // Execute
  let snapshot = build_snapshot(positions, price_data, assets)

  // Verify: Empty results
  should.be_true(snapshot.positions == [])
  should.be_true(snapshot.missing_prices == [])
  should.be_true(snapshot.total_value == 0.0)
  should.be_true(dict.size(snapshot.by_instrument_type) == 0)
}

// Test 4: Single position portfolio (edge case but common for new investors)
pub fn single_position_snapshot_test() {
  let assert Ok(qty) = quantity(100.0)
  let assert Ok(prc) = price(150.0)

  let positions = [Position(isin: isin("TEST123"), quantity: qty)]

  let assets = [
    Asset(
      isin: isin("TEST123"),
      symbol: symbol("TEST"),
      name: asset_name("Test Asset"),
      instrument_type: instrument_type("EQUITY"),
    ),
  ]

  let price_data = [
    PriceData(
      isin: isin("TEST123"),
      price: prc,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
  ]

  // Execute
  let snapshot = build_snapshot(positions, price_data, assets)

  // Verify: Single position processed correctly
  should.be_true(list.length(snapshot.positions) == 1)
  should.be_true(snapshot.missing_prices == [])
  should.be_true(snapshot.total_value == 100.0 *. 150.0)
  // 15000.0

  // Verify: 100% allocation to EQUITY
  let equity_weight = case
    dict.get(snapshot.by_instrument_type, instrument_type("EQUITY"))
  {
    Ok(w) -> w
    Error(_) -> 0.0
  }
  should.be_true(float.absolute_value(equity_weight -. 1.0) <. 0.001)
}
