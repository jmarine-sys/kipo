<script lang="ts">
  import { prefs, elegirTema, alternarPrivado, elegirObjetivo, type Tema } from '$lib/preferencias.svelte';
  import { signOut } from '$lib/session.svelte';

  /**
   * Ajustes — lo que se toca una vez y no se vuelve a mirar.
   *
   * Todo esto vivía en la pantalla de cuentas, que terminó pareciendo más una
   * pantalla de configuración que de cuentas. La regla de «todo a dos clicks»
   * está bien para lo que se usa seguido; aplicada a TODO, amontona en el camino
   * rápido cosas que se tocan una vez por año.
   */
</script>

<div class="page stack">
  <div class="spread">
    <a href="/" class="back" aria-label="Volver">←</a>
    <h1>Ajustes</h1>
    <span></span>
  </div>

  <section class="card stack">
    <h2>Tu dinero</h2>
    <a class="link" href="/categorias">Categorías →</a>
    <a class="link" href="/libros">Libros y personas →</a>
  </section>

  <section class="card stack">
    <h2>Cómo se ve</h2>

    <div>
      <span class="rotulo">Tema</span>
      <div class="temas">
        {#each [['auto','Automático'],['claro','Claro'],['oscuro','Oscuro']] as [id, etiqueta]}
          <button class:on={prefs.tema === id} onclick={() => elegirTema(id as Tema)}>
            {etiqueta}
          </button>
        {/each}
      </div>
      {#if prefs.tema === 'auto'}
        <p class="dim sm ayuda">Sigue lo que tenga configurado tu teléfono.</p>
      {/if}
    </div>

    <label class="casilla">
      <input type="checkbox" checked={prefs.privado} onchange={alternarPrivado} />
      <span>
        Ocultar los importes
        <span class="dim sm bloque">Los difumina en toda la app, para mirarla con gente al lado.</span>
      </span>
    </label>
  </section>

  <section class="card stack">
    <h2>Tu objetivo</h2>
    <label class="campo">
      <span>Cuánto querés que rindan tus inversiones por año</span>
      <span class="row">
        <input type="number" min="0" max="200" step="0.5" value={prefs.objetivo}
               oninput={(e) => elegirObjetivo(Number(e.currentTarget.value) || 0)} />
        <span class="dim">% anual</span>
      </span>
    </label>
    <p class="dim sm">
      Es contra lo que se compara el rendimiento en <a href="/cartera">Inversiones</a>.
    </p>
  </section>

  <button class="peligro" onclick={signOut}>Cerrar sesión</button>
</div>

<style>
  .back { font-size: 1.5rem; text-decoration: none; }
  h2 { font-size: .95rem; margin: 0; }
  .link { display: block; text-decoration: none; padding: .35rem 0; }
  .rotulo { font-size: .78rem; color: var(--text-dim); display: block; margin-bottom: .35rem; }
  .temas { display: grid; grid-template-columns: repeat(3, 1fr); gap: .35rem; }
  .temas button { min-height: 40px; font-size: .84rem; }
  .temas button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .casilla { display: flex; align-items: flex-start; gap: .6rem; }
  .bloque { display: block; }
  .campo { display: flex; flex-direction: column; gap: .3rem; }
  .campo > span:first-child { font-size: .78rem; color: var(--text-dim); }
  .row { display: flex; align-items: center; gap: .5rem; }
  .row input { max-width: 7rem; }
  .sm { font-size: .77rem; }
  .ayuda { margin: .35rem 0 0; }
</style>
