<script lang="ts">
  import { onMount } from "svelte";
  import { Progress } from "@skeletonlabs/skeleton-svelte";
  import IconLoader from '~icons/lucide/loader-2';
  import IconAlert from '~icons/lucide/alert-triangle';
  import IconPieChart from '~icons/lucide/pie-chart';
  import PortfolioOverview from "../lib/PortfolioOverview.svelte";
  import { fetchDashboardData, type Position } from "../lib/api";

  let positions = $state<Position[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      loading = true;
      positions = await fetchDashboardData();
      error = null;
    } catch (err) {
      error =
        err instanceof Error ? err.message : "Failed to load portfolio data";
      console.error("Error loading dashboard:", err);
    } finally {
      loading = false;
    }
  });

  // Calculate total portfolio value
  let totalValue = $derived(positions.reduce((sum, pos) => sum + pos.value, 0));
</script>

<div class="space-y-8">
  <!-- Header Section -->
  <div
    class="flex flex-col md:flex-row md:items-center md:justify-between gap-4"
  >
    <div>
      <h2 class="h2">Portfolio Dashboard</h2>
      <p class="text-sm text-surface-600">
        Real-time overview of your investment portfolio
      </p>
    </div>
    <div class="flex items-center gap-4">
      <div class="text-right">
        <div class="text-sm text-surface-600">Total Value</div>
        <div class="text-2xl font-bold text-primary-600">
          €{totalValue.toLocaleString("de-DE")}
        </div>
      </div>
    </div>
  </div>

  {#if loading}
    <div
      class="card preset-filled-surface-100-900 flex items-center justify-center h-96"
    >
      <div class="text-center space-y-4">
        <Progress value={null} class="items-center w-fit">
          <Progress.Circle>
            <Progress.CircleTrack />
            <Progress.CircleRange />
          </Progress.Circle>
        </Progress>
        <p class="text-surface-600">Loading portfolio data...</p>
      </div>
    </div>
  {:else if error}
    <div class="card preset-filled-surface-100-900 p-8">
      <div class="text-center space-y-4">
        <div
          class="w-16 h-16 mx-auto bg-error-500/10 rounded-full flex items-center justify-center"
        >
          <IconAlert class="w-8 h-8 text-error-500" />
        </div>
        <h3 class="h3 text-error-600">Unable to Load Portfolio</h3>
        <p class="text-surface-600">{error}</p>
        <button
          class="btn variant-filled"
          onclick={() => window.location.reload()}
        >
          Try Again
        </button>
      </div>
    </div>
  {:else if positions.length === 0}
    <div class="card preset-filled-surface-100-900 p-8">
      <div class="text-center space-y-4">
        <div
          class="w-16 h-16 mx-auto bg-surface-400/10 rounded-full flex items-center justify-center"
        >
          <IconPieChart class="w-8 h-8 text-surface-400" />
        </div>
        <h3 class="h3">No Portfolio Data</h3>
        <p class="text-surface-600">
          Import your portfolio data to see the overview
        </p>
        <button class="btn variant-filled">Import Data</button>
      </div>
    </div>
  {:else}
    <div class="card preset-filled-surface-100-900 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="h3">Portfolio Allocation</h3>
      </div>
      <div class="flex justify-center">
        <PortfolioOverview {positions} width={500} height={500} />
      </div>
    </div>
  {/if}
</div>

