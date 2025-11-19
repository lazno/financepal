import application/types.{type Context}
import domain/policy_types.{policy_target_key_value}
import domain/rebalancing.{
  type DriftAnalysis, type DriftReport, type DriftStatus, InBand, OutOfBand,
}
import gleam/http.{Get}
import gleam/int
import gleam/json
import gleam/result
import gleam/string
import persistence/asset_registry_repository
import persistence/policy_repository
import persistence/position_repository
import persistence/price_data_repository
import rest/resource/common.{internal_error, ok}
import wisp.{type Request, type Response}

pub fn handle_get_drift(req: Request, ctx: Context) -> Response {
  case req.method {
    Get -> {
      let result = {
        // 1. Fetch data
        use policies <- result.try(
          policy_repository.list_policies(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch policies: " <> string.inspect(e)
          }),
        )

        use policy <- result.try(case policies {
          [p, ..] -> Ok(p)
          [] -> Error("No policy found")
        })

        use positions <- result.try(
          position_repository.get_all_positions(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch positions: " <> string.inspect(e)
          }),
        )

        use price_data <- result.try(
          price_data_repository.get_latest_price_data(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch prices: " <> string.inspect(e)
          }),
        )

        use assets <- result.try(
          asset_registry_repository.get_all_assets(ctx.db)
          |> result.map_error(fn(e) {
            "Failed to fetch assets: " <> string.inspect(e)
          }),
        )

        // 2. Build snapshot
        let snapshot = rebalancing.build_snapshot(positions, price_data, assets)

        // 3. Detect drift
        use report <- result.try(rebalancing.detect_drift(snapshot, policy))

        Ok(report)
      }

      case result {
        Ok(report) -> {
          let json = drift_report_to_json(report)
          ok(json)
        }
        Error(e) -> internal_error(e)
      }
    }
    _ -> wisp.method_not_allowed([Get])
  }
}

fn drift_report_to_json(report: DriftReport) -> json.Json {
  json.array(report.analyses, drift_analysis_to_json)
}

fn drift_analysis_to_json(analysis: DriftAnalysis) -> json.Json {
  json.object([
    #("asset", json.string(policy_target_key_value(analysis.target_key))),
    #(
      "target",
      json.float(int.to_float(analysis.target_weight_bps) /. 100.0),
    ),
    #(
      "current",
      json.float(int.to_float(analysis.current_weight_bps) /. 100.0),
    ),
    #(
      "bandLower",
      json.float(int.to_float(analysis.lower_bound_bps) /. 100.0),
    ),
    #(
      "bandUpper",
      json.float(int.to_float(analysis.upper_bound_bps) /. 100.0),
    ),
    #("status", json.string(drift_status_to_string(analysis.status))),
  ])
}

fn drift_status_to_string(status: DriftStatus) -> String {
  case status {
    InBand -> "in_band"
    OutOfBand -> "out_of_band"
  }
}
