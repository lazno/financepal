# FinancePal

A personal portfolio tracker backend micro-spike built with Gleam, Wisp, and SQLite.

## Tech Stack

- **Language**: Gleam
- **Web Framework**: Wisp
- **Database**: SQLite (via sqlight)
- **HTTP Server**: Mist
- **Port**: 8080

## Features

- Import financial transactions from CSV files
- Calculate Time-Weighted Return (TWR) for portfolio positions
- RESTful API following OpenAPI specification
- Type-safe implementation using Gleam's type system

## Project Structure

```
financepal/
├── src/
│   ├── financepal.gleam    # Main entry point
│   ├── router.gleam        # HTTP request routing
│   ├── database.gleam      # Database connection and schema
│   ├── repository.gleam    # Database operations
│   ├── csv_parser.gleam    # CSV parsing logic
│   └── types.gleam         # Type definitions
├── gleam.toml              # Project configuration
├── docker-compose.yml      # Docker setup
├── Dockerfile              # Container image
└── example.csv             # Sample transaction data
```

## Setup Instructions

### Option 1: Using Docker (Recommended)

1. Build and start the application:

```bash
docker-compose up --build
```

The server will start on `http://localhost:8080`

### Option 2: Local Development

1. Install Gleam (<https://gleam.run/getting-started/installing/>)

2. Download dependencies:

```bash
gleam deps download
```

3. Run the application:

```bash
gleam run
```

## API Endpoints

### POST /api/import

Import transactions from a CSV file.

**Request:**

- Method: `POST`
- Content-Type: `multipart/form-data`
- Body: CSV file with field name `file`

**CSV Format:**

```
date,symbol,type,quantity,price,fees,account
2024-01-15,AAPL,buy,10,150.25,9.99,Brokerage-A
```

**Response:**

```json
{
  "message": "Imported 12 transactions",
  "count": 12
}
```

**Example using curl:**

```bash
curl -X POST http://localhost:8080/api/import \
  -F "file=@example.csv"
```

### GET /api/performance

Get portfolio performance metrics with Time-Weighted Return calculations.

**Request:**

- Method: `GET`

**Response:**

```json
{
  "positions": [
    {
      "symbol": "AAPL",
      "quantity": 20.0,
      "avg_price": 152.08,
      "current_price": 180.0,
      "twr": 0.183
    }
  ]
}
```

**Example using curl:**

```bash
curl http://localhost:8080/api/performance
```

## Database Schema

The `transactions` table:

| Column       | Type    | Description                          |
|--------------|---------|--------------------------------------|
| id           | INTEGER | Primary key (auto-increment)         |
| date         | TEXT    | Transaction date                     |
| symbol       | TEXT    | Stock symbol                         |
| type         | TEXT    | Transaction type ("buy" or "sell")   |
| quantity     | REAL    | Number of shares                     |
| price        | REAL    | Price per share                      |
| fees         | REAL    | Transaction fees (default 0.0)       |
| account      | TEXT    | Account name                         |
| inserted_at  | DATETIME| Timestamp of record insertion        |

## Performance Calculation

The Time-Weighted Return (TWR) is calculated as:

1. Group transactions by symbol
2. For each symbol:
   - Calculate weighted average purchase price from "buy" transactions
   - Get current price from the most recent transaction
   - Calculate current quantity: sum(buy quantities) - sum(sell quantities)
   - Calculate TWR: (current_price / avg_price) - 1.0

## Testing the API

1. Start the server (see Setup Instructions)

2. Import the example data:

```bash
curl -X POST http://localhost:8080/api/import \
  -F "file=@example.csv"
```

3. Get performance metrics:

```bash
curl http://localhost:8080/api/performance
```

## Error Handling

The API uses Gleam's Result types for comprehensive error handling:

- **400 Bad Request**: Invalid CSV format, missing file, invalid data
- **500 Internal Server Error**: Database errors, calculation errors

Error responses follow this format:

```json
{
  "error": "Error message description"
}
```

## Development Notes

- SQLite database file (`financepal.db`) is created automatically on first run
- The application uses Gleam's type system for compile-time safety
- All fallible operations return `Result` types
- CSV parsing validates transaction types and numeric values

## License

This is a micro-spike for demonstration purposes.
