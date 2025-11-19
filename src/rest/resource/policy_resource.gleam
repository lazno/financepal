import application/types.{type Context}
import domain/policy_types.{
  InstrumentType, Policy, allocation, allocation_bps, min_trade_value, policy_id,
  policy_id_value, policy_name, policy_sensitivity, policy_sensitivity_cap_bps,
  policy_sensitivity_floor_bps, policy_sensitivity_rel_bps, policy_target,
  policy_target_key, policy_target_key_value, policy_target_weights,
  turnover_cap,
}
import gleam/dict
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Put}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import persistence/db_utils
import persistence/policy_repository
import rest/resource/common.{bad_request, internal_error, ok}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> handle_get_policy(ctx)
    Put -> handle_update_policy(req, ctx)
    Delete -> handle_delete_policy(ctx)
    _ -> wisp.method_not_allowed([Get, Put, Delete])
  }
}

fn handle_get_policy(ctx: Context) -> Response {
  let result = {
    // Try to fetch policy
    case policy_repository.get_first_policy(ctx.db) {
      Ok(policy) -> {
        let json =
          json.object([
            #("id", json.string(policy_id_value(policy.id))),
            #(
              "targets",
              json.object(
                policy_target_weights(policy.targets)
                |> dict.to_list
                |> list.map(fn(pair) {
                  let #(key, value) = pair
                  #(
                    policy_target_key_value(key),
                    json.int(allocation_bps(value)),
                  )
                }),
              ),
            ),
            #(
              "sensitivity",
              json.object([
                #(
                  "rel_bps",
                  json.int(policy_sensitivity_rel_bps(policy.sensitivity)),
                ),
                #(
                  "floor_bps",
                  json.int(policy_sensitivity_floor_bps(policy.sensitivity)),
                ),
                #(
                  "cap_bps",
                  json.int(policy_sensitivity_cap_bps(policy.sensitivity)),
                ),
              ]),
            ),
          ])
        Ok(json)
      }
      Error(db_utils.DbError("No policy found")) -> {
        // Return 404 if no policy exists
        Error(wisp.not_found())
      }
      Error(e) -> panic as { "Failed to fetch policy: " <> string.inspect(e) }
    }
  }

  case result {
    Ok(json) -> ok(json)
    Error(response) -> response
  }
}

fn handle_update_policy(req: Request, ctx: Context) -> Response {
  use json_body <- wisp.require_json(req)

  let safe_decoder = {
    use raw_targets <- decode.field(
      "targets",
      decode.dict(decode.map(decode.string, policy_target_key), decode.int),
    )
    use raw_sensitivity <- decode.field("sensitivity", {
      use rel <- decode.field("rel_bps", decode.int)
      use floor <- decode.field("floor_bps", decode.int)
      use cap <- decode.field("cap_bps", decode.int)
      decode.success(#(rel, floor, cap))
    })
    decode.success(#(raw_targets, raw_sensitivity))
  }

  let result = {
    use #(raw_targets, #(rel, floor, cap)) <- result.try(
      decode.run(json_body, safe_decoder)
      |> result.map_error(fn(e) {
        bad_request("Invalid JSON structure: " <> string.inspect(e))
      }),
    )

    // Validate Sensitivity
    use sensitivity <- result.try(
      policy_sensitivity(rel, floor, cap)
      |> result.map_error(fn(e) { bad_request(e) }),
    )

    // Convert raw ints to Allocations
    use weights <- result.try(
      dict.fold(raw_targets, Ok(dict.new()), fn(acc, key, val) {
        use d <- result.try(acc)
        case allocation(val) {
          Ok(a) -> Ok(dict.insert(d, key, a))
          Error(e) -> Error(bad_request("Invalid allocation value: " <> e))
        }
      }),
    )

    // Create PolicyTarget (validates sum = 100%)
    use targets <- result.try(
      policy_target(InstrumentType, weights)
      |> result.map_error(fn(e) { bad_request(e) }),
    )

    // Check if policy exists
    case policy_repository.get_first_policy(ctx.db) {
      Ok(current_policy) -> {
        // Update existing with new targets AND sensitivity
        let updated_policy =
          Policy(..current_policy, targets: targets, sensitivity: sensitivity)

        use _ <- result.try(
          policy_repository.update_policy(ctx.db, updated_policy)
          |> result.map_error(fn(e) {
            internal_error("Failed to update policy: " <> string.inspect(e))
          }),
        )
        Ok(Nil)
      }
      Error(db_utils.DbError("No policy found")) -> {
        // Create new policy with provided targets and sensitivity
        let assert Ok(min_trade) = min_trade_value(0.0)
        let assert Ok(turnover) = turnover_cap(10_000)

        let new_policy =
          Policy(
            id: policy_id("default"),
            name: policy_name("Default Policy"),
            targets: targets,
            sensitivity: sensitivity,
            min_trade_value: min_trade,
            turnover_cap: turnover,
          )

        use _ <- result.try(
          policy_repository.insert_policy(ctx.db, new_policy)
          |> result.map_error(fn(e) {
            internal_error("Failed to create policy: " <> string.inspect(e))
          }),
        )
        Ok(Nil)
      }
      Error(e) ->
        Error(internal_error(
          "Failed to check policy existence: " <> string.inspect(e),
        ))
    }
  }

  case result {
    Ok(_) -> ok(json.object([]))
    Error(response) -> response
  }
}

fn handle_delete_policy(ctx: Context) -> Response {
  let result = {
    use policy <- result.try(
      policy_repository.get_first_policy(ctx.db)
      |> result.map_error(fn(e) {
        case e {
          db_utils.DbError("No policy found") -> wisp.not_found()
          _ -> internal_error("Failed to fetch policy: " <> string.inspect(e))
        }
      }),
    )

    use _ <- result.try(
      policy_repository.delete_policy(ctx.db, policy.id)
      |> result.map_error(fn(e) {
        internal_error("Failed to delete policy: " <> string.inspect(e))
      }),
    )

    Ok(Nil)
  }

  case result {
    Ok(_) -> ok(json.object([]))
    Error(response) -> response
  }
}
