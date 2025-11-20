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
      const data = await fetchDashboardData();
      positions = data.sort((a, b) => b.value - a.value);
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

<div class="container mx-auto max-w-5xl pb-20 space-y-8">
  <!-- Header Section -->
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4 mb-10">
    <div>
      <h1 class="text-4xl font-bold mb-2 bg-clip-text text-transparent bg-gradient-to-br from-primary-500 to-primary-300 tracking-tighter">
        Portfolio Dashboard
      </h1>
      <p class="text-surface-600 dark:text-surface-400 font-light">
        Real-time overview of your investment portfolio
      </p>
    </div>
    <div class="glass-card px-6 py-3 rounded-xl flex items-center gap-4">
      <div class="text-left sm:text-right">
        <div class="text-xs text-surface-500 uppercase tracking-wider font-medium mb-1">Total Value</div>
        <div class="text-2xl font-bold text-primary-600 dark:text-primary-400">
          €{totalValue.toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </div>
      </div>
    </div>
  </div>

  {#if loading}
    <div
      class="glass-card flex items-center justify-center h-64 sm:h-80 lg:h-96 rounded-2xl"
    >
      <div class="text-center space-y-4">
        <Progress value={null} class="items-center w-fit">
          <Progress.Circle>
            <Progress.CircleTrack />
            <Progress.CircleRange />
          </Progress.Circle>
        </Progress>
        <p class="text-surface-600 dark:text-surface-400">Loading portfolio data...</p>
      </div>
    </div>
  {:else if error}
    <div class="glass-card p-8 rounded-2xl border-l-4 border-error-500">
      <div class="text-center space-y-4">
        <div
          class="w-16 h-16 mx-auto bg-error-500/10 rounded-full flex items-center justify-center"
        >
          <IconAlert class="w-8 h-8 text-error-500" />
        </div>
        <h3 class="text-xl font-bold text-error-600">Unable to Load Portfolio</h3>
        <p class="text-surface-600 dark:text-surface-400">{error}</p>
        <button
          class="btn variant-filled-error"
          onclick={() => window.location.reload()}
        >
          Try Again
        </button>
      </div>
    </div>
  {:else if positions.length === 0}
    <div class="glass-card p-8 rounded-2xl">
      <div class="text-center space-y-4">
        <div
          class="w-16 h-16 mx-auto bg-primary-500/10 rounded-full flex items-center justify-center"
        >
          <IconPieChart class="w-8 h-8 text-primary-500" />
        </div>
        <h3 class="text-xl font-bold text-surface-900 dark:text-surface-50">No Portfolio Data</h3>
        <p class="text-surface-600 dark:text-surface-400">
          Import your portfolio data to see the overview
        </p>
        <button class="btn variant-filled-primary">Import Data</button>
      </div>
    </div>
  {:else}
    <div class="glass-card p-6 sm:p-8 rounded-2xl">
      <div class="flex items-center justify-between mb-6">
        <h3 class="section-title text-xl font-bold pl-3">Portfolio Allocation</h3>
      </div>
      <div class="flex justify-center w-full">
        <PortfolioOverview {positions} />
      </div>
    </div>
  {/if}
</div>

<style lang="postcss">
    .glass-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.9) 0%, rgba(255, 255, 255, 0.8) 100%);
        border: 1px solid rgba(157, 78, 221, 0.15);
        box-shadow: 0 8px 32px rgba(157, 78, 221, 0.08);
    }
    :global([data-mode='dark']) .glass-card {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid rgba(212, 165, 255, 0.15);
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    }

    .section-title {
        color: var(--color-surface-900);
        position: relative;
    }
    :global([data-mode='dark']) .section-title {
        color: var(--color-surface-50);
    }
    .section-title::before {
        content: '';
        position: absolute;
        left: 0;
        top: 50%;
        transform: translateY(-50%);
        width: 4px;
        height: 24px;
        border-radius: 2px;
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-300) 100%);
    }

    /* Button Styles */
    .btn.variant-filled-primary {
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-400) 100%);
        color: white;
        border: none;
        transition: all 0.2s ease;
    }
    .btn.variant-filled-primary:hover {
        transform: translateY(-2px);
        box-shadow: 0 10px 15px -3px rgba(157, 78, 221, 0.3);
    }
</style>

