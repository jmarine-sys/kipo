<script lang="ts">
  import Cuenta from '$lib/Cuenta.svelte';
  import { nombresRepetidos, esAmbigua } from '$lib/ledger/tipos';
  import { byUse } from '$lib/frequent';
  import type { Account } from '$lib/types';

  /**
   * Elegir una cuenta — el mismo trato que las categorías.
   *
   * Eran todas las cuentas como fichas, en fila. Funciona con cuatro y deja de
   * funcionar con doce, que es exactamente lo que pasó con las categorías: una
   * lista larga de fichas no es un selector, es una lista.
   *
   * Se ofrecen unas pocas y el resto por buscador. El orden no es alfabético:
   *
   *   1. las que más usás, que es lo que hace que un toque alcance
   *   2. entre iguales, las de ARS primero — es la moneda del día a día y en la
   *      que se carga casi todo
   */
  let {
    cuentas,
    valor = null,
    onelegir,
    vacio = 'No hay ninguna cuenta para esto.'
  }: {
    cuentas: Account[];
    valor?: string | null;
    onelegir: (id: string) => void;
    vacio?: string;
  } = $props();

  const TOPE = 5;

  let buscando = $state(false);
  let busca = $state('');

  const repetidos = $derived(nombresRepetidos(cuentas));
  const elegida = $derived(cuentas.find((c) => c.id === valor) ?? null);


  /** Las más usadas, con las de ARS adelante entre las que empatan en uso. */
  const sugeridas = $derived.by(() => {
    // `byUse` ya las ordenó por cuánto se usan. Acá solo se adelantan las de
    // ARS entre las que empatan, sin romper ese orden: el índice original
    // desempata, así que una cuenta muy usada en dólares no cae al final.
    const usadas = byUse(cuentas);
    const pesa = (c: Account) => (c.unit === 'ARS' ? 0 : 1);
    return usadas
      .map((c, i) => ({ c, i }))
      .sort((a, b) => pesa(a.c) - pesa(b.c) || a.i - b.i)
      .slice(0, TOPE)
      .map((x) => x.c);
  });

  const coinciden = $derived(
    cuentas.filter((c) =>
      !busca.trim() ||
      `${c.name} ${c.unit} ${c.institution ?? ''}`.toLowerCase().includes(busca.trim().toLowerCase()))
  );

  function elegir(id: string) {
    onelegir(id);
    buscando = false;
    busca = '';
  }

  /** Enfoca el buscador al abrirlo: si lo abriste es porque vas a escribir. */
  function focoAlMontar(el: HTMLInputElement) {
    el.focus();
  }
</script>

{#if !cuentas.length}
  <p class="dim sm">{vacio}</p>
{:else if elegida && !buscando}
  <!-- Elegida: una sola ficha y el resto se va del camino. -->
  <div class="wrap">
    <button class="chip on" onclick={() => (buscando = true)}>
      <Cuenta cuenta={elegida} ambigua={esAmbigua(elegida, repetidos)} />
      <span class="tag">cambiar</span>
    </button>
  </div>
{:else if !buscando}
  <div class="wrap">
    {#each sugeridas as c}
      <button class="chip" onclick={() => elegir(c.id)}>
        <Cuenta cuenta={c} ambigua={esAmbigua(c, repetidos)} />
      </button>
    {/each}
    {#if cuentas.length > sugeridas.length}
      <button class="chip more" onclick={() => (buscando = true)}>Todas ▾</button>
    {/if}
  </div>
{:else}
  <div class="todas">
    <input class="search" bind:value={busca} use:focoAlMontar
           placeholder="Buscar por nombre, moneda o banco…" />
    <div class="wrap">
      {#each coinciden as c}
        <button class="chip" class:on={valor === c.id} onclick={() => elegir(c.id)}>
          <Cuenta cuenta={c} ambigua={esAmbigua(c, repetidos)} banco="siempre" />
        </button>
      {:else}
        <p class="dim sm">Nada coincide con «{busca}».</p>
      {/each}
    </div>
    <button class="link" onclick={() => { buscando = false; busca = ''; }}>Cerrar</button>
  </div>
{/if}

<style>
  .wrap { display: flex; flex-wrap: wrap; gap: .4rem; }
  .chip {
    min-height: 42px; padding: 0 .85rem; border-radius: 999px; font-size: .88rem;
    display: inline-flex; align-items: center; gap: .4rem; max-width: 100%;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .chip.more { border-style: dashed; }
  .tag {
    font-size: .66rem; padding: .05rem .3rem; border-radius: 4px;
    background: color-mix(in srgb, currentColor 16%, transparent);
  }
  .todas { display: flex; flex-direction: column; gap: .5rem; }
  .search { width: 100%; }
  .link { background: none; border: none; align-self: flex-start; padding: .2rem 0; min-height: 0; }
</style>
