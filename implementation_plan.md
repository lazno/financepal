# FinancePal Implementation Plan: From Tracker to Rebalancing Tool

## Executive Summary
Transform FinancePal from a basic portfolio tracker into an intelligent rebalancing tool with flexible asset grouping, tag-based allocations, and real-time UI. The solution will support multiple broker imports (starting with Directa-SIM), flexible tagging for asset classification, and sophisticated rebalancing algorithms.

## Architecture Overview

### Core Components
1. **Backend**: Gleam + Wisp + SQLite (proven foundation)
2. **Frontend**: Decision pending (Elixir/Phoenix vs Gleam Wisp+Lustre)
3. **Real-time**: WebSocket integration (built-in with Phoenix, custom with Wisp)
4. **Data Visualization**: D3.js for charts and portfolio visualization
5. **Asset Classification**: Flexible tagging system with rule engine

## Phase 1: Foundation (Weeks 1-3)
**Goal**: Establish core infrastructure and Directa-SIM support

### 1.1 Directa-SIM Integration
- [ ] Implement Directa-SIM CSV parser (`src/domain/directa_parser.gleam`)
- [ ] Add `/api/import/directa` endpoint
- [ ] Test with provided anonymized data
- [ ] Validate price calculations and fee aggregation
- [ ] Add broker detection to existing import endpoint

### 1.2 Database Schema Extensions
- [ ] Create migration for asset tags system
- [ ] Create migration for portfolio allocations
- [ ] Create migration for rebalancing rules
- [ ] Create migration for rebalancing history

### 1.3 Core Domain Extensions
- [ ] Extend types for tagging system
- [ ] Add rebalancing calculation functions
- [ ] Implement tag-based allocation algorithms
- [ ] Create rule validation engine

**Deliverables**: Working Directa-SIM import, extended database schema, core rebalancing types

## Phase 2: Asset Classification (Weeks 4-5)
**Goal**: Implement flexible tagging system

### 2.1 Tag Management API
- [ ] `GET /api/tags` - List all tags
- [ ] `POST /api/tags` - Create new tag
- [ ] `PUT /api/tags/:id` - Update tag
- [ ] `DELETE /api/tags/:id` - Delete tag

### 2.2 Asset Tagging
- [ ] `POST /api/assets/:symbol/tags` - Add tags to asset
- [ ] `DELETE /api/assets/:symbol/tags/:tag` - Remove tag from asset
- [ ] `GET /api/assets/:symbol/tags` - Get asset tags
- [ ] Auto-tagging based on symbol/ISIN analysis

### 2.3 Tag Groups
- [ ] Create tag group management endpoints
- [ ] Implement hierarchical tag organization
- [ ] Add tag group visualization

**Deliverables**: Full tagging system with API, auto-tagging capabilities

## Phase 3: Allocation Rules (Weeks 6-7)
**Goal**: Implement rule-based allocation system

### 3.1 Rule Engine
- [ ] Create rule definition and validation
- [ ] Implement rule priority system
- [ ] Add rule conflict detection
- [ ] Create rule execution engine

### 3.2 Allocation Targets
- [ ] Tag-based allocation targets
- [ ] Symbol-based allocation targets
- [ ] Multi-level allocation (groups within groups)
- [ ] Account-specific allocations

### 3.3 Rule Types Implementation
- [ ] Concentration limits (single asset caps)
- [ ] Category limits (sector/geography caps)
- [ ] Strategy rules (core/satellite ratios)
- [ ] Custom rule combinations

**Deliverables**: Working rule engine with various rule types

## Phase 4: Rebalancing Engine (Weeks 8-9)
**Goal**: Build core rebalancing algorithms

### 4.1 Drift Calculation
- [ ] Current vs target allocation analysis
- [ ] Multi-currency support
- [ ] Real-time drift updates
- [ ] Historical drift tracking

### 4.2 Recommendation Generation
- [ ] Buy/sell recommendation algorithm
- [ ] Priority scoring system
- [ ] Fee-aware recommendations
- [ ] Tax-loss harvesting integration

### 4.3 Rebalancing Triggers
- [ ] Threshold-based triggers
- [ ] Time-based triggers
- [ ] Manual triggers
- [ ] Cash-flow based triggers

**Deliverables**: Intelligent rebalancing recommendations with multiple trigger types

## Phase 5: Frontend Decision & Implementation (Weeks 10-12)
**Goal**: Choose and implement frontend stack

### 5.1 Frontend Stack Decision
**Option A: Elixir/Phoenix (Recommended)**
- ✅ Built-in WebSocket support (Channels)
- ✅ Mature ecosystem and libraries
- ✅ Better SSR experience
- ✅ Rich real-time capabilities
- ❌ Additional language/stack to maintain

**Option B: Gleam Wisp + Lustre**
- ✅ Single language throughout
- ✅ Type safety end-to-end
- ❌ Lustre SSR syntax concerns
- ❌ WebSocket implementation needed
- ❌ Less mature ecosystem

**Recommendation**: Start with Phoenix for faster development, consider migration later if needed.

### 5.2 Core UI Components
- [ ] Portfolio overview dashboard
- [ ] Asset allocation visualization (D3.js)
- [ ] Tag management interface
- [ ] Rule configuration UI
- [ ] Rebalancing recommendations display

### 5.3 Real-time Features
- [ ] Live portfolio value updates
- [ ] Real-time drift notifications
- [ ] WebSocket integration
- [ ] Push notification system

**Deliverables**: Functional frontend with real-time capabilities

## Phase 6: Advanced Features (Weeks 13-15)
**Goal**: Add sophisticated features and optimizations

### 6.1 Multi-Account Support
- [ ] Cross-account rebalancing
- [ ] Account-specific rules
- [ ] Tax-advantaged account handling
- [ ] Asset location optimization

### 6.2 Performance Analytics
- [ ] Rebalancing effectiveness tracking
- [ ] Cost analysis and optimization
- [ ] Tax impact calculations
- [ ] Performance attribution

### 6.3 Advanced Rules
- [ ] Time-based rule variations
- [ ] Market condition adaptations
- [ ] Volatility-adjusted allocations
- [ ] Correlation-based diversification

**Deliverables**: Advanced rebalancing capabilities with full analytics

## Phase 7: Testing & Optimization (Weeks 16-17)
**Goal**: Ensure reliability and performance

### 7.1 Testing
- [ ] Unit tests for all algorithms
- [ ] Integration tests for APIs
- [ ] End-to-end testing with real data
- [ ] Performance testing with large portfolios

### 7.2 Optimization
- [ ] Database query optimization
- [ ] Caching strategies
- [ ] Background job processing
- [ ] Memory usage optimization

### 7.3 Documentation
- [ ] API documentation
- [ ] User guides
- [ ] Admin documentation
- [ ] Deployment guides

**Deliverables**: Production-ready system with comprehensive testing

## Technical Architecture

### Backend Structure
```
src/
├── domain/
│   ├── types.gleam              # Core domain types
│   ├── calc.gleam               # Portfolio calculations
│   ├── csv_parser.gleam         # Generic CSV parsing
│   ├── directa_parser.gleam     # Directa-SIM specific
│   ├── tagging.gleam            # Tag management
│   ├── rebalancing.gleam        # Rebalancing algorithms
│   └── rules_engine.gleam       # Rule processing
├── persistence/
│   ├── database.gleam           # Database connection
│   ├── transaction_repository.gleam
│   ├── tag_repository.gleam
│   ├── allocation_repository.gleam
│   └── rebalancing_repository.gleam
└── rest/
    ├── resource/
    │   ├── router.gleam         # Main routing
    │   ├── import_resource.gleam
    │   ├── portfolio_resource.gleam
    │   ├── tagging_resource.gleam
    │   └── rebalancing_resource.gleam
    └── client/
        └── yahoo.gleam          # Price fetching
```

### Frontend Structure (Phoenix)
```
lib/financepal_web/
├── controllers/
│   ├── page_controller.ex       # Main pages
│   ├── portfolio_controller.ex  # Portfolio API
│   ├── tagging_controller.ex    # Tag management
│   └── rebalancing_controller.ex
├── channels/
│   ├── portfolio_channel.ex     # Real-time updates
│   └── rebalancing_channel.ex
├── templates/
│   ├── layout/
│   ├── page/
│   ├── portfolio/
│   └── rebalancing/
└── static/
    ├── js/
    │   ├── app.js
    │   ├── portfolio.js         # Portfolio visualization
    │   ├── rebalancing.js       # Rebalancing UI
    │   └── charts.js            # D3.js integration
    └── css/
```

## Key Design Decisions

### 1. Tag-Based Asset Classification
- **Pros**: Maximum flexibility, assets can have multiple tags
- **Cons**: More complex queries, requires careful tag management
- **Mitigation**: Auto-tagging, tag groups, validation rules

### 2. Rule-Based Allocation System
- **Pros**: Flexible constraints, easy to extend
- **Cons**: Potential rule conflicts, complexity
- **Mitigation**: Priority system, conflict detection, clear UI

### 3. Phoenix for Frontend
- **Pros**: Mature, great real-time support, rich ecosystem
- **Cons**: Additional language, more complex deployment
- **Mitigation**: Docker deployment, clear separation of concerns

## Risk Mitigation

### Technical Risks
1. **Performance with large portfolios**: Implement caching and optimization
2. **Rule complexity**: Start simple, add complexity gradually
3. **Multi-currency complexity**: Start with EUR focus, expand later

### Business Risks
1. **User adoption**: Build intuitive UI, provide good documentation
2. **Regulatory compliance**: Add disclaimers, avoid investment advice
3. **Data accuracy**: Implement validation, provide audit trails

## Success Metrics

### Technical Metrics
- API response time < 200ms for portfolio calculations
- Support for 1000+ assets per portfolio
- 99.9% uptime for core functionality
- < 1 second for rebalancing recommendations

### User Experience Metrics
- Time to first rebalancing recommendation < 5 seconds
- Import success rate > 95% for supported brokers
- User satisfaction score > 4.5/5
- Feature adoption rate > 60% for active users

## Next Steps

1. **Immediate**: Review and approve this implementation plan
2. **Week 1**: Begin Phase 1 (Directa-SIM integration)
3. **Week 4**: Start frontend stack evaluation and decision
4. **Ongoing**: Regular progress reviews and adjustments

This plan provides a clear path from the current portfolio tracker to a sophisticated rebalancing tool while maintaining flexibility for adjustments based on user feedback and technical discoveries.