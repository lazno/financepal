# Corrected Fix for convert_italian_date_to_iso Function

## Problem
Both the original code and my previous fix have the same issue: they try to use function calls (`string.length()`) in guard clauses, which is not allowed in Gleam.

## Correct Solution
We need to avoid function calls in guards entirely. Here are two valid approaches:

### Option 1: Use nested case statements
```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  let parts = string.split(italian_date, "/")
  
  case parts {
    [day, month, year] -> {
      case string.length(day), string.length(month), string.length(year) {
        2, 2, 4 -> Ok(year <> "-" <> month <> "-" <> day)
        _, _, _ -> Error(InvalidDateFormat(italian_date))
      }
    }
    _ -> Error(InvalidDateFormat(italian_date))
  }
}
```

### Option 2: Use let bindings and simple pattern matching
```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  let parts = string.split(italian_date, "/")
  
  case parts {
    [day, month, year] -> {
      let day_len = string.length(day)
      let month_len = string.length(month)
      let year_len = string.length(year)
      
      case day_len == 2 && month_len == 2 && year_len == 4 {
        True -> Ok(year <> "-" <> month <> "-" <> day)
        False -> Error(InvalidDateFormat(italian_date))
      }
    }
    _ -> Error(InvalidDateFormat(italian_date))
  }
}
```

### Option 3: Use pattern matching on string literals (most elegant)
```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  case string.split(italian_date, "/") {
    [day, month, year] if day |> string.length == 2 && month |> string.length == 2 && year |> string.length == 4 ->
      Ok(year <> "-" <> month <> "-" <> day)
    _ ->
      Error(InvalidDateFormat(italian_date))
  }
}
```

Wait, Option 3 still has function calls in guards! Let me provide the truly correct version:

### Option 4: The actually correct version (no function calls in guards)
```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  case string.split(italian_date, "/") {
    [day, month, year] -> {
      case day, month, year {
        d, m, y if string.length(d) == 2 && string.length(m) == 2 && string.length(y) == 4 ->
          Ok(year <> "-" <> month <> "-" <> day)
        _, _, _ ->
          Error(InvalidDateFormat(italian_date))
      }
    }
    _ ->
      Error(InvalidDateFormat(italian_date))
  }
}
```

Actually, this still has function calls in guards! The fundamental issue is that **Gleam does not allow any function calls in guard clauses**.

## The Real Solution: No Guards with Function Calls
We must avoid function calls in guards completely:

```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  case string.split(italian_date, "/") {
    [day, month, year] -> {
      let is_valid = string.length(day) == 2 && string.length(month) == 2 && string.length(year) == 4
      case is_valid {
        True -> Ok(year <> "-" <> month <> "-" <> day)
        False -> Error(InvalidDateFormat(italian_date))
      }
    }
    _ -> Error(InvalidDateFormat(italian_date))
  }
}
```

This is the only valid approach: evaluate the function calls first, then use the result in a simple pattern match.