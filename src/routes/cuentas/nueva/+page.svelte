<script lang="ts">
  import { goto } from '$app/navigation';
  import FormularioCuenta from '$lib/FormularioCuenta.svelte';
</script>

<div class="page stack">
  <div class="spread"><a href="/cuentas" class="back">←</a><h1>Nueva cuenta</h1><span></span></div>

  <FormularioCuenta onlisto={() => goto('/cuentas')} />

  <p class="dim sm note">
    Un plazo fijo y una posición se cargan aparte, porque piden otros datos:
    <a href="/cuentas/plazo-fijo">plazo fijo</a> · <a href="/inversiones">posición</a>.
  </p>
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  .sm { font-size: .76rem; }
  .note { margin-top: .5rem; }
</style>
