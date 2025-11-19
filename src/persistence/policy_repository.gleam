import domain/policy_types.{
  type Policy, type PolicyId, type PolicySensitivity, type PolicyTarget, Policy,
  allocation, allocation_bps, min_trade_value, min_trade_value_amount, policy_id,
  policy_id_value, policy_name, policy_name_value, policy_sensitivity,
  policy_sensitivity_cap_bps, policy_sensitivity_floor_bps,
  policy_sensitivity_rel_bps, policy_target, policy_target_key,
  policy_target_key_value, policy_target_weights, turnover_cap, turnover_cap_bps,
}
import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import persistence/db_utils.{type TransactionError, db_error}
import sqlight
import youid/uuid

pub fn insert_policy(
  conn: sqlight.Connection,
  policy: Policy,
) -> Result(PolicyId, TransactionError(e)) {
  let id = uuid.v7() |> uuid.to_string
  let policy_id = policy_id(id)

  let sql =
    "INSERT INTO policy (id, name, targets, sensitivity, min_trade_value, turnover_cap) 
     VALUES (?, ?, ?, ?, ?, ?)"

  let targets_json = target_to_json(policy.targets)
  let sensitivity_json = sensitivity_to_json(policy.sensitivity)

  use _ <- result.try(
    sqlight.query(
      sql,
      conn,
      [
        sqlight.text(policy_id_value(policy_id)),
        sqlight.text(policy_name_value(policy.name)),
        sqlight.text(targets_json),
        sqlight.text(sensitivity_json),
        sqlight.text(
          float.to_string(min_trade_value_amount(policy.min_trade_value)),
        ),
        sqlight.text(int.to_string(turnover_cap_bps(policy.turnover_cap))),
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

pub fn target_to_json(target: PolicyTarget) -> String {
  let target_type = #(
    "target_type",
    json.string(case policy_types.policy_target_type(target) {
      policy_types.InstrumentType -> "InstrumentType"
    }),
  )
  let weight_list = #(
    "weights",
    policy_target_weights(target)
      |> dict.to_list
      |> list.map(fn(pair) {
        let #(key, value) = pair
        #(policy_target_key_value(key), json.int(allocation_bps(value)))
      })
      |> json.object,
  )

  json.object([target_type, weight_list])
  |> json.to_string
}

fn sensitivity_to_json(sensitivity: PolicySensitivity) -> String {
  let rel = policy_sensitivity_rel_bps(sensitivity)
  let floor = policy_sensitivity_floor_bps(sensitivity)
  let cap = policy_sensitivity_cap_bps(sensitivity)

  json.object([
    #("rel_bps", json.int(rel)),
    #("floor_bps", json.int(floor)),
    #("cap_bps", json.int(cap)),
  ])
  |> json.to_string
}

fn decode_policy() -> decode.Decoder(Policy) {
  use id <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  use targets_json <- decode.field(2, decode.string)
  use sensitivity_json <- decode.field(3, decode.string)
  use min_trade_value_float <- decode.field(4, decode.float)
  use turnover_cap_float <- decode.field(5, decode.int)

  let policy_id = policy_id(id)

  // Validate name - panic on failure
  let policy_name = policy_name(name)
  // Parse targets JSON - panic on failure  
  let policy_target = case json_to_targets(targets_json) {
    Ok(d) -> d
    Error(e) -> panic as { "FATAL: Invalid targets JSON" <> string.inspect(e) }
  }

  // Parse sensitivity JSON - panic on failure
  let sensitivity = case json_to_sensitiviy(sensitivity_json) {
    Ok(d) -> d
    Error(e) ->
      panic as { "FATAL: Invalid sensitivity JSON: " <> string.inspect(e) }
  }

  // Validate min trade value - panic on failure
  let min_trade_value = case min_trade_value(min_trade_value_float) {
    Ok(v) -> v
    Error(e) -> panic as { "FATAL: Invalid min_trade_value: " <> e }
  }

  // Validate turnover cap - panic on failure
  let turnover_cap = case turnover_cap(turnover_cap_float) {
    Ok(c) -> c
    Error(e) -> panic as { "FATAL: Invalid turnover_cap: " <> e }
  }

  decode.success(Policy(
    id: policy_id,
    name: policy_name,
    targets: policy_target,
    sensitivity: sensitivity,
    min_trade_value: min_trade_value,
    turnover_cap: turnover_cap,
  ))
}

fn json_to_targets(json: String) -> Result(PolicyTarget, json.DecodeError) {
  let decoder = {
    use target_type <- decode.field(
      "target_type",
      decode.map(decode.string, fn(s) {
        case policy_types.policy_target_type_from_string(s) {
          Ok(v) -> v
          Error(s) -> panic as { "FATAL: could not parse target_type: " <> s }
        }
      }),
    )
    use weights <- decode.field(
      "weights",
      decode.dict(
        decode.map(decode.string, fn(s) { policy_target_key(s) }),
        decode.map(decode.int, fn(i) {
          case allocation(i) {
            Ok(a) -> a
            Error(s) -> panic as { "FATAL: could not parse allocation: " <> s }
          }
        }),
      ),
    )

    decode.success(case policy_target(target_type, weights) {
      Ok(pt) -> pt
      Error(s) -> panic as { "FATAL: could not parse policy target" <> s }
    })
  }
  json.parse(json, decoder)
  // Simple JSON parsing - in production would use proper JSON parser
}

fn json_to_sensitiviy(
  json: String,
) -> Result(PolicySensitivity, json.DecodeError) {
  let decoder = {
    // rel_bps: Int, floor_bps: Int, cap_bps: Int
    use rel_bps <- decode.field("rel_bps", decode.int)
    use floor_bps <- decode.field("floor_bps", decode.int)
    use cap_bps <- decode.field("cap_bps", decode.int)
    decode.success(case policy_sensitivity(rel_bps, floor_bps, cap_bps) {
      Ok(ps) -> ps
      Error(e) -> panic as { "FATAL: could not parse sensitivity: " <> e }
    })
  }
  json.parse(json, decoder)
}
