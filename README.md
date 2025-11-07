I've analyzed the current FinancePal project and created a concise GitHub-style README that accurately reflects what's actually implemented. Here's the updated README:

# FinancePal

A personal portfolio tracker backend built with Gleam, Wisp, and SQLite. Imports transaction data from Directa SIM CSV files and provides basic position tracking.

## What it does

- **Import transactions**: Upload Directa SIM CSV files containing buy/sell transactions
- **Track positions**: Calculates current holdings based on transaction history
- **Price fetching**: Automatically fetches latest prices via Yahoo Finance API
- **Multi-currency support**: Handles transactions in different currencies

## Quick start

### Local development
```bash
gleam deps download
gleam run
```

Server runs on `http://localhost:8080`

## API

### POST /api/import
Import Directa SIM CSV transactions.

**Request:**
- Method: `POST`
- Content-Type: `multipart/form-data`
- Body: CSV file with field name `file`

**Example:**
```bash
curl -X POST http://localhost:8080/api/import \
  -F "file=@directa.csv"
```

**Response:**
```json
{
  "count": 12
}
```

## Tech stack

- **Language**: Gleam
- **Web framework**: Wisp
- **Database**: SQLite
- **HTTP server**: Mist
- **Price data**: Yahoo Finance API
- **Actor system**: Gleam OTP for background price fetching

## Current limitations

- Portfolio/performance endpoint is commented out (not implemented)
- Only supports Directa SIM CSV format
- No web UI - API only
- Database gets cleared on each startup (development mode)

## CSV format

Directa SIM export format with columns:
- date, symbol, isin, asset_name, type, quantity, account, order_reference

This is a development project - expect breaking changes and incomplete features.