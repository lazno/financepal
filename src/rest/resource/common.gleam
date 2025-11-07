import gleam/json

import wisp.{type Response}

pub fn ok(msg: json.Json) -> Response {
  wisp.json_response(json.to_string(msg), 200)
}

pub fn bad_request(msg: String) -> Response {
  http_error(msg, 400)
}

pub fn internal_error(msg: String) -> Response {
  http_error(msg, 500)
}

fn http_error(msg: String, code: Int) -> Response {
  let error = error_response(msg)
  wisp.json_response(json.to_string(error_response_to_json(error)), code)
}

type ErrorResponse {
  ErrorResponse(error: String)
}

fn error_response(error: String) -> ErrorResponse {
  ErrorResponse(error)
}

fn error_response_to_json(response: ErrorResponse) -> json.Json {
  json.object([#("error", json.string(response.error))])
}
