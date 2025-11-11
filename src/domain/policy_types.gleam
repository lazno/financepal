import gleam/dict
import gleam/float

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
  Allocation(value: Float)
}

pub fn allocation(value: Float) -> Result(Allocation, String) {
  case value >=. 0.0, value <=. 1.0 {
    True, True -> Ok(Allocation(value))
    _, _ -> Error("Allocation must be betwen 0 and 1")
  }
}

pub fn allocation_value(allocation: Allocation) -> Float {
  allocation.value
}

pub type PolicyTargetType {
  InstrumentType
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
    dict.fold(weights, 0.0, fn(acc, _key, value) {
      acc +. allocation_value(value)
    })

  case float.absolute_value(total -. 1.0) <. 0.001 {
    True -> Ok(PolicyTarget(target_type, weights))
    False ->
      Error("Policy targets must sum to 1.0, got: " <> float.to_string(total))
  }
}

pub fn policy_target_weights(
  target: PolicyTarget,
) -> dict.Dict(PolicyTargetKey, Allocation) {
  target.weights
}

// Domain: PolicySensitivity
pub opaque type PolicySensitivity {
  PolicySensitivity(rel: Float, floor_pp: Float, cap_pp: Float)
}

pub fn policy_sensitivity(
  rel: Float,
  floor_pp: Float,
  cap_pp: Float,
) -> Result(PolicySensitivity, String) {
  case rel <. 0.0, floor_pp <. 0.0, cap_pp <. 0.0, floor_pp >. cap_pp {
    True, _, _, _ ->
      Error("Relative sensitivity cannot be negative: " <> float.to_string(rel))
    _, True, _, _ ->
      Error("Floor cannot be negative: " <> float.to_string(floor_pp))
    _, _, True, _ ->
      Error("Cap cannot be negative: " <> float.to_string(cap_pp))
    _, _, _, True ->
      Error(
        "Floor cannot exceed cap: "
        <> float.to_string(floor_pp)
        <> " > "
        <> float.to_string(cap_pp),
      )
    False, False, False, False -> {
      // Ensure reasonable bounds
      case rel >. 1.0, floor_pp >. 0.5, cap_pp >. 0.5 {
        True, _, _ ->
          Error(
            "Relative sensitivity too high (> 100%): " <> float.to_string(rel),
          )
        _, True, _ ->
          Error("Floor too high (> 50pp): " <> float.to_string(floor_pp))
        _, _, True ->
          Error("Cap too high (> 50pp): " <> float.to_string(cap_pp))
        False, False, False -> Ok(PolicySensitivity(rel, floor_pp, cap_pp))
      }
    }
  }
}

pub fn policy_sensitivity_rel(sensitivity: PolicySensitivity) -> Float {
  sensitivity.rel
}

pub fn policy_sensitivity_floor_pp(sensitivity: PolicySensitivity) -> Float {
  sensitivity.floor_pp
}

pub fn policy_sensitivity_cap_pp(sensitivity: PolicySensitivity) -> Float {
  sensitivity.cap_pp
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
  TurnoverCap(percentage: Float)
}

pub fn turnover_cap(percentage: Float) -> Result(TurnoverCap, String) {
  case percentage <. 0.0, percentage >. 1.0 {
    True, _ ->
      Error("Turnover cap cannot be negative: " <> float.to_string(percentage))
    _, True ->
      Error("Turnover cap cannot exceed 1.0: " <> float.to_string(percentage))
    False, False -> Ok(TurnoverCap(percentage))
  }
}

pub fn turnover_cap_percentage(cap: TurnoverCap) -> Float {
  cap.percentage
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
