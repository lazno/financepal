<script lang="ts">
  import Layout from "./lib/Layout.svelte";
  import Dashboard from "./routes/Dashboard.svelte";
  import Targets from "./routes/Targets.svelte";

  let currentPath = $state(window.location.pathname);

  function navigate(path: string) {
    window.history.pushState({}, "", path);
    currentPath = path;
  }

  window.addEventListener("popstate", () => {
    currentPath = window.location.pathname;
  });

  // Make navigate available globally for links
  (window as any).navigate = navigate;
</script>

<Layout>
  {#if currentPath === "/"}
    <Dashboard />
  {:else if currentPath === "/targets"}
    <Targets />
  {:else}
    <Dashboard />
  {/if}
</Layout>

