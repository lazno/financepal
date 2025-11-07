import domain/common_types.{
  type Currency, type Isin, type Price, type PriceData, PriceData, currency,
  currency_name, price, price_amount,
}
import gleam/dynamic/decode
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp

type YahooPriceInfo {
  YahooPriceInfo(
    price: Price,
    currency: Currency,
    timestamp: timestamp.Timestamp,
  )
}

pub fn fetch_price_from_yahoo(isin: Isin) -> Result(PriceData, String) {
  use symbol <- result.try(fetch_symbol_internal(isin))
  use price_info <- result.try(fetch_price_internal(symbol))

  case currency_name(price_info.currency) {
    "EUR" -> Ok(price_info.price)
    _ -> {
      use conversion_rate <- result.try(fetch_euro_rate_internal(
        price_info.currency,
      ))
      use adjusted_conversion_rate <- result.try(adjust_conversion_rate(
        price_info.currency,
        conversion_rate.price,
      ))

      convert_prices(adjusted_conversion_rate, price_info.price)
    }
  }
  |> result.map(fn(converted_price) {
    PriceData(isin, converted_price, currency("EUR"), price_info.timestamp)
  })
}

///this method catches some gotchas like for example on british exchanges prices being listed in GBp (pences), 
///but yahoo will uppercase the pence to GBP if we want to see the forex trading pair GBpEUR
fn adjust_conversion_rate(
  currency: Currency,
  rate: Price,
) -> Result(Price, String) {
  case currency_name(currency) {
    "GBp" -> price(price_amount(rate) /. 100.0)
    _ -> Ok(rate)
  }
}

fn convert_prices(rate: Price, value: Price) -> Result(Price, String) {
  price(price_amount(rate) *. price_amount(value))
}

fn fetch_price_internal(symbol: String) -> Result(YahooPriceInfo, String) {
  use request <- result.try(prices_request(symbol))
  use response <- result.try(send_request(request))
  parse_price_data_response(response)
}

fn fetch_symbol_internal(isin: Isin) -> Result(String, String) {
  use request <- result.try(isin_request(isin))
  use response <- result.try(send_request(request))
  parse_isin_response(response)
}

fn fetch_euro_rate_internal(
  currency: Currency,
) -> Result(YahooPriceInfo, String) {
  let symbol =
    currency_name(currency)
    |> string.append("EUR=X")

  use request <- result.try(prices_request(symbol))
  use response <- result.try(send_request(request))
  parse_price_data_response(response)
}

fn parse_isin_response(
  resp: response.Response(String),
) -> Result(String, String) {
  case resp.status {
    200 ->
      extract_symbol_from_json(resp.body)
      |> result.map_error(fn(e) {
        "Error parsing yahoo isin response: " <> string.inspect(e)
      })
    403 -> Error("Rate limited by Yahoo")
    _ ->
      Error(
        "HTTP error while fetching symbol for an isin: "
        <> int.to_string(resp.status),
      )
  }
}

fn extract_symbol_from_json(body: String) -> Result(String, String) {
  let decoder =
    decode.at(
      ["quotes"],
      decode.list(decode.field("symbol", decode.string, decode.success)),
    )
  json.parse(body, decoder)
  |> result.map_error(fn(e) {
    "error decoding symbol json: " <> string.inspect(e)
  })
  |> result.map(fn(l) {
    list.first(l)
    |> result.map_error(fn(_) { "no symbol found on yahoo" })
  })
  |> result.flatten
}

fn parse_price_data_response(
  resp: response.Response(String),
) -> Result(YahooPriceInfo, String) {
  case resp.status {
    200 ->
      result.map_error(extract_pricedata_from_json(resp.body), fn(e) {
        "Error parsing yahoo pricedata response: " <> string.inspect(e)
      })
    403 -> Error("Rate limited by Yahoo")
    _ -> Error("HTTP error while fetching pricedata: " <> string.inspect(resp))
  }
}

fn extract_pricedata_from_json(body: String) -> Result(YahooPriceInfo, String) {
  let decoder =
    decode.at(
      ["chart", "result"],
      decode.list(decode.at(["meta"], price_data_decoder())),
    )

  json.parse(body, decoder)
  |> result.map_error(fn(e) {
    "error decoding pricedata json: " <> string.inspect(e)
  })
  |> result.map(fn(l) {
    list.first(l)
    |> result.map_error(fn(_) { "no pricedata found on yahoo" })
    |> result.flatten
  })
  |> result.flatten
}

fn price_data_decoder() -> decode.Decoder(Result(YahooPriceInfo, String)) {
  use price <- decode.field(
    "regularMarketPrice",
    decode.map(decode.float, price),
  )
  use currency <- decode.field(
    "currency",
    decode.map(decode.string, fn(s) {
      result.map_error(Ok(currency(s)), string.inspect)
    }),
  )

  let paired = {
    use p <- result.try(price)
    use c <- result.try(currency)
    Ok(YahooPriceInfo(p, c, timestamp.system_time()))
  }

  decode.success(paired)
}

fn send_request(
  http_req: request.Request(String),
) -> Result(response.Response(String), String) {
  http_req
  |> request.set_header("User-Agent", "FinancePal/1.0")
  |> request.set_header("Accept", "application/json")
  |> httpc.send
  |> result.map_error(fn(e) { "Error sending request: " <> string.inspect(e) })
}

fn isin_request(isin: Isin) -> Result(request.Request(String), String) {
  let url =
    "https://query1.finance.yahoo.com/v1/finance/search?q="
    <> common_types.isin_value(isin)
    <> "&newsCount=0&listsCount=0&quotesCount=1&quotesQueryId=tss_match_phrase_query"

  request.to(url)
  |> result.map_error(fn(e) { "could not parse isin url" <> string.inspect(e) })
}

fn prices_request(symbol: String) -> Result(request.Request(String), String) {
  let url = "https://query1.finance.yahoo.com/v8/finance/chart/" <> symbol
  request.to(url)
  |> result.map_error(fn(e) {
    "could not parse prices url" <> string.inspect(e)
  })
}
