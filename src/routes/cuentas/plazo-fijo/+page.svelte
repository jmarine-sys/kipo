<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { listBalances } from '$lib/ledger/api';
  import { crearPlazoFijo, tasaImplicita, diasEntre } from '$lib/ledger/inversiones';
  import { money, today } from '$lib/format';
  import type { AccountBalance } from '$lib/types';

  let cuentas = $state<AccountBalance[]>([]);
  let error = $state<string | null>(null);
  let busy = $state(false);

  let nombre = $state('');
  let desdeId = $state<string | null>(null);
  let capitalRaw = $state('');
  let esperadoRaw = $state('');
  let vence = $state('');
  let institucion = $state('');
  const fecha = today();

  const num = (s: string) => Number(s.replace(/\./g, '').replace(',', '.')) || 0;
  const capital = $derived(num(capitalRaw));
  const esperado = $derived(num(esperadoRaw));

  /** De donde puede salir el capital: plata disponible, no otra inversión. */
  const origenes = $derived(cuentas.filter((c) => c.valuation === 'balance' && c.kind === 'asset'));
  const origen = $derived(cuentas.find((c) => c.account_id === desdeId) ?? null);

  const dias = $derived(vence ? diasEntre(fecha, vence) : 0);
  const interes = $derived(esperado > capital ? esperado - capital : 0);
  const tna = $derived(tasaImplicita(capital, esperado, dias));

  const listo = $derived(
    !!nombre.trim() && !!desdeId && capital > 0 && esperado > capital && dias > 0
  );

  onMount(async () => {
    try { cuentas = await listBalances(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
  });

  async function crear(e: SubmitEvent) {
    e.preventDefault();
    if (!listo || !desdeId) return;
    busy = true; error = null;
    try {
      await crearPlazoFijo({
        nombre: nombre.trim(), desdeId, capital, vence, esperado,
        institucion: institucion.trim() || null, fecha
      });
      goto('/cuentas');
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo constituir';
      busy = false;
    }
  }
</script>

<div class="page stack">
  <div class="spread">
    <a href="/cuentas" class="back" aria-label="Volver">←</a>
    <h1>Nuevo plazo fijo</h1>
    <span></span>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  <form class="card stack" onsubmit={crear}>
    <label class="campo"><span>Cómo lo llamás</span>
      <input bind:value={nombre} required placeholder="Plazo fijo 90 días" />
    </label>

    <label class="campo"><span>Sale de</span>
      <select bind:value={desdeId} required>
        <option value={null} disabled>Elegí una cuenta</option>
        {#each origenes as c}
          <option value={c.account_id}>{c.name} · {money(c.balance, c.unit)}</option>
        {/each}
      </select>
    </label>

    <div class="row dos">
      <label class="campo"><span>Capital</span>
        <input class="monto" inputmode="decimal" bind:value={capitalRaw} required placeholder="1000000" />
      </label>
      <label class="campo"><span>Vence el</span>
        <input type="date" bind:value={vence} required min={fecha} />
      </label>
    </div>

    <label class="campo"><span>Cuánto vuelve al vencimiento</span>
      <input class="monto" inputmode="decimal" bind:value={esperadoRaw} required placeholder="1090000" />
    </label>

    <label class="campo"><span>Dónde (opcional)</span>
      <input bind:value={institucion} placeholder="Santander" />
    </label>

    {#if interes && dias > 0}
      <!-- La tasa no se guarda: se deduce de capital, monto final y plazo. Es el
           número con el que se comparan las ofertas, así que conviene verlo
           mientras se carga, no después. -->
      <p class="resumen">
        Ganás <b class="money pos">{money(interes, origen?.unit ?? 'ARS')}</b> en {dias} días
        {#if tna}· equivale a una tasa anual de <b>{tna.toFixed(1)}%</b>{/if}
      </p>
    {/if}

    <button class="btn-primary" type="submit" disabled={busy || !listo}>
      {busy ? 'Constituyendo…' : 'Constituir'}
    </button>
  </form>

  <p class="dim sm nota">
    La plata sale de tu cuenta y queda inmovilizada: tu patrimonio no cambia, pero
    baja lo disponible. El día del vencimiento te va a aparecer en la Agenda para
    registrar la vuelta.
  </p>
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .sm { font-size: .82rem; }
  .dos { gap: .5rem; align-items: flex-end; }
  .dos > .campo { flex: 1; }
  .monto { text-align: right; }
  .resumen {
    margin: 0; padding: .7rem .85rem; border-radius: 10px;
    background: var(--surface-2); font-size: .88rem;
  }
  .nota { margin-top: .2rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
