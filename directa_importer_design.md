# Directa-SIM CSV Importer Design

## Overview
Implementation of a broker-specific CSV importer for Directa-SIM that maps their export format to our common transaction format.

## Directa-SIM Format Analysis

### CSV Structure
```
Transaction date,Value date,Transaction type,Ticker,Isin,Protocol,Description,Quantity,Amount in euros,Currency amount,Currency,Order reference
22-10-2025,24-10-2025,Buy,PHPD,JE00B1VS3002,,WISDOMTREE PHYSICAL PALLADIUM,1,"-1,00",1,EUR,x
22-10-2025,24-10-2025,Commissions,PHPD,JE00B1VS3002,,WISDOMTREE PHYSICAL PALLADIUM,0,"-1,00",1,EUR,x
```

### Key Fields for Rebalancing
- **Transaction date**: Trade execution date (DD-MM-YYYY format)
- **Transaction type**: Buy/Sell/Commissions/etc.
- **Ticker**: Stock symbol (e.g., PHPD, RBOT, WGLD)
- **Quantity**: Number of shares (0 for commission entries)
- **Amount in euros**: Total transaction amount (negative for buys, positive for sells)
- **Currency**: Transaction currency (EUR/USD)
- **Order reference**: Groups related transactions together

## Implementation Strategy

### 1. Transaction Grouping
Use order reference to group related entries:
- Main trade (Buy/Sell)
- Commission entry (separate row with same order reference)
- Tax entries (can be ignored for rebalancing)

### 2. Data Mapping

```gleam
// Directa-SIM -> Our Format Mapping
{
  date: convert_date("22-10-2025") // -> "2025-10-22"
  symbol: "PHPD"
  type: "Buy" -> Buy
  quantity: 1
  price: calculate_price("-1,00", 1) // -> 1.00
  fees: aggregate_commissions(order_reference) // -> 1.00
  currency: "EUR"
  account: "Directa-SIM" // default account name
}
```

### 3. Price Calculation
Since Directa doesn't provide per-share price:
```gleam
price = abs(amount_in_euros) / quantity
```
For EUR-only focus, we ignore currency_amount column.

### 4. Fee Aggregation
Group commission entries by order reference and sum them:
```gleam
total_fees = sum_of_all_commission_amounts_for_order
```

## Implementation Steps

### Phase 1: Core Parser
1. Create `directa_parser.gleam` module
2. Implement date conversion function
3. Implement price calculation function
4. Implement transaction grouping by order reference
5. Implement fee aggregation logic

### Phase 2: Integration
1. Add Directa-SIM import endpoint to router
2. Extend CSV parser to detect format automatically
3. Add validation for Directa-specific requirements
4. Implement error handling for malformed data

### Phase 3: Testing
1. Test with provided anonymized data
2. Verify price calculations
3. Test fee aggregation
4. Validate date conversions

## Code Structure

```gleam
// src/domain/directa_parser.gleam
pub fn parse_directa_csv(content: String) -> Result(List(Transaction), DirectaError) {
  // Implementation
}

fn parse_directa_date(date_str: String) -> Result(String, String) {
  // Convert DD-MM-YYYY to YYYY-MM-DD
}

fn calculate_directa_price(amount_str: String, quantity: Int) -> Result(Float, String) {
  // Parse "1,00" format and calculate price per share
}

fn group_by_order_reference(rows: List(DirectaRow)) -> Dict(String, List(DirectaRow)) {
  // Group related transactions
}

fn aggregate_fees(rows: List(DirectaRow)) -> Float {
  // Sum commission amounts
}
```

## Error Handling

### DirectaError Type
```gleam
pub type DirectaError {
  InvalidDateFormat(String)
  InvalidNumberFormat(String)
  MissingOrderReference
  InvalidTransactionType(String)
  DivisionByZero // quantity = 0 for main transaction
}
```

## Validation Rules

1. **Required Fields**: Transaction date, type, ticker, quantity, amount, order reference
2. **Valid Transaction Types**: Only process "Buy" and "Sell" (ignore others)
3. **Positive Quantity**: Main transactions must have quantity > 0
4. **EUR Focus**: Only process EUR currency transactions initially
5. **Order Reference**: Must be present for grouping

## Future Extensibility

This design allows easy addition of other brokers:
- Create new parser modules (e.g., `degiro_parser.gleam`)
- Implement same interface: `parse_broker_csv() -> Result(List(Transaction), Error)`
- Add broker detection logic in main import endpoint
- Reuse common validation and error handling patterns

## Next Steps

1. Implement the Directa parser module
2. Add new API endpoint: `POST /api/import/directa`
3. Test with the provided sample data
4. Validate calculated prices against expected values
5. Integrate with existing transaction repository