<script lang="ts">
  import { Navigation } from '@skeletonlabs/skeleton-svelte';
  import { AppBar } from '@skeletonlabs/skeleton-svelte';
  import PortfolioDriftChart from './lib/PortfolioDriftChart.svelte';
  import PortfolioOverview from './lib/PortfolioOverview.svelte';
  
  // Theme toggle function - switches between light and dark modes
  // Uses Tailwind's data-mode attribute strategy
  function toggleTheme() {
    const html = document.documentElement;
    const currentMode = html.getAttribute('data-mode');
    const newMode = currentMode === 'dark' ? 'light' : 'dark';
    html.setAttribute('data-mode', newMode);
    
    // Optional: Persist preference to localStorage
    localStorage.setItem('theme', newMode);
  }
  
  // Optional: Load saved theme preference on mount
  import { onMount } from 'svelte';
  onMount(() => {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
      document.documentElement.setAttribute('data-mode', savedTheme);
    }
  });

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

  const mockDriftPositions = [
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
</script>

<Navigation>
  <Navigation.Header>
    <AppBar>
      <AppBar.Lead>
        <h1 class="h1">FinancePal</h1>
      </AppBar.Lead>
      <AppBar.Trail>
        <button class="btn variant-filled" onclick={toggleTheme} aria-label="Toggle theme">
          <span class="dark:hidden">🌙</span>
          <span class="hidden dark:inline">☀️</span>
        </button>
      </AppBar.Trail>
    </AppBar>
  </Navigation.Header>
  
  <Navigation.Content>
    <div class="w-full max-w-7xl mx-auto p-4 space-y-8">
      <div class="h2 text-center">Portfolio Dashboard</div>
      
      <section class="card p-4">
        <h3 class="h3 mb-4">Portfolio Overview</h3>
        <PortfolioOverview 
          positions={mockPortfolioPositions}
          width={400}
          height={400}
        />
      </section>
      
      <section class="card p-4">
        <h3 class="h3 mb-4">Portfolio Drift</h3>
        <PortfolioDriftChart 
          positions={mockDriftPositions}
          width={900}
          height={500}
        />
      </section>
    </div>
  </Navigation.Content>
</Navigation>
