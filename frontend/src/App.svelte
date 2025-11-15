<script lang="ts">
  import PortfolioDriftChart from './lib/PortfolioDriftChart.svelte';
  import PortfolioOverview from './lib/PortfolioOverview.svelte';

  // Mock portfolio data for donut chart
  const mockPortfolioPositions = [
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


  // Mock data with asymmetric bands for drift chart
  const mockDriftPositions = [
    { 
      asset: 'Main Position', 
      target: 80, 
      current: 81,
      bandLower: 0.05,  // -5%
      bandUpper: 0.05   // +10%
    },
    { 
      asset: 'Secondary', 
      target: 15, 
      current: 17,
      bandLower: 0.10,  // -10%
      bandUpper: 0.10   // +10%
    },
    { 
      asset: 'Small Holding', 
      target: 4, 
      current: 3.2,
      bandLower: 0.15,  // -15%
      bandUpper: 0.15   // +20%
    },
    { 
      asset: 'Tiny Position', 
      target: 1, 
      current: 0.95,
      bandLower: 0.5,  // -10%
      bandUpper: 0.5   // +10%
    }
  ];
</script>

<main>
  <h1>FinancePal - Portfolio Dashboard</h1>
  
  <div class="dashboard">
    

    <div class="chart-section">
      <h2>Portfolio Overview</h2>
      <PortfolioOverview 
        positions={mockPortfolioPositions}
        width={400}
        height={400}
      />
    </div>
    
    <div class="chart-section">
      <h2>Portfolio Drift</h2>
      <PortfolioDriftChart 
        positions={mockDriftPositions}
        width={900}
        height={500}
      />
    </div>
  </div>
</main>
