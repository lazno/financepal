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
  import IconXCircle from "~icons/lucide/x-circle";
  import type { DriftPosition } from "../lib/api";

  let loading = $state(true);
  let error = $state<string | null>(null);
  let policy = $state<Policy | null>(null);
  let portfolio = $state<PortfolioResponse | null>(null);
  let saving = $state(false);
  let newInstrumentType = $state("");

  // Merged data structure for the UI
  interface Row {
    instrumentType: string;
    currentBps: number;
    targetBps: number;
    band: [number, number];
  }

  const DEFAULT_SENSITIVITY = { rel_bps: 1000, floor_bps: 300, cap_bps: 500 };
  const DEFAULT_SENSITIVITY_DISPLAY_STR =
    "Default Band: ±10% (Min 3pp, Max 5pp)";

  let rows = $state<Row[]>([]);

  // Derived stats
  let totalTargetBps = $derived(rows.reduce((sum, r) => sum + r.targetBps, 0));
  let isValid = $derived(totalTargetBps === 10000);

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
    // If policy exists, use its targets.
    // If not, default to current weights (so sum is ~100% and user can start easily).
    const targets = policy ? policy.targets : { ...currentWeights };

    // If no policy, use default sensitivity
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
        };
      })
      .filter((r) => r.currentBps > 0 || r.targetBps > 0) // Only show if held or targeted
      .sort((a, b) => a.instrumentType.localeCompare(b.instrumentType));
  }

  function addInstrument() {
    if (!newInstrumentType.trim()) return;

    const type = newInstrumentType.trim();
    // Check if already exists
    if (rows.some((r) => r.instrumentType === type)) {
      newInstrumentType = "";
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
      },
    ].sort((a, b) => a.instrumentType.localeCompare(b.instrumentType));

    newInstrumentType = "";
  }

  function removeRow(index: number) {
    rows = rows.filter((_, i) => i !== index);
  }

  function resetToCurrent() {
    if (!portfolio) return;

    // Recalculate current weights
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

    // Update rows
    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;

    rows.forEach((r) => {
      r.targetBps = currentWeights[r.instrumentType] || 0;
      r.band = calculateBand(r.targetBps, sensitivity);
    });
  }

  function updateTarget(index: number, newPct: number) {
    const newBps = pctToBps(newPct);
    rows[index].targetBps = newBps;
    // Recalculate band immediately
    const sensitivity = policy ? policy.sensitivity : DEFAULT_SENSITIVITY;
    rows[index].band = calculateBand(newBps, sensitivity);
  }

  async function save() {
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

      // We need an ID for the policy object, but if it's new, the backend ignores it/generates it.
      // We'll use a placeholder if policy is null.
      const policyToSave: Policy = {
        id: policy?.id || "new",
        targets,
        sensitivity,
      };

      await updatePolicy(policyToSave);
      // Reload to confirm
      policy = await fetchPolicy();
      initRows();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      saving = false;
    }
  }

  async function removePolicy() {
    if (
      !confirm(
        "Are you sure you want to delete the entire policy? This will reset all targets.",
      )
    )
      return;
    saving = true;
    try {
      await deletePolicy();
      policy = null;
      initRows();
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    } finally {
      saving = false;
    }
  }
</script>

<div class="space-y-6">
  <div class="flex justify-between items-center">
    <div>
      <h2 class="h2">Target Allocation</h2>
      <p class="text-surface-600">Define your desired portfolio composition.</p>
    </div>
    <div class="flex gap-2 items-center">
      {#if policy}
        <div class="badge variant-soft-surface">
          Band: ±{bpsToPct(policy.sensitivity.rel_bps)}% (Min {bpsToPct(
            policy.sensitivity.floor_bps,
          )}pp, Max {bpsToPct(policy.sensitivity.cap_bps)}pp)
        </div>
        <button
          class="btn-icon btn-icon-sm variant-soft-error"
          onclick={removePolicy}
          title="Delete Policy"
        >
          <IconXCircle class="w-4 h-4" />
        </button>
      {:else}
        <div class="badge variant-soft-surface">
          {DEFAULT_SENSITIVITY_DISPLAY_STR}
        </div>
      {/if}
    </div>
  </div>

  {#if loading}
    <div class="p-10 text-center">Loading...</div>
  {:else if error}
    <div class="alert variant-filled-error">{error}</div>
  {:else}
    <div class="card p-4 space-y-4">
      <div class="table-container">
        <table class="table table-hover">
          <thead>
            <tr>
              <th>Instrument Type</th>
              <th class="text-right">Current</th>
              <th class="text-right">Target</th>
              <th class="text-right">Band</th>
              <th class="text-center">Drift</th>
              <th class="w-10"></th>
            </tr>
          </thead>
          <tbody>
            {#each rows as row, i}
              <tr>
                <td class="align-middle">{row.instrumentType}</td>
                <td class="text-right align-middle">
                  {row.currentBps === 0
                    ? "—"
                    : bpsToPct(row.currentBps).toFixed(2) + "%"}
                </td>
                <td class="text-right w-32 align-middle">
                  <div
                    class="input-group input-group-divider grid-cols-[1fr_auto]"
                  >
                    <input
                      type="number"
                      min="0"
                      max="100"
                      step="0.1"
                      value={bpsToPct(row.targetBps)}
                      oninput={(e) =>
                        updateTarget(i, parseFloat(e.currentTarget.value) || 0)}
                    />
                    <div class="input-group-shim">%</div>
                  </div>
                </td>
                <td class="text-right text-surface-600 align-middle">
                  {bpsToPct(row.band[0]).toFixed(2)}% - {bpsToPct(
                    row.band[1],
                  ).toFixed(2)}%
                </td>
                <td class="text-center align-middle">
                  {#if row.currentBps < row.band[0]}
                    <span class="badge variant-filled-primary">Under</span>
                  {:else if row.currentBps > row.band[1]}
                    <span class="badge variant-filled-error">Over</span>
                  {:else}
                    <span class="badge variant-filled-success">OK</span>
                  {/if}
                </td>
                <td class="text-right align-middle w-10">
                  {#if row.currentBps === 0}
                    <button
                      class="btn-icon btn-icon-sm variant-soft-error"
                      onclick={() => removeRow(i)}
                      title="Remove"
                    >
                      <IconTrash class="w-4 h-4" />
                    </button>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
          <tfoot>
            <tr>
              <td colspan="2" class="font-bold text-right">Total:</td>
              <td
                class="text-right font-bold {isValid
                  ? 'text-success-500'
                  : 'text-error-500'}"
              >
                {bpsToPct(totalTargetBps).toFixed(2)}%
              </td>
              <td colspan="3">
                {#if !isValid}
                  <span class="text-error-500 text-sm ml-2"
                    >Must sum to 100%</span
                  >
                {/if}
              </td>
            </tr>
          </tfoot>
        </table>
      </div>

      <!-- Add Instrument Section -->
      <div
        class="flex gap-2 items-center p-2 bg-surface-50-900 rounded-container-token border border-surface-200-800"
      >
        <input
          class="input w-full"
          type="text"
          placeholder="Add new instrument type (e.g. Crypto, Gold)..."
          bind:value={newInstrumentType}
          onkeydown={(e) => e.key === "Enter" && addInstrument()}
        />
        <button
          class="btn variant-filled-secondary"
          disabled={!newInstrumentType.trim()}
          onclick={addInstrument}
        >
          <IconPlus class="mr-2" /> Add
        </button>
      </div>

      <div class="flex justify-end gap-2 pt-4 border-t border-surface-500/30">
        <button class="btn variant-soft-surface" onclick={resetToCurrent}>
          <IconRefreshCw class="mr-2" /> Reset to Current
        </button>
        <button
          class="btn variant-filled-primary"
          disabled={!isValid || saving}
          onclick={save}
        >
          {#if saving}Saving...{:else}<IconSave class="mr-2" /> Save Changes{/if}
        </button>
      </div>
    </div>
    <div class="card preset-filled-surface-100-900 p-4 sm:p-6">
      <div
        class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 sm:gap-4 mb-4 sm:mb-6"
      >
        <h3 class="text-lg sm:text-xl font-bold">Projected Drift</h3>
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

      <ResponsiveDriftChart positions={chartPositions} />
    </div>
  {/if}
</div>
