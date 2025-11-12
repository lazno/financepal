import gleam/dict
import gleam/float
import gleam/int

// Domain: PolicyId
pub opaque type PolicyId {
  PolicyId(value: String)
}

pub fn policy_id(value: String) -> PolicyId {
  PolicyId(value)
}

pub fn policy_id_value(id: PolicyId) -> String {
  id.value
}

// Domain: PolicyName
pub opaque type PolicyName {
  PolicyName(value: String)
}

pub fn policy_name(value: String) -> PolicyName {
  PolicyName(value)
}

pub fn policy_name_value(name: PolicyName) -> String {
  name.value
}

pub opaque type PolicyTargetKey {
  PolicyTargetKey(value: String)
}

pub fn policy_target_key(value: String) -> PolicyTargetKey {
  PolicyTargetKey(value)
}

pub fn policy_target_key_value(key: PolicyTargetKey) -> String {
  key.value
}

pub opaque type Allocation {
  Allocation(bps: Int)
}

pub fn allocation(bps: Int) -> Result(Allocation, String) {
  case bps >= 0, bps <= 10_000 {
    True, True -> Ok(Allocation(bps))
    _, _ -> Error("Allocation must be betwen 0 and 1")
  }
}

pub fn allocation_bps(allocation: Allocation) -> Int {
  allocation.bps
}

pub type PolicyTargetType {
  InstrumentType
}

pub fn policy_target_type_from_string(
  s: String,
) -> Result(PolicyTargetType, String) {
  case s {
    "InstrumentType" -> Ok(InstrumentType)
    _ -> Error("unkown PolicyTargetType: ")
  }
}

// Domain: PolicyTarget
pub opaque type PolicyTarget {
  PolicyTarget(
    target_type: PolicyTargetType,
    weights: dict.Dict(PolicyTargetKey, Allocation),
  )
}

pub fn policy_target(
  target_type: PolicyTargetType,
  weights: dict.Dict(PolicyTargetKey, Allocation),
) -> Result(PolicyTarget, String) {
  let total =
    dict.fold(weights, 0, fn(acc, _key, value) { acc + allocation_bps(value) })

  case total == 10_000 {
    True -> Ok(PolicyTarget(target_type, weights))
    False ->
      Error("Policy targets must sum to 10000, got: " <> int.to_string(total))
  }
}

pub fn policy_target_weights(
  target: PolicyTarget,
) -> dict.Dict(PolicyTargetKey, Allocation) {
  target.weights
}

pub fn policy_target_type(target: PolicyTarget) -> PolicyTargetType {
  target.target_type
}

// Domain: PolicySensitivity
pub opaque type PolicySensitivity {
  PolicySensitivity(rel_bps: Int, floor_bps: Int, cap_bps: Int)
}

pub fn policy_sensitivity(
  rel_bps: Int,
  floor_bps: Int,
  cap_bps: Int,
) -> Result(PolicySensitivity, String) {
  case rel_bps < 0, floor_bps < 0, cap_bps < 0, floor_bps > cap_bps {
    True, _, _, _ ->
      Error(
        "Relative sensitivity cannot be negative: " <> int.to_string(rel_bps),
      )
    _, True, _, _ ->
      Error("Floor cannot be negative: " <> int.to_string(floor_bps))
    _, _, True, _ -> Error("Cap cannot be negative: " <> int.to_string(cap_bps))
    _, _, _, True ->
      Error(
        "Floor cannot exceed cap: "
        <> int.to_string(floor_bps)
        <> " > "
        <> int.to_string(cap_bps),
      )
    False, False, False, False -> {
      // Ensure reasonable bounds
      case rel_bps > 10_000, floor_bps > 5000, cap_bps > 50_000 {
        True, _, _ ->
          Error(
            "Relative sensitivity too high (> 100%): " <> int.to_string(rel_bps),
          )
        _, True, _ ->
          Error("Floor too high (> 50pp): " <> int.to_string(floor_bps))
        _, _, True -> Error("Cap too high (> 50pp): " <> int.to_string(cap_bps))
        False, False, False ->
          Ok(PolicySensitivity(rel_bps, floor_bps, cap_bps))
      }
    }
  }
}

pub fn policy_sensitivity_rel_bps(sensitivity: PolicySensitivity) -> Int {
  sensitivity.rel_bps
}

pub fn policy_sensitivity_floor_bps(sensitivity: PolicySensitivity) -> Int {
  sensitivity.floor_bps
}

pub fn policy_sensitivity_cap_bps(sensitivity: PolicySensitivity) -> Int {
  sensitivity.cap_bps
}

// Domain: MinTradeValue
pub opaque type MinTradeValue {
  MinTradeValue(amount: Float)
}

pub fn min_trade_value(amount: Float) -> Result(MinTradeValue, String) {
  case amount <. 0.0 {
    True ->
      Error("Min trade value cannot be negative: " <> float.to_string(amount))
    False -> Ok(MinTradeValue(amount))
  }
}

pub fn min_trade_value_amount(value: MinTradeValue) -> Float {
  value.amount
}

// Domain: TurnoverCap
pub opaque type TurnoverCap {
  TurnoverCap(bps: Int)
}

pub fn turnover_cap(bps: Int) -> Result(TurnoverCap, String) {
  case bps < 0, bps > 10_000 {
    True, _ -> Error("Turnover cap cannot be negative: " <> int.to_string(bps))
    _, True -> Error("Turnover cap cannot exceed 1.0: " <> int.to_string(bps))
    False, False -> Ok(TurnoverCap(bps))
  }
}

pub fn turnover_cap_bps(cap: TurnoverCap) -> Int {
  cap.bps
}

// Domain: Policy
pub type Policy {
  Policy(
    id: PolicyId,
    name: PolicyName,
    targets: PolicyTarget,
    sensitivity: PolicySensitivity,
    min_trade_value: MinTradeValue,
    turnover_cap: TurnoverCap,
  )
}
