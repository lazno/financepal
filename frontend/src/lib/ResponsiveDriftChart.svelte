<script lang="ts">
  import { onMount } from 'svelte';
  import PortfolioDriftChart from './PortfolioDriftChart.svelte';
  import type { DriftPosition } from './api';
  
  interface Props {
    positions: DriftPosition[];
    aspectRatio?: number;
  }
  
  let { positions, aspectRatio = 0.5 }: Props = $props();
  
  let container: HTMLDivElement;
  let containerWidth = $state(0);
  
  function updateDimensions() {
    if (container) {
      containerWidth = container.clientWidth;
    }
  }
  
  onMount(() => {
    // Use requestAnimationFrame to ensure DOM is ready
    requestAnimationFrame(() => {
      updateDimensions();
    });
    
    const handleResize = () => {
      requestAnimationFrame(() => {
        updateDimensions();
      });
    };
    
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  });
  
  $effect(() => {
    // Update when positions change or sidebar collapses
    requestAnimationFrame(() => {
      updateDimensions();
    });
  });
</script>

<div bind:this={container} class="w-full">
  {#if containerWidth > 0}
    <PortfolioDriftChart 
      {positions}
    />
  {/if}
</div>