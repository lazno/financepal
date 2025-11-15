# FinancePal

A personal portfolio tracker built with Gleam backend and Svelte/Skeleton frontend. Imports transaction data from Directa SIM CSV files and provides interactive portfolio visualization.

## What it does

### Backend (Gleam)
- **Import transactions**: Upload Directa SIM CSV files containing buy/sell transactions
- **Track positions**: Calculates current holdings based on transaction history  
- **Price fetching**: Automatically fetches latest prices via Yahoo Finance API
- **Multi-currency support**: Handles transactions in different currencies
- **REST API**: Provides endpoints for portfolio data and imports

### Frontend (Svelte + Skeleton)
- **Interactive charts**: D3.js visualizations for portfolio allocation and drift analysis
- **Dark mode**: Full theme support with light/dark mode toggle
- **Responsive design**: Tailwind CSS with Skeleton design system
- **Real-time updates**: Hover interactions and dynamic data display

## Quick start

### Backend
```bash
cd ..  # Go to backend root
gleam deps download
gleam run
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

Backend runs on `http://localhost:8080`  
Frontend runs on `http://localhost:5173`

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

### GET /api/portfolio
Get portfolio performance metrics (when implemented)

## Frontend Features

### Portfolio Overview (Donut Chart)
- Interactive donut chart with Fireflies color palette
- Hover to highlight slices and show details
- Center text updates with value and percentage
- Transparent center for theme adaptation

### Portfolio Drift (Bullet Chart)
- Horizontal bars showing current vs target allocation
- Color-coded status: green (in band), blue (under), red (over)
- Band boundaries with orange markers
- Interactive tooltips with detailed metrics
- 100% reference line

### Theming
- **Light/Dark mode**: Toggle in top-right corner
- **Automatic adaptation**: All text and backgrounds adapt to theme
- **Customizable colors**: Central COLORS configuration in each component
- **Skeleton integration**: Uses Skeleton v4 design tokens

## Tech Stack

### Backend
- **Language**: Gleam
- **Web framework**: Wisp
- **Database**: SQLite
- **HTTP server**: Mist
- **Price data**: Yahoo Finance API
- **Actor system**: Gleam OTP for background price fetching

### Frontend
- **Framework**: Svelte 5
- **Design system**: Skeleton v4
- **Styling**: Tailwind CSS v4
- **Charts**: D3.js
- **Build tool**: Vite

## Customization

### Changing Chart Colors

Colors are centralized in each component's `COLORS` configuration object:

**PortfolioDriftChart.svelte** (lines 69-98):
```typescript
const COLORS = {
  barInBand: '#10b981',  // Green for in-band positions
  barUnder: '#3b82f6',   // Blue for under-target
  barOver: '#ef4444',    // Red for over-target
  bandLine: '#f59e0b',   // Orange for band boundaries
  // ... more colors
}
```

**PortfolioOverview.svelte** (lines 58-69):
```typescript
const SLICE_COLORS = [
  '#5a7a7c', '#5d9b8e', '#7db88a', // Fireflies palette
  // ... 12 colors total
]
```

### Theming System

The app uses Skeleton's `light-dark()` CSS function for automatic theme adaptation:

- **Surface colors**: `var(--color-surface-50-950)` adapts to theme
- **Text colors**: `var(--color-surface-900-100)` ensures readability
- **Semantic colors**: `var(--color-success-500)` maintains meaning in both themes

To customize theme behavior, modify the `COLORS` object in each component.

## Current Limitations

- Portfolio/performance endpoint is commented out (not implemented)
- Only supports Directa SIM CSV format
- Database gets cleared on each startup (development mode)
- Frontend uses mock data (not connected to backend API yet)

## CSV Format

Directa SIM export format with columns:
- date, symbol, isin, asset_name, type, quantity, account, order_reference

This is a development project - expect breaking changes and incomplete features.
