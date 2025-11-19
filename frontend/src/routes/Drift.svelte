<script lang="ts">
  import { onMount } from "svelte";
  import { Progress } from "@skeletonlabs/skeleton-svelte";
  import ResponsiveDriftChart from "../lib/ResponsiveDriftChart.svelte";
  import { fetchDriftData, type DriftPosition } from "../lib/api";
  import IconAlert from "~icons/lucide/alert-triangle";
  import IconTrending from "~icons/lucide/trending-up";

  let driftPositions = $state<DriftPosition[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      loading = true;
      driftPositions = await fetchDriftData();
      error = null;
    } catch (err) {
      error = err instanceof Error ? err.message : "Failed to load drift data";
      console.error("Error loading drift analysis:", err);
    } finally {
      loading = false;
    }
  });

  // Calculate drift statistics
  let driftStats = $derived(() => {
    if (driftPositions.length === 0) return { inBand: 0, under: 0, over: 0 };

    let inBand = 0,
      under = 0,
      over = 0;
    driftPositions.forEach((pos) => {
      if (pos.current < pos.lowerBound) under++;
      else if (pos.current > pos.upperBound) over++;
      else inBand++;
    });

    return { inBand, under, over };
  });
</script>

<div class="space-y-4 sm:space-y-6 lg:space-y-8">
  <!-- Header Section -->
  <div
    class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4"
  >
    <div>
      <h2 class="text-xl sm:text-2xl lg:text-3xl font-bold">Drift Analysis</h2>
      <p class="text-xs sm:text-sm text-surface-600">
        Monitor portfolio allocation drift against target allocations
      </p>
    </div>

    {#if driftPositions.length > 0}
      <div class="flex gap-3 sm:gap-4">
        <div class="text-center">
          <div
            class="text-lg sm:text-xl lg:text-2xl font-bold text-success-600"
          >
            {driftStats().inBand}
          </div>
          <div class="text-[10px] sm:text-xs text-surface-600">In Band</div>
        </div>
        <div class="text-center">
          <div
            class="text-lg sm:text-xl lg:text-2xl font-bold text-primary-600"
          >
            {driftStats().under}
          </div>
          <div class="text-[10px] sm:text-xs text-surface-600">Under</div>
        </div>
        <div class="text-center">
          <div class="text-lg sm:text-xl lg:text-2xl font-bold text-error-600">
            {driftStats().over}
          </div>
          <div class="text-[10px] sm:text-xs text-surface-600">Over</div>
        </div>
      </div>
    {/if}
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
        <p class="text-sm sm:text-base text-surface-600">
          Loading drift analysis...
        </p>
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
        <h3 class="text-lg sm:text-xl font-bold text-error-600">
          Analysis Unavailable
        </h3>
        <p class="text-sm sm:text-base text-surface-600">{error}</p>
        <button
          class="btn variant-filled text-sm sm:text-base"
          onclick={() => window.location.reload()}
        >
          Retry
        </button>
      </div>
    </div>
  {:else if driftPositions.length === 0}
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6 lg:p-8">
      <div class="text-center space-y-4">
        <div
          class="w-12 h-12 sm:w-16 sm:h-16 mx-auto bg-surface-400/10 rounded-full flex items-center justify-center"
        >
          <IconTrending class="w-6 h-6 sm:w-8 sm:h-8 text-surface-400" />
        </div>
        <h3 class="text-lg sm:text-xl font-bold">No Drift Data Available</h3>
        <p class="text-sm sm:text-base text-surface-600">
          Configure target allocations to see drift analysis
        </p>
        <button class="btn variant-filled text-sm sm:text-base"
          >Configure Targets</button
        >
      </div>
    </div>
  {:else}
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6">
      <div
        class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4 mb-4 sm:mb-6"
      >
        <h3 class="text-lg sm:text-xl font-bold">
          Portfolio Drift Visualization
        </h3>
        <div
          class="flex flex-wrap items-center gap-2 sm:gap-3 lg:gap-4 text-xs sm:text-sm"
        >
          <div class="flex items-center gap-1.5 sm:gap-2">
            <div class="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-success-500 rounded"></div>
            <span>In Band</span>
          </div>
          <div class="flex items-center gap-1.5 sm:gap-2">
            <div class="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-primary-500 rounded"></div>
            <span>Under Target</span>
          </div>
          <div class="flex items-center gap-1.5 sm:gap-2">
            <div class="w-2.5 h-2.5 sm:w-3 sm:h-3 bg-error-500 rounded"></div>
            <span>Over Target</span>
          </div>
        </div>
      </div>

      <ResponsiveDriftChart positions={driftPositions} aspectRatio={0.4} />
    </div>
  {/if}
</div>

