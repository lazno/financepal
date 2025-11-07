import gleam/erlang/application
import gleam/result
import migrant
import migrant/types
import sqlight

pub type Connection =
  sqlight.Connection

pub fn connect(path: String) -> Result(Connection, sqlight.Error) {
  sqlight.open(path)
}

const priv_location = "financepal"

pub fn init_schema(conn: Connection) -> Result(Nil, String) {
  use directory <- result.try(
    application.priv_directory(priv_location)
    |> result.map_error(fn(_) { "Error while loading migration directory" }),
  )

  use res <- result.try(
    migrant.migrate(conn, directory <> "/migration")
    |> result.map_error(fn(err) {
      case err {
        types.RollbackError(message, _) -> message
        types.MigrationError(message, _) -> message
        types.FilenameError(message) -> message
        types.FileError(_) -> "File Error"
        types.ExtractionError(message) -> message
        types.ExpectedFolderError -> "Expected a folder"
        types.DatabaseError(_) -> "Database Error"
      }
    }),
  )

  Ok(res)
}
