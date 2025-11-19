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

  import { onMount } from "svelte";
  import * as d3 from "d3";

  // ============================================================================
  // TYPE DEFINITIONS
  // ============================================================================

  interface Position {
    asset: string;
    target: number;
    current: number;
    lowerBound: number; // Absolute percentage
    upperBound: number; // Absolute percentage
  }

  interface Props {
    positions: Position[]; // Array of positions to visualize
  }

  // ============================================================================
  // COMPONENT PROPS
  // ============================================================================

  let { positions = $bindable([]) }: Props = $props();

  // ============================================================================
  // COMPONENT STATE
  // ============================================================================

  let chartContainer: HTMLDivElement; // Reference to the chart container
  let tooltip: HTMLDivElement; // Reference to the tooltip element
  let containerWidth = $state(0);
  let containerHeight = $state(0);

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

  // Reference elements to extract actual theme colors
  let colorRefSuccess: HTMLDivElement;
  let colorRefPrimary: HTMLDivElement;
  let colorRefError: HTMLDivElement;
  let colorRefWarning: HTMLDivElement;

  // Helper to get actual computed color from a reference element
  function getComputedColor(
    element: HTMLElement | undefined,
    property: "backgroundColor" | "color" = "backgroundColor",
  ): string {
    if (!element) return "#000000";
    const computed = getComputedStyle(element)[property];
    return computed || "#000000";
  }

  // Helper to get theme-aware color based on data-mode
  function getThemeAwareColor(lightColor: string, darkColor: string): string {
    const isDark =
      document.documentElement.getAttribute("data-mode") === "dark";
    return isDark ? darkColor : lightColor;
  }

  // ============================================================================
  // HELPER FUNCTIONS
  // ============================================================================

  /**
   * Determines if a position is within band, under, or over target
   * @param current - Current allocation percentage
   * @param target - Target allocation percentage
   * @param lowerBound - Lower band percentage
   * @param upperBound - Upper band percentage
   * @returns 'in' | 'under' | 'over'
   */
  function getStatus(current: number, lowerBound: number, upperBound: number) {
    if (current < lowerBound) return "under";
    if (current > upperBound) return "over";
    return "in";
  }

  // ============================================================================
  // CHART RENDERING
  // ============================================================================

  function updateDimensions() {
    if (chartContainer) {
      // Get the actual width of the parent container
      const rect = chartContainer.getBoundingClientRect();
      containerWidth =
        rect.width || chartContainer.clientWidth || chartContainer.offsetWidth;

      // If still 0, try the parent element
      if (containerWidth === 0 && chartContainer.parentElement) {
        containerWidth = chartContainer.parentElement.clientWidth;
      }

      // Responsive height: taller on mobile, shorter on desktop
      const baseHeight =
        window.innerWidth < 640 ? 800 : window.innerWidth < 1024 ? 600 : 500;
      containerHeight = Math.max(
        400,
        Math.min(baseHeight, positions.length * 80),
      );
    }
  }

  function renderChart() {
    if (
      !chartContainer ||
      !tooltip ||
      positions.length === 0 ||
      containerWidth === 0
    )
      return;

    // Clear any existing chart
    d3.select(chartContainer).selectAll("*").remove();

    // Get theme colors from actual computed styles
    const COLORS = {
      barInBand: getComputedColor(colorRefSuccess),
      barUnder: getComputedColor(colorRefPrimary),
      barOver: getComputedColor(colorRefError),
      bandLine: getComputedColor(colorRefWarning),
      bandDot: getComputedColor(colorRefWarning),
      bandText: getComputedColor(colorRefWarning),
      targetLine: getThemeAwareColor("#111827", "#f3f4f6"), // gray-900 / gray-100
      targetText: getThemeAwareColor("#4b5563", "#9ca3af"), // gray-600 / gray-400
      currentText: getThemeAwareColor("#111827", "#f3f4f6"), // gray-900 / gray-100
      axisText: getThemeAwareColor("#4b5563", "#9ca3af"), // gray-600 / gray-400
      axisLine: getThemeAwareColor("#d1d5db", "#4b5563"), // gray-300 / gray-600
      axisLabel: getThemeAwareColor("#4b5563", "#9ca3af"), // gray-600 / gray-400
      tooltipBg: "#1f2937",
      tooltipBorder: "#4b5563",
      chartBg: "#f9fafb",
    };

    // ------------------------------------------------------------------------
    // INTERACTION HELPERS
    // ------------------------------------------------------------------------

    function updateTooltipPosition(event: any) {
      const tooltipRect = tooltip.getBoundingClientRect();
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;

      // Calculate initial position (offset from cursor/touch)
      let left = event.clientX + 10;
      let top = event.clientY + 15;

      // 1. Horizontal Positioning Strategy
      // Try placing to the right. If it overflows, flip to the left.
      if (left + tooltipRect.width > viewportWidth - 10) {
        left = event.clientX - tooltipRect.width - 10;
      }

      // 2. Vertical Positioning Strategy
      // Try placing below. If it overflows, flip to above.
      if (top + tooltipRect.height > viewportHeight - 10) {
        top = event.clientY - tooltipRect.height - 10;
      }

      // 3. Hard Clamping (The "Safety Net")
      // Ensure the tooltip NEVER goes off-screen, regardless of the above logic.
      // This handles cases where the tooltip is wider than the available space on either side.

      // Clamp Left: Ensure it's at least 10px from the left edge
      left = Math.max(10, left);

      // Clamp Right: Ensure it's at least 10px from the right edge
      // (We prioritize the left clamp if the screen is extremely narrow)
      if (left + tooltipRect.width > viewportWidth - 10) {
        left = Math.max(10, viewportWidth - tooltipRect.width - 10);
      }

      // Clamp Top: Ensure it's at least 10px from the top edge
      top = Math.max(10, top);

      // Clamp Bottom: Ensure it's at least 10px from the bottom edge
      if (top + tooltipRect.height > viewportHeight - 10) {
        top = Math.max(10, viewportHeight - tooltipRect.height - 10);
      }

      tooltip.style.left = left + "px";
      tooltip.style.top = top + "px";
    }

    function showTooltip(event: any, pos: Position, element: any) {
      // Increase bar opacity
      d3.select(element).select(".allocation-bar").attr("opacity", 1);

      // Calculate drift metrics
      const drift = pos.current - pos.target;
      const driftPercent = ((drift / pos.target) * 100).toFixed(1);
      const driftSign = drift > 0 ? "+" : "";

      // Calculate band boundaries for display
      const bandLowerVal = pos.lowerBound;
      const bandUpperVal = pos.upperBound;

      // Get status
      const status = getStatus(pos.current, pos.lowerBound, pos.upperBound);

      // Build tooltip content
      const labelColor = "#9ca3af";
      const textColor = "#f3f4f6";

      tooltip.innerHTML = `
        <div style="font-weight: 600; margin-bottom: 8px; font-size: 15px; color: ${textColor};">${pos.asset}</div>
        <div style="display: grid; grid-template-columns: auto auto; gap: 6px 16px; font-size: 13px;">
          <span style="color: ${labelColor};">Target:</span>
          <span style="font-weight: 500; color: ${textColor};">${pos.target.toFixed(2)}%</span>
          
          <span style="color: ${labelColor};">Current:</span>
          <span style="font-weight: 500; color: ${textColor};">${pos.current.toFixed(2)}%</span>
          
          <span style="color: ${labelColor};">Drift:</span>
          <span style="font-weight: 600; color: ${drift > 0 ? COLORS.barOver : drift < 0 ? COLORS.barUnder : COLORS.barInBand};">
            ${driftSign}${drift.toFixed(2)}% (${driftSign}${driftPercent}%)
          </span>
          
          <span style="color: ${labelColor};">Band:</span>
          <span style="font-weight: 500; color: ${COLORS.bandLine};">${bandLowerVal.toFixed(2)}% - ${bandUpperVal.toFixed(2)}%</span>
          
          <span style="color: ${labelColor};">Status:</span>
          <span style="font-weight: 600; color: ${status === "in" ? COLORS.barInBand : status === "under" ? COLORS.barUnder : COLORS.barOver};">
            ${status === "in" ? "✓ In Band" : status === "under" ? "↓ Under" : "↑ Over"}
          </span>
        </div>
      `;

      tooltip.style.display = "block";
      updateTooltipPosition(event);
    }

    function hideTooltip(element: any) {
      if (element) {
        d3.select(element).select(".allocation-bar").attr("opacity", 0.85);
      } else {
        // Reset all bars if no specific element provided (for background click)
        d3.selectAll(".allocation-bar").attr("opacity", 0.85);
      }
      tooltip.style.display = "none";
    }

    // ------------------------------------------------------------------------
    // LAYOUT CONFIGURATION - Responsive margins
    // Adjust these values to change spacing and positioning
    // ------------------------------------------------------------------------
    const isMobile = containerWidth < 640;
    const isTablet = containerWidth >= 640 && containerWidth < 1024;

    const margin = {
      top: isMobile ? 40 : 60,
      right: isMobile ? 60 : 80,
      bottom: isMobile ? 60 : 80,
      left: isMobile ? 80 : isTablet ? 100 : 120,
    };
    const chartWidth = containerWidth - margin.left - margin.right;
    const chartHeight = containerHeight - margin.top - margin.bottom;

    // ------------------------------------------------------------------------
    // SVG SETUP
    // ------------------------------------------------------------------------
    const svg = d3
      .select(chartContainer)
      .append("svg")
      .attr("width", containerWidth)
      .attr("height", containerHeight)
      .attr("viewBox", `0 0 ${containerWidth} ${containerHeight}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .on("click", () => {
        hideTooltip(null);
      });

    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    // ------------------------------------------------------------------------
    // BAR HEIGHT CALCULATION
    // Bars are scaled based on current allocation for visual hierarchy
    //
    // ADJUST THESE VALUES TO CONTROL BAR HEIGHT EXAGGERATION:
    // - minBarHeight: Smaller values = more dramatic difference (try 8-20)
    // - maxBarHeight multiplier: Larger values = taller max bars (try 0.8-1.0)
    //
    // Examples:
    //   minBarHeight=15, multiplier=0.8  -> moderate exaggeration
    //   minBarHeight=8,  multiplier=0.9  -> strong exaggeration
    //   minBarHeight=20, multiplier=0.65 -> subtle exaggeration (original)
    // ------------------------------------------------------------------------
    const maxCurrent = d3.max(positions, (d) => d.current) || 100;
    const minBarHeight = 12; // Minimum bar height in pixels (smaller = more dramatic)
    const maxBarHeight = Math.min((chartHeight / positions.length) * 0.85, 120); // Max bar height

    const heightScale = d3
      .scaleLinear()
      .domain([0, maxCurrent])
      .range([minBarHeight, maxBarHeight]);

    // ------------------------------------------------------------------------
    // SCALES
    // ------------------------------------------------------------------------

    // Sort positions by current allocation (descending) for visual hierarchy
    const sortedPositions = [...positions].sort(
      (a, b) => b.current - a.current,
    );

    // Y-axis: Position each asset
    const yScale = d3
      .scaleBand()
      .domain(sortedPositions.map((d) => d.asset))
      .range([0, chartHeight])
      .padding(0.3); // Space between bars (0-1, higher = more space)

    // X-axis: Percentage scale
    // Calculate max considering all positions' bands
    const maxPercent =
      d3.max(positions, (d) => {
        return Math.max(d.current, d.target * 1.2); // Add some buffer
      }) || 100;

    // Ensure domain goes to at least 10% to avoid extreme zoom on tiny portfolios
    const domainMax = Math.max(maxPercent * 1.15, 10);

    const xScale = d3
      .scaleLinear()
      .domain([0, domainMax]) // Add padding on the right
      .range([0, chartWidth]);

    // ------------------------------------------------------------------------
    // GRID LINES
    // Vertical lines for easier reading of percentages
    // ------------------------------------------------------------------------
    g.append("g")
      .attr("class", "grid")
      .selectAll("line")
      .data(xScale.ticks(10))
      .join("line")
      .attr("x1", (d) => xScale(d))
      .attr("x2", (d) => xScale(d))
      .attr("y1", 0)
      .attr("y2", chartHeight)
      .attr("stroke", COLORS.axisLine)
      .attr("stroke-width", 1);

    // Add explicit 100% grid line if not already included in ticks
    if (domainMax >= 100) {
      g.append("line")
        .attr("x1", xScale(100))
        .attr("x2", xScale(100))
        .attr("y1", 0)
        .attr("y2", chartHeight)
        .attr("stroke", COLORS.axisLine)
        .attr("stroke-width", 1)
        .attr("stroke-dasharray", "3,3"); // Dashed line for 100% mark
    }

    // ------------------------------------------------------------------------
    // DRAW POSITIONS
    // Each position gets its own group with bar, markers, and labels
    // (Already sorted by current allocation in the yScale definition above)
    // ------------------------------------------------------------------------
    sortedPositions.forEach((pos) => {
      const barHeight = heightScale(pos.current);
      const yPos =
        (yScale(pos.asset) || 0) + (yScale.bandwidth() - barHeight) / 2;

      // Calculate band boundaries using position-specific bands
      const bandLower = pos.lowerBound;
      const bandUpper = pos.upperBound;

      // Get status for this position
      const status = getStatus(pos.current, pos.lowerBound, pos.upperBound);

      // Create a group for this position
      const posGroup = g
        .append("g")
        .attr("class", "position-group")
        .style("cursor", "pointer");

      // ----------------------------------------------------------------------
      // CURRENT ALLOCATION BAR
      // Color-coded based on status (in band, under, over)
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      const barColor =
        status === "in"
          ? COLORS.barInBand
          : status === "under"
            ? COLORS.barUnder
            : COLORS.barOver;

      posGroup
        .append("rect")
        .attr("class", "allocation-bar")
        .attr("x", 0)
        .attr("y", yPos)
        .attr("width", xScale(pos.current))
        .attr("height", barHeight)
        .style("fill", barColor)
        .attr("opacity", 0.85)
        .attr("rx", 0); // Corner radius (0 = square corners)

      // ----------------------------------------------------------------------
      // BAND BOUNDARY LINES (Dashed lines showing acceptable range)
      // Drawn AFTER bars so they appear on top
      // ADJUST: stroke-width to change line thickness
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      const strokeWidth = 1.5;

      posGroup
        .append("line")
        .attr("x1", xScale(bandLower))
        .attr("x2", xScale(bandLower))
        .attr("y1", yPos)
        .attr("y2", yPos + barHeight + 3)
        .style("stroke", COLORS.bandLine)
        .attr("stroke-width", strokeWidth) // Line thickness
        .attr("stroke-dasharray", "5,3"); // Dash pattern: 5px dash, 3px gap

      posGroup
        .append("line")
        .attr("x1", xScale(bandUpper))
        .attr("x2", xScale(bandUpper))
        .attr("y1", yPos)
        .attr("y2", yPos + barHeight + 3)
        .style("stroke", COLORS.bandLine)
        .attr("stroke-width", strokeWidth)
        .attr("stroke-dasharray", "5,3");

      // ----------------------------------------------------------------------
      // BAND BOUNDARY MARKERS (Triangles)
      // Replaced dots with "half-triangles" pointing inwards/downwards
      // Lower band: Triangle pointing left
      // Upper band: Triangle pointing right
      // ----------------------------------------------------------------------

      // Lower Band Triangle (Points Left)
      // Path: Start at (x, y-5), go down-left, go up, close
      // Offset by strokeWidth/2 to align with the outer edge of the line
      const triangleWidth = 5;
      const triangleHeight = 7;
      const lowerX = xScale(bandLower) + strokeWidth / 2;
      posGroup
        .append("path")
        .attr(
          "d",
          `M ${lowerX} ${yPos - 5} L ${lowerX - triangleWidth} ${yPos - 5} L ${lowerX} ${yPos - 5 + triangleHeight} Z`,
        )
        .style("fill", COLORS.bandDot);

      // Upper Band Triangle (Points Right)
      // Path: Start at (x, y-5), go down-right, go up, close
      // Offset by strokeWidth/2 to align with the outer edge of the line
      const upperX = xScale(bandUpper) - strokeWidth / 2;
      posGroup
        .append("path")
        .attr(
          "d",
          `M ${upperX} ${yPos - 5} L ${upperX + triangleWidth} ${yPos - 5} L ${upperX} ${yPos - 5 + triangleHeight} Z`,
        )
        .style("fill", COLORS.bandDot);

      // ----------------------------------------------------------------------
      // CURRENT PERCENTAGE LABEL (Right of bar)
      // Shows the actual current allocation
      // ADJUST: font-size to change text size
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      // posGroup
      //   .append("text")
      //   .attr("x", xScale(pos.current) + (isMobile ? 6 : 10))
      //   .attr("y", yPos + barHeight / 2)
      //   .attr("dominant-baseline", "middle")
      //   .style("fill", COLORS.currentText)
      //   .attr("font-size", isMobile ? "11px" : "14px")
      //   .attr("font-weight", "700")
      //   .text(`${pos.current.toFixed(pos.current < 10 ? 2 : 0)}%`);

      // ----------------------------------------------------------------------
      // TARGET MARKER (Vertical line showing target allocation)
      // ADJUST: stroke-width to change line thickness
      // Colors defined in COLORS configuration object at top of file
      // Use .style() not .attr() for CSS custom properties to work
      // ----------------------------------------------------------------------
      posGroup
        .append("line")
        .attr("x1", xScale(pos.target))
        .attr("x2", xScale(pos.target))
        .attr("y1", yPos - 8)
        .attr("y2", yPos + barHeight + 8)
        .style("stroke", COLORS.targetLine)
        .attr("stroke-width", 2);

      // ----------------------------------------------------------------------
      // HOVER & CLICK INTERACTIONS
      // Show tooltip and highlight bar on hover (Desktop) or click (Mobile)
      // ----------------------------------------------------------------------
      posGroup
        .on("mouseenter", function (event) {
          showTooltip(event, pos, this);
        })
        .on("mousemove", function (event) {
          updateTooltipPosition(event);
        })
        .on("mouseleave", function () {
          hideTooltip(this);
        })
        .on("click", function (event) {
          // Stop propagation so the background click handler doesn't immediately hide it
          event.stopPropagation();
          showTooltip(event, pos, this);
        });
    });

    // ------------------------------------------------------------------------
    // Y AXIS (Asset labels on the left)
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    const yAxis = g
      .append("g")
      .attr("class", "y-axis")
      .call(d3.axisLeft(yScale));

    yAxis
      .selectAll("text")
      .style("font-size", isMobile ? "11px" : "14px")
      .style("font-weight", "500")
      .style("fill", COLORS.axisText);

    yAxis.selectAll("line").remove(); // Remove tick lines
    yAxis.select(".domain").remove(); // Remove axis line

    // ------------------------------------------------------------------------
    // X AXIS (Percentage scale at the bottom)
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    const xAxis = g
      .append("g")
      .attr("class", "x-axis")
      .attr("transform", `translate(0,${chartHeight})`)
      .call(
        d3
          .axisBottom(xScale)
          .ticks(isMobile ? 5 : 10)
          .tickFormat((d) => `${d}%`),
      );

    xAxis
      .selectAll("text")
      .style("font-size", isMobile ? "10px" : "13px")
      .style("fill", COLORS.axisText);

    xAxis.selectAll("line").style("stroke", COLORS.axisLine);

    xAxis.select(".domain").style("stroke", COLORS.axisLine);

    // ------------------------------------------------------------------------
    // X AXIS LABEL
    // Colors defined in COLORS configuration object at top of file
    // Use .style() not .attr() for CSS custom properties to work
    // ------------------------------------------------------------------------
    g.append("text")
      .attr("x", chartWidth / 2)
      .attr("y", chartHeight + (isMobile ? 40 : 50))
      .attr("text-anchor", "middle")
      .style("fill", COLORS.axisLabel)
      .attr("font-size", isMobile ? "12px" : "14px")
      .attr("font-weight", "500")
      .text("Allocation (%)");
  }

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  onMount(() => {
    // Use requestAnimationFrame to ensure DOM layout is complete
    requestAnimationFrame(() => {
      updateDimensions();
      renderChart();
    });

    // Handle window resize
    const handleResize = () => {
      updateDimensions();
      renderChart();
    };

    window.addEventListener("resize", handleResize);

    // Watch for theme changes and re-render
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (
          mutation.type === "attributes" &&
          mutation.attributeName === "data-mode"
        ) {
          renderChart();
        }
      });
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-mode"],
    });

    return () => {
      window.removeEventListener("resize", handleResize);
      observer.disconnect();
    };
  });

  // Re-render when positions change or dimensions change
  $effect(() => {
    if (positions && containerWidth > 0) {
      renderChart();
    }
  });
</script>

<!-- ========================================================================== -->
<!-- TEMPLATE -->
<!-- ========================================================================== -->

<div class="chart-wrapper">
  <!-- Hidden elements to extract theme colors -->
  <div bind:this={colorRefSuccess} class="hidden bg-success-500"></div>
  <div bind:this={colorRefPrimary} class="hidden bg-primary-500"></div>
  <div bind:this={colorRefError} class="hidden bg-error-500"></div>
  <div bind:this={colorRefWarning} class="hidden bg-warning-500"></div>

  <div
    bind:this={chartContainer}
    class="chart bg-gray-50 dark:bg-gray-900"
  ></div>
  <div
    bind:this={tooltip}
    class="tooltip bg-gray-800 border border-gray-600"
  ></div>
</div>

<!-- ========================================================================== -->
<!-- STYLES -->
<!-- ========================================================================== -->

<style>
  /* Container for chart and tooltip */
  .chart-wrapper {
    position: relative;
    display: block;
    width: 100%;
  }

  /* Chart background and styling */
  .chart {
    border-radius: 8px;
    padding: 10px;
    width: 100%;
  }

  /* Tooltip styling */
  .tooltip {
    position: fixed; /* Fixed positioning prevents cutoff */
    display: none;
    border-radius: 8px;
    padding: 14px;
    pointer-events: none; /* Tooltip doesn't interfere with mouse events */
    z-index: 1000;
    box-shadow:
      0 10px 15px -3px rgba(0, 0, 0, 0.3),
      0 4px 6px -2px rgba(0, 0, 0, 0.2);
    min-width: 220px;
    max-width: 90vw; /* Ensure it never exceeds screen width on mobile */
  }

  /* Smooth transitions for hover effects */
  :global(.position-group) {
    transition: opacity 0.2s;
  }
</style>
