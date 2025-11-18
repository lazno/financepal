<script lang="ts">
  /**
   * Portfolio Drift Bullet Chart Component
   * 
   * Visualizes portfolio positions with target allocations, current allocations,
   * and acceptable drift bands (configurable per position).
   * 
   * Features:
   * - Horizontal bars showing current allocation
   * - Target markers (vertical black lines)
   * - Band boundaries (orange dashed lines with dots)
   * - Color-coded status (green=in band, blue=under, red=over)
   * - Interactive tooltips on hover
   * - Per-position band configuration with asymmetric bands
   */

  import { onMount } from 'svelte';
  import * as d3 from 'd3';

  // ============================================================================
  // TYPE DEFINITIONS
  // ============================================================================

  interface Position {
    asset: string;
    target: number;
    current: number;
    bandLower: number;  // Lower band as percentage (e.g., 0.10 for -10%)
    bandUpper: number;  // Upper band as percentage (e.g., 0.15 for +15%)
  }

  interface Props {
    positions: Position[];       // Array of positions to visualize
    width?: number;              // Total SVG width in pixels (default: 1200)
    height?: number;             // Total SVG height in pixels (default: 600)
  }

  // ============================================================================
  // COMPONENT PROPS
  // ============================================================================

  let {
    positions = $bindable([]),
    width = 1200,
    height = 600
  }: Props = $props();

  // ============================================================================
  // COMPONENT STATE
  // ============================================================================

  let chartContainer: HTMLDivElement;  // Reference to the chart container
  let tooltip: HTMLDivElement;         // Reference to the tooltip element

  // ============================================================================
  // COLOR CONFIGURATION - Easy to find and change colors
  // ============================================================================
  // All chart colors are defined here for easy customization
  // You can use:
  // 1. Skeleton CSS custom properties: 'var(--color-success-500)'
  // 2. Tailwind colors: '#10b981'
  // 3. Any valid CSS color: 'rgb(59, 130, 246)' or 'blue'
  //
  // NOTE: Skeleton v4 only has these semantic colors:
  //   --color-primary, --color-secondary, --color-success, 
  //   --color-warning, --color-error
  // For other colors, use hex values or Tailwind colors

  const COLORS = {
    // Bar colors based on status
    // ORIGINAL COLORS RESTORED - customize these values as needed
    barInBand: '#10b981',           // Green - position within band (original)
    barUnder: '#3b82f6',            // Blue - position under target (original)
    barOver: '#ef4444',             // Red - position over target (original)
    
    // Band boundary markers
    bandLine: '#f59e0b',            // Orange - band boundary lines (original)
    bandDot: '#f59e0b',             // Orange - band boundary dots (original)
    bandText: '#f59e0b',            // Orange - band range labels (original)
    
    // Target markers
    targetLine: '#1f2937',          // Dark - target vertical line (original)
    targetText: '#6b7280',          // Gray - target labels (original)
    
    // Current value labels
    currentText: '#1f2937',         // Dark - current % labels (original)
    
    // Axis styling
    axisText: '#6b7280',            // Gray - axis labels (original)
    axisLine: '#d1d5db',            // Light gray - axis/grid lines (original)
    axisLabel: '#6b7280',           // Gray - axis title (original)
    
    // Tooltip styling - using Skeleton surface colors for theme integration
    tooltipBg: 'var(--color-surface-800)',      // Dark gray - tooltip background
    tooltipBorder: 'var(--color-surface-600)',  // Medium gray - tooltip border
    
    // Chart background - using Skeleton surface color for theme integration
    chartBg: 'var(--color-surface-50)'          // Very light gray - chart background
  };

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================

  /**
   * Determines if a position is within band, under, or over target
   * @param current - Current allocation percentage
   * @param target - Target allocation percentage
   * @param bandLower - Lower band percentage (e.g., 0.10 for -10%)
   * @param bandUpper - Upper band percentage (e.g., 0.15 for +15%)
   * @returns 'in' | 'under' | 'over'
   */
  function getStatus(current: number, target: number, bandLower: number, bandUpper: number) {
    const lower = target * (1 - bandLower);
    const upper = target * (1 + bandUpper);
    if (current < lower) return 'under';
    if (current > upper) return 'over';
    return 'in';
  }

  // ============================================================================
  // CHART RENDERING
  // ============================================================================

  function renderChart() {
    if (!chartContainer || !tooltip || positions.length === 0) return;

    // Clear any existing chart
    d3.select(chartContainer).selectAll('*').remove();

    // ------------------------------------------------------------------------
    // LAYOUT CONFIGURATION
    // Adjust these values to change spacing and positioning
    // ------------------------------------------------------------------------
    const margin = { 
      top: 60,      // Space above chart for band labels
      right: 40,    // Space to the right for current % labels
      bottom: 80,   // Space below chart for axis and target labels
      left: 120     // Space to the left for asset names
    };
    const chartWidth = width - margin.left - margin.right;
    const chartHeight = height - margin.top - margin.bottom;

    // ------------------------------------------------------------------------
    // SVG SETUP
    // ------------------------------------------------------------------------
    const svg = d3.select(chartContainer)
      .append('svg')
      .attr('width', width)
      .attr('height', height);

    const g = svg.append('g')
      .attr('transform', `translate(${margin.left},${margin.top})`);

    // ------------------------------------------------------------------------
    // BAR HEIGHT CALCULATION
    // Bars are scaled based on target allocation for visual hierarchy
    // ------------------------------------------------------------------------
    const maxTarget = d3.max(positions, d => d.target) || 100;
    const minBarHeight = 30;   // Minimum bar height in pixels
    const maxBarHeight = Math.min((chartHeight / positions.length) * 0.65, 100);

    const heightScale = d3.scaleLinear()
      .domain([0, maxTarget])
      .range([minBarHeight, maxBarHeight]);

    // ------------------------------------------------------------------------
    // SCALES
    // ------------------------------------------------------------------------
    
    // Y-axis: Position each asset
    const yScale = d3.scaleBand()
      .domain(positions.map(d => d.asset))
      .range([0, chartHeight])
      .padding(0.3);  // Space between bars (0-1, higher = more space)

    // X-axis: Percentage scale
    // Calculate max considering all positions' bands
    const maxPercent = d3.max(positions, d => {
      return Math.max(d.current, d.target * (1 + d.bandUpper));
    }) || 100;

    // Ensure domain goes to at least 100% to show the 100% tick mark
    const domainMax = Math.max(maxPercent * 1.15, 100);

    const xScale = d3.scaleLinear()
      .domain([0, domainMax])  // Add padding on the right, ensure 100% is included
      .range([0, chartWidth]);

    // ------------------------------------------------------------------------
    // GRID LINES
    // Vertical lines for easier reading of percentages
    // ------------------------------------------------------------------------
    g.append('g')
      .attr('class', 'grid')
      .selectAll('line')
      .data(xScale.ticks(10))
      .join('line')
      .attr('x1', d => xScale(d))
      .attr('x2', d => xScale(d))
      .attr('y1', 0)
      .attr('y2', chartHeight)
      .attr('stroke', COLORS.axisLine)
      .attr('stroke-width', 1);

    // Add explicit 100% grid line if not already included in ticks
    if (domainMax >= 100) {
      g.append('line')
        .attr('x1', xScale(100))
        .attr('x2', xScale(100))
        .attr('y1', 0)
        .attr('y2', chartHeight)
        .attr('stroke', COLORS.axisLine)
        .attr('stroke-width', 1)
        .attr('stroke-dasharray', '3,3');  // Dashed line for 100% mark
    }

    // ------------------------------------------------------------------------
    // DRAW POSITIONS
    // Each position gets its own group with bar, markers, and labels
    // ------------------------------------------------------------------------
    positions.forEach((pos) => {
      const barHeight = heightScale(pos.target);
      const yPos = (yScale(pos.asset) || 0) + (yScale.bandwidth() - barHeight) / 2;
      
      // Calculate band boundaries using position-specific bands
      const bandLower = pos.target * (1 - pos.bandLower);
      const bandUpper = pos.target * (1 + pos.bandUpper);
      
      // Get status for this position
      const status = getStatus(pos.current, pos.target, pos.bandLower, pos.bandUpper);

      // Create a group for this position
      const posGroup = g.append('g')
        .attr('class', 'position-group')
        .style('cursor', 'pointer');

      // ----------------------------------------------------------------------
      // CURRENT ALLOCATION BAR
      // Color-coded based on status (in band, under, over)
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      const barColor = status === 'in' ? COLORS.barInBand : 
                       status === 'under' ? COLORS.barUnder : COLORS.barOver;

      posGroup.append('rect')
        .attr('class', 'allocation-bar')
        .attr('x', 0)
        .attr('y', yPos)
        .attr('width', xScale(pos.current))
        .attr('height', barHeight)
        .style('fill', barColor)
        .attr('opacity', 0.85)
        .attr('rx', 0);  // Corner radius (0 = square corners)

      // ----------------------------------------------------------------------
      // BAND BOUNDARY LINES (Dashed lines showing acceptable range)
      // Drawn AFTER bars so they appear on top
      // ADJUST: stroke-width to change line thickness
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('line')
        .attr('x1', xScale(bandLower))
        .attr('x2', xScale(bandLower))
        .attr('y1', yPos)
        .attr('y2', yPos + barHeight)
        .style('stroke', COLORS.bandLine)
        .attr('stroke-width', 1.5)  // Line thickness
        .attr('stroke-dasharray', '5,3');  // Dash pattern: 5px dash, 3px gap

      posGroup.append('line')
        .attr('x1', xScale(bandUpper))
        .attr('x2', xScale(bandUpper))
        .attr('y1', yPos)
        .attr('y2', yPos + barHeight)
        .style('stroke', COLORS.bandLine)
        .attr('stroke-width', 1.5)
        .attr('stroke-dasharray', '5,3');

      // ----------------------------------------------------------------------
      // BAND BOUNDARY DOTS (Circles at top of band lines)
      // ADJUST: 'r' attribute to change dot size
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('circle')
        .attr('cx', xScale(bandLower))
        .attr('cy', yPos)
        .attr('r', 5)  // Dot radius in pixels
        .style('fill', COLORS.bandDot);

      posGroup.append('circle')
        .attr('cx', xScale(bandUpper))
        .attr('cy', yPos)
        .attr('r', 5)
        .style('fill', COLORS.bandDot);

      // ----------------------------------------------------------------------
      // BAND RANGE LABEL (Text above bar showing acceptable range)
      // Shows the acceptable range (e.g., "72.0%–88.0%")
      // ADJUST: font-size to change text size
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('text')
        .attr('x', (xScale(bandLower) + xScale(bandUpper)) / 2)
        .attr('y', yPos - 10)
        .attr('text-anchor', 'middle')
        .style('fill', COLORS.bandText)
        .attr('font-size', '13px')
        .attr('font-weight', '600')
        .text(`${bandLower.toFixed(1)}%–${bandUpper.toFixed(1)}%`);

      // ----------------------------------------------------------------------
      // CURRENT PERCENTAGE LABEL (Right of bar)
      // Shows the actual current allocation
      // ADJUST: font-size to change text size
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('text')
        .attr('x', xScale(pos.current) + 10)
        .attr('y', yPos + barHeight / 2)
        .attr('dominant-baseline', 'middle')
        .style('fill', COLORS.currentText)
        .attr('font-size', '14px')
        .attr('font-weight', '700')
        .text(`${pos.current.toFixed(pos.current < 10 ? 2 : 0)}%`);

      // ----------------------------------------------------------------------
      // TARGET MARKER (Vertical line showing target allocation)
      // ADJUST: stroke-width to change line thickness
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('line')
        .attr('x1', xScale(pos.target))
        .attr('x2', xScale(pos.target))
        .attr('y1', yPos - 8)
        .attr('y2', yPos + barHeight + 8)
        .style('stroke', COLORS.targetLine)
        .attr('stroke-width', 2);

      // ----------------------------------------------------------------------
      // TARGET LABEL (Below bar showing "T: 80%")
      // ADJUST: font-size to change text size
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup.append('text')
        .attr('x', xScale(pos.target))
        .attr('y', yPos + barHeight + 22)
        .attr('text-anchor', 'middle')
        .style('fill', COLORS.targetText)
        .attr('font-size', '12px')
        .attr('font-weight', '500')
        .text(`T: ${pos.target}%`);

      // ----------------------------------------------------------------------
      // HOVER INTERACTIONS
      // Show tooltip and highlight bar on hover
      // ----------------------------------------------------------------------
      posGroup
        .on('mouseenter', function(event) {
          // Increase bar opacity on hover
          d3.select(this).select('.allocation-bar')
            .attr('opacity', 1);

          // Calculate drift metrics
          const drift = pos.current - pos.target;
          const driftPercent = ((drift / pos.target) * 100).toFixed(1);
          const driftSign = drift > 0 ? '+' : '';

          // Build tooltip content with asymmetric band display
          tooltip.innerHTML = `
            <div style="font-weight: 600; margin-bottom: 8px; font-size: 15px; color: white;">${pos.asset}</div>
            <div style="display: grid; grid-template-columns: auto auto; gap: 6px 16px; font-size: 13px;">
              <span style="color: #9ca3af;">Target:</span>
              <span style="font-weight: 500; color: white;">${pos.target.toFixed(2)}%</span>
              
              <span style="color: #9ca3af;">Current:</span>
              <span style="font-weight: 500; color: white;">${pos.current.toFixed(2)}%</span>
              
              <span style="color: #9ca3af;">Drift:</span>
              <span style="font-weight: 600; color: ${drift > 0 ? '#ef4444' : drift < 0 ? '#3b82f6' : '#10b981'};">
                ${driftSign}${drift.toFixed(2)}% (${driftSign}${driftPercent}%)
              </span>
              
              <span style="color: #9ca3af;">Band:</span>
              <span style="font-weight: 500; color: white;">${bandLower.toFixed(2)}% - ${bandUpper.toFixed(2)}% (-${(pos.bandLower * 100).toFixed(0)}% / +${(pos.bandUpper * 100).toFixed(0)}%)</span>
              
              <span style="color: #9ca3af;">Status:</span>
              <span style="font-weight: 600; color: ${status === 'in' ? '#10b981' : status === 'under' ? '#3b82f6' : '#ef4444'};">
                ${status === 'in' ? '✓ In Band' : status === 'under' ? '↓ Under' : '↑ Over'}
              </span>
            </div>
          `;

          // Position and show tooltip with smart viewport-aware placement
          // Uses fixed positioning to prevent cutoff
          tooltip.style.display = 'block';
          
          // Get tooltip dimensions after making it visible
          const tooltipRect = tooltip.getBoundingClientRect();
          const viewportWidth = window.innerWidth;
          const viewportHeight = window.innerHeight;
          
          // Calculate initial position
          let left = event.clientX + 10;
          let top = event.clientY + 15;
          
          // Adjust horizontal position if tooltip would overflow right edge
          if (left + tooltipRect.width > viewportWidth - 10) {
            left = event.clientX - tooltipRect.width - 10;
          }
          
          // Adjust vertical position if tooltip would overflow bottom edge
          if (top + tooltipRect.height > viewportHeight - 10) {
            top = event.clientY - tooltipRect.height - 10;
          }
          
          tooltip.style.left = left + 'px';
          tooltip.style.top = top + 'px';
        })
        .on('mousemove', function(event) {
          // Update tooltip position as mouse moves with smart viewport-aware placement
          const tooltipRect = tooltip.getBoundingClientRect();
          const viewportWidth = window.innerWidth;
          const viewportHeight = window.innerHeight;
          
          // Calculate initial position
          let left = event.clientX + 10;
          let top = event.clientY + 15;
          
          // Adjust horizontal position if tooltip would overflow right edge
          if (left + tooltipRect.width > viewportWidth - 10) {
            left = event.clientX - tooltipRect.width - 10;
          }
          
          // Adjust vertical position if tooltip would overflow bottom edge
          if (top + tooltipRect.height > viewportHeight - 10) {
            top = event.clientY - tooltipRect.height - 10;
          }
          
          tooltip.style.left = left + 'px';
          tooltip.style.top = top + 'px';
        })
        .on('mouseleave', function() {
          // Reset bar opacity and hide tooltip
          d3.select(this).select('.allocation-bar')
            .attr('opacity', 0.85);

          tooltip.style.display = 'none';
        });
    });

    // ------------------------------------------------------------------------
    // Y AXIS (Asset labels on the left)
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    const yAxis = g.append('g')
      .attr('class', 'y-axis')
      .call(d3.axisLeft(yScale));

    yAxis.selectAll('text')
      .style('font-size', '14px')
      .style('font-weight', '500')
      .style('fill', COLORS.axisText);

    yAxis.selectAll('line').remove();  // Remove tick lines
    yAxis.select('.domain').remove();  // Remove axis line

    // ------------------------------------------------------------------------
    // X AXIS (Percentage scale at the bottom)
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    const xAxis = g.append('g')
      .attr('class', 'x-axis')
      .attr('transform', `translate(0,${chartHeight})`)
      .call(d3.axisBottom(xScale)
        .ticks(10)
        .tickFormat(d => `${d}%`));

    xAxis.selectAll('text')
      .style('font-size', '13px')
      .style('fill', COLORS.axisText);

    xAxis.selectAll('line')
      .style('stroke', COLORS.axisLine);

    xAxis.select('.domain')
      .style('stroke', COLORS.axisLine);

    // ------------------------------------------------------------------------
    // X AXIS LABEL
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    g.append('text')
      .attr('x', chartWidth / 2)
      .attr('y', chartHeight + 50)
      .attr('text-anchor', 'middle')
      .style('fill', COLORS.axisLabel)
      .attr('font-size', '14px')
      .attr('font-weight', '500')
      .text('Allocation (%)');
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
  <div bind:this={chartContainer} class="chart"></div>
  <div bind:this={tooltip} class="tooltip"></div>
</div>

<!-- ========================================================================== -->
<!-- STYLES -->
<!-- ========================================================================== -->

<style>
  /* Container for chart and tooltip */
  .chart-wrapper {
    position: relative;
    display: inline-block;
  }

  /* Chart background and styling - uses Skeleton surface color */
  /* Color defined in COLORS configuration object at top of file */
  .chart {
    background: var(--color-surface-50);
    border-radius: 8px;
    padding: 10px;
  }

  /* Tooltip styling - uses Skeleton surface colors */
  /* Colors defined in COLORS configuration object at top of file */
  .tooltip {
    position: fixed;  /* Fixed positioning prevents cutoff */
    display: none;
    background: var(--color-surface-800);  /* Dark surface background */
    border: 1px solid var(--color-surface-600);
    border-radius: 8px;
    padding: 14px;
    pointer-events: none;  /* Tooltip doesn't interfere with mouse events */
    z-index: 1000;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -2px rgba(0, 0, 0, 0.2);
    min-width: 220px;
  }

  /* Smooth transitions for hover effects */
  :global(.position-group) {
    transition: opacity 0.2s;
  }
</style>
