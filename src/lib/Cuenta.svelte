<script lang="ts">
  /**
   * Cómo se nombra una cuenta — en un solo lugar.
   *
   * Se mostraban distinto en cada pantalla: en una el nombre pelado, en otra con
   * la etiqueta «tarjeta», en otra con la moneda. Y el nombre solo no alcanza:
   * «Caja de ahorro» puede ser la de pesos o la de dólares, y podés tener dos con
   * el mismo nombre en bancos distintos.
   *
   * QUÉ SE MUESTRA Y POR QUÉ:
   *   la moneda   SIEMPRE, porque cambia lo que significa el número que escribís
   *   «tarjeta»   cuando es un pasivo y la pantalla no lo dice de otra forma:
   *               ahí gastar AUMENTA el saldo, y eso hay que avisarlo
   *   el banco    depende de la pantalla, y por eso es un parámetro
   *
   * Lo del banco es la parte discutida. En la lista de cuentas va siempre: es
   * donde vas a distinguir una de otra. En el camino rápido —elegir cuenta al
   * registrar— va solo cuando dos se llaman igual, porque ahí cada carácter de
   * más hace más lenta la lectura, y ese camino es el criterio de éxito del MVP.
   */
  let {
    cuenta,
    ambigua = false,
    tarjeta = true,
    banco = 'ambigua'
  }: {
    cuenta: { name: string; unit: string; kind?: string | null; institution?: string | null };
    /** true cuando otra cuenta comparte su nombre. Lo decide quien arma la lista. */
    ambigua?: boolean;
    /** Mostrar «tarjeta». Se apaga donde el tipo ya está escrito debajo. */
    tarjeta?: boolean;
    /** Cuándo mostrar el banco. En la lista de cuentas, siempre. */
    banco?: 'ambigua' | 'siempre' | 'nunca';
  } = $props();

  const muestraBanco = $derived(
    banco === 'siempre' ? !!cuenta.institution
    : banco === 'nunca' ? false
    : ambigua && !!cuenta.institution
  );
</script>

<span class="cuenta">
  <span class="nombre">{cuenta.name}</span>
  <span class="tag unidad">{cuenta.unit}</span>
  {#if tarjeta && cuenta.kind === 'liability'}<span class="tag">tarjeta</span>{/if}
  {#if muestraBanco}<span class="tag banco">{cuenta.institution}</span>{/if}
</span>

<style>
  /* El nombre se achica y las etiquetas nunca: si la fila no entra, lo que se
     recorta es el nombre —que se puede adivinar— y no la moneda ni el banco, que
     son justo lo que distingue una cuenta de otra. */
  .cuenta { display: inline-flex; align-items: baseline; gap: .3rem; min-width: 0; max-width: 100%; }
  .nombre { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; flex: 0 1 auto; }
  .tag {
    flex: 0 0 auto;
    font-size: .66rem; padding: .05rem .3rem; border-radius: 4px;
    background: color-mix(in srgb, currentColor 14%, transparent);
    white-space: nowrap; opacity: .85; font-weight: 500;
  }
  .unidad { letter-spacing: .02em; }
  .banco { font-style: italic; }
</style>
