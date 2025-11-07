import actor/position_records_processor.{type Message as PositionMessage}
import gleam/erlang/process
import sqlight

pub type Context {
  Context(
    db: sqlight.Connection,
    position_records_processor: process.Subject(PositionMessage),
  )
}
