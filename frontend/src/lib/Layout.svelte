<script lang="ts">
  import { AppBar } from '@skeletonlabs/skeleton-svelte';
  import IconSun from '~icons/lucide/sun';
  import IconMoon from '~icons/lucide/moon';
  import SideNav from './SideNav.svelte';
  
  interface Props {
    children?: import('svelte').Snippet;
  }
  
  let { children }: Props = $props();
  let sideNavCollapsed = $state(false);
  
  // Theme toggle function - toggles between light and dark mode
  function toggleTheme() {
    const html = document.documentElement;
    const currentMode = html.getAttribute('data-mode');
    const newMode = currentMode === 'dark' ? 'light' : 'dark';
    
    html.setAttribute('data-mode', newMode);
    localStorage.setItem('theme', newMode);
  }
  
  // Load saved theme preference with system theme support
  import { onMount } from 'svelte';
  onMount(() => {
    // Check for saved theme preference or default to system preference
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
      // Use saved preference
      document.documentElement.setAttribute('data-mode', savedTheme);
    } else if (systemPrefersDark) {
      // Use system preference if no saved preference
      document.documentElement.setAttribute('data-mode', 'dark');
    }
    
    // Listen for system theme changes when no manual preference is set
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleSystemThemeChange = (e: MediaQueryListEvent) => {
      if (!localStorage.getItem('theme')) {
        document.documentElement.setAttribute('data-mode', e.matches ? 'dark' : 'light');
      }
    };
    
    mediaQuery.addEventListener('change', handleSystemThemeChange);
    
    // Cleanup listener on unmount
    return () => {
      mediaQuery.removeEventListener('change', handleSystemThemeChange);
    };
  });
</script>

<div class="flex h-screen bg-surface-50-950">
  <SideNav bind:collapsed={sideNavCollapsed} />
  
  <div class="flex-1 flex flex-col min-w-0">
    <AppBar>
      <AppBar.Toolbar class="grid-cols-[1fr_auto]">
        <AppBar.Headline>
          <h1 class="h1">FinancePal</h1>
        </AppBar.Headline>
        <AppBar.Trail>
          <button class="btn-icon variant-ghost" onclick={toggleTheme} aria-label="Toggle theme">
            <IconSun class="w-5 h-5 dark:hidden" />
            <IconMoon class="w-5 h-5 hidden dark:block" />
          </button>
        </AppBar.Trail>
      </AppBar.Toolbar>
    </AppBar>
    
    <main class="flex-1 overflow-y-auto p-4 md:p-8">
      {@render children?.()}
    </main>
  </div>
</div>

<style>
  :global(.h1) {
    font-size: 24px;
    font-weight: 700;
    margin: 0;
  }
</style>