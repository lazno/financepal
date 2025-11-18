// API client for fetching portfolio data

export interface Position {
  label: string;
  value: number;
}

export interface DriftPosition {
  asset: string;
  target: number;
  current: number;
  bandLower: number;
  bandUpper: number;
}

const mockPortfolioPositions: Position[] = [
  { label: 'VWCE ETF', value: 35000 },
  { label: 'Bitcoin', value: 20000 },
  { label: 'Apple', value: 15000 },
  { label: 'Microsoft', value: 12000 },
  { label: 'Google', value: 8000 },
  { label: 'Amazon', value: 6000 },
  { label: 'Ethereum', value: 3000 },
  { label: 'Apple', value: 15000 },
  { label: 'Apple', value: 15000 },
  { label: 'Apple', value: 15000 },
  { label: 'Microsoft', value: 12000 },
  { label: 'Google', value: 8000 },
  { label: 'Amazon', value: 6000 },
  { label: 'Ethereum', value: 3000 },
  { label: 'Microsoft', value: 12000 },
  { label: 'Google', value: 8000 },
  { label: 'Amazon', value: 6000 },
  { label: 'Ethereum', value: 3000 },
  { label: 'Microsoft', value: 12000 },
  { label: 'Google', value: 8000 },
  { label: 'Amazon', value: 6000 },
  { label: 'Ethereum', value: 3000 },
  { label: 'Cash', value: 1000 }
];

const mockDriftPositions: DriftPosition[] = [
  {
    asset: 'Main Position',
    target: 80,
    current: 81,
    bandLower: 0.05,
    bandUpper: 0.05
  },
  {
    asset: 'Secondary',
    target: 15,
    current: 17,
    bandLower: 0.10,
    bandUpper: 0.10
  },
  {
    asset: 'Small Holding',
    target: 4,
    current: 3.2,
    bandLower: 0.15,
    bandUpper: 0.15
  },
  {
    asset: 'Tiny Position',
    target: 1,
    current: 0.95,
    bandLower: 0.5,
    bandUpper: 0.5
  }
];

export async function fetchDashboardData(): Promise<Position[]> {
  // Simulate API call delay
  await new Promise(resolve => setTimeout(resolve, 5));
  return mockPortfolioPositions;
}

export async function fetchDriftData(): Promise<DriftPosition[]> {
  // Simulate API call delay
  await new Promise(resolve => setTimeout(resolve, 5));
  return mockDriftPositions;
}
