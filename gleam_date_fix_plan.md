# Fix for convert_italian_date_to_iso Function

## Problem
The original code has invalid syntax with function calls in guards:

```gleam
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  let [day, month, year] = string.split(italian_date, "/")
  
  let day_length = string.length(day)
  let month_length = string.length(month)
  let year_length = string.length(year)

  if string.length(day) == 2 && string.length(month) == 2 && string.length(year) == 4 ->
      Ok(year <> "-" <> month <> "-" <> day)
    _ ->
      Error(InvalidDateFormat(italian_date))
  }
}
```

## Solution
In Gleam, you cannot use function calls in guards. Instead, use a case statement with bound variables:

```gleam
/// Convert Italian date format (DD/MM/YYYY) to ISO format (YYYY-MM-DD)
pub fn convert_italian_date_to_iso(italian_date: String) -> Result(String, DirectaSimError) {
  let parts = string.split(italian_date, "/")
  
  case parts {
    [day, month, year] if string.length(day) == 2 && string.length(month) == 2 && string.length(year) == 4 ->
      Ok(year <> "-" <> month <> "-" <> day)
    _ ->
      Error(InvalidDateFormat(italian_date))
  }
}
```

## Key Changes
1. Use `let parts = string.split(italian_date, "/")` instead of pattern matching directly
2. Use `case parts` to pattern match on the result
3. The guard clause `if string.length(day) == 2 && string.length(month) == 2 && string.length(year) == 4` is valid because it uses the bound variables `day`, `month`, and `year`

## Note
The current code in `src/domain/directa_sim_types.gleam` (lines 89-98) already has the correct implementation, so no changes are needed to the actual file.