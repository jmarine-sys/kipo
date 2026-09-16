<script lang="ts">
  import { supabase } from '$lib/supabase';

  let email = $state('');
  let password = $state('');
  let code = $state('');
  let step = $state<'credentials' | 'totp'>('credentials');
  let factorId = $state<string | null>(null);
  let busy = $state(false);
  let error = $state<string | null>(null);

  /** ADR-008: el segundo factor es opcional por usuario, asi que hay que preguntarle
      a Supabase si ESTE usuario necesita subir de aal1 a aal2. */
  async function needsTotp(): Promise<boolean> {
    const { data, error: e } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (e || !data) return false;
    return data.nextLevel === 'aal2' && data.nextLevel !== data.currentLevel;
  }

  async function withPassword(event: SubmitEvent) {
    event.preventDefault();
    busy = true; error = null;
    try {
      const { error: e } = await supabase.auth.signInWithPassword({ email, password });
      if (e) throw e;

      if (await needsTotp()) {
        const { data, error: fe } = await supabase.auth.mfa.listFactors();
        if (fe) throw fe;
        const totp = data?.totp?.[0];
        if (!totp) throw new Error('Tu cuenta pide segundo factor pero no tiene ninguno cargado.');
        factorId = totp.id;
        step = 'totp';
      }
      // si no hace falta segundo factor, el layout redirige solo al detectar la sesion
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo iniciar sesión';
    } finally {
      busy = false;
    }
  }

  async function verifyTotp(event: SubmitEvent) {
    event.preventDefault();
    if (!factorId) return;
    busy = true; error = null;
    try {
      const { error: e } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
      if (e) throw e;
    } catch (e) {
      error = e instanceof Error ? e.message : 'Código incorrecto';
      code = '';
    } finally {
      busy = false;
    }
  }

  async function withGoogle() {
    busy = true; error = null;
    const { error: e } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin }
    });
    if (e) { error = e.message; busy = false; }
  }
</script>

<div class="page login">
  <header>
    <img class="mascota" src="/marca/kipo-saludo.svg" alt="" width="150" height="156" />
    <h1>Kipo</h1>
    <p class="dim">Tu dinero, en buenas manos.</p>
  </header>

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if step === 'credentials'}
    <form class="stack" onsubmit={withPassword}>
      <label>
        <span class="dim">Correo</span>
        <input type="email" bind:value={email} required autocomplete="email"
               inputmode="email" placeholder="vos@ejemplo.com" />
      </label>
      <label>
        <span class="dim">Contraseña</span>
        <input type="password" bind:value={password} required autocomplete="current-password" />
      </label>
      <button class="btn-primary" type="submit" disabled={busy}>
        {busy ? 'Entrando…' : 'Entrar'}
      </button>
    </form>

    <div class="sep"><span>o</span></div>
    <button onclick={withGoogle} disabled={busy}>Continuar con Google</button>

  {:else}
    <form class="stack" onsubmit={verifyTotp}>
      <p>Ingresá el código de tu aplicación de autenticación.</p>
      <input class="code" bind:value={code} required autocomplete="one-time-code"
             inputmode="numeric" pattern="[0-9]*" maxlength="6" placeholder="000000" />
      <button class="btn-primary" type="submit" disabled={busy || code.length < 6}>
        {busy ? 'Verificando…' : 'Verificar'}
      </button>
    </form>
  {/if}
</div>

<style>
  .login { max-width: 380px; padding-top: 5vh; }
  header { text-align: center; margin-bottom: 1.6rem; }
  .mascota { display: block; margin: 0 auto .4rem; width: 150px; height: auto; }
  header h1 { font-size: 2.2rem; letter-spacing: -0.035em; font-weight: 750; }
  header p { margin: .15rem 0 0; }

  label { display: flex; flex-direction: column; gap: .3rem; font-size: .85rem; }
  input {
    min-height: var(--tap);
    padding: 0 .85rem;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    width: 100%;
  }
  input:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }

  .code {
    text-align: center;
    font-size: 1.9rem;
    letter-spacing: .4em;
    text-indent: .4em;
    font-variant-numeric: tabular-nums;
    min-height: 62px;
  }

  .sep { display: flex; align-items: center; gap: .75rem; margin: 1.25rem 0 .75rem; color: var(--text-dim); font-size: .8rem; }
  .sep::before, .sep::after { content: ''; flex: 1; height: 1px; background: var(--border); }

  button { width: 100%; }
  .err {
    background: color-mix(in srgb, var(--neg) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--neg) 40%, transparent);
    color: var(--neg);
    padding: .7rem .85rem; border-radius: var(--radius); font-size: .88rem;
  }
</style>
