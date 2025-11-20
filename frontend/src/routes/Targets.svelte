<script lang="ts">
  import { onMount } from "svelte";
  import {
    fetchPortfolioRaw,
    fetchPolicy,
    updatePolicy,
    deletePolicy,
    type Policy,
    type PortfolioResponse,
  } from "../lib/api";
  import { calculateBand, bpsToPct, pctToBps } from "../lib/policy-logic";
  import ResponsiveDriftChart from "../lib/ResponsiveDriftChart.svelte";
  import IconSave from "~icons/lucide/save";
  import IconRefreshCw from "~icons/lucide/refresh-cw";
  import IconPlus from "~icons/lucide/plus";
  import IconTrash from "~icons/lucide/trash-2";
  import IconX from "~icons/lucide/x";
  import IconPin from "~icons/lucide/pin";
  import IconPinOff from "~icons/lucide/pin-off";
  import type { DriftPosition } from "../lib/api";

  let loading = $state(true);
  let error = $state<string | null>(null);
  let policy = $state<Policy | null>(null);
  let portfolio = $state<PortfolioResponse | null>(null);
  let saving = $state(false);
  
  // Modal state
  let showDeleteModal = $state(false);
  let showAddTooltip = $state(false);
  let newInstrumentType = $state("");
  let isAddingInstrument = $state(false);

  // Merged data structure for the UI
  interface Row {
    instrumentType: string;
    currentBps: number;
    targetBps: number;
    band: [number, number];
    pinned: boolean;
  }

  const DEFAULT_SENSITIVITY = { rel_bps: 1000, floor_bps: 300, cap_bps: 500 };

  let rows = $state<Row[]>([]);

  // Derived stats
  let totalTargetBps = $derived(rows.reduce((sum, r) => sum + r.targetBps, 0));
  let isValid = $derived(Math.abs(totalTargetBps - 10000) < 5); // Allow small rounding error tolerance

  // Chart data
  let chartPositions: DriftPosition[] = $derived(
    rows.map((r) => {
      const [min, max] = r.band;
      return {
        asset: r.instrumentType,
        target: bpsToPct(r.targetBps),
        current: bpsToPct(r.currentBps),
        lowerBound: bpsToPct(min),
        upperBound: bpsToPct(max),
        status:
          r.currentBps >= min && r.currentBps <= max
            ? "in_band"
            : ("out_of_band" as const),
      };
    }),
  );

  onMount(async () => {
    try {
      const [pol, port] = await Promise.all([
        fetchPolicy(),
        fetchPortfolioRaw(),
      ]);
      policy = pol;
      portfolio = port;
      initRows();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      loading = false;
    }
  });

  function initRows() {
    if (!portfolio) return;

    // 1. Calculate current weights
    const typeValues: Record<string, number> = {};
    let totalValue = 0;

    portfolio.positions_by_currency.forEach((group) => {
      Object.values(group).forEach((currTotal) => {
        currTotal.positions.forEach((pos) => {
          const type = pos.instrument_type || "Other";
          typeValues[type] = (typeValues[type] || 0) + pos.market_value;
          totalValue += pos.market_value;
        });
      });
    });

    const currentWeights: Record<string, number> = {};
    if (totalValue > 0) {
      for (const [type, val] of Object.entries(typeValues)) {
        currentWeights[type] = Math.round((val / totalValue) * 10000);
      }
    }

    // 2. Determine targets
    const targets = policy ? policy.targets : { ...currentWeights };
    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;

    // 3. Merge
    const allTypes = new Set([
      ...Object.keys(targets),
      ...Object.keys(currentWeights),
    ]);

    rows = Array.from(allTypes)
      .map((type) => {
        const target = targets[type] || 0;
        const current = currentWeights[type] || 0;
        return {
          instrumentType: type,
          currentBps: current,
          targetBps: target,
          band: calculateBand(target, sensitivity),
          pinned: false,
        };
      })
      .filter((r) => r.currentBps > 0 || r.targetBps > 0)
      .sort((a, b) => {
          if (b.currentBps !== a.currentBps) return b.currentBps - a.currentBps;
          return a.instrumentType.localeCompare(b.instrumentType);
      });
  }

  function removeRow(index: number) {
    rows = rows.filter((_, i) => i !== index);
  }

  function togglePin(index: number) {
    rows[index].pinned = !rows[index].pinned;
  }

  function handleSliderChange(index: number, newPct: number) {
    const newBps = pctToBps(newPct);
    const oldBps = rows[index].targetBps;
    const diffBps = newBps - oldBps;

    if (diffBps === 0) return;

    // Update the changed row
    rows[index].targetBps = newBps;
    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;
    rows[index].band = calculateBand(newBps, sensitivity);

    // Redistribute difference among unpinned rows
    const unpinnedRows = rows.filter((r, i) => i !== index && !r.pinned);
    
    if (unpinnedRows.length > 0) {
      const totalUnpinnedBps = unpinnedRows.reduce((sum, r) => sum + r.targetBps, 0);
      
      // We need to remove 'diffBps' from the other rows
      let distributedBps = 0;
      
      // Sort unpinned rows by allocation size (largest first) to hide rounding errors in the largest bucket
      const sortedUnpinnedIndices = unpinnedRows
          .map(r => rows.indexOf(r))
          .sort((a, b) => rows[b].targetBps - rows[a].targetBps);

      sortedUnpinnedIndices.forEach((realIndex, i) => {
        const row = rows[realIndex];
        let adjustment = 0;

        if (i === sortedUnpinnedIndices.length - 1) {
            // Last item gets the exact remainder to ensure zero-sum change
            adjustment = -diffBps - distributedBps;
        } else {
             // Standard proportional distribution
             const proportion = totalUnpinnedBps > 0 ? row.targetBps / totalUnpinnedBps : 1 / unpinnedRows.length;
             adjustment = Math.round(-diffBps * proportion);
        }

        let newTarget = row.targetBps + adjustment;
        
        // Clamp to 0, but tracking exact changes is hard if we clamp.
        // If we hit 0, we break the zero-sum game unless we re-distribute the overflow.
        // For standard slider usage, simple clamping is acceptable as the user will see the total go red if they push too far.
        if (newTarget < 0) newTarget = 0;
        
        // Track what we ACTUALLY changed
        distributedBps += (newTarget - row.targetBps);

        rows[realIndex].targetBps = newTarget;
        rows[realIndex].band = calculateBand(newTarget, sensitivity);
      });
    }
  }

    function addInstrument() {
    if (!newInstrumentType.trim()) return;

    const type = newInstrumentType.trim().toUpperCase();
    if (rows.some((r) => r.instrumentType === type)) {
      newInstrumentType = "";
      isAddingInstrument = false;
      showAddTooltip = false; // Ensure tooltip is hidden
      return;
    }

    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;

    rows = [
      ...rows,
      {
        instrumentType: type,
        currentBps: 0,
        targetBps: 0,
        band: calculateBand(0, sensitivity),
        pinned: false,
      },
    ].sort((a, b) => {
        if (b.currentBps !== a.currentBps) return b.currentBps - a.currentBps;
        return a.instrumentType.localeCompare(b.instrumentType);
    });

    newInstrumentType = "";
    isAddingInstrument = false;
    showAddTooltip = false; // Ensure tooltip is hidden
  }

  function resetToCurrent() {
    if (!portfolio) return;
    
    const typeValues: Record<string, number> = {};
    let totalValue = 0;

    portfolio.positions_by_currency.forEach((group) => {
      Object.values(group).forEach((currTotal) => {
        currTotal.positions.forEach((pos) => {
          const type = pos.instrument_type || "Other";
          typeValues[type] = (typeValues[type] || 0) + pos.market_value;
          totalValue += pos.market_value;
        });
      });
    });

    const currentWeights: Record<string, number> = {};
    if (totalValue > 0) {
      for (const [type, val] of Object.entries(typeValues)) {
        currentWeights[type] = Math.round((val / totalValue) * 10000);
      }
    }

    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;

    rows.forEach(r => {
        r.targetBps = currentWeights[r.instrumentType] || 0;
        r.band = calculateBand(r.targetBps, sensitivity);
        r.pinned = false;
    });
  }

  async function save() {
    // Auto-correct small rounding errors (±5bps) before saving
    if (Math.abs(totalTargetBps - 10000) < 5 && totalTargetBps !== 10000) {
        let currentSum = rows.reduce((acc, r) => acc + r.targetBps, 0);
        const drift = 10000 - currentSum;
        
        // Find largest allocation to absorb the drift
        let maxIndex = -1;
        let maxVal = -1;
        rows.forEach((r, i) => {
            if (r.targetBps > maxVal) {
                maxVal = r.targetBps;
                maxIndex = i;
            }
        });
        
        if (maxIndex !== -1) {
            rows[maxIndex].targetBps += drift;
            // Re-calculate band for the modified row
            const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;
            rows[maxIndex].band = calculateBand(rows[maxIndex].targetBps, sensitivity);
        }
    }

    if (!isValid) return;
    saving = true;
    try {
      const targets: Record<string, number> = {};
      rows.forEach((r) => {
        if (r.targetBps > 0) {
          targets[r.instrumentType] = r.targetBps;
        }
      });

      const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;

      const policyToSave: Policy = {
        id: policy?.id || "new",
        targets,
        sensitivity,
      };

      await updatePolicy(policyToSave);
      policy = await fetchPolicy();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      saving = false;
    }
  }

  async function removePolicy() {
    saving = true;
    try {
      await deletePolicy();
      policy = null;
      initRows();
      showDeleteModal = false;
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      saving = false;
    }
  }
</script>

<div class="container mx-auto max-w-5xl pb-20">
  <!-- Header -->
  <div class="flex justify-between items-start mb-10">
    <div class="header-content">
      <h1 class="text-4xl font-bold mb-2 bg-clip-text text-transparent bg-gradient-to-br from-primary-500 to-primary-300 tracking-tighter">
        Target Allocation
      </h1>
      <p class="text-surface-600 dark:text-surface-400 font-light">
        Define your desired portfolio composition.
      </p>
    </div>
    <div class="band-badge px-4 py-2 rounded-lg text-sm font-semibold backdrop-blur-md">
      {#if policy}
        Band: ±{bpsToPct(policy.sensitivity.rel_bps)}% (Min {bpsToPct(policy.sensitivity.floor_bps)}pp, Max {bpsToPct(policy.sensitivity.cap_bps)}pp)
      {:else}
        Band: ±10% (Min 3pp, Max 5pp)
      {/if}
    </div>
  </div>

  {#if loading}
    <div class="p-10 text-center">Loading...</div>
  {:else if error}
    <div class="alert variant-filled-error">{error}</div>
  {:else}
    <!-- Chart Section -->
    <div class="projected-draft mb-10 rounded-2xl p-8 backdrop-blur-md">
      <div class="section-title text-xl font-bold mb-6 flex items-center gap-3">Projected Draft</div>
      <div class="flex gap-6 mb-6 flex-wrap">
        <div class="flex items-center gap-2 text-sm font-medium text-surface-600 dark:text-surface-400">
          <div class="w-3 h-3 rounded bg-success-500"></div>
          <span>In Band</span>
        </div>
        <div class="flex items-center gap-2 text-sm font-medium text-surface-600 dark:text-surface-400">
          <div class="w-3 h-3 rounded bg-primary-500"></div>
          <span>Under Target</span>
        </div>
        <div class="flex items-center gap-2 text-sm font-medium text-surface-600 dark:text-surface-400">
          <div class="w-3 h-3 rounded bg-error-500"></div>
          <span>Over Target</span>
        </div>
      </div>
      
      <div class="w-full">
        <ResponsiveDriftChart positions={chartPositions} />
      </div>
    </div>

    <!-- Table Section (Desktop) -->
    <div class="hidden md:block table-wrapper mb-8 rounded-2xl overflow-hidden backdrop-blur-md">
      <table class="w-full border-collapse">
        <thead>
          <tr>
            <th class="px-4 py-5 text-left text-xs font-bold uppercase tracking-wider">Instrument Type</th>
            <th class="px-4 py-5 text-left text-xs font-bold uppercase tracking-wider">Current</th>
            <th class="px-4 py-5 text-left text-xs font-bold uppercase tracking-wider w-1/2">Target Allocation</th>
            <th class="px-4 py-5 text-center text-xs font-bold uppercase tracking-wider w-32"></th>
          </tr>
        </thead>
        <tbody>
          {#each rows as row, i}
            <tr class="hover:bg-primary-500/5 dark:hover:bg-primary-500/10 transition-colors">
              <td class="px-4 py-5 text-sm border-b border-primary-500/10 dark:border-primary-300/10 instrument-name font-bold tracking-wide">{row.instrumentType}</td>
              <td class="px-4 py-5 text-sm border-b border-primary-500/10 dark:border-primary-300/10 current-pct font-bold text-base">
                {row.currentBps === 0 ? "—" : bpsToPct(row.currentBps).toFixed(2) + "%"}
              </td>
              <td class="px-4 py-5 text-sm border-b border-primary-500/10 dark:border-primary-300/10">
                <div class="slider-container flex items-center gap-3 w-full">
                  <input
                    type="range"
                    class="flex-1 h-1.5 rounded-full appearance-none cursor-pointer bg-primary-500/20"
                    min="0"
                    max="100"
                    step="1"
                    value={bpsToPct(row.targetBps)}
                    oninput={(e) => handleSliderChange(i, parseFloat(e.currentTarget.value))}
                    disabled={row.pinned}
                  />
                  <span class="target-value min-w-[3rem] text-right font-bold text-base">{bpsToPct(row.targetBps).toFixed(0)}%</span>
                </div>
              </td>
              <td class="px-4 py-5 text-sm border-b border-primary-500/10 dark:border-primary-300/10 text-center">
                <div class="flex items-center justify-end gap-2 pr-4">
                  <button 
                    class="pin-btn w-8 h-8 rounded-md flex items-center justify-center transition-colors duration-200 {row.pinned ? 'pinned' : ''}" 
                    onclick={() => togglePin(i)}
                    title={row.pinned ? "Unpin allocation" : "Pin allocation"}
                  >
                    {#if row.pinned}
                      <IconPin class="w-4 h-4" />
                    {:else}
                      <IconPinOff class="w-4 h-4 opacity-50" />
                    {/if}
                  </button>
                  {#if row.currentBps === 0}
                    <button
                      class="pin-btn w-8 h-8 rounded-md flex items-center justify-center transition-colors duration-200 hover:text-error-500 hover:bg-error-500/10"
                      onclick={() => removeRow(i)}
                      title="Remove instrument"
                    >
                      <IconTrash class="w-4 h-4" />
                    </button>
                  {:else}
                    <div class="w-8 h-8"></div> <!-- Spacer to keep alignment -->
                  {/if}
                </div>
              </td>
            </tr>
          {/each}
          
          <!-- Total Row -->
          <tr class="total-row font-bold">
            <td colspan="2" class="border-none py-6"></td>
            <td class="border-none py-6 text-right">
              <div class="flex items-center justify-end gap-2 text-lg font-bold {isValid ? 'text-success-500' : 'text-error-500'}">
                <span class="total-indicator w-2 h-2 rounded-full inline-block mr-2 {isValid ? 'bg-success-500' : 'bg-error-500 animate-pulse'}"></span>
                <span>Total: {bpsToPct(totalTargetBps).toFixed(0)}%</span>
              </div>
            </td>
            <td class="border-none py-6"></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Mobile Card View -->
    <div class="md:hidden space-y-4 mb-8">
      {#each rows as row, i}
        <div class="glass-card p-4 rounded-xl border border-primary-500/10 relative overflow-hidden">
           <!-- Row 1: Name + Current + Pin -->
           <div class="flex justify-between items-start mb-4">
              <div>
                 <div class="font-bold text-lg tracking-wide mb-1">{row.instrumentType}</div>
                 <div class="text-xs font-medium text-surface-500 uppercase tracking-wider">Current: <span class="text-primary-600 dark:text-primary-400 text-sm">{row.currentBps === 0 ? "—" : bpsToPct(row.currentBps).toFixed(2) + "%"}</span></div>
              </div>
              <div class="flex gap-2">
                  <button 
                    class="w-8 h-8 rounded-lg bg-surface-100 dark:bg-surface-800 flex items-center justify-center transition-colors {row.pinned ? 'text-primary-500 bg-primary-500/10' : 'text-surface-400'}" 
                    onclick={() => togglePin(i)}
                  >
                    {#if row.pinned}
                      <IconPin class="w-4 h-4" />
                    {:else}
                      <IconPinOff class="w-4 h-4" />
                    {/if}
                  </button>
                  {#if row.currentBps === 0}
                    <button
                      class="w-8 h-8 rounded-lg bg-surface-100 dark:bg-surface-800 text-surface-400 hover:text-error-500 hover:bg-error-500/10 flex items-center justify-center transition-colors"
                      onclick={() => removeRow(i)}
                    >
                      <IconTrash class="w-4 h-4" />
                    </button>
                  {/if}
              </div>
           </div>

           <!-- Row 2: Slider -->
           <div class="mb-2">
              <div class="flex justify-between text-xs font-medium mb-2 text-surface-500">
                 <span>Target Allocation</span>
                 <span class="text-lg font-bold text-primary-600 dark:text-primary-400">{bpsToPct(row.targetBps).toFixed(0)}%</span>
              </div>
              <input
                type="range"
                class="w-full h-2 rounded-full appearance-none cursor-pointer bg-surface-200 dark:bg-surface-700"
                min="0"
                max="100"
                step="1"
                value={bpsToPct(row.targetBps)}
                oninput={(e) => handleSliderChange(i, parseFloat(e.currentTarget.value))}
                disabled={row.pinned}
              />
           </div>
        </div>
      {/each}

      <!-- Mobile Total -->
      <div class="glass-card p-4 rounded-xl border border-primary-500/10 flex justify-between items-center">
         <span class="font-bold text-surface-600 dark:text-surface-300">Total Allocation</span>
         <div class="flex items-center gap-2 text-lg font-bold {isValid ? 'text-success-500' : 'text-error-500'}">
            <span class="w-2 h-2 rounded-full {isValid ? 'bg-success-500' : 'bg-error-500 animate-pulse'}"></span>
            {bpsToPct(totalTargetBps).toFixed(0)}%
         </div>
      </div>
    </div>

    <!-- Bottom Actions -->
    <div class="flex flex-col md:flex-row justify-between items-center gap-5">
      <!-- Add Instrument -->
      <div class="relative h-12 flex items-center w-full md:w-auto justify-center md:justify-start order-2 md:order-1">
        {#if isAddingInstrument}
            <div class="glass-input-container flex items-center gap-2 p-1.5 rounded-lg animate-fade-in w-full md:w-auto justify-between">
                <input 
                    type="text" 
                    bind:value={newInstrumentType}
                    placeholder="Type..." 
                    class="bg-transparent border-none focus:ring-0 text-sm w-full md:w-32 px-2 font-medium outline-none"
                    autofocus
                    onkeydown={(e) => e.key === 'Enter' && addInstrument()}
                />
                <div class="flex gap-1">
                    <button class="w-8 h-8 rounded-md bg-primary-500 text-white flex items-center justify-center hover:bg-primary-600 transition-colors shadow-sm" onclick={addInstrument}>
                        <IconPlus class="w-5 h-5" />
                    </button>
                    <button class="w-8 h-8 rounded-md flex items-center justify-center text-surface-500 hover:text-error-500 hover:bg-error-500/10 transition-colors" onclick={() => isAddingInstrument = false}>
                        <IconX class="w-4 h-4" />
                    </button>
                </div>
            </div>
        {:else}
            <button 
                class="add-btn-icon w-12 h-12 rounded-xl flex items-center justify-center text-2xl cursor-pointer transition-all duration-200 shadow-sm"
                onmouseenter={() => showAddTooltip = true}
                onmouseleave={() => showAddTooltip = false}
                onclick={() => { isAddingInstrument = true; showAddTooltip = false; }}
            >
                +
            </button>
            {#if showAddTooltip}
                <div class="tooltip absolute bottom-full left-1/2 md:left-0 transform -translate-x-1/2 md:translate-x-0 mb-2 px-3 py-2 rounded bg-surface-900 text-white text-xs whitespace-nowrap z-50 shadow-lg pointer-events-none">Add Instrument</div>
            {/if}
        {/if}
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 w-full md:w-auto order-1 md:order-2">
        <button class="btn px-6 py-3 rounded-lg font-bold text-sm transition-all duration-300 shadow-sm btn-secondary flex items-center justify-center" onclick={resetToCurrent}>
          <IconRefreshCw class="mr-2 w-4 h-4" /> <span class="whitespace-nowrap">Reset</span>
        </button>
        <button 
            class="btn px-6 py-3 rounded-lg font-bold text-sm transition-all duration-300 shadow-sm btn-danger disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:border-opacity-30 flex items-center justify-center" 
            onclick={() => showDeleteModal = true}
            disabled={!policy || policy.id === 'new'}
            title={(!policy || policy.id === 'new') ? "No saved policy to delete" : "Delete current policy"}
        >
          <IconTrash class="mr-2 w-4 h-4" /> Delete
        </button>
        <button 
          class="btn px-6 py-3 rounded-lg font-bold text-sm transition-all duration-300 shadow-sm btn-primary flex items-center justify-center" 
          disabled={!isValid || saving}
          onclick={save}
        >
          {#if saving}Saving...{:else}<IconSave class="mr-2 w-4 h-4" /> Save{/if}
        </button>
      </div>
    </div>
  {/if}
</div>

<!-- Delete Modal -->
{#if showDeleteModal}
<div class="modal fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm active">
    <div class="modal-content w-full max-w-md p-8 rounded-2xl shadow-2xl">
        <div class="modal-title text-xl font-bold mb-3">Delete Allocation?</div>
        <div class="modal-text mb-6 text-sm opacity-80">Are you sure you want to delete this target allocation? This action cannot be undone.</div>
        <div class="modal-actions flex gap-3">
            <button class="btn px-6 py-3 rounded-lg font-bold text-sm transition-all duration-300 shadow-sm btn-secondary flex-1" onclick={() => showDeleteModal = false}>Cancel</button>
            <button class="btn px-6 py-3 rounded-lg font-bold text-sm transition-all duration-300 shadow-sm btn-danger flex-1" onclick={removePolicy}>Delete</button>
        </div>
    </div>
</div>
{/if}

<style lang="postcss">
    /* Custom Styles matching the reference design */
    
    .band-badge {
        background: rgba(157, 78, 221, 0.1);
        border: 1px solid rgba(157, 78, 221, 0.3);
        color: var(--color-primary-500);
    }
    :global([data-mode='dark']) .band-badge {
        background: rgba(212, 165, 255, 0.1);
        border: 1px solid rgba(212, 165, 255, 0.3);
        color: var(--color-primary-300);
    }

    .projected-draft {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.9) 0%, rgba(255, 255, 255, 0.8) 100%);
        border: 1px solid rgba(157, 78, 221, 0.15);
        box-shadow: 0 8px 32px rgba(157, 78, 221, 0.08);
    }
    :global([data-mode='dark']) .projected-draft {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid rgba(212, 165, 255, 0.15);
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    }

    .section-title {
        color: var(--color-surface-900);
    }
    :global([data-mode='dark']) .section-title {
        color: var(--color-surface-50);
    }
    .section-title::before {
        content: '';
        display: inline-block;
        width: 4px;
        height: 24px;
        border-radius: 2px;
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-300) 100%);
    }

    .table-wrapper {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.9) 0%, rgba(255, 255, 255, 0.8) 100%);
        border: 1px solid rgba(157, 78, 221, 0.15);
        box-shadow: 0 8px 32px rgba(157, 78, 221, 0.08);
    }
    :global([data-mode='dark']) .table-wrapper {
        background: rgba(255, 255, 255, 0.02);
        border: 1px solid rgba(212, 165, 255, 0.15);
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    }

    thead {
        background: linear-gradient(90deg, rgba(157, 78, 221, 0.08) 0%, rgba(199, 125, 255, 0.05) 100%);
        border-bottom: 2px solid rgba(157, 78, 221, 0.15);
    }
    :global([data-mode='dark']) thead {
        background: linear-gradient(90deg, rgba(212, 165, 255, 0.1) 0%, rgba(183, 139, 255, 0.05) 100%);
        border-bottom: 2px solid rgba(212, 165, 255, 0.2);
    }

    th {
        color: var(--color-primary-600);
    }
    :global([data-mode='dark']) th {
        color: var(--color-primary-300);
    }

    td {
        color: var(--color-surface-900);
    }
    :global([data-mode='dark']) td {
        color: var(--color-surface-100);
    }

    .current-pct {
        color: var(--color-primary-600);
    }
    :global([data-mode='dark']) .current-pct {
        color: var(--color-primary-300);
    }

    /* Slider Styling */
    
    /* Webkit Thumb */
    input[type="range"]::-webkit-slider-thumb {
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-300) 100%);
        margin-top: -5px; /* Center on track */
    }
    input[type="range"]::-webkit-slider-thumb:hover {
        transform: scale(1.2);
    }

    /* Firefox Thumb */
    input[type="range"]::-moz-range-thumb {
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-300) 100%);
    }
    input[type="range"]::-moz-range-thumb:hover {
        transform: scale(1.2);
    }

    .target-value {
        color: var(--color-primary-600);
    }
    :global([data-mode='dark']) .target-value {
        color: var(--color-primary-300);
    }

    /* Pin Button */
    .pin-btn {
        color: var(--color-surface-400);
    }
    .pin-btn:hover {
        background-color: rgba(157, 78, 221, 0.1);
        color: var(--color-primary-500);
    }
    .pin-btn.pinned {
        background-color: rgba(157, 78, 221, 0.2);
        color: var(--color-primary-500);
    }

    /* Total Row */
    .total-row {
        background: linear-gradient(90deg, rgba(157, 78, 221, 0.12) 0%, rgba(199, 125, 255, 0.08) 100%);
        border-top: 2px solid rgba(157, 78, 221, 0.15);
    }
    :global([data-mode='dark']) .total-row {
        background: linear-gradient(90deg, rgba(212, 165, 255, 0.15) 0%, rgba(183, 139, 255, 0.08) 100%);
        border-top: 2px solid rgba(212, 165, 255, 0.2);
    }

    /* Buttons */
    .btn-primary {
        background: linear-gradient(135deg, var(--color-primary-500) 0%, var(--color-primary-400) 100%);
        color: white;
        border: none;
    }
    .btn-primary:hover:not(:disabled) {
        transform: translateY(-2px);
        box-shadow: 0 10px 15px -3px rgba(157, 78, 221, 0.3);
    }
    .btn-primary:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .btn-secondary {
        background-color: var(--color-surface-50);
        color: var(--color-primary-600);
        border: 1px solid rgba(157, 78, 221, 0.3);
    }
    :global([data-mode='dark']) .btn-secondary {
        background-color: rgba(157, 78, 221, 0.1);
        color: var(--color-primary-300);
        border: 1px solid rgba(157, 78, 221, 0.3);
    }
    .btn-secondary:hover {
        background-color: white;
        border-color: rgba(157, 78, 221, 0.5);
        box-shadow: 0 4px 6px -1px rgba(157, 78, 221, 0.1);
    }
    :global([data-mode='dark']) .btn-secondary:hover {
        background-color: rgba(157, 78, 221, 0.2);
        border-color: rgba(157, 78, 221, 0.5);
    }

    .btn-danger {
        background-color: rgba(220, 38, 38, 0.1);
        color: var(--color-error-500);
        border: 1px solid rgba(220, 38, 38, 0.3);
    }
    .btn-danger:hover {
        background-color: rgba(220, 38, 38, 0.2);
        border-color: rgba(220, 38, 38, 0.5);
    }

    /* Add Instrument */
    .add-btn-icon {
        background: linear-gradient(135deg, rgba(157, 78, 221, 0.1) 0%, rgba(199, 125, 255, 0.1) 100%);
        border: 1px solid rgba(157, 78, 221, 0.3);
        color: var(--color-primary-500);
    }
    :global([data-mode='dark']) .add-btn-icon {
        background: rgba(212, 165, 255, 0.1);
        border: 1px solid rgba(212, 165, 255, 0.3);
        color: var(--color-primary-300);
    }
    .add-btn-icon:hover {
        transform: scale(1.05);
        background: linear-gradient(135deg, rgba(157, 78, 221, 0.15) 0%, rgba(199, 125, 255, 0.15) 100%);
    }

    .glass-card {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.9) 0%, rgba(255, 255, 255, 0.8) 100%);
        box-shadow: 0 4px 16px rgba(157, 78, 221, 0.08);
    }
    :global([data-mode='dark']) .glass-card {
        background: rgba(255, 255, 255, 0.02);
        box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
    }

    .glass-input-container {
        background: linear-gradient(135deg, rgba(157, 78, 221, 0.05) 0%, rgba(199, 125, 255, 0.05) 100%);
        border: 1px solid rgba(157, 78, 221, 0.3);
        box-shadow: 0 4px 12px rgba(157, 78, 221, 0.1);
    }
    :global([data-mode='dark']) .glass-input-container {
        background: rgba(212, 165, 255, 0.1);
        border: 1px solid rgba(212, 165, 255, 0.3);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
    }
    
    .glass-input-container input {
        color: var(--color-surface-900);
    }
    :global([data-mode='dark']) .glass-input-container input {
        color: var(--color-surface-50);
    }
    :global([data-mode='dark']) .glass-input-container input::placeholder {
        color: var(--color-surface-400);
    }

    .tooltip::after {
        content: '';
        position: absolute;
        top: 100%;
        left: 50%;
        transform: translateX(-50%);
        border-width: 4px;
        border-style: solid;
        border-color: var(--color-surface-900) transparent transparent transparent;
    }

    /* Modal */
    .modal-content {
        background: linear-gradient(135deg, rgba(255, 255, 255, 0.95) 0%, rgba(255, 255, 255, 0.9) 100%);
        border: 1px solid rgba(157, 78, 221, 0.2);
    }
    :global([data-mode='dark']) .modal-content {
        background: linear-gradient(135deg, rgba(45, 31, 58, 0.95) 0%, rgba(26, 22, 37, 0.95) 100%);
        border: 1px solid rgba(212, 165, 255, 0.2);
    }
    .modal-title {
        color: var(--color-surface-900);
    }
    :global([data-mode='dark']) .modal-title {
        color: var(--color-surface-50);
    }
    .modal-text {
        color: var(--color-surface-700);
    }
    :global([data-mode='dark']) .modal-text {
        color: var(--color-surface-300);
    }
</style>
