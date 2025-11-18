<script lang="ts">
  /**
   * Portfolio Overview Donut Chart Component
   * 
   * Displays portfolio allocation as an interactive donut chart with
   * hover states and dynamic center text.
   * 
   * Features:
   * - D3.js donut chart with 12-color Fireflies palette
   * - Interactive hover: active slice at 100%, others dimmed to 25%
   * - Center text updates to show hovered slice value + percentage
   * - Smooth 300ms transitions
   * - Responsive SVG with viewBox
   */

  import { onMount } from 'svelte';
  import * as d3 from 'd3';

  // ============================================================================
  // TYPE DEFINITIONS
  // ============================================================================

  interface Position {
    label: string;
    value: number;
  }

  interface Props {
    positions?: Position[];
    width?: number;
    height?: number;
  }

  // ============================================================================
  // COMPONENT PROPS
  // ============================================================================

  let {
    positions = $bindable([]),
    width = 400,
    height = 400
  }: Props = $props();

  // ============================================================================
  // COMPONENT STATE
  // ============================================================================

  let chartContainer: HTMLDivElement;
  let centerValue: HTMLDivElement;
  let centerLabel: HTMLDivElement;
  let centerPercentage: HTMLDivElement;

  // ============================================================================
  // COLOR CONFIGURATION - Easy to find and change colors
  // ============================================================================
  // Fireflies color palette - 12 sequential colors (preserved as requested)
  // These are the original colors you want to keep
  const SLICE_COLORS = [
    '#5a7a7c', '#5d9b8e', '#7db88a', '#a0d17d', '#c8e66f', '#d4ea6a',
    '#b8d65c', '#9cc458', '#88b350', '#74a248', '#689142', '#5d803c'
  ];

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================

  function formatCurrency(value: number): string {
    return '€' + value.toLocaleString('de-DE');
  }

  function formatPercentage(value: number, total: number): string {
    return ((value / total) * 100).toFixed(1) + '%';
  }

  // Calculate total value for initial display
  let initialCenterValue = $state('€0');
  
  $effect(() => {
    if (positions.length > 0) {
      const total = d3.sum(positions, d => d.value);
      initialCenterValue = formatCurrency(total);
    } else {
      initialCenterValue = '€0';
    }
  });

  // ============================================================================
  // CHART RENDERING
  // ============================================================================

  function renderChart() {
    if (!chartContainer || positions.length === 0) return;

    // Clear existing chart
    d3.select(chartContainer).selectAll('*').remove();

    const totalValueCalc = d3.sum(positions, d => d.value);
    const defaultValue = formatCurrency(totalValueCalc);
    const defaultLabel = 'Total';

    // Create SVG
    const svg = d3.select(chartContainer)
      .append('svg')
      .attr('viewBox', `0 0 ${width} ${height}`)
      .attr('preserveAspectRatio', 'xMidYMid meet')
      .attr('width', '100%')
      .attr('height', '100%');

    const g = svg.append('g')
      .attr('transform', `translate(${width / 2}, ${height / 2})`);

    // Donut dimensions
    const radius = Math.min(width, height) / 2 - 20;
    const innerRadius = radius * 0.7; // Creates a larger donut hole for thinner slices

    // Create pie layout
    const pie = d3.pie<Position>()
      .value(d => d.value)
      .sort(null);

    // Create arc generator
    const arc = d3.arc<d3.PieArcDatum<Position>>()
      .innerRadius(innerRadius)
      .outerRadius(radius);

    // Create slices
    const slices = g.selectAll('.slice')
      .data(pie(positions))
      .enter()
      .append('g')
      .attr('class', 'slice');

    // Get stroke color from CSS custom property for theme adaptation
    const root = document.documentElement;
    const computedStyle = getComputedStyle(root);
    const strokeColorRgb = computedStyle.getPropertyValue('--color-surface-50').trim();
    const strokeColor = strokeColorRgb ? `rgb(${strokeColorRgb})` : '#ffffff';
    
    // Add path for each slice
    slices.append('path')
      .attr('d', arc as any)
      .attr('fill', (_d, i) => SLICE_COLORS[i % SLICE_COLORS.length])
      .attr('stroke', strokeColor)
      .attr('stroke-width', 2)
      .style('cursor', 'pointer')
      .style('opacity', 0.9)
      .style('transition', 'opacity 0.3s ease')
      .on('mouseenter', function(_event, d) {
        // Update center text
        if (centerValue && centerLabel && centerPercentage) {
          centerValue.textContent = formatCurrency(d.data.value);
          centerLabel.textContent = d.data.label;
          centerPercentage.textContent = formatPercentage(d.data.value, totalValueCalc);
          centerPercentage.style.display = 'block';
        }

        // Dim all slices to 40% first
        slices.selectAll('path').style('opacity', 0.4);
        
        // Then set hovered slice to 100%
        d3.select(this).style('opacity', 1.0);
      })
      .on('mouseleave', function() {
        // Reset center text
        if (centerValue && centerLabel && centerPercentage) {
          centerValue.textContent = defaultValue;
          centerLabel.textContent = defaultLabel;
          centerPercentage.style.display = 'none';
        }

        // Reset all slice opacity
        slices.selectAll('path').style('opacity', 0.9);
      });

    // Add transparent circle for donut hole (no background, just defines the hole)
    // The center text will show through the transparent background
    g.append('circle')
      .attr('r', innerRadius)
      .attr('fill', 'transparent');
  }

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  onMount(() => {
    renderChart();
  });

  // Re-render when positions change
  $effect(() => {
    if (positions) {
      renderChart();
    }
  });
</script>

<!-- ========================================================================== -->
<!-- TEMPLATE -->
<!-- ========================================================================== -->

<div class="chart-wrapper">
  <div bind:this={chartContainer} class="chart-container"></div>
  <div class="center-content">
    <div bind:this={centerValue} class="center-value">{initialCenterValue}</div>
    <div bind:this={centerLabel} class="center-label">Total</div>
    <div bind:this={centerPercentage} class="center-percentage" style="display: none;"></div>
  </div>
</div>

<!-- ========================================================================== -->
<!-- STYLES -->
<!-- ========================================================================== -->

<style>
  .chart-wrapper {
    position: relative;
    display: inline-block;
    width: 100%;
    max-width: 400px;
  }

  .chart-container {
    width: 100%;
    height: auto;
    aspect-ratio: 1;
  }

  .center-content {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    pointer-events: none;
    transition: all 0.3s ease;
  }

  .center-value {
    /* Uses Skeleton h3 typography scale */
    font-size: var(--text-3xl);
    font-weight: 700;
    /* Uses Skeleton surface color with light-dark() for theme adaptation */
    /* 900 in light mode, 100 in dark mode for proper contrast */
    color: var(--color-surface-900-100);
    margin-bottom: 0.2rem;
    transition: all 0.3s ease;
  }

  .center-label {
    /* Uses Skeleton small text size */
    font-size: var(--text-sm);
    /* Uses Skeleton surface color with light-dark() for theme adaptation */
    /* 500 in light mode, 400 in dark mode for proper contrast */
    color: var(--color-surface-500-400);
    font-weight: 500;
    transition: all 0.3s ease;
  }

  .center-percentage {
    /* Uses Skeleton base text size */
    font-size: var(--text-base);
    /* Uses Skeleton surface color with light-dark() for theme adaptation */
    /* 600 in light mode, 300 in dark mode for proper contrast */
    color: var(--color-surface-600-300);
    margin-top: 0.2rem;
    font-weight: 600;
  }
</style>
