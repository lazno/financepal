<script lang="ts">
  import { onMount } from "svelte";
  import { Progress } from "@skeletonlabs/skeleton-svelte";
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

<div class="space-y-4 sm:space-y-6 lg:space-y-8">
  <!-- Header Section -->
  <div
    class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4"
  >
    <div>
      <h2 class="text-xl sm:text-2xl lg:text-3xl font-bold">Portfolio Dashboard</h2>
      <p class="text-xs sm:text-sm text-surface-600">
        Real-time overview of your investment portfolio
      </p>
    </div>
    <div class="flex items-center gap-4">
      <div class="text-left sm:text-right">
        <div class="text-xs sm:text-sm text-surface-600">Total Value</div>
        <div class="text-xl sm:text-2xl font-bold text-primary-600">
          €{totalValue.toLocaleString("de-DE")}
        </div>
      </div>
    </div>
  </div>

  {#if loading}
    <div
      class="card preset-filled-surface-100-900 flex items-center justify-center h-64 sm:h-80 lg:h-96"
    >
      <div class="text-center space-y-4">
        <Progress value={null} class="items-center w-fit">
          <Progress.Circle>
            <Progress.CircleTrack />
            <Progress.CircleRange />
          </Progress.Circle>
        </Progress>
        <p class="text-sm sm:text-base text-surface-600">Loading portfolio data...</p>
      </div>
    </div>
  {:else if error}
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6 lg:p-8">
      <div class="text-center space-y-4">
        <div
          class="w-12 h-12 sm:w-16 sm:h-16 mx-auto bg-error-500/10 rounded-full flex items-center justify-center"
        >
          <IconAlert class="w-6 h-6 sm:w-8 sm:h-8 text-error-500" />
        </div>
        <h3 class="text-lg sm:text-xl font-bold text-error-600">Unable to Load Portfolio</h3>
        <p class="text-sm sm:text-base text-surface-600">{error}</p>
        <button
          class="btn variant-filled text-sm sm:text-base"
          onclick={() => window.location.reload()}
        >
          Try Again
        </button>
      </div>
    </div>
  {:else if positions.length === 0}
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6 lg:p-8">
      <div class="text-center space-y-4">
        <div
          class="w-12 h-12 sm:w-16 sm:h-16 mx-auto bg-surface-400/10 rounded-full flex items-center justify-center"
        >
          <IconPieChart class="w-6 h-6 sm:w-8 sm:h-8 text-surface-400" />
        </div>
        <h3 class="text-lg sm:text-xl font-bold">No Portfolio Data</h3>
        <p class="text-sm sm:text-base text-surface-600">
          Import your portfolio data to see the overview
        </p>
        <button class="btn variant-filled text-sm sm:text-base">Import Data</button>
      </div>
    </div>
  {:else}
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6">
      <div class="flex items-center justify-between mb-4 sm:mb-6">
        <h3 class="text-lg sm:text-xl lg:text-2xl font-bold">Portfolio Allocation</h3>
      </div>
      <div class="flex justify-center w-full">
        <PortfolioOverview {positions} />
      </div>
    </div>
  {/if}
</div>

