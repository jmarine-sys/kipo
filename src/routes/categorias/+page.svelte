<script lang="ts">
  import { onMount } from 'svelte';
  import {
    listCategoryUsage, createCategory, archiveCategory,
    renameCategory, deleteCategory
  } from '$lib/ledger/api';
  import { colorCategoria } from '$lib/categorias';
  import type { CategoryUsage } from '$lib/types';

  let cats = $state<CategoryUsage[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);
  let busy = $state(false);

  let tipo = $state<'income' | 'expense'>('expense');
  let abierta = $state<string | null>(null);
  let nombre = $state('');

  let nuevoNombre = $state('');
  let nuevoPadre = $state<string | null>(null);

  const madres = $derived(cats.filter((c) => !c.parent_id));
  const arbol = $derived(
    madres
      .filter((p) => p.kind === tipo)
      .map((p) => ({ ...p, hijas: cats.filter((c) => c.parent_id === p.category_id) }))
  );

  function abrir(c: CategoryUsage) {
    if (abierta === c.category_id) { abierta = null; return; }
    abierta = c.category_id;
    nombre = c.name;
    error = null;
  }

  async function load() {
    loading = true;
    try { cats = await listCategoryUsage(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  }

  async function guardarNombre(c: CategoryUsage) {
    if (!nombre.trim() || nombre.trim() === c.name) return;
    busy = true; error = null;
    try { await renameCategory(c.category_id, nombre); abierta = null; await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo renombrar'; }
    finally { busy = false; }
  }

  async function quitar(c: CategoryUsage) {
    const puede = c.movimientos === 0;
    const texto = puede
      ? `¿Borrar "${c.name}" definitivamente? No tiene movimientos, así que no se pierde nada.`
      : `¿Archivar "${c.name}"? Sus movimientos quedan intactos y la siguen mostrando.`;
    if (!confirm(texto)) return;
    busy = true; error = null;
    try {
      if (puede) await deleteCategory(c.category_id);
      else await archiveCategory(c.category_id);
      abierta = null;
      await load();
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo';
    } finally { busy = false; }
  }

  async function agregar(e: SubmitEvent) {
    e.preventDefault();
    busy = true; error = null;
    try {
      await createCategory({ name: nuevoNombre.trim(), kind: tipo, parent_id: nuevoPadre });
      nuevoNombre = ''; nuevoPadre = null;
      await load();
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo crear';
    } finally { busy = false; }
  }

  onMount(load);
</script>

<div class="page stack">
  <div class="spread"><a href="/cuentas" class="back">←</a><h1>Categorías</h1><span></span></div>

  <!-- ADR-012: "Ahorros" e "Inversiones" NO son categorías, son cuentas.
       Ponerlas acá reintroduciría el error que restaba el ahorro del resultado. -->
  <p class="dim sm">
    El ahorro y las inversiones no van acá: son <a href="/cuentas">cuentas</a>.
    Mover plata entre cuentas no es un gasto.
  </p>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  <div class="modos">
    {#each [['expense', 'Gastos'], ['income', 'Ingresos']] as [k, l]}
      <button class:on={tipo === k}
              onclick={() => { tipo = k as typeof tipo; abierta = null; nuevoPadre = null; }}>{l}</button>
    {/each}
  </div>

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#each arbol as p}
      <section class="card">
        <button class="fila madre" onclick={() => abrir(p)}>
          <i class="punto" style="background:{colorCategoria(p.name)}"></i>
          <b>{p.name}</b>
          <span class="uso dim">{p.movimientos || ''}</span>
        </button>
        {#if abierta === p.category_id}
          {@render editor(p)}
        {/if}

        {#if p.hijas.length}
          <ul>
            {#each p.hijas as c}
              <li>
                <button class="fila" onclick={() => abrir(c)}>
                  <span class="nom">{c.name}</span>
                  <span class="uso dim">{c.movimientos || ''}</span>
                </button>
                {#if abierta === c.category_id}
                  {@render editor(c)}
                {/if}
              </li>
            {/each}
          </ul>
        {/if}
      </section>
    {/each}

    <form class="card stack" onsubmit={agregar}>
      <h2>Agregar</h2>
      <input bind:value={nuevoNombre} required placeholder="Nombre" />
      <select bind:value={nuevoPadre}>
        <option value={null}>Sin agrupar (nivel principal)</option>
        {#each madres.filter((p) => p.kind === tipo && !p.is_system) as p}
          <option value={p.category_id}>Dentro de {p.name}</option>
        {/each}
      </select>
      <button class="btn-primary" type="submit" disabled={busy || !nuevoNombre.trim()}>Agregar</button>
    </form>
  {/if}
</div>

{#snippet editor(c: CategoryUsage)}
  <div class="panel stack">
    <label class="campo">
      <span>Nombre</span>
      <span class="row">
        <input bind:value={nombre} />
        <button class="btn-primary chico" disabled={busy || !nombre.trim() || nombre.trim() === c.name}
                onclick={() => guardarNombre(c)}>Guardar</button>
      </span>
    </label>

    {#if c.is_system}
      <!-- Renombrarlas es seguro: el código las busca por lo que SON
           (is_system + tipo), nunca por su nombre. -->
      <p class="dim sm">
        La usa el sistema para registrar los ajustes de saldo. Podés renombrarla,
        pero no quitarla.
      </p>
    {:else}
      <div class="finales">
        <button class="peligro" onclick={() => quitar(c)} disabled={busy}>
          {c.movimientos === 0 ? 'Borrar' : 'Archivar'}
        </button>
        <span class="dim sm">
          {c.movimientos === 0
            ? 'No tiene movimientos'
            : `${c.movimientos} movimiento${c.movimientos === 1 ? '' : 's'}: no se puede borrar`}
        </span>
      </div>
    {/if}
  </div>
{/snippet}

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .sm { font-size: .8rem; }
  .modos { display: grid; grid-template-columns: 1fr 1fr; gap: .4rem; }
  .modos button { min-height: 44px; border-radius: 10px; }
  .modos button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }

  .fila {
    display: flex; align-items: center; gap: .5rem;
    width: 100%; border: none; background: none; text-align: left;
    padding: .4rem 0; min-height: 42px;
  }
  .fila.madre { padding-bottom: .5rem; }
  .nom { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .fila b { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .uso { font-size: .74rem; flex-shrink: 0; font-variant-numeric: tabular-nums; }
  .punto { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }

  ul { list-style: none; margin: 0; padding: 0 0 0 .85rem; display: flex; flex-direction: column;
       border-left: 2px solid var(--border); }

  .panel { padding: .8rem; margin: .2rem 0 .5rem; background: var(--surface-2); border-radius: 10px; }
  .panel p { margin: 0; }
  .campo .row { gap: .4rem; }
  .campo .row input { flex: 1; }
  .chico { min-height: 44px; padding: 0 .9rem; flex-shrink: 0; }
  .finales { display: flex; align-items: center; gap: .6rem; flex-wrap: wrap; }
  .peligro {
    color: var(--neg); background: none;
    border-color: color-mix(in srgb, var(--neg) 35%, transparent);
    min-height: 40px; padding: 0 .9rem;
  }

  h2 { font-size: .95rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
