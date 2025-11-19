import application/types.{type Context}
import gleam/http
import rest/resource/directa_sim_resource
import rest/resource/drift_resource
import rest/resource/policy_resource
import rest/resource/portfolio_resource
import simplifile
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  case wisp.path_segments(req) {
    ["api", "import"] -> handle_import(req, ctx)
    ["api", "portfolio"] -> portfolio_resource.handle_get_portfolio(req, ctx)
    ["api", "drift"] -> drift_resource.handle_get_drift(req, ctx)
    ["api", "policy"] -> policy_resource.handle_request(req, ctx)
    [] -> serve_index()
    _ -> serve_static(req)
  }
}

fn serve_index() -> Response {
  // Read and serve index.html directly for root path
  let assert Ok(index_content) = simplifile.read("frontend/dist/index.html")
  wisp.html_response(index_content, 200)
}

fn serve_static(req: Request) -> Response {
  // Serve all other requests from frontend/dist directory
  wisp.serve_static(req, under: "/", from: "frontend/dist", next: fn() {
    wisp.not_found()
  })
}

fn handle_import(req: Request, ctx: Context) -> Response {
  case req.method {
    http.Post -> {
      directa_sim_resource.handle_post_import_csv(req, ctx)
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}
