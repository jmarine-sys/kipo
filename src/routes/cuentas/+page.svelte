<script lang="ts">
  import Vacio from '$lib/Vacio.svelte';
  import { onMount } from 'svelte';
  import {
    listBalances, listCategories, createTransaction,
    archiveAccount, renameAccount, deleteAccount, setInstitution,
    listResumenTarjeta, type ResumenTarjeta
  } from '$lib/ledger/api';
  import { adjustment } from '$lib/ledger/entries';
  import { tipoDeCuenta, nombresRepetidos, esAmbigua } from '$lib/ledger/tipos';
  import Cuenta from '$lib/Cuenta.svelte';
  import { money, today } from '$lib/format';
  import type { AccountBalance, Category } from '$lib/types';

  let balances = $state<AccountBalance[]>([]);
  let categories = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let abierta = $state<string | null>(null);
  let cuotas = $state<ResumenTarjeta[]>([]);

  const cuotasDe = (id: string) => cuotas.filter((c) => c.account_id === id);

  const mesLargo = (iso: string) =>
    new Date(iso + 'T12:00:00').toLocaleDateString('es-AR', { month: 'long', year: 'numeric' });
  let nombre = $state('');
  let realRaw = $state('');
  let busy = $state(false);

  /** El modelo calcula por mecánica (ADR-012); la interfaz agrupa por intuición. */
  const GRUPOS = [
    { id: 'balance', titulo: 'Disponible',   pista: 'Plata que podés usar hoy' },
    { id: 'accrual', titulo: 'Inmovilizado', pista: 'Comprometido hasta su vencimiento' },
    { id: 'market',  titulo: 'Invertido',    pista: 'Se valúa a precio de mercado' }
  ] as const;

  /**
   * Dos formas de mirar la misma lista, y ninguna sobra — OD-37.
   *
   * Por tipo contesta "¿cuánto puedo gastar hoy?", que es el punto 8 del brief.
   * Por banco contesta "¿cuánto tengo en Macro?", que es como piensa el usuario:
   * un banco le da pesos, dólares y tarjeta, y en la app quedaban tres cuentas
   * sueltas sin ninguna relación visible.
   *
   * No se elige una: se ofrece el interruptor y que cada quien mire como quiera.
   */
  let vista = $state<'tipo' | 'banco'>('tipo');

  const porTipo = $derived(
    GRUPOS.map((g) => ({ id: g.id as string, titulo: g.titulo, pista: g.pista,
                         items: balances.filter((b) => b.valuation === g.id) }))
      .filter((g) => g.items.length)
  );

  const porBanco = $derived.by(() => {
    const mapa = new Map<string, typeof balances>();
    for (const b of balances) {
      const clave = b.institution?.trim() || '';
      mapa.set(clave, [...(mapa.get(clave) ?? []), b]);
    }
    // Las que no dicen dónde están van últimas: son un pendiente, no un grupo.
    return [...mapa.entries()]
      .sort(([a], [b]) => (a === '' ? 1 : b === '' ? -1 : a.localeCompare(b)))
      .map(([clave, items]) => ({
        id: clave || 'sin-banco',
        titulo: clave || 'Sin indicar dónde',
        pista: clave ? `${items.length} ${items.length === 1 ? 'cuenta' : 'cuentas'}`
                     : 'Poneles el banco y se agrupan solas',
        items
      }));
  });

  const grupos = $derived(vista === 'tipo' ? porTipo : porBanco);

  /** Solo tiene sentido ofrecer la vista por banco si hay algo que agrupar. */
  const hayBancos = $derived(new Set(balances.map((b) => b.institution?.trim()).filter(Boolean)).size > 0);

  /**
   * La categoría de ajustes se busca por su ROL, no por su nombre ni por
   * «is_system + tipo».
   *
   * Por el nombre fallaba al renombrarla. Por «is_system + gasto» funcionaba
   * mientras hubiera una sola de sistema por tipo, y ADR-032 agregó los aportes
   * entre libros: desde ahí, esa búsqueda podía devolver «Aporte a otro libro» y
   * el ajuste de saldo se habría registrado contra la categoría equivocada.
   */
  const catAjuste = $derived(categories.find((c) => c.system_role === 'ajuste') ?? null);

  const abierto = $derived(balances.find((b) => b.account_id === abierta) ?? null);
  const real = $derived(Number(realRaw.replace(/\./g, '').replace(',', '.')) || 0);
  const delta = $derived(abierto ? real - Number(abierto.balance) : 0);

  function abrir(b: AccountBalance) {
    if (abierta === b.account_id) { abierta = null; return; }
    abierta = b.account_id;
    nombre = b.name;
    banco = b.institution ?? '';
    realRaw = '';
    error = null;
  }

  async function load() {
    loading = true;
    try {
      [balances, categories] = await Promise.all([listBalances(), listCategories()]);
      // Accesorio: si falla, la pantalla sigue andando sin la proyección.
      listResumenTarjeta().then((r) => (cuotas = r)).catch(() => {});
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loading = false; }
  }

  let banco = $state('');

  /** Los bancos ya usados, para que 'Macro' y 'macro' no sean dos grupos. */
  const repetidos = $derived(nombresRepetidos(balances));

  const bancosUsados = $derived(
    [...new Set(balances.map((b) => b.institution?.trim()).filter(Boolean) as string[])].sort()
  );

  async function guardarBanco() {
    if (!abierto) return;
    busy = true; error = null;
    try { await setInstitution(abierto.account_id, banco); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo guardar'; }
    finally { busy = false; }
  }

  async function guardarNombre() {
    if (!abierto || !nombre.trim() || nombre.trim() === abierto.name) return;
    busy = true; error = null;
    try { await renameAccount(abierto.account_id, nombre); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo renombrar'; }
    finally { busy = false; }
  }

  /**
   * ADR-005: la válvula de escape de los saldos aproximados. No se "corrige" el
   * saldo a mano: se registra un movimiento contra Ajustes, así la deriva queda
   * MEDIDA y no escondida.
   */
  async function ajustar() {
    if (!abierto || !catAjuste || !delta) return;
    busy = true; error = null;
    try {
      await createTransaction(adjustment({
        accountId: abierto.account_id, adjustCategoryId: catAjuste.id,
        delta, unit: abierto.unit, date: today(), description: 'Ajuste de saldo'
      }));
      abierta = null; realRaw = '';
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo ajustar';
    } finally { busy = false; }
  }

  async function archivar(b: AccountBalance) {
    if (!confirm(`¿Archivar "${b.name}"? No se borra: sus movimientos quedan intactos.`)) return;
    busy = true;
    try { await archiveAccount(b.account_id); abierta = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
    finally { busy = false; }
  }

  async function borrar(b: AccountBalance) {
    if (!confirm(`¿Borrar "${b.name}" definitivamente? No tiene movimientos, así que no se pierde nada.`)) return;
    busy = true;
    try { await deleteAccount(b.account_id); abierta = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo borrar'; }
    finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread">
    <h1>Cuentas</h1>
    <div class="row altas">
      <a class="add" href="/cuentas/nueva">+ Cuenta</a>
    </div>
  </div>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#if hayBancos}
      <div class="vistas">
        {#each [['tipo', 'Por tipo'], ['banco', 'Por banco']] as [id, etiqueta]}
          <button class:on={vista === id}
                  onclick={() => (vista = id as typeof vista)}>{etiqueta}</button>
        {/each}
      </div>
    {/if}

    {#if !grupos.length}
      <Vacio titulo="Todavía no tenés cuentas."
             detalle="Una cuenta es cada lugar donde hay plata tuya: el efectivo, el banco, la tarjeta, los dólares. Cada gasto sale de una."
             href="/cuentas/nueva" accion="Crear la primera" />
    {/if}

    {#each grupos as g}
      <section class="card">
        <header><h2>{g.titulo}</h2> <span class="dim sm">{g.pista}</span></header>
        <ul>
          {#each g.items as b}
            <li>
              <button class="acc spread" onclick={() => abrir(b)}>
                <span class="nom">
                  <!-- La misma ficha que en el resto de la app: nombre, moneda,
                       y el banco solo cuando hay otra cuenta que se llama igual. -->
                  <Cuenta cuenta={b} ambigua={esAmbigua(b, repetidos)} />
                  <!-- El tipo va DEBAJO y en su propia línea, no al lado: al lado
                       se colapsaba cuando no entraba, y quedaba a veces arriba y
                       a veces abajo. Una lista se lee por su forma, y la forma no
                       puede depender del largo del nombre. -->
                  <span class="tipo dim">{tipoDeCuenta(b)}</span>
                </span>
                <b class="money" class:neg={Number(b.balance) < 0}>{money(b.balance, b.unit)}</b>
              </button>

              {#if abierta === b.account_id}
                <div class="panel stack">
                  <!-- OD-23: el saldo dice CUANTO debés; esto dice CUANDO. Con dos
                       compras en cuotas ya es imposible anticiparlo de memoria. -->
                  {#if b.kind === 'liability' && cuotasDe(b.account_id).length}
                    <div class="cuotas">
                      <h3>Lo que viene en cuotas</h3>
                      <ul class="meses">
                        {#each cuotasDe(b.account_id) as r}
                          <li class="spread">
                            <span class="cap">{mesLargo(r.mes)}</span>
                            <span class="dim sm">{r.cuotas} {r.cuotas === 1 ? 'cuota' : 'cuotas'}</span>
                            <b class="money">{money(r.total, r.unit)}</b>
                          </li>
                        {/each}
                      </ul>
                      <p class="dim sm">
                        No incluye los consumos de una sola cuota: esos ya están en el saldo.
                      </p>
                    </div>
                  {/if}
                  <label class="campo">
                    <span>Nombre</span>
                    <span class="row">
                      <input bind:value={nombre} />
                      <button class="btn-primary chico" disabled={busy || nombre.trim() === b.name || !nombre.trim()}
                              onclick={guardarNombre}>Guardar</button>
                    </span>
                  </label>

                  <!-- OD-37: con esto la vista "Por banco" se vuelve alcanzable.
                       Antes solo se podia poner al CREAR la cuenta, y la puesta
                       en marcha las crea sin banco. -->
                  <label class="campo">
                    <span>¿Dónde está? <span class="dim">agrupa tus cuentas por banco</span></span>
                    <span class="row">
                      <input bind:value={banco} list="bancos-usados"
                             placeholder="Santander, Mercado Pago, Balanz…" />
                      <button class="btn-primary chico"
                              disabled={busy || banco.trim() === (b.institution ?? '')}
                              onclick={guardarBanco}>Guardar</button>
                    </span>
                    <datalist id="bancos-usados">
                      {#each bancosUsados as x}<option value={x}></option>{/each}
                    </datalist>
                  </label>

                  {#if g.id === 'balance' && catAjuste}
                    <label class="campo">
                      <span>¿Cuánto dice en realidad?</span>
                      <input class="monto" inputmode="decimal" bind:value={realRaw}
                             placeholder={String(b.balance).split('.')[0]} />
                    </label>
                    {#if delta}
                      <p class="sm">
                        Se registra un ajuste de
                        <b class="money" class:neg={delta < 0} class:pos={delta > 0}>
                          {delta > 0 ? '+' : ''}{money(delta, b.unit)}
                        </b>
                        contra <em>{catAjuste.name}</em>, así la diferencia queda medida.
                      </p>
                      <button class="btn-primary" onclick={ajustar} disabled={busy}>
                        {busy ? 'Ajustando…' : 'Ajustar saldo'}
                      </button>
                    {/if}
                  {/if}

                  <div class="finales">
                    {#if b.movimientos === 0}
                      <button class="peligro" onclick={() => borrar(b)} disabled={busy}>Borrar</button>
                      <span class="dim sm">No tiene movimientos</span>
                    {:else}
                      <button class="peligro" onclick={() => archivar(b)} disabled={busy}>Archivar</button>
                      <span class="dim sm">
                        {b.movimientos} movimiento{b.movimientos === 1 ? '' : 's'}: no se puede borrar
                      </span>
                    {/if}
                  </div>
                </div>
              {/if}
            </li>
          {/each}
        </ul>
      </section>
    {/each}

    <p class="aprox">≈ Saldos estimados: no hay conciliación con el banco</p>
    <!-- Las categorías, los libros y las preferencias se mudaron a Ajustes: esta
         pantalla se estaba pareciendo más a una de configuración que a una de
         cuentas. Ver ADR-033. -->
    <a class="link" href="/ajustes">Ajustes →</a>


  {/if}
</div>

<style>
  .cuotas h3 { font-size: .85rem; margin: 0 0 .4rem; }
  .cuotas .meses { list-style: none; margin: 0 0 .4rem; padding: 0; display: grid; gap: .25rem; }
  .cuotas .meses li { align-items: baseline; gap: .5rem; }
  .cuotas .cap { text-transform: capitalize; }
  .cuotas p { margin: 0; }
  .nom { display: flex; flex-direction: column; align-items: flex-start; gap: .1rem; min-width: 0; }
  .nom .tipo { font-size: .72rem; }
  .vistas { display: grid; grid-template-columns: 1fr 1fr; gap: .4rem; margin-bottom: .2rem; }
  .vistas button { min-height: 40px; font-size: .85rem; }
  .vistas button.on {
    background: var(--accent); color: var(--accent-fg);
    border-color: transparent; font-weight: 600;
  }

  .altas { gap: .9rem; }
  .add { text-decoration: none; font-size: .86rem; font-weight: 600; white-space: nowrap; }
  header { margin-bottom: .6rem; }
  header h2 { display: inline; margin-right: .4rem; }
  .sm { font-size: .78rem; }
  ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: .3rem; }

  .acc { width: 100%; border: none; background: none; padding: .45rem 0; min-height: 42px; text-align: left; gap: .6rem; }
  .nom { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .acc b { white-space: nowrap; }

  .panel { padding: .8rem; margin: .2rem 0 .5rem; background: var(--surface-2); border-radius: 10px; }
  .campo .row { gap: .4rem; }
  .campo .row input { flex: 1; }
  .monto { text-align: right; font-size: 1.05rem; }
  .chico { min-height: 44px; padding: 0 .9rem; flex-shrink: 0; }
  .panel p { margin: 0; }

  .finales {
    display: flex; align-items: center; gap: .6rem; flex-wrap: wrap;
    padding-top: .6rem; border-top: 1px solid var(--border);
  }
  .peligro {
    color: var(--neg); background: none;
    border-color: color-mix(in srgb, var(--neg) 35%, transparent);
    min-height: 40px; padding: 0 .9rem;
  }

  .link { display: block; text-align: center; padding: .6rem; font-size: .9rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
