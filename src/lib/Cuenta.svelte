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
   *   la moneda   siempre, porque cambia lo que significa el número que escribís
   *   «tarjeta»   siempre que sea un pasivo: ahí gastar AUMENTA el saldo
   *   el banco    solo cuando hace falta para distinguirla de otra igual
   *
   * Lo último es deliberado. Poner el banco en todas alarga cada ficha y hace más
   * lento leer la lista, que es el camino rápido de la app; ponerlo solo cuando
   * hay ambigüedad resuelve el problema justo donde existe.
   */
  let {
    cuenta,
    ambigua = false
  }: {
    cuenta: { name: string; unit: string; kind?: string | null; institution?: string | null };
    /** true cuando otra cuenta comparte su nombre. Lo decide quien arma la lista. */
    ambigua?: boolean;
  } = $props();
</script>

<span class="cuenta">
  <span class="nombre">{cuenta.name}</span>
  <span class="tag unidad">{cuenta.unit}</span>
  {#if cuenta.kind === 'liability'}<span class="tag">tarjeta</span>{/if}
  {#if ambigua && cuenta.institution}<span class="tag banco">{cuenta.institution}</span>{/if}
</span>

<style>
  .cuenta { display: inline-flex; align-items: baseline; gap: .3rem; min-width: 0; }
  .nombre { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .tag {
    font-size: .66rem; padding: .05rem .3rem; border-radius: 4px;
    background: color-mix(in srgb, currentColor 14%, transparent);
    white-space: nowrap; opacity: .85; font-weight: 500;
  }
  .unidad { letter-spacing: .02em; }
  .banco { font-style: italic; }
</style>
