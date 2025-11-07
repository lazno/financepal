# FinancePal Development Context

## Projekt Overview

Self-hosted Portfolio-Tracker für Investment-Management, Banking und Household-Expenses.

**Tech Stack:** Gleam, Wisp, Lustre, SQLite, Svelte, Skeleton, d3.js  
**Standort:** Italien  
**Konten:** Directa SIM, Trade Republic, KuCoin, ING.it, Revolut

## Kernfunktionen

- **Investment:** Performance-Tracking (MWR, XIRR, Gewinn absolut/prozentual) - *geplant*
- **Banking:** Account-Balances, Cash-Flow - *geplant*
- **Household:** Expense-Tracking, Budget - *geplant*
- **Rebalancing:** Asset-Allocation, Gruppierung, Target-Allocation, Portfolio/Einlagen-basiert - *in Arbeit*
- **Live Prices:** Yahoo Finance API, automatisches Fetching (30 Sekunden), Actor-basiert - *implementiert*

**Nicht benötigt:** Tax-Calculations, GDPR-Compliance, Deep Crypto-Features

## Aktueller Implementierungsstatus

### ✅ Implementiert

- CSV Import (POST `/api/import`)
- Transaction Repository (Insert, Get All, Get Symbols)
- Price Fetcher Actor (Background-Job)
- Yahoo Finance Client (Chart API)
- Position Calculation (Weighted Average Price)
- Database Migrations (via `migrant`)
- Domain Types (Opaque Types mit Validierung)

### ⏳ In Arbeit

- **Directa SIM CSV Parser:** Broker-spezifischer Import mit Fee-Adjustment

### 🔮 Geplant

- Rebalancing-Logik
- Frontend (Lustre/Svelte)
- Asset Groups Management
- Target Allocations
- Performance Metrics (MWR, XIRR)
- Trade Republic Parser

## File Tree

```
src/
├── actor/
│   └── price_fetcher.gleam
├── domain/
│   ├── calc.gleam
│   └── types.gleam
├── persistence/
│   ├── database.gleam
│   ├── price_data_repository.gleam
│   └── transaction_repository.gleam
├── rest/
│   ├── client/
│   │   └── yahoo.gleam
│   └── resource/
│       ├── csv_parser.gleam
│       └── router.gleam
└── financepal.gleam

priv/
└── migration/
    └── *.sql

test/
Dockerfile
docker-compose.yml
example.csv
financepal.db
gleam.toml
manifest.toml
README.md
```

## Datenmodell

### Implementierte Tables

**transactions** (UUIDv7):

```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  symbol TEXT NOT NULL,
  type TEXT NOT NULL,              -- 'buy' or 'sell'
  quantity REAL NOT NULL,
  price REAL NOT NULL,             -- Fee-adjusted price per share
  currency TEXT NOT NULL,
  fees REAL DEFAULT 0.0,
  account TEXT NOT NULL,
  inserted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_transactions_date ON transactions(date DESC);
CREATE INDEX idx_transactions_symbol ON transactions(symbol);
```

**Key Decision:** Minimales Schema für Rebalancing-Focus. Fees werden in `price` eingerechnet (fee-adjusted price).

**prices**:

```sql
CREATE TABLE prices (
  id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  price REAL NOT NULL,
  currency TEXT NOT NULL,
  fetched_at REAL NOT NULL
);
CREATE INDEX idx_prices_symbol_fetched ON prices(symbol, fetched_at DESC);
```

### Geplante Tables (vorhanden, nicht in Verwendung)

**asset_groups** (AUTOINCREMENT, eventuell auf UUID umstellen):

```sql
CREATE TABLE asset_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  parent_group_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_group_id) REFERENCES asset_groups(id)
);

CREATE TABLE asset_group_members (
  symbol TEXT NOT NULL,
  group_id INTEGER NOT NULL,
  PRIMARY KEY (symbol, group_id),
  FOREIGN KEY (group_id) REFERENCES asset_groups(id) ON DELETE CASCADE
);
```

## Domain Types (Opaque Types)

Alle Domain-Types sind als **Opaque Types** mit Validierung implementiert:

```gleam
// domain/types.gleam
pub opaque type Symbol { Symbol(ticker: String) }
pub opaque type TransactionDate { TransactionDate(value: String) }
pub opaque type Quantity { Quantity(shares: Float) }
pub opaque type Price { Price(amount: Float) }
pub opaque type Fees { Fees(amount: Float) }
pub opaque type Currency { Currency(name: String) }
pub opaque type Account { Account(name: String) }

pub type TransactionType { Buy | Sell }

pub type Transaction {
  Transaction(
    date: TransactionDate,
    symbol: Symbol,
    transaction_type: TransactionType,
    quantity: Quantity,
    price: Price,
    currency: Currency,
    fees: Fees,
    account: Account,
  )
}

pub type Position {
  Position(symbol: Symbol, quantity: Quantity, avg_price: Price)
}

pub type PriceData {
  PriceData(
    symbol: Symbol,
    price: Price,
    currency: Currency,
    timestamp: timestamp.Timestamp,
  )
}
```

**Validierung:**

- `quantity()`, `price()`, `fees()` prüfen auf negative Werte
- `transaction_type_from_string()` validiert "buy"/"sell"
- Accessor-Funktionen: `symbol_ticker()`, `price_amount()`, etc.

## CSV Import

**Endpoint:** `POST /api/import`  
**Format:** Multipart form-data mit field name `"file"`

**CSV-Struktur:**

```csv
date,symbol,type,quantity,price,currency,fees,account
2024-01-15,AAPL,buy,10,150.50,USD,2.50,Directa
```

**Implementation:**

- Parser: `rest/resource/csv_parser.gleam`
- Validiert alle Domain-Constraints
- Fehlertypen: `InvalidFormat`, `InvalidNumber`, `InvalidDomainValue`
- Response: `{"count": 10}` oder `{"error": "..."}`

## Directa SIM CSV Import (In Arbeit)

### CSV Format

- **Header:** Lines 1-9 (Metadata: Account, Extraction Date, Date Range)
- **Data:** Ab Line 10 (Column Headers + Transactions)

### Sample Columns

- Transaction date, Settlement date
- Type (Buy/Sell/Commission/Tax/Wire Transfer)
- Ticker, Description
- Quantity, Price, Amount (EUR)
- Order Reference

### Import Strategy

1. Extract account info from header line 1
2. Skip lines 1-9
3. Parse Buy/Sell transactions only
4. Group by `order_reference` to link fees
5. **Calculate fee-adjusted price:** `adjusted_price = (total_amount + fees) / quantity`
6. Insert into `transactions` with adjusted price
7. **Ignore:** Taxes (gross performance approach), Dividends, Transfers

### Trade Republic Compatibility

- Similar CSV structure
- Same fee-adjustment approach
- Implementation nach Directa-Validierung

### Crypto (KuCoin)

- Später
- Taxes nicht vom Broker abgeführt
- **Approach:** Gross performance für alle Assets (konsistent)

## Price Fetcher Actor

**Architektur:** OTP Actor mit Background-Fetching

**Configuration:**

- Interval: 30 Sekunden (`interval_ms: 30_000`)
- Rate-Limit: 1 Sekunde zwischen Symbolen (`rate_limit_delay_ms: 1000`)

**Messages:**

```gleam
pub type Message {
  FetchAllPrices(subject: process.Subject(Message))
  FetchSymbol(symbol: String)
  Shutdown
}
```

**Flow:**

1. Actor startet beim Application-Start
2. Initial trigger: `FetchAllPrices` wird gesendet
3. Lädt alle Symbole aus `transactions` Table
4. Fetched Preise von Yahoo Finance (mit Rate-Limiting)
5. Speichert in `prices` Table
6. Scheduled nächsten Fetch via `process.send_after()`

**Wichtig:** Subject muss in `FetchAllPrices` Message mitgegeben werden, da `process.new_subject()` nur für aktuellen Prozess funktioniert.

**Start:**

```gleam
// financepal.gleam
let assert Ok(subject) = price_fetcher.start(db)
process.send(subject, FetchAllPrices(subject))
```

## Yahoo Finance Integration

**API:** Inoffizielle Chart API (kein API-Key erforderlich)  
**Endpoint:** `https://query1.finance.yahoo.com/v8/finance/chart/{symbol}`

**Headers:**

```gleam
"User-Agent": "FinancePal/1.0"
"Accept": "application/json"
```

**Response Parsing:**

```gleam
// JSON Path: chart.result[0].meta
{
  "symbol": "AAPL",
  "regularMarketPrice": 150.50,
  "currency": "USD"
}
```

**Error Handling:**

- 200: Parse JSON
- 403: Rate limited
- Andere: HTTP error

**Return Type:** `Result(List(PriceData), String)`

## Position Calculation

**Implementation:** `domain/calc.gleam`

**Algorithmus:**

1. Gruppiere Transactions nach Symbol
2. Trenne Buys und Sells
3. Berechne Total Quantity: `total_buy - total_sell`
4. Berechne Weighted Average Price: `Σ(qty * price) / Σ(qty)` (nur Buys)
5. Erstelle Position

**Validierung:**

- Mindestens 1 Buy-Transaction erforderlich
- Quantity darf nicht negativ werden (Sells > Buys)

## Application Start

```gleam
// src/financepal.gleam
pub fn main() -> Nil {
  wisp.configure_logger()

  // 1. Database
  let assert Ok(db) = database.connect("financepal.db")
  let assert Ok(_) = database.init_schema(db)

  // 2. Price Fetcher Actor
  let assert Ok(subject) = price_fetcher.start(db)
  process.send(subject, FetchAllPrices(subject))

  // 3. Web Server
  let ctx = router.Context(db: db)
  let handler = fn(req) { router.handle_request(req, ctx) }

  let assert Ok(_) =
    wisp_mist.handler(handler, "financepal_secret_key")
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  io.println("Server started on http://localhost:8080")
  process.sleep_forever()
}
```

## Wichtige Implementierungsdetails

### UUID-Generierung

- **Package:** `youid`
- **Transactions:** UUIDv7 (`uuid.v7_string()`)
- **Prices:** UUIDv7
- **Asset Groups:** INTEGER AUTOINCREMENT (eventuell auf UUID umstellen)

### Database Migrations

- **Package:** `migrant`
- **Location:** `priv/migration/*.sql`
- Automatisch beim Start via `database.init_schema()`

### Actor Subject Pattern

**Problem:** `process.new_subject()` erstellt Subject für aktuellen Prozess, nicht für Actor.

**Lösung:** Subject als Parameter in Message mitgeben:

```gleam
// ❌ Falsch
process.send_after(process.new_subject(), delay, FetchAllPrices)

// ✅ Richtig
FetchAllPrices(subject: process.Subject(Message))
process.send_after(subject, delay, FetchAllPrices(subject))
```

### Opaque Types Pattern

Alle Domain-Types nutzen Opaque Types mit Constructor-Funktionen:

```gleam
pub opaque type Price { Price(amount: Float) }

pub fn price(amount: Float) -> Result(Price, String) {
  case amount <. 0.0 {
    True -> Error("Price cannot be negative")
    False -> Ok(Price(amount))
  }
}

pub fn price_amount(p: Price) -> Float {
  p.amount
}
```

### Repository Pattern

Repositories nutzen rekursive Loops für Batch-Inserts:

```gleam
fn insert_transactions_loop(
  conn: Connection,
  transactions: List(Transaction),
  count: Int,
) -> Result(Int, sqlight.Error) {
  case transactions {
    [] -> Ok(count)
    [first, ..rest] -> {
      // Insert first
      use _ <- result.try(sqlight.query(...))
      // Recurse
      insert_transactions_loop(conn, rest, count + 1)
    }
  }
}
```

## Nächste Schritte

1. **Directa SIM Parser:**
   - Implementieren in `src/financepal/importers/directa.gleam`
   - Header-Parsing (Account-Info)
   - Fee-Adjustment Logic
   - Validierung gegen Directa Portfolio

2. **Rebalancing-Logik:**
   - Portfolio-Wert berechnen (Positions * Current Prices)
   - Ist-Allocation vs. Target-Allocation
   - Delta berechnen
   - Rebalancing-Vorschlag generieren

3. **Asset Groups Management:**
   - CRUD Endpoints für Groups
   - Hierarchie-Support (parent_group_id)
   - Group-Members Management

4. **Target Allocations:**
   - Table erstellen (symbol/group, target_percentage)
   - CRUD Endpoints
   - Validierung (Summe = 100%)

5. **Frontend:**
   - Portfolio-Übersicht (Positions + Current Prices)
   - Transaction-Import UI
   - Target-Allocation Editor
   - Rebalancing-Vorschlag Anzeige

## Design-Prinzipien

- **Transaction-based Ledger:** Immutable Events
- **Opaque Types:** Domain-Validierung auf Type-Level
- **Repository Pattern:** Separation of Concerns
- **Actor-based Background Jobs:** OTP für Concurrency
- **Result-based Error Handling:** Keine Exceptions
- **Minimal Schema:** Focus auf Rebalancing, später erweiterbar
- **Gross Performance:** Taxes ignorieren (Standard-Approach)
- **Keine Python-Dependencies:** Pure Gleam/Erlang

## Bekannte Issues

1. **Asset Groups:** INTEGER statt UUID (inkonsistent mit anderen Tables)
2. **Timestamp Format:** `prices.fetched_at` ist REAL (Unix seconds), sollte konsistent sein
3. **Currency:** Noch keine Währungsumrechnung implementiert
4. **Fees:** In `price` eingerechnet, aber auch separat gespeichert (Redundanz)

## Code-Anfragen

Für Details zu spezifischen Modulen, frage nach dem Code:

- `domain/types.gleam` - Domain Types
- `domain/calc.gleam` - Position Calculation
- `persistence/*_repository.gleam` - Database Operations
- `rest/client/yahoo.gleam` - Yahoo Finance Client
- `rest/resource/csv_parser.gleam` - CSV Import
- `rest/resource/router.gleam` - HTTP Endpoints
- `actor/price_fetcher.gleam` - Background Price Fetching
