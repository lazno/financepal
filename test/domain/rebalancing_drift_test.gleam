import domain/common_types.{
  Asset, PriceData, asset_name, currency, instrument_type, isin, price, quantity,
  symbol,
}
import domain/policy_types.{
  Policy, allocation, min_trade_value, policy_id, policy_name,
  policy_sensitivity, policy_target, policy_target_key, policy_target_key_value,
  turnover_cap,
}
import domain/position_types.{Position}
import domain/rebalancing.{InBand, OutOfBand, build_snapshot, detect_drift}
import gleam/dict
import gleam/int
import gleam/list
import gleam/time/timestamp
import gleeunit/should

// Test 1: Normal portfolio with no drift (all allocations within bands)
pub fn no_drift_test() {
  // Setup: Portfolio at target allocations (60% equity, 30% bonds, 10% cash)
  let assert Ok(qty_aapl) = quantity(60.0)
  let assert Ok(qty_bond) = quantity(30.0)
  let assert Ok(qty_cash) = quantity(10.0)

  let positions = [
    Position(isin: isin("US0378331005"), quantity: qty_aapl),
    Position(isin: isin("US9128284X36"), quantity: qty_bond),
    Position(isin: isin("CASH123"), quantity: qty_cash),
  ]

  let assets = [
    Asset(
      isin: isin("US0378331005"),
      symbol: symbol("AAPL"),
      name: asset_name("Apple"),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US9128284X36"),
      symbol: symbol("BOND"),
      name: asset_name("Treasury"),
      instrument_type: instrument_type("BOND"),
    ),
    Asset(
      isin: isin("CASH123"),
      symbol: symbol("CASH"),
      name: asset_name("Cash"),
      instrument_type: instrument_type("CASH"),
    ),
  ]

  let assert Ok(price_aapl) = price(100.0)
  let assert Ok(price_bond) = price(100.0)
  let assert Ok(price_cash) = price(100.0)

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
    PriceData(
      isin: isin("CASH123"),
      price: price_cash,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
  ]

  // Build snapshot (should be 60% equity, 30% bonds, 10% cash)
  let snapshot = build_snapshot(positions, price_data, assets)

  // Setup policy: 60% equity, 30% bonds, 10% cash
  let assert Ok(equity_alloc) = allocation(6000)
  let assert Ok(bond_alloc) = allocation(3000)
  let assert Ok(cash_alloc) = allocation(1000)

  let targets =
    dict.from_list([
      #(policy_target_key("EQUITY"), equity_alloc),
      #(policy_target_key("BOND"), bond_alloc),
      #(policy_target_key("CASH"), cash_alloc),
    ])

  let assert Ok(target) = policy_target(policy_types.InstrumentType, targets)
  let assert Ok(sensitivity) = policy_sensitivity(2000, 200, 800)
  let assert Ok(min_trade) = min_trade_value(100.0)
  let assert Ok(turnover) = turnover_cap(10_000)

  let policy =
    Policy(
      id: policy_id("test-policy"),
      name: policy_name("Test Policy"),
      targets: target,
      sensitivity: sensitivity,
      min_trade_value: min_trade,
      turnover_cap: turnover,
    )

  // Execute drift detection
  let assert Ok(drift_report) = detect_drift(snapshot, policy)

  // Verify: All analyses should be InBand
  should.equal(list.length(drift_report.analyses), 3)

  list.each(drift_report.analyses, fn(analysis) {
    should.equal(analysis.delta_to_edge_bps, 0)
    should.equal(analysis.status, InBand)
  })
}

// Test 2: Portfolio with drift (equity overweight)
pub fn equity_overweight_drift_test() {
  // Setup: Portfolio with 70% equity (10pp over target)
  let assert Ok(qty_aapl) = quantity(70.0)
  let assert Ok(qty_bond) = quantity(30.0)

  let positions = [
    Position(isin: isin("US0378331005"), quantity: qty_aapl),
    Position(isin: isin("US9128284X36"), quantity: qty_bond),
  ]

  let assets = [
    Asset(
      isin: isin("US0378331005"),
      symbol: symbol("AAPL"),
      name: asset_name("Apple"),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US9128284X36"),
      symbol: symbol("BOND"),
      name: asset_name("Treasury"),
      instrument_type: instrument_type("BOND"),
    ),
  ]

  let assert Ok(price_aapl) = price(100.0)
  let assert Ok(price_bond) = price(100.0)

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

  // Build snapshot (should be 70% equity, 30% bonds)
  let snapshot = build_snapshot(positions, price_data, assets)

  // Setup policy: 60% equity, 40% bonds
  let assert Ok(equity_alloc) = allocation(6000)
  let assert Ok(bond_alloc) = allocation(4000)

  let targets =
    dict.from_list([
      #(policy_target_key("EQUITY"), equity_alloc),
      #(policy_target_key("BOND"), bond_alloc),
    ])

  let assert Ok(target) = policy_target(policy_types.InstrumentType, targets)
  let assert Ok(sensitivity) = policy_sensitivity(2000, 200, 800)
  let assert Ok(min_trade) = min_trade_value(100.0)
  let assert Ok(turnover) = turnover_cap(1000)

  let policy =
    Policy(
      id: policy_id("test-policy"),
      name: policy_name("Test Policy"),
      targets: target,
      sensitivity: sensitivity,
      min_trade_value: min_trade,
      turnover_cap: turnover,
    )

  // Execute drift detection
  let assert Ok(drift_report) = detect_drift(snapshot, policy)

  // Verify: Equity should be OutOfBand with 2pp delta (70% - 68% band upper bound)
  let equity_analysis =
    list.find(drift_report.analyses, fn(a) {
      policy_target_key_value(a.target_key) == "EQUITY"
    })
  let assert Ok(equity) = equity_analysis

  should.equal(equity.status, OutOfBand)
  should.be_true(int.absolute_value(equity.delta_to_edge_bps - 200) == 0)

  // Verify: Bonds should also be OutOfBand (30% < 32% band lower bound)
  let bond_analysis =
    list.find(drift_report.analyses, fn(a) {
      policy_target_key_value(a.target_key) == "BOND"
    })
  let assert Ok(bond) = bond_analysis

  should.equal(bond.status, OutOfBand)
  // Delta: 32% band lower bound - 30% current = 2pp
  should.be_true(int.absolute_value(bond.delta_to_edge_bps - 200) == 0)
}

// Test 3: Mixed scenario (some in band, some out of band)
pub fn mixed_drift_test() {
  // Setup: Portfolio with 50% equity (underweight), 40% bonds (overweight), 10% cash (target)
  let assert Ok(qty_aapl) = quantity(50.0)
  let assert Ok(qty_bond) = quantity(40.0)
  let assert Ok(qty_cash) = quantity(10.0)

  let positions = [
    Position(isin: isin("US0378331005"), quantity: qty_aapl),
    Position(isin: isin("US9128284X36"), quantity: qty_bond),
    Position(isin: isin("CASH123"), quantity: qty_cash),
  ]

  let assets = [
    Asset(
      isin: isin("US0378331005"),
      symbol: symbol("AAPL"),
      name: asset_name("Apple"),
      instrument_type: instrument_type("EQUITY"),
    ),
    Asset(
      isin: isin("US9128284X36"),
      symbol: symbol("BOND"),
      name: asset_name("Treasury"),
      instrument_type: instrument_type("BOND"),
    ),
    Asset(
      isin: isin("CASH123"),
      symbol: symbol("CASH"),
      name: asset_name("Cash"),
      instrument_type: instrument_type("CASH"),
    ),
  ]

  let assert Ok(price_aapl) = price(100.0)
  let assert Ok(price_bond) = price(100.0)
  let assert Ok(price_cash) = price(100.0)

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
    PriceData(
      isin: isin("CASH123"),
      price: price_cash,
      currency: currency("USD"),
      timestamp: timestamp.from_unix_seconds(1_234_567_890),
    ),
  ]

  // Build snapshot (50% equity, 40% bonds, 10% cash)
  let snapshot = build_snapshot(positions, price_data, assets)

  // Setup policy: 60% equity, 30% bonds, 10% cash
  let assert Ok(equity_alloc) = allocation(6000)
  let assert Ok(bond_alloc) = allocation(3000)
  let assert Ok(cash_alloc) = allocation(1000)

  let targets =
    dict.from_list([
      #(policy_target_key("EQUITY"), equity_alloc),
      #(policy_target_key("BOND"), bond_alloc),
      #(policy_target_key("CASH"), cash_alloc),
    ])

  let assert Ok(target) = policy_target(policy_types.InstrumentType, targets)
  let assert Ok(sensitivity) = policy_sensitivity(2000, 200, 800)
  let assert Ok(min_trade) = min_trade_value(100.0)
  let assert Ok(turnover) = turnover_cap(1000)

  let policy =
    Policy(
      id: policy_id("test-policy"),
      name: policy_name("Test Policy"),
      targets: target,
      sensitivity: sensitivity,
      min_trade_value: min_trade,
      turnover_cap: turnover,
    )

  // Execute drift detection
  let assert Ok(drift_report) = detect_drift(snapshot, policy)

  // Verify: Equity should be OutOfBand (underweight)
  let equity_analysis =
    list.find(drift_report.analyses, fn(a) {
      policy_target_key_value(a.target_key) == "EQUITY"
    })
  let assert Ok(equity) = equity_analysis

  should.equal(equity.status, OutOfBand)
  // Delta: 52% band lower bound - 50% current = 2pp
  should.be_true(int.absolute_value(equity.delta_to_edge_bps - 200) == 0)

  // Verify: Bonds should be OutOfBand (overweight)
  let bond_analysis =
    list.find(drift_report.analyses, fn(a) {
      policy_target_key_value(a.target_key) == "BOND"
    })
  let assert Ok(bond) = bond_analysis

  should.equal(bond.status, OutOfBand)
  // Delta: 40% current - 36% band upper bound = 4pp
  should.be_true(int.absolute_value(bond.delta_to_edge_bps - 400) == 0)

  // Verify: Cash should be InBand (at target)
  let cash_analysis =
    list.find(drift_report.analyses, fn(a) {
      policy_target_key_value(a.target_key) == "CASH"
    })
  let assert Ok(cash) = cash_analysis

  should.equal(cash.status, InBand)
  should.equal(cash.delta_to_edge_bps, 0)
}
