<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';
  import { createAccount, listAccounts } from '$lib/ledger/api';

  let name = $state('');
  let kind = $state<'asset' | 'liability'>('asset');
  let unit = $state('ARS');
  let institution = $state('');
  let fxSource = $state('');
  let busy = $state(false);
  let error = $state<string | null>(null);
  let bancos = $state<string[]>([]);

  onMount(async () => {
    try {
      const cuentas = await listAccounts();
      bancos = [...new Set(cuentas.map((a) => a.institution?.trim()).filter(Boolean) as string[])].sort();
    } catch { /* la sugerencia es un lujo: si falla, se escribe a mano */ }
  });

  // Una tarjeta es un pasivo y NO es plata gastable: su saldo es deuda. ADR-004.
  const spendable = $derived(kind === 'asset');

  async function save(e: SubmitEvent) {
    e.preventDefault();
    busy = true; error = null;
    try {
      await createAccount({
        name: name.trim(),
        kind,
        unit,
        is_spendable: spendable,
        institution: institution.trim() || null,
        fx_source: fxSource || null
      });
      goto('/cuentas');
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo crear';
      busy = false;
    }
  }
</script>

<div class="page stack">
  <div class="spread"><a href="/cuentas" class="back">←</a><h1>Nueva cuenta</h1><span></span></div>

  {#if error}<p class="err">{error}</p>{/if}

  <form class="stack" onsubmit={save}>
    <label><span class="dim">Nombre</span>
      <input bind:value={name} required placeholder="Banco Santander" /></label>

    <fieldset>
      <legend class="dim">Qué es</legend>
      <div class="opts">
        <button type="button" class:on={kind === 'asset'} onclick={() => (kind = 'asset')}>
          Tengo plata acá
          <span class="dim sm">efectivo, banco, billetera</span>
        </button>
        <button type="button" class:on={kind === 'liability'} onclick={() => (kind = 'liability')}>
          Debo plata acá
          <span class="dim sm">tarjeta de crédito, préstamo</span>
        </button>
      </div>
    </fieldset>

    <fieldset>
      <legend class="dim">Moneda</legend>
      <div class="opts row2">
        {#each ['ARS', 'USD'] as u}
          <button type="button" class:on={unit === u} onclick={() => (unit = u)}>{u}</button>
        {/each}
      </div>
    </fieldset>

    {#if unit === 'USD'}
      <!-- ADR-011: la fuente de cotizacion es propiedad de la CUENTA.
           Los dolares comprados en blue se valuan con blue; los del broker con MEP. -->
      <fieldset>
        <legend class="dim">Con qué cotización se valúa</legend>
        <div class="opts row3">
          {#each [['', 'La de siempre'], ['blue', 'Blue'], ['mep', 'MEP'], ['ccl', 'CCL'], ['oficial', 'Oficial']] as [v, l]}
            <button type="button" class:on={fxSource === v} onclick={() => (fxSource = v)}>{l}</button>
          {/each}
        </div>
      </fieldset>
    {/if}

    <!-- Sugiere los bancos que ya usaste: "Macro" y "macro" serían dos grupos
         distintos en la pantalla de cuentas, y nadie se daría cuenta. Es el
         mismo riesgo que hizo descartar agrupar portafolios por institución
         (ADR-026), y acá se mitiga sin tabla nueva. -->
    <label><span class="dim">Dónde está (opcional)</span>
      <input bind:value={institution} list="bancos"
             placeholder="Santander, Balanz, Binance…" />
      <datalist id="bancos">
        {#each bancos as b}<option value={b}></option>{/each}
      </datalist>
      {#if bancos.length}
        <span class="dim sm pista">
          Si es de un banco que ya cargaste, elegilo de la lista: así quedan agrupadas.
        </span>
      {/if}
    </label>

    <button class="btn-primary" type="submit" disabled={busy || !name.trim()}>
      {busy ? 'Creando…' : 'Crear cuenta'}
    </button>
  </form>

  <p class="dim sm note">
    Los plazos fijos y las inversiones se registran distinto y llegan más adelante.
    Acá creás cuentas de las que entra y sale plata.
  </p>
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  label:not(.casilla) { display: flex; flex-direction: column; gap: .3rem; }
  label > span:first-child { font-size: .78rem; color: var(--text-dim); }
  fieldset { border: none; padding: 0; margin: 0; }
  legend { font-size: .85rem; margin-bottom: .35rem; }
  .opts { display: grid; gap: .5rem; }
  .opts.row2 { grid-template-columns: 1fr 1fr; }
  .opts.row3 { grid-template-columns: repeat(auto-fit, minmax(90px, 1fr)); }
  .opts button {
    display: flex; flex-direction: column; align-items: flex-start; gap: .15rem;
    padding: .7rem .85rem; min-height: var(--tap); text-align: left;
  }
  .opts.row2 button, .opts.row3 button { align-items: center; justify-content: center; }
  .opts button.on { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 12%, var(--surface)); }
  .sm { font-size: .76rem; }
  .note { margin-top: .5rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
