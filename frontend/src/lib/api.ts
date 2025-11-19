// API client for fetching portfolio data

export interface Position {
  label: string;
  value: number;
}

export interface DriftPosition {
  asset: string;
  target: number;
  current: number;
  lowerBound: number;
  upperBound: number;
  status: 'in_band' | 'out_of_band';
}

interface PortfolioResponse {
  positions_by_currency: Record<string, CurrencyTotal>[];
}

interface CurrencyTotal {
  total_market_value: number;
  positions: PositionValue[];
}

interface PositionValue {
  symbol: string;
  quantity: number;
  price: number;
  market_value: number;
}

interface DriftAnalysisResponse {
  asset: string;
  target: number;
  current: number;
  bandLower: number;
  bandUpper: number;
  status: string;
}

export async function fetchDashboardData(): Promise<Position[]> {
  const response = await fetch('/api/portfolio');
  if (!response.ok) {
    throw new Error(`Failed to fetch portfolio data: ${response.statusText}`);
  }
  const data: PortfolioResponse = await response.json();
  
  const positions: Position[] = [];
  
  for (const currencyEntry of data.positions_by_currency) {
    for (const currency in currencyEntry) {
      const total = currencyEntry[currency];
      for (const pos of total.positions) {
        positions.push({
          label: pos.symbol,
          value: pos.market_value
        });
      }
    }
  }
  
  // Sort by value descending
  return positions.sort((a, b) => b.value - a.value);
}

export async function fetchDriftData(): Promise<DriftPosition[]> {
  const response = await fetch('/api/drift');
  if (!response.ok) {
    throw new Error(`Failed to fetch drift data: ${response.statusText}`);
  }
  const data: DriftAnalysisResponse[] = await response.json();
  
  return data.map(item => ({
    asset: item.asset,
    target: item.target,
    current: item.current,
    lowerBound: item.bandLower,
    upperBound: item.bandUpper,
    status: item.status as 'in_band' | 'out_of_band'
  }));
}
