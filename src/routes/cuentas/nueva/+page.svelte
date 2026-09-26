<script lang="ts">
  import { goto } from '$app/navigation';
  import FormularioCuenta from '$lib/FormularioCuenta.svelte';
</script>

<div class="page stack">
  <div class="spread"><a href="/cuentas" class="back">←</a><h1>Nueva cuenta</h1><span></span></div>

  <FormularioCuenta onlisto={() => goto('/cuentas')} />

  <!-- Decia `/cuentas/plazo-fijo`, que NUNCA EXISTIO como ruta: era un 404 a la
       vista. El chequeo de navegacion no lo veia porque solo buscaba pantallas
       sin camino de entrada, y esto era lo contrario: un camino sin pantalla. -->
  <p class="dim sm note">
    Un plazo fijo y una posición se cargan en <a href="/inversiones">Inversiones</a>,
    porque piden otros datos: un vencimiento, un ticker.
  </p>
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  .sm { font-size: .76rem; }
  .note { margin-top: .5rem; }
</style>
