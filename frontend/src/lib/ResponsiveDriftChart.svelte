<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import PortfolioDriftChart from './PortfolioDriftChart.svelte';
  import type { DriftPosition } from './api';
  
  interface Props {
    positions: DriftPosition[];
    aspectRatio?: number;
  }
  
  let { positions, aspectRatio = 0.5 }: Props = $props();
  
  let container: HTMLDivElement;
  let containerWidth = $state(0);
  let containerHeight = $state(0);
  
  function updateDimensions() {
    if (container) {
      containerWidth = container.clientWidth;
      containerHeight = Math.round(containerWidth * aspectRatio);
    }
  }
  
  onMount(() => {
    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  });
  
  $effect(() => {
    // Update when positions change or sidebar collapses
    updateDimensions();
  });
</script>

<div bind:this={container} class="w-full">
  {#if containerWidth > 0}
    <PortfolioDriftChart 
      {positions}
      width={containerWidth}
      height={containerHeight}
    />
  {/if}
</div>