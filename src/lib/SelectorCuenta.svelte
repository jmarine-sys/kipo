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

  /**
   * Tres, no cinco.
   *
   * Esta pantalla busca ser ágil, no completa: la ficha de una cuenta lleva
   * nombre, moneda y a veces banco, así que tres ya ocupan una fila entera en un
   * teléfono. El resto está a un toque en «Todas», que además busca entre TODAS
   * y no solo entre las que aparecen.
   */
  const TOPE = 3;

  let buscando = $state(false);
  let busca = $state('');

  const repetidos = $derived(nombresRepetidos(cuentas));
  const elegida = $derived(cuentas.find((c) => c.id === valor) ?? null);


  /**
   * Las más usadas, con las de ARS adelante entre las que empatan en uso.
   *
   * La elegida SIEMPRE está en la fila, aunque no entre en las tres primeras.
   * Antes, cuando había una elegida, la fila se reemplazaba por una sola ficha
   * con «cambiar» — y como el formulario recuerda la última cuenta usada, al
   * entrar NUNCA se veían las sugerencias. Parecía que el selector no existía
   * en «Pagás con» y sí en «Hacia», que es donde no hay nada recordado.
   *
   * Recordar la cuenta se queda: es lo que sostiene el camino de tres toques.
   * Lo que se va es esconder el resto.
   */
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

  /** Lo que se dibuja: las sugeridas, y la elegida si quedó afuera. */
  const enPantalla = $derived(
    elegida && !sugeridas.some((c) => c.id === elegida.id)
      ? [elegida, ...sugeridas].slice(0, TOPE + 1)
      : sugeridas
  );

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
{:else if !buscando}
  <div class="wrap">
    {#each enPantalla as c}
      <button class="chip" class:on={valor === c.id} onclick={() => elegir(c.id)}>
        <Cuenta cuenta={c} ambigua={esAmbigua(c, repetidos)} />
      </button>
    {/each}
    {#if cuentas.length > enPantalla.length}
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
  .todas { display: flex; flex-direction: column; gap: .5rem; }
  .search { width: 100%; }
  .link { background: none; border: none; align-self: flex-start; padding: .2rem 0; min-height: 0; }
</style>
