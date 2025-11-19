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

export interface PositionValue {
  symbol: string;
  name: string;
  quantity: number;
  price: number;
  market_value: number;
  instrument_type: string;
}

export interface PortfolioResponse {
  positions_by_currency: Record<string, CurrencyTotal>[];
}

interface CurrencyTotal {
  total_market_value: number;
  positions: PositionValue[];
}

interface DriftAnalysisResponse {
  asset: string;
  target: number;
  current: number;
  bandLower: number;
  bandUpper: number;
  status: string;
}

export interface PolicySensitivity {
  rel_bps: number;
  floor_bps: number;
  cap_bps: number;
}

export interface Policy {
  id: string;
  targets: Record<string, number>; // key -> bps
  sensitivity: PolicySensitivity;
}

export async function fetchPolicy(): Promise<Policy | null> {
  const response = await fetch('/api/policy');
  if (response.status === 404) {
    return null;
  }
  if (!response.ok) {
    throw new Error(`Failed to fetch policy: ${response.statusText}`);
  }
  return await response.json();
}

export async function updatePolicy(policy: Policy): Promise<void> {
  const response = await fetch('/api/policy', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(policy)
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to update policy: ${errorText}`);
  }
}

export async function deletePolicy(): Promise<void> {
  const response = await fetch('/api/policy', {
    method: 'DELETE'
  });
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to delete policy: ${errorText}`);
  }
}

export async function fetchPortfolioRaw(): Promise<PortfolioResponse> {
  const response = await fetch('/api/portfolio');
  if (!response.ok) {
    throw new Error(`Failed to fetch portfolio data: ${response.statusText}`);
  }
  return await response.json();
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
          label: pos.name,
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
