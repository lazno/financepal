<script lang="ts">
  import { Navigation } from "@skeletonlabs/skeleton-svelte";
  import IconDashboard from "~icons/lucide/layout-dashboard";
  import IconTrending from "~icons/lucide/trending-up";
  import IconTarget from "~icons/lucide/target";
  import IconPanelClose from "~icons/lucide/panel-left-close";
  import IconPanelOpen from "~icons/lucide/panel-left-open";
  import IconMoreVertical from "~icons/lucide/more-vertical";
  import IconSun from "~icons/lucide/sun";
  import IconMoon from "~icons/lucide/moon";

  interface Props {
    collapsed?: boolean;
  }

  let { collapsed = $bindable(false) }: Props = $props();
  let isMenuOpen = $state(false);

  function toggleNav() {
    collapsed = !collapsed;
  }

  function navigate(path: string) {
    window.history.pushState({}, "", path);
    window.dispatchEvent(new PopStateEvent("popstate"));
  }

  function toggleTheme() {
    const html = document.documentElement;
    const currentMode = html.getAttribute("data-mode");
    const newMode = currentMode === "dark" ? "light" : "dark";

    html.setAttribute("data-mode", newMode);
    localStorage.setItem("theme", newMode);
    isMenuOpen = false;
  }

  const navItems = [
    { path: "/", label: "Dashboard", icon: IconDashboard },
    { path: "/targets", label: "Targets", icon: IconTarget },
  ];

  let currentPath = $state(window.location.pathname);

  window.addEventListener("popstate", () => {
    currentPath = window.location.pathname;
  });
</script>

<Navigation
  layout="sidebar"
  class="h-full bg-surface-50-950 border-r border-surface-200-800 transition-all duration-300 flex flex-col {collapsed
    ? 'w-20'
    : 'w-64'}"
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

  <Navigation.Content class="pt-4 flex-1">
    <Navigation.Menu class="flex flex-col gap-2">
      {#each navItems as item}
        <a
          href={item.path}
          onclick={(e) => {
            e.preventDefault();
            navigate(item.path);
          }}
          class="btn hover:preset-tonal {collapsed
            ? 'w-[52px] mx-auto flex-col items-center justify-center gap-1'
            : 'flex items-center gap-3 px-4 w-full justify-start'}"
          class:preset-filled-primary-500={currentPath === item.path}
        >
          <item.icon class="w-5 h-5 flex-shrink-0" />
          {#if !collapsed}
            <span class="text-sm font-medium text-surface-900-50"
              >{item.label}</span
            >
          {/if}
        </a>
      {/each}
    </Navigation.Menu>
  </Navigation.Content>

  <Navigation.Footer class="p-4 border-t border-surface-200-800 relative">
    {#if isMenuOpen}
      <!-- Backdrop -->
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="fixed inset-0 z-40"
        onclick={() => (isMenuOpen = false)}
      ></div>

      <!-- Menu -->
      <div
        class="absolute bottom-full left-4 mb-2 w-48 bg-surface-50-950 rounded-container-token shadow-xl border border-surface-200-800 overflow-hidden z-50"
      >
        <button
          onclick={toggleTheme}
          class="w-full text-left px-4 py-3 hover:bg-surface-100-900 flex items-center gap-3 transition-colors"
        >
          <IconSun class="w-5 h-5 dark:hidden" />
          <IconMoon class="w-5 h-5 hidden dark:block" />
          <span class="text-sm font-medium">Toggle Theme</span>
        </button>
      </div>
    {/if}

    <button
      onclick={() => (isMenuOpen = !isMenuOpen)}
      class="btn hover:preset-tonal w-full {collapsed
        ? 'justify-center px-0'
        : 'justify-between px-4'}"
    >
      {#if !collapsed}
        <span class="text-sm font-medium">Settings</span>
      {/if}
      <IconMoreVertical class="w-5 h-5" />
    </button>
  </Navigation.Footer>
</Navigation>
