<script lang="ts">
  import { Navigation } from "@skeletonlabs/skeleton-svelte";
  import IconDashboard from '~icons/lucide/layout-dashboard';
  import IconTrending from '~icons/lucide/trending-up';
  import IconPanelClose from '~icons/lucide/panel-left-close';
  import IconPanelOpen from '~icons/lucide/panel-left-open';

  interface Props {
    collapsed?: boolean;
  }

  let { collapsed = $bindable(false) }: Props = $props();

  function toggleNav() {
    collapsed = !collapsed;
  }

  function navigate(path: string) {
    window.history.pushState({}, "", path);
    window.dispatchEvent(new PopStateEvent("popstate"));
  }

  const navItems = [
    { path: "/", label: "Dashboard", icon: IconDashboard },
    { path: "/drift", label: "Drift Analysis", icon: IconTrending },
  ];

  let currentPath = $state(window.location.pathname);

  window.addEventListener("popstate", () => {
    currentPath = window.location.pathname;
  });
</script>

<Navigation
  layout={collapsed ? "rail" : "sidebar"}
  class="h-full bg-surface-50-950 border-r border-surface-200-800"
>
  <Navigation.Header>
    <div
      class="flex items-center justify-between p-4 border-b border-surface-200-800"
    >
      {#if !collapsed}
        <span class="font-bold text-lg text-surface-900-50">FinancePal</span>
      {/if}
      <button
        onclick={toggleNav}
        class="btn-icon variant-ghost"
        aria-label={collapsed ? "Expand navigation" : "Collapse navigation"}
      >
        {#if collapsed}
          <IconPanelOpen class="w-5 h-5" />
        {:else}
          <IconPanelClose class="w-5 h-5" />
        {/if}
      </button>
    </div>
  </Navigation.Header>

  <Navigation.Content>
    <Navigation.Menu>
      {#each navItems as item}
        <a
          href={item.path}
          onclick={(e) => {
            e.preventDefault();
            navigate(item.path);
          }}
          class="btn hover:preset-tonal justify-start px-4 w-full {collapsed
            ? 'aspect-square max-w-[84px] flex-col items-center gap-1'
            : 'flex items-center gap-3'}"
          class:preset-filled-primary-500={currentPath === item.path}
        >
          <item.icon class="w-5 h-5" />
          {#if !collapsed}
            <span class="text-sm font-medium text-surface-900-50">{item.label}</span>
          {/if}
        </a>
      {/each}
    </Navigation.Menu>
  </Navigation.Content>
</Navigation>

