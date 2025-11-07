# Portfolio Rebalancing Design

## Overview
Transform FinancePal from a portfolio tracker into an intelligent rebalancing tool that helps maintain target asset allocations.

## Core Concepts

### 1. Target Allocations
User-defined percentage targets for different assets/asset classes:
- **By Symbol**: Individual stock/ETF targets (e.g., AAPL: 10%, GOOGL: 15%)
- **By Category**: Asset class targets (e.g., Tech: 25%, Bonds: 30%)
- **By Account**: Different targets per brokerage account

### 2. Rebalancing Triggers
Conditions that prompt rebalancing:
- **Threshold-based**: When allocation drifts > X% from target
- **Time-based**: Regular intervals (monthly, quarterly)
- **Manual**: User-initiated
- **Cash-based**: When new funds available

### 3. Rebalancing Recommendations
Suggested trades to bring portfolio back to target:
- **Buy recommendations**: Assets below target allocation
- **Sell recommendations**: Assets above target allocation
- **Priority scoring**: Based on drift magnitude, liquidity, fees

## Data Model Design

### Database Schema Extensions

```sql
-- Target allocations table
CREATE TABLE target_allocations (
  id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  target_percentage REAL NOT NULL,
  category TEXT,
  account TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (symbol) REFERENCES transactions(symbol)
);

-- Rebalancing history
CREATE TABLE rebalancing_history (
  id TEXT PRIMARY KEY,
  triggered_at DATETIME NOT NULL,
  trigger_type TEXT NOT NULL, -- 'threshold', 'time', 'manual'
  total_drift REAL NOT NULL,
  recommendations_count INTEGER NOT NULL,
  executed BOOLEAN DEFAULT FALSE,
  executed_at DATETIME,
  notes TEXT
);

-- Rebalancing recommendations
CREATE TABLE rebalancing_recommendations (
  id TEXT PRIMARY KEY,
  rebalancing_id TEXT NOT NULL,
  symbol TEXT NOT NULL,
  current_allocation REAL NOT NULL,
  target_allocation REAL NOT NULL,
  drift REAL NOT NULL,
  recommended_action TEXT NOT NULL, -- 'buy', 'sell'
  recommended_quantity INTEGER NOT NULL,
  estimated_amount REAL NOT NULL,
  priority INTEGER NOT NULL,
  executed BOOLEAN DEFAULT FALSE,
  executed_quantity INTEGER,
  executed_price REAL,
  FOREIGN KEY (rebalancing_id) REFERENCES rebalancing_history(id)
);

-- Rebalancing triggers configuration
CREATE TABLE rebalancing_triggers (
  id TEXT PRIMARY KEY,
  trigger_type TEXT NOT NULL,
  threshold_percentage REAL, -- for threshold-based triggers
  time_interval TEXT, -- for time-based triggers ('monthly', 'quarterly')
  enabled BOOLEAN DEFAULT TRUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## Algorithm Design

### 1. Current Allocation Calculation
```gleam
fn calculate_current_allocations(
  positions: List(Position),
  total_value: Float
) -> Dict(Symbol, Allocation) {
  // Calculate percentage of each position relative to total portfolio
  // Return map of symbol -> current_percentage
}
```

### 2. Target vs Current Comparison
```gleam
fn calculate_drift(
  current: Dict(Symbol, Float),
  targets: Dict(Symbol, Float)
) -> List(Drift) {
  // For each symbol with target:
  // - Calculate current percentage
  // - Calculate drift = current - target
  // - Return sorted list by absolute drift magnitude
}
```

### 3. Rebalancing Recommendations
```gleam
fn generate_recommendations(
  drifts: List(Drift),
  prices: Dict(Symbol, Price),
  constraints: RebalancingConstraints
) -> List(Recommendation) {
  // 1. Identify assets needing rebalancing (drift > threshold)
  // 2. Calculate recommended quantities
  // 3. Apply constraints (min trade size, fees, etc.)
  // 4. Prioritize by drift magnitude and liquidity
  // 5. Return actionable recommendations
}
```

### 4. Priority Scoring Algorithm
```gleam
fn calculate_priority(
  drift: Float,
  liquidity: Float,
  fees: Float,
  market_conditions: MarketData
) -> Int {
  // Score = (absolute_drift * 100) + liquidity_bonus - fees_penalty
  // Higher score = higher priority
}
```

## API Endpoints

### Target Allocation Management
```
GET    /api/allocations/targets          - Get all target allocations
POST   /api/allocations/targets          - Create new target allocation
PUT    /api/allocations/targets/:id      - Update target allocation
DELETE /api/allocations/targets/:id      - Delete target allocation
```

### Rebalancing Analysis
```
GET    /api/rebalancing/analysis         - Get current drift analysis
POST   /api/rebalancing/analyze          - Trigger rebalancing analysis
GET    /api/rebalancing/recommendations  - Get current recommendations
```

### Rebalancing Execution
```
POST   /api/rebalancing/execute          - Execute specific recommendations
GET    /api/rebalancing/history          - Get rebalancing history
GET    /api/rebalancing/history/:id      - Get specific rebalancing details
```

### Trigger Configuration
```
GET    /api/rebalancing/triggers         - Get trigger configurations
POST   /api/rebalancing/triggers         - Create trigger configuration
PUT    /api/rebalancing/triggers/:id     - Update trigger configuration
```

## Rebalancing Strategies

### 1. Threshold-Based Rebalancing
- **Trigger**: When any asset drifts > X% from target
- **Pros**: Responsive to market movements
- **Cons**: Can trigger frequently in volatile markets
- **Recommended**: 5-10% threshold

### 2. Calendar-Based Rebalancing
- **Trigger**: Regular intervals (monthly/quarterly)
- **Pros**: Predictable, lower transaction costs
- **Cons**: May miss optimal rebalancing opportunities
- **Recommended**: Monthly for active portfolios

### 3. Cash-Flow Based Rebalancing
- **Trigger**: When new funds available (deposits, dividends)
- **Pros**: No selling required, tax-efficient
- **Cons**: Limited to under-weight assets
- **Recommended**: Primary strategy for taxable accounts

### 4. Hybrid Approach
- **Primary**: Cash-flow based when possible
- **Secondary**: Threshold-based for major drifts
- **Tertiary**: Calendar-based for fine-tuning

## UI Components Needed

### 1. Allocation Overview
- Current vs target allocation pie charts
- Drift visualization (bar charts)
- Color-coded drift indicators (green/yellow/red)

### 2. Rebalancing Dashboard
- Current recommendations list
- Priority scoring display
- Estimated costs and tax implications
- One-click execution buttons

### 3. Target Allocation Editor
- Drag-and-drop allocation builder
- Real-time validation (sums to 100%)
- Category-based grouping
- Historical allocation tracking

### 4. Settings & Configuration
- Trigger threshold settings
- Rebalancing strategy selection
- Notification preferences
- Tax optimization options

## Real-Time Features

### WebSocket Updates
- Live portfolio value changes
- Real-time drift calculations
- Market movement alerts
- Recommendation updates

### Push Notifications
- Rebalancing opportunities
- Threshold breaches
- Market news affecting allocations
- Execution confirmations

## Implementation Phases

### Phase 1: Core Functionality
1. Target allocation CRUD operations
2. Basic drift calculation
3. Simple rebalancing recommendations
4. Manual execution

### Phase 2: Automation
1. Trigger configuration
2. Automated analysis
3. Recommendation notifications
4. Batch execution

### Phase 3: Advanced Features
1. Tax-loss harvesting integration
2. Multi-account rebalancing
3. Cash-flow optimization
4. Performance tracking

### Phase 4: Intelligence
1. Machine learning for optimal timing
2. Market condition adaptation
3. Personalized recommendations
4. Risk-based adjustments

## Technical Considerations

### Performance
- Cache frequent calculations
- Incremental drift updates
- Efficient database queries
- Background processing for analysis

### Accuracy
- Precise decimal arithmetic
- Currency conversion handling
- Fee inclusion in calculations
- Tax implication modeling

### Reliability
- Transaction rollback support
- Idempotent operations
- Error recovery mechanisms
- Data validation at multiple levels

## Next Steps

1. **Database Schema**: Create migration files for new tables
2. **Core Types**: Extend domain types for rebalancing concepts
3. **Calculation Engine**: Implement drift calculation algorithms
4. **API Endpoints**: Build REST endpoints for rebalancing operations
5. **Frontend Planning**: Design UI components and real-time features