import gleam/io
import gleam/result
import gleam/string
import sqlight

fn start_transaction(
  con: sqlight.Connection,
) -> Result(Nil, TransactionError(e)) {
  sqlight.exec("BEGIN TRANSACTION;", con)
  |> result.map_error(fn(e) { db_error("Error starting transaction", e) })
}

fn commit_transaction(
  res: Result(a, TransactionError(b)),
  con: sqlight.Connection,
) -> Result(a, TransactionError(b)) {
  case res {
    Ok(value) ->
      sqlight.exec("COMMIT", con)
      |> result.map_error(fn(e) {
        db_error("error while commiting transaction", e)
      })
      |> result.replace(value)
    Error(UserError(user_error)) ->
      case sqlight.exec("ROLLBACK", con) {
        Ok(_) -> Error(UserError(user_error))
        Error(e) -> {
          io.print_error(
            "CRITICAL: rollback of transaction failed: " <> string.inspect(e),
          )
          Error(UserError(user_error))
        }
      }
    e -> e
  }
}

pub fn wrap_in_transaction(
  fun: fn() -> Result(a, b),
  con: sqlight.Connection,
) -> Result(a, TransactionError(b)) {
  use _ <- result.try(start_transaction(con))
  fun()
  |> result.map_error(fn(e) { UserError(e) })
  |> commit_transaction(con)
}

pub type TransactionError(e) {
  DbError(String)
  UserError(e)
}

pub fn db_error(msg: String, error: sqlight.Error) -> TransactionError(e) {
  DbError(msg <> ": " <> string.inspect(error))
}
