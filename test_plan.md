# Test Plan for convert_italian_date_to_iso Function

## Test Cases

### Valid Date Formats
1. **Standard Italian date**: "15/03/2023" → Should return Ok("2023-03-15")
2. **Single digit day and month**: "05/07/2022" → Should return Ok("2022-07-05")
3. **End of year**: "31/12/2023" → Should return Ok("2023-12-31")
4. **Beginning of year**: "01/01/2024" → Should return Ok("2024-01-01")

### Invalid Date Formats
1. **Wrong separator**: "15-03-2023" → Should return Error(InvalidDateFormat("15-03-2023"))
2. **Missing parts**: "15/2023" → Should return Error(InvalidDateFormat("15/2023"))
3. **Extra parts**: "15/03/2023/extra" → Should return Error(InvalidDateFormat("15/03/2023/extra"))
4. **Wrong day length**: "5/03/2023" → Should return Error(InvalidDateFormat("5/03/2023"))
5. **Wrong month length**: "15/3/2023" → Should return Error(InvalidDateFormat("15/3/2023"))
6. **Wrong year length**: "15/03/23" → Should return Error(InvalidDateFormat("15/03/23"))
7. **Empty string**: "" → Should return Error(InvalidDateFormat(""))

## Implementation Notes

The corrected function should be:

```gleam
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

## Testing Approach

Since we're in Architect mode and can't directly modify Gleam files, we should:

1. Verify the current implementation in `src/domain/directa_sim_types.gleam` matches the corrected version
2. If it doesn't match, request to switch to a mode that can edit Gleam files
3. Run the existing tests to ensure no regressions
4. Add new test cases if needed

## Current Status
Looking at the actual file, the current implementation (lines 89-98) already uses a valid case statement without function calls in guards, so it appears to be correct. However, it uses a different approach than what we've discussed.