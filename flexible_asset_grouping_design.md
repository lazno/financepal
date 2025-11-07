# Flexible Asset Grouping & Tagging System

## Problem with Hierarchical Groups
- Assets can only belong to one group
- Rigid structure doesn't reflect real-world complexity
- Difficult to create overlapping categories
- Hard to implement flexible rules

## Solution: Tag-Based System with Rule Engine

### Core Concepts

#### 1. Tags
Flexible labels that can be applied to assets:
- **Asset-specific**: `AAPL`, `GOOGL`, `IE00B6R52259`
- **Category**: `tech`, `etf`, `bond`, `precious-metal`
- **Strategy**: `beta`, `core-satellite`, `dividend`, `growth`
- **Geography**: `us`, `europe`, `emerging`, `global`
- **Sector**: `technology`, `healthcare`, `finance`
- **Size**: `large-cap`, `mid-cap`, `small-cap`
- **Style**: `value`, `growth`, `blend`

#### 2. Tag Groups
Collections of related tags for organizational purposes:
- **Asset Classes**: `stocks`, `bonds`, `etfs`, `precious-metals`
- **Strategies**: `beta-portfolio`, `core-satellite`, `dividend-focus`
- **Regions**: `developed-markets`, `emerging-markets`
- **Sectors**: `tech-sector`, `healthcare-sector`

#### 3. Rules
Flexible constraints and allocations based on tag combinations:
- **Concentration limits**: "No single stock > 5% of portfolio"
- **Category limits**: "Tech allocation ≤ 25%"
- **Strategy rules**: "Core holdings ≥ 60% of portfolio"
- **Geographic limits**: "Emerging markets ≤ 15%"

### Database Schema

```sql
-- Asset tags (flexible tagging system)
CREATE TABLE asset_tags (
  id TEXT PRIMARY KEY,
  symbol TEXT NOT NULL,
  tag TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (symbol) REFERENCES transactions(symbol),
  UNIQUE(symbol, tag)
);

-- Tag groups for organization
CREATE TABLE tag_groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  color TEXT, -- for UI visualization
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tag group memberships
CREATE TABLE tag_group_members (
  id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  tag TEXT NOT NULL,
  FOREIGN KEY (group_id) REFERENCES tag_groups(id),
  UNIQUE(group_id, tag)
);

-- Rule definitions
CREATE TABLE allocation_rules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  rule_type TEXT NOT NULL, -- 'concentration', 'category', 'strategy'
  target_tags TEXT NOT NULL, -- JSON array of tags
  condition_tags TEXT, -- JSON array of condition tags (optional)
  max_percentage REAL,
  min_percentage REAL,
  priority INTEGER DEFAULT 100,
  enabled BOOLEAN DEFAULT TRUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Portfolio allocations (can target tags or individual assets)
CREATE TABLE portfolio_allocations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  target_type TEXT NOT NULL, -- 'tag', 'symbol', 'group'
  target_value TEXT NOT NULL, -- tag name, symbol, or group id
  target_percentage REAL NOT NULL,
  allocation_type TEXT NOT NULL, -- 'strategic', 'tactical', 'constraint'
  account_filter TEXT, -- optional account restriction
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### Example Tag Assignments

```gleam
// Apple stock tags
AAPL: ["stock", "us", "technology", "large-cap", "growth", "beta", "core-holding"]
// MSCI World ETF
IE00B6R52259: ["etf", "global", "equity", "core-satellite", "beta", "diversified"]
// Gold ETF
JE00B1VS3002: ["etf", "precious-metal", "gold", "commodity", "inflation-hedge"]
// Bond ETF
XS2364199757: ["bond", "europe", "government", "fixed-income", "romania"]
```

### Example Rules

```gleam
// Concentration limit: No single stock > 5%
{
  name: "Single Stock Limit",
  rule_type: "concentration",
  target_tags: ["stock"],
  max_percentage: 5.0,
  priority: 100
}

// Category limit: Tech ≤ 25%
{
  name: "Tech Allocation Cap",
  rule_type: "category",
  target_tags: ["technology"],
  max_percentage: 25.0,
  priority: 90
}

// Strategy rule: Core holdings ≥ 60%
{
  name: "Core Holdings Minimum",
  rule_type: "strategy",
  target_tags: ["core-holding", "beta"],
  min_percentage: 60.0,
  priority: 80
}

// Geographic limit: Emerging markets ≤ 15%
{
  name: "Emerging Markets Cap",
  rule_type: "geographic",
  target_tags: ["emerging"],
  max_percentage: 15.0,
  priority: 85
}
```

### Flexible Allocation Examples

#### 1. Beta Portfolio Allocation
```gleam
// Target: 70% beta, 30% satellite
// Beta includes: core ETFs, large-cap stocks
// Satellite includes: thematic ETFs, small-cap, individual picks

portfolio_allocations: [
  {
    name: "Beta Portfolio",
    target_type: "tag",
    target_value: "beta",
    target_percentage: 70.0,
    allocation_type: "strategic"
  },
  {
    name: "Satellite Portfolio", 
    target_type: "tag",
    target_value: "core-satellite",
    target_percentage: 30.0,
    allocation_type: "strategic"
  }
]
```

#### 2. Asset Class Allocation
```gleam
// Target: 60% stocks, 20% bonds, 10% precious metals, 10% cash

portfolio_allocations: [
  { target_tags: ["stock"], target_percentage: 60.0 },
  { target_tags: ["bond"], target_percentage: 20.0 },
  { target_tags: ["precious-metal"], target_percentage: 10.0 }
  // Cash not tracked yet
]
```

#### 3. Geographic Allocation
```gleam
// Target: 50% US, 30% Europe, 15% Emerging, 5% Other

portfolio_allocations: [
  { target_tags: ["us"], target_percentage: 50.0 },
  { target_tags: ["europe"], target_percentage: 30.0 },
  { target_tags: ["emerging"], target_percentage: 15.0 }
]
```

### Calculation Algorithm

```gleam
// Calculate allocation for a set of tags
fn calculate_tag_allocation(
  positions: List(Position),
  target_tags: List(String)
) -> Float {
  // 1. Find all positions that have ANY of the target tags
  // 2. Sum their market values
  // 3. Calculate percentage of total portfolio
}

// Check rules compliance
fn check_allocation_rules(
  positions: List(Position),
  rules: List(AllocationRule)
) -> List(RuleViolation) {
  // 1. For each rule, calculate current allocation
  // 2. Compare against min/max constraints
  // 3. Return violations with severity scores
}

// Generate rebalancing recommendations
fn generate_tag_based_recommendations(
  current_allocations: Dict(String, Float),
  target_allocations: List(PortfolioAllocation),
  rules: List(AllocationRule)
) -> List(Recommendation) {
  // 1. Calculate drift for each target allocation
  // 2. Apply rules constraints
  // 3. Generate buy/sell recommendations
  // 4. Prioritize by impact and rule importance
}
```

### UI Benefits

#### 1. Hierarchical Drill-Down
```
Portfolio Overview
├── Asset Classes (60% stocks, 20% bonds, 10% metals)
│   ├── Stocks
│   │   ├── US Stocks (35%)
│   │   ├── European Stocks (15%)
│   │   └── Emerging Markets (10%)
│   ├── Bonds
│   │   └── Government Bonds (20%)
│   └── Precious Metals
│       └── Gold ETFs (10%)
└── Strategies
    ├── Beta Portfolio (70%)
    └── Satellite Portfolio (30%)
```

#### 2. Flexible Views
- **By Asset Class**: See stocks vs bonds vs metals
- **By Geography**: US vs Europe vs Emerging
- **By Strategy**: Beta vs Satellite vs Thematic
- **By Sector**: Tech vs Healthcare vs Finance
- **Custom Groups**: User-defined tag combinations

#### 3. Rule Visualization
- Color-coded compliance status
- Interactive rule editor
- "What-if" scenario testing
- Conflict detection between rules

### Advanced Features

#### 1. Dynamic Tag Assignment
```gleam
// Auto-tag based on symbol characteristics
fn auto_tag_asset(symbol: String, description: String) -> List(String) {
  // Parse ISIN for country
  // Analyze description for sector/keywords
  // Apply heuristics for size/style
  // Return suggested tags
}
```

#### 2. Tag-Based Rules Engine
```gleam
// Complex rule conditions
{
  name: "Tech Stock Concentration",
  condition: "tag:technology AND tag:stock AND NOT tag:etf",
  max_percentage: 15.0,
  priority: 95
}
```

#### 3. Overlap Analysis
```gleam
// Detect overlapping allocations
fn analyze_tag_overlap(
  allocations: List(PortfolioAllocation)
) -> List(OverlapIssue) {
  // Identify assets counted in multiple targets
  // Calculate total allocation vs sum of targets
  // Suggest resolution strategies
}
```

### Migration Path from Current System

1. **Phase 1**: Add tagging support alongside existing transactions
2. **Phase 2**: Create default tag assignments for existing assets
3. **Phase 3**: Implement tag-based allocation targets
4. **Phase 4**: Add rule engine and compliance checking
5. **Phase 5**: Migrate from symbol-based to tag-based rebalancing

### Implementation Priority

1. **Core tagging system** (asset → tags mapping)
2. **Basic allocation targets** (tag → percentage)
3. **Simple rules engine** (concentration limits)
4. **UI for tag management** (add/edit/delete tags)
5. **Advanced rules** (complex conditions, priorities)
6. **Overlap detection and resolution**

This approach provides maximum flexibility while maintaining simplicity for basic use cases. Assets can belong to multiple categories, rules can target specific combinations, and the UI can present hierarchical views without forcing rigid structure.