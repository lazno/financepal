import domain/policy_types.{
  Policy, allocation, min_trade_value, policy_id, policy_name,
  policy_sensitivity, policy_target, policy_target_key, turnover_cap,
}
import domain/rebalancing.{band_lower_bound, band_upper_bound, get_band}
import gleam/dict
import gleam/int
import gleeunit/should

// Test 1: Normal policy with typical targets and sensitivity
pub fn normal_policy_bands_test() {
  // Setup: 60% equity, 30% bonds, 10% cash with 20% rel, 2pp floor, 8pp cap
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

  // Execute: Get bands for each instrument type
  let assert Ok(equity_band) = get_band(policy, policy_target_key("EQUITY"))
  let assert Ok(bond_band) = get_band(policy, policy_target_key("BOND"))
  let assert Ok(cash_band) = get_band(policy, policy_target_key("CASH"))

  // Verify: Equity band should be [0.60 - 0.08, 0.60 + 0.08] = [0.52, 0.68]
  should.equal(int.absolute_value(band_lower_bound(equity_band) - 5200), 0)
  should.equal(int.absolute_value(band_upper_bound(equity_band) - 6800), 0)

  // Verify: Bond band should be [0.30 - 0.06, 0.30 + 0.06] = [0.24, 0.36]
  should.equal(int.absolute_value(band_lower_bound(bond_band) - 2400), 0)
  should.equal(int.absolute_value(band_upper_bound(bond_band) - 3600), 0)

  // Verify: Cash band should be [0.10 - 0.02, 0.10 + 0.02] = [0.08, 0.12]
  should.equal(int.absolute_value(band_lower_bound(cash_band) - 800), 0)
  should.equal(int.absolute_value(band_upper_bound(cash_band) - 1200), 0)
}

// Test 2: Policy with floor constraint (small targets get minimum width)
pub fn floor_constraint_bands_test() {
  // Setup: 5% small allocation with 20% rel would give 1pp, but floor is 2pp
  let assert Ok(equity_alloc) = allocation(9500)
  let assert Ok(alt_alloc) = allocation(500)

  let targets =
    dict.from_list([
      #(policy_target_key("EQUITY"), equity_alloc),
      #(policy_target_key("ALTERNATIVE"), alt_alloc),
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

  // Execute: Get band for alternative allocation
  let assert Ok(alt_band) = get_band(policy, policy_target_key("ALTERNATIVE"))

  // Verify: Alternative band should use floor of 2pp: [0.05 - 0.02, 0.05 + 0.02] = [0.03, 0.07]
  should.be_true(int.absolute_value(band_lower_bound(alt_band) - 300) == 0)
  should.be_true(int.absolute_value(band_upper_bound(alt_band) - 700) == 0)
}

// Test 3: Policy with cap constraint (large targets get maximum width)
pub fn cap_constraint_bands_test() {
  // Setup: 80% large allocation with 20% rel would give 16pp, but cap is 8pp
  let assert Ok(equity_alloc) = allocation(8000)
  let assert Ok(bond_alloc) = allocation(2000)

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

  // Execute: Get band for equity allocation
  let assert Ok(equity_band) = get_band(policy, policy_target_key("EQUITY"))

  // Verify: Equity band should use cap of 8pp: [0.80 - 0.08, 0.80 + 0.08] = [0.72, 0.88]
  should.be_true(int.absolute_value(band_lower_bound(equity_band) - 7200) == 0)
  should.be_true(int.absolute_value(band_upper_bound(equity_band) - 8800) == 0)
}
