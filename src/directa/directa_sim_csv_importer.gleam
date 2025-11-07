import directa/directa_sim_types.{
  type DirectaSimError, type DirectaSimRow, type ImportSuccess, Buy as DBuy,
  DirectaSimRow, Sell as DSell,
}
import domain/position_types.{type PositionRecord, Buy as RBuy, Sell as RSell}
import gleam/regexp

import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gsv

import domain/common_types.{
  Asset, account, asset_name, isin, order_reference, quantity, record_date,
  symbol,
}

fn ensure_not_empty(
  lines: Result(List(List(String)), DirectaSimError),
) -> Result(List(List(String)), DirectaSimError) {
  case lines {
    Ok([]) -> Error(directa_sim_types.EmptyFile)
    _ -> lines
  }
}

fn parse_account_name(
  csv_lines: List(List(String)),
) -> Result(String, DirectaSimError) {
  use re <- result.try(
    result.map_error(regexp.from_string(": (\\w+) "), fn(e) {
      directa_sim_types.InternalError(string.inspect(e))
    }),
  )

  use header_line <- result.try(
    csv_lines
    |> list.first
    |> result.map_error(fn(_) { directa_sim_types.MissingAccountName }),
  )

  case header_line {
    [] -> Error(directa_sim_types.MissingAccountName)
    [first, ..] -> {
      case string.trim(first) {
        "" -> Error(directa_sim_types.MissingAccountName)
        s -> {
          case regexp.scan(re, s) {
            [regexp.Match(_, [option.Some(account)])] -> Ok(account)
            _ -> Error(directa_sim_types.CannotParseAccountName(s))
          }
        }
      }
    }
  }
}

pub fn directa_sim_to_rebalancing(
  account_name: String,
  rows: List(DirectaSimRow),
) -> Result(List(PositionRecord), DirectaSimError) {
  rows
  |> list.filter(fn(row) {
    row.transaction_type == DBuy || row.transaction_type == DSell
  })
  |> list.map(fn(row) {
    use tx_type <- result.try(case row.transaction_type {
      DBuy -> Ok(RBuy)
      DSell -> Ok(RSell)
      _ ->
        Error(
          directa_sim_types.InvalidTransactionType(string.inspect(
            row.transaction_type,
          )),
        )
    })
    use q <- result.try(
      row.quantity
      |> quantity
      |> result.map_error(fn(e) { directa_sim_types.InvalidQuantityFormat(e) }),
    )

    Ok(position_types.PositionRecord(
      date: record_date(row.transaction_date),
      asset: Asset(
        symbol: symbol(row.ticker),
        isin: isin(row.isin),
        name: asset_name(row.description),
      ),
      account: account(account_name),
      quantity: q,
      position_record_type: tx_type,
      order_reference: order_reference(row.order_reference),
    ))
  })
  |> result.all
}

/// Parse Directa-sim CSV file
pub fn parse_directa_sim_csv(
  contents: String,
) -> Result(ImportSuccess, DirectaSimError) {
  use lines <- result.try(
    gsv.to_lists(contents, ",")
    |> result.map_error(fn(_) { directa_sim_types.InvalidFileFormat })
    |> ensure_not_empty,
  )

  use account_name <- result.try(parse_account_name(lines))

  lines
  // data lines start at line 10
  |> list.drop(10)
  |> list.map(parse_data_line)
  // at this point we have a result of all parsed rows
  // pack failed and succeeded lines side by side
  |> result.all
  |> result.map(fn(parsed_lines) {
    directa_sim_types.ImportSuccess(account_name, parsed_lines)
  })
}

/// Parse a single CSV line into DirectaSimRow
fn parse_data_line(
  parts: List(String),
) -> Result(DirectaSimRow, DirectaSimError) {
  case parts {
    [
      transaction_date,
      _,
      transaction_type,
      ticker,
      isin,
      _,
      description,
      quantity,
      _,
      _,
      _,
      order_reference,
    ] -> {
      use converted_date <- result.try(
        directa_sim_types.convert_italian_date_to_iso(transaction_date),
      )
      use parsed_transaction_type <- result.try(
        directa_sim_types.parse_transaction_type(transaction_type),
      )

      use parsed_quantity <- result.try(directa_sim_types.parse_quantity(
        quantity,
      ))

      Ok(DirectaSimRow(
        transaction_date: converted_date,
        transaction_type: parsed_transaction_type,
        ticker: string.trim(ticker),
        isin: string.trim(isin),
        description: string.trim(description),
        quantity: parsed_quantity,
        order_reference: order_reference,
      ))
    }
    _ ->
      Error(directa_sim_types.InvalidColumnCount(
        "Invalid CSV format: expected 12 columns, got "
        <> string.inspect(list.length(parts)),
      ))
  }
}
