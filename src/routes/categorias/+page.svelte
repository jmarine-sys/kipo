<script lang="ts">
  import { onMount } from 'svelte';
  import { listCategories, createCategory, archiveCategory } from '$lib/ledger/api';
  import type { Category } from '$lib/types';

  let cats = $state<Category[]>([]);
  let loading = $state(true);
  let error = $state<string | null>(null);

  let name = $state('');
  let kind = $state<'income' | 'expense'>('expense');
  let parentId = $state<string | null>(null);
  let busy = $state(false);

  const parents = $derived(cats.filter((c) => !c.parent_id));
  const tree = $derived(
    parents
      .filter((p) => p.kind === kind)
      .map((p) => ({ ...p, children: cats.filter((c) => c.parent_id === p.id) }))
  );

  async function load() {
    loading = true;
    try { cats = await listCategories(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo cargar'; }
    finally { loading = false; }
  }

  async function add(e: SubmitEvent) {
    e.preventDefault();
    busy = true; error = null;
    try {
      await createCategory({ name: name.trim(), kind, parent_id: parentId });
      name = ''; parentId = null;
      await load();
    } catch (err) {
      error = err instanceof Error ? err.message : 'No se pudo crear';
    } finally { busy = false; }
  }

  async function archive(c: Category) {
    if (c.is_system) return;
    if (!confirm(`¿Archivar "${c.name}"? Sus movimientos quedan intactos.`)) return;
    try { await archiveCategory(c.id); await load(); }
    catch (e) { error = e instanceof Error ? e.message : 'No se pudo archivar'; }
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

  {#if error}<p class="err">{error}</p>{/if}

  <div class="modes">
    {#each [['expense', 'Gastos'], ['income', 'Ingresos']] as [k, l]}
      <button class:on={kind === k} onclick={() => { kind = k as typeof kind; parentId = null; }}>{l}</button>
    {/each}
  </div>

  {#if loading}
    <p class="dim">Cargando…</p>
  {:else}
    {#each tree as p}
      <section class="card">
        <div class="spread grp">
          <b>{p.name}</b>
          {#if !p.is_system}<button class="x" onclick={() => archive(p)} aria-label="Archivar">✕</button>{/if}
        </div>
        {#if p.children.length}
          <ul>
            {#each p.children as c}
              <li class="spread">
                <span>{c.name}</span>
                <button class="x" onclick={() => archive(c)} aria-label="Archivar">✕</button>
              </li>
            {/each}
          </ul>
        {/if}
      </section>
    {/each}

    <form class="card stack" onsubmit={add}>
      <h2>Agregar</h2>
      <input bind:value={name} required placeholder="Nombre" />
      <select bind:value={parentId}>
        <option value={null}>Sin agrupar (nivel principal)</option>
        {#each parents.filter((p) => p.kind === kind && !p.is_system) as p}
          <option value={p.id}>Dentro de {p.name}</option>
        {/each}
      </select>
      <button class="btn-primary" type="submit" disabled={busy || !name.trim()}>Agregar</button>
    </form>
  {/if}
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h1 { font-size: 1.15rem; }
  .sm { font-size: .8rem; }
  .modes { display: grid; grid-template-columns: 1fr 1fr; gap: .4rem; }
  .modes button { min-height: 42px; border-radius: 10px; }
  .modes button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }
  .grp { margin-bottom: .4rem; }
  ul { list-style: none; margin: 0; padding: 0 0 0 .85rem; display: flex; flex-direction: column; gap: .35rem;
       border-left: 2px solid var(--border); }
  .x { border: none; background: none; color: var(--text-dim); min-height: 32px; min-width: 32px; padding: 0; }
  input, select {
    width: 100%; min-height: var(--tap); padding: 0 .85rem;
    background: var(--surface-2); border: 1px solid var(--border); border-radius: var(--radius);
  }
  h2 { font-size: .95rem; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg); padding: .7rem .85rem; border-radius: var(--radius);
  }
</style>
