<script lang="ts">
  import { onMount } from 'svelte';
  import { Progress } from '@skeletonlabs/skeleton-svelte';
  import ResponsiveDriftChart from '../lib/ResponsiveDriftChart.svelte';
  import { fetchDriftData, type DriftPosition } from '../lib/api';
  import IconAlert from '~icons/lucide/alert-triangle';
  import IconTrending from '~icons/lucide/trending-up';
  
  let driftPositions = $state<DriftPosition[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  
  onMount(async () => {
    try {
      loading = true;
      driftPositions = await fetchDriftData();
      error = null;
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load drift data';
      console.error('Error loading drift analysis:', err);
    } finally {
      loading = false;
    }
  });
  
  // Calculate drift statistics
  let driftStats = $derived(() => {
    if (driftPositions.length === 0) return { inBand: 0, under: 0, over: 0 };
    
    let inBand = 0, under = 0, over = 0;
    driftPositions.forEach(pos => {
      const lower = pos.target * (1 - pos.bandLower);
      const upper = pos.target * (1 + pos.bandUpper);
      
      if (pos.current < lower) under++;
      else if (pos.current > upper) over++;
      else inBand++;
    });
    
    return { inBand, under, over };
  });
</script>

<div class="space-y-8">
  <!-- Header Section -->
  <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
    <div>
      <h2 class="h2">Drift Analysis</h2>
      <p class="text-sm text-surface-600">Monitor portfolio allocation drift against target allocations</p>
    </div>
    
    {#if driftPositions.length > 0}
      <div class="flex gap-4">
        <div class="text-center">
          <div class="text-2xl font-bold text-success-600">{driftStats().inBand}</div>
          <div class="text-xs text-surface-600">In Band</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-primary-600">{driftStats().under}</div>
          <div class="text-xs text-surface-600">Under</div>
        </div>
        <div class="text-center">
          <div class="text-2xl font-bold text-error-600">{driftStats().over}</div>
          <div class="text-xs text-surface-600">Over</div>
        </div>
      </div>
    {/if}
  </div>
  
  {#if loading}
    <div class="card preset-filled-surface-100-900 flex items-center justify-center h-96">
      <div class="text-center space-y-4">
        <Progress value={null} class="items-center w-fit">
          <Progress.Circle>
            <Progress.CircleTrack />
            <Progress.CircleRange />
          </Progress.Circle>
        </Progress>
        <p class="text-surface-600">Loading drift analysis...</p>
      </div>
    </div>
  {:else if error}
    <div class="card preset-filled-surface-100-900 p-8">
      <div class="text-center space-y-4">
        <div class="w-16 h-16 mx-auto bg-error-500/10 rounded-full flex items-center justify-center">
          <IconAlert class="w-8 h-8 text-error-500" />
        </div>
        <h3 class="h3 text-error-600">Analysis Unavailable</h3>
        <p class="text-surface-600">{error}</p>
        <button 
          class="btn variant-filled"
          onclick={() => window.location.reload()}
        >
          Retry
        </button>
      </div>
    </div>
  {:else if driftPositions.length === 0}
    <div class="card preset-filled-surface-100-900 p-8">
      <div class="text-center space-y-4">
        <div class="w-16 h-16 mx-auto bg-surface-400/10 rounded-full flex items-center justify-center">
          <IconTrending class="w-8 h-8 text-surface-400" />
        </div>
        <h3 class="h3">No Drift Data Available</h3>
        <p class="text-surface-600">
          Configure target allocations to see drift analysis
        </p>
        <button class="btn variant-filled">Configure Targets</button>
      </div>
    </div>
  {:else}
    <div class="card preset-filled-surface-100-900 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="h3">Portfolio Drift Visualization</h3>
        <div class="flex items-center gap-4 text-sm">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-success-500 rounded"></div>
            <span>In Band</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-primary-500 rounded"></div>
            <span>Under Target</span>
          </div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-error-500 rounded"></div>
            <span>Over Target</span>
          </div>
        </div>
      </div>
      
      <ResponsiveDriftChart 
        positions={driftPositions}
        aspectRatio={0.4}
      />
    </div>
  {/if}
</div>