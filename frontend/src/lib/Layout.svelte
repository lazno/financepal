<script lang="ts">
  import { Dialog, Portal } from '@skeletonlabs/skeleton-svelte';
  import IconMenu from '~icons/lucide/menu';
  import IconX from '~icons/lucide/x';
  import SideNav from './SideNav.svelte';
  
  interface Props {
    children?: import('svelte').Snippet;
  }
  
  let { children }: Props = $props();
  let sideNavCollapsed = $state(false);
  let mobileDrawerOpen = $state(false);
  
  // Handle navigation in mobile - close drawer
  function handleMobileNavigation() {
    mobileDrawerOpen = false;
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
  
  // Drawer animations
  const animBackdrop = 'transition transition-discrete opacity-0 starting:data-[state=open]:opacity-0 data-[state=open]:opacity-100';
  const animModal = 'transition transition-discrete opacity-0 -translate-x-full starting:data-[state=open]:opacity-0 starting:data-[state=open]:-translate-x-full data-[state=open]:opacity-100 data-[state=open]:translate-x-0';
</script>

<div class="flex h-screen bg-surface-50-950">
  <!-- Desktop Sidebar: Hidden on mobile (< lg), visible on desktop -->
  <div class="hidden lg:block">
    <SideNav bind:collapsed={sideNavCollapsed} />
  </div>
  
  <!-- Mobile Drawer using Dialog component -->
  <Dialog open={mobileDrawerOpen} onOpenChange={(details) => mobileDrawerOpen = details.open}>
    <Portal>
      <Dialog.Backdrop class="fixed inset-0 z-50 bg-surface-50-950/50 {animBackdrop}" />
      <Dialog.Positioner class="fixed inset-0 z-50 flex justify-start">
        <Dialog.Content class="h-screen w-64 bg-surface-50-950 shadow-xl {animModal}">
          <div class="flex justify-between items-center p-4 border-b border-surface-200-800">
            <span class="font-bold text-lg">Menu</span>
            <Dialog.CloseTrigger class="btn-icon variant-ghost">
              <IconX class="w-5 h-5" />
            </Dialog.CloseTrigger>
          </div>
          <!-- eslint-disable-next-line -->
          <div onclick={handleMobileNavigation} role="button" tabindex="0" onkeydown={(e) => e.key === 'Enter' && handleMobileNavigation()}>
            <SideNav collapsed={false} />
          </div>
        </Dialog.Content>
      </Dialog.Positioner>
    </Portal>
  </Dialog>
  
  <div class="flex-1 flex flex-col min-w-0">
    <!-- Mobile Menu Button -->
    <div class="lg:hidden p-4 pb-0">
      <button 
        class="btn-icon variant-ghost" 
        onclick={() => mobileDrawerOpen = true}
        aria-label="Open menu"
      >
        <IconMenu class="w-6 h-6" />
      </button>
    </div>
    
    <main class="flex-1 overflow-y-auto p-3 sm:p-4 md:p-6 lg:p-8">
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