<script lang="ts">
  /**
   * Estado vacío, uno solo para toda la app.
   *
   * Distingue dos situaciones que se parecen y no son lo mismo:
   *
   *   "todavía no hay nada"  → invita a crear. El personaje suma.
   *   "nada coincide"        → hay que cambiar el filtro. Una ilustración grande
   *                            estorba: lo que hace falta es quitar el filtro.
   */
  let {
    titulo,
    detalle = null,
    href = null,
    accion = null,
    /** false cuando es un resultado de búsqueda vacío, no un comienzo */
    conMascota = true,
    onaccion = null
  }: {
    titulo: string;
    detalle?: string | null;
    href?: string | null;
    accion?: string | null;
    conMascota?: boolean;
    onaccion?: (() => void) | null;
  } = $props();
</script>

<div class="vacio card" class:compacto={!conMascota}>
  {#if conMascota}
    <img class="ilustracion" src="/marca/kipo-duda.svg" alt="" width="150" height="141" />
  {/if}
  <p class="titulo">{titulo}</p>
  {#if detalle}<p class="detalle dim">{detalle}</p>{/if}
  {#if accion && href}
    <a class="btn-primary accion" {href}>{accion}</a>
  {:else if accion && onaccion}
    <button class="btn-primary accion" onclick={onaccion}>{accion}</button>
  {/if}
</div>

<style>
  /* El componente ES la tarjeta. Envolverlo en otra sumaba los dos rellenos. */
  .vacio { text-align: center; padding: 1.6rem 1rem; }
  .vacio.compacto { padding: 1.9rem 1rem; }
  .ilustracion { width: 150px; margin-bottom: .6rem; }
  .titulo { margin: 0; font-size: .95rem; }
  .detalle { margin: .35rem 0 0; font-size: .84rem; }
  .accion {
    display: inline-block; text-decoration: none;
    margin-top: .9rem; padding: .75rem 1.2rem; border-radius: var(--radius);
  }
</style>
