import domain/policy_types.{
  type MinTradeValue, type Policy, type PolicyId, type PolicyName,
  type PolicySensitivity, type PolicyTarget, type TurnoverCap, Policy,
  min_trade_value, min_trade_value_amount, policy_id, policy_id_value,
  policy_name, policy_name_value, policy_sensitivity, policy_sensitivity_cap_pp,
  policy_sensitivity_floor_pp, policy_sensitivity_rel, policy_target,
  policy_target_weights, turnover_cap, turnover_cap_percentage,
}
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/list
import gleam/result
import gleam/string
import persistence/db_utils.{type TransactionError, db_error}
import sqlight
import youid/uuid

pub fn insert_policy(
  conn: sqlight.Connection,
  name: PolicyName,
  targets: PolicyTarget,
  sensitivity: PolicySensitivity,
  min_trade_value: MinTradeValue,
  turnover_cap: TurnoverCap,
) -> Result(PolicyId, TransactionError(e)) {
  let id = uuid.v7() |> uuid.to_string
  let policy_id = policy_id(id)

  let sql =
    "INSERT INTO policy (id, name, targets, sensitivity, min_trade_value, turnover_cap) 
     VALUES (?, ?, ?, ?, ?, ?)"

  let targets_json = targets |> policy_target_weights |> dict_to_json
  let sensitivity_json = sensitivity_to_json(sensitivity)

  use _ <- result.try(
    sqlight.query(
      sql,
      conn,
      [
        sqlight.text(policy_id_value(policy_id)),
        sqlight.text(policy_name_value(name)),
        sqlight.text(targets_json),
        sqlight.text(sensitivity_json),
        sqlight.text(float.to_string(min_trade_value_amount(min_trade_value))),
        sqlight.text(float.to_string(turnover_cap_percentage(turnover_cap))),
      ],
      decode.success(Nil),
    )
    |> result.map_error(fn(e) { db_error("Error inserting policy into db", e) }),
  )

  Ok(policy_id)
}

pub fn list_policies(
  conn: sqlight.Connection,
) -> Result(List(Policy), TransactionError(e)) {
  let sql =
    "SELECT id, name, targets, sensitivity, min_trade_value, turnover_cap 
             FROM policy ORDER BY name"

  sqlight.query(sql, conn, [], decode_policy())
  |> result.map_error(fn(e) { db_error("Error listing policies from db", e) })
}

pub fn delete_policy(
  conn: sqlight.Connection,
  policy_id: PolicyId,
) -> Result(Nil, TransactionError(e)) {
  let sql = "DELETE FROM policy WHERE id = ?"

  sqlight.query(
    sql,
    conn,
    [sqlight.text(policy_id_value(policy_id))],
    decode.success(Nil),
  )
  |> result.replace(Nil)
  |> result.map_error(fn(e) { db_error("Error deleting policy from db", e) })
}

// Helper functions

fn dict_to_json(dict: dict.Dict(String, Float)) -> String {
  dict
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(key, value) = pair
    "\"" <> key <> "\":" <> float.to_string(value)
  })
  |> string.join(",")
  |> fn(content) { "{" <> content <> "}" }
}

fn sensitivity_to_json(sensitivity: PolicySensitivity) -> String {
  let rel = policy_sensitivity_rel(sensitivity)
  let floor = policy_sensitivity_floor_pp(sensitivity)
  let cap = policy_sensitivity_cap_pp(sensitivity)

  "{\"rel\":"
  <> float.to_string(rel)
  <> ",\"floor_pp\":"
  <> float.to_string(floor)
  <> ",\"cap_pp\":"
  <> float.to_string(cap)
  <> "}"
}

fn decode_policy() -> decode.Decoder(Policy) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use targets_json <- decode.field("targets", decode.string)
  use sensitivity_json <- decode.field("sensitivity", decode.string)
  use min_trade_value_str <- decode.field("min_trade_value", decode.string)
  use turnover_cap_str <- decode.field("turnover_cap", decode.string)

  let policy_id = policy_id(id)

  // Validate name - panic on failure
  let policy_name = policy_name(name)
  // Parse targets JSON - panic on failure  
  let targets_dict = case json_to_dict(targets_json) {
    Ok(d) -> d
    Error(_) -> panic as "FATAL: Invalid targets JSON"
  }

  // Validate targets - panic on failure
  let policy_target = case policy_target(targets_dict) {
    Ok(t) -> t
    Error(_) -> panic as "FATAL: Invalid policy targets"
  }

  // Parse sensitivity JSON - panic on failure
  let sensitivity_dict = case json_to_dict(sensitivity_json) {
    Ok(d) -> d
    Error(_) -> panic as "FATAL: Invalid sensitivity JSON"
  }

  // Extract sensitivity fields - panic if missing
  let rel = case dict.get(sensitivity_dict, "rel") {
    Ok(v) -> v
    Error(_) -> panic as "FATAL: Missing rel field"
  }

  let floor_pp = case dict.get(sensitivity_dict, "floor_pp") {
    Ok(v) -> v
    Error(_) -> panic as "FATAL: Missing floor_pp field"
  }

  let cap_pp = case dict.get(sensitivity_dict, "cap_pp") {
    Ok(v) -> v
    Error(_) -> panic as "FATAL: Missing cap_pp field"
  }

  // Validate sensitivity - panic on failure
  let policy_sensitivity = case policy_sensitivity(rel, floor_pp, cap_pp) {
    Ok(s) -> s
    Error(_) -> panic as "FATAL: Invalid policy sensitivity"
  }

  // Parse min trade value - panic on failure
  let min_trade_value_float = case float.parse(min_trade_value_str) {
    Ok(f) -> f
    Error(_) -> panic as "FATAL: Invalid min_trade_value number"
  }

  // Validate min trade value - panic on failure
  let min_trade_value = case min_trade_value(min_trade_value_float) {
    Ok(v) -> v
    Error(_) -> panic as "FATAL: Invalid min_trade_value"
  }

  // Parse turnover cap - panic on failure
  let turnover_cap_float = case float.parse(turnover_cap_str) {
    Ok(f) -> f
    Error(_) -> panic as "FATAL: Invalid turnover_cap number"
  }

  // Validate turnover cap - panic on failure
  let turnover_cap = case turnover_cap(turnover_cap_float) {
    Ok(c) -> c
    Error(_) -> panic as "FATAL: Invalid turnover_cap"
  }

  decode.success(Policy(
    id: policy_id,
    name: policy_name,
    targets: policy_target,
    sensitivity: policy_sensitivity,
    min_trade_value: min_trade_value,
    turnover_cap: turnover_cap,
  ))
}

fn json_to_dict(json: String) -> Result(dict.Dict(String, Float), Nil) {
  // Simple JSON parsing - in production would use proper JSON parser
  case json {
    "{}" -> Ok(dict.new())
    _ -> {
      // This is a simplified implementation
      // In a real implementation, you'd use a proper JSON parser
      Error(Nil)
    }
  }
}
