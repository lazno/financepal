import actor/position_records_processor.{PositionRecordsUpdated}
import application/types.{type Context}
import directa/directa_sim_csv_importer
import directa/directa_sim_types
import domain/position_types.{type PositionRecord}
import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import persistence/position_records_repository
import rest/resource/common.{bad_request, internal_error, ok}
import simplifile
import wisp.{type Request, type Response}

pub fn handle_post_import_csv(req: Request, ctx: Context) -> Response {
  use formdata <- wisp.require_form(req)

  let insert_result = {
    use file_content <- result.try(get_file_from_formdata(formdata))
    use records <- result.try(parse_into_records(file_content))
    insert_records(ctx, records)
  }

  case insert_result {
    Ok(count) -> {
      process.send(ctx.position_records_processor, PositionRecordsUpdated)
      let response =
        json.object([
          #("count", json.int(count)),
        ])
      ok(response)
    }
    Error(e) -> e
  }
}

fn parse_into_records(
  file_content: String,
) -> Result(List(PositionRecord), Response) {
  let records = {
    use parsed <- result.try(directa_sim_csv_importer.parse_directa_sim_csv(
      file_content,
    ))
    directa_sim_csv_importer.directa_sim_to_rebalancing(
      parsed.account_name,
      parsed.transactions,
    )
  }
  result.map_error(records, map_directa_sim_errors)
}

fn insert_records(
  ctx: Context,
  records: List(PositionRecord),
) -> Result(Int, Response) {
  position_records_repository.insert_position_records(ctx.db, records)
  |> result.map_error(fn(e) {
    internal_error("Database error: " <> string.inspect(e))
  })
}

fn get_file_from_formdata(formdata: wisp.FormData) -> Result(String, Response) {
  // Files are now tuples of #(String, UploadedFile)
  case
    list.find(formdata.files, fn(file_tuple) {
      let #(field_name, _uploaded_file) = file_tuple
      field_name == "file"
    })
  {
    Ok(file_tuple) -> {
      let #(_field_name, uploaded_file) = file_tuple
      // Read the file from the temporary path
      case simplifile.read(uploaded_file.path) {
        Ok(content) -> Ok(content)
        Error(_) -> Error(bad_request("Failed to read uploaded file"))
      }
    }
    Error(_) -> Error(bad_request("No file uploaded with name 'file'"))
  }
}

fn map_directa_sim_errors(e: directa_sim_types.DirectaSimError) -> Response {
  case e {
    directa_sim_types.EmptyFile -> bad_request("File was empty")
    directa_sim_types.InvalidColumnCount(e) -> bad_request(e)
    directa_sim_types.InvalidDateFormat(e) ->
      bad_request("Not a valid date format. " <> e)
    directa_sim_types.InvalidFileFormat -> bad_request("Not a valid CSV file")
    directa_sim_types.InvalidNumberFormat(field, value) ->
      bad_request(field <> " with value " <> value <> " is not a valid number")
    directa_sim_types.InvalidQuantityFormat(e) -> bad_request(e)
    directa_sim_types.InvalidTransactionType(e) ->
      bad_request("invalid transaction type: " <> e)
    directa_sim_types.MissingAccountName ->
      bad_request("could not find account name in csv")
    directa_sim_types.CannotParseAccountName(e) ->
      bad_request("cannot parse account name: " <> e)
    directa_sim_types.InternalError(e) -> {
      internal_error(e)
    }
  }
}
