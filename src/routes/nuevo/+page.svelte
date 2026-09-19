<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { listAccounts, listCategories, createTransaction, cotizacionesVigentes } from '$lib/ledger/api';
  import { plausibilidad, type Cotizacion } from '$lib/ledger/plausibilidad';
  import { misLibros, cuentasDeLibro, aportarALibro } from '$lib/ledger/libros';
  import { createScheduled, FRECUENCIAS, type Frecuencia } from '$lib/ledger/recurrentes';
  import { nombresRepetidos, esAmbigua } from '$lib/ledger/tipos';
  import Cuenta from '$lib/Cuenta.svelte';
  import { expense, income, transfer, exchange, impliedRate } from '$lib/ledger/entries';
  import { money, today, shortDate, num } from '$lib/format';
  import { bump, byUse } from '$lib/frequent';
  import type { Account, Category } from '$lib/types';

  // Tres modos, no cuatro. "Transferir" y "Cambio" eran la misma intención —mover
  // plata de un lado a otro— y la diferencia (si cambia de moneda) la sabe la app
  // mirando las cuentas. Si el usuario tiene que preguntar en qué se diferencian,
  // la distinción no estaba en su cabeza: estaba en el modelo.
  type Mode = 'expense' | 'income' | 'move';
  const MODES: { id: Mode; label: string }[] = [
    { id: 'expense', label: 'Gasto' },
    { id: 'income',  label: 'Ingreso' },
    { id: 'move',    label: 'Mover' }
  ];

  let mode = $state<Mode>('expense');
  let raw = $state('');
  let raw2 = $state('');
  let accountId = $state<string | null>(null);
  let toAccountId = $state<string | null>(null);
  let categoryId = $state<string | null>(null);
  let date = $state(today());
  let note = $state('');
  let showNote = $state(false);
  let showAllCats = $state(false);
  let search = $state('');
  let busy = $state(false);
  let error = $state<string | null>(null);

  let accounts = $state<Account[]>([]);
  let categories = $state<Category[]>([]);
  let loaded = $state(false);

  const amount = $derived(num(raw));
  const amount2 = $derived(num(raw2));

  const payable = $derived(accounts.filter((a) => a.valuation === 'balance'));
  const sources = $derived(
    mode === 'income' ? payable.filter((a) => a.kind === 'asset')
    : mode === 'move' ? accounts
    : payable
  );
  const account = $derived(accounts.find((a) => a.id === accountId) ?? null);
  const toAccount = $derived(accounts.find((a) => a.id === toAccountId) ?? null);
  const destinations = $derived(accounts.filter((a) => a.id !== accountId));

  /**
   * Mover plata a una cuenta de OTRO libro — ADR-032.
   *
   * Vivía escondido en la pantalla de libros, y no era su lugar: la intención es
   * la misma que mover plata acá adentro, y dónde cae decide la mecánica. Es el
   * mismo criterio con el que «Transferir» y «Cambio» se fundieron en «Mover».
   *
   * Lo que cambia no es la intención sino la contabilidad: adentro del libro es
   * una transferencia y tu patrimonio no se mueve; hacia otro libro es un GASTO,
   * porque esa plata ya no la podés usar solo. Por eso se dice en la pantalla.
   */
  type Ajena = { id: string; name: string; unit: string; libro: string; libroNombre: string };
  let ajenas = $state<Ajena[]>([]);

  const ajenasPosibles = $derived(
    account ? ajenas.filter((a) => a.unit === account.unit) : []
  );
  const ajenaElegida = $derived(ajenas.find((a) => a.id === toAccountId) ?? null);

  // Los nombres que se repiten, para aclarar el banco SOLO donde hace falta.
  const repetidos = $derived(nombresRepetidos(accounts));

  // ---- categorías -----------------------------------------------------------
  const catKind = $derived(mode === 'income' ? 'income' : 'expense');
  const leaves = $derived(
    categories.filter((c) => c.kind === catKind && !categories.some((x) => x.parent_id === c.id))
  );
  /** Las seis más usadas cubren casi todo. El resto vive detrás de "Todas". */
  const top = $derived(byUse(leaves).slice(0, 6));
  const parentOf = (c: Category) => categories.find((p) => p.id === c.parent_id)?.name ?? null;
  const groups = $derived.by(() => {
    const q = search.trim().toLowerCase();
    const match = q
      ? leaves.filter((c) => c.name.toLowerCase().includes(q)
          || (parentOf(c) ?? '').toLowerCase().includes(q))
      : leaves;
    const map = new Map<string, Category[]>();
    for (const c of match) {
      const g = parentOf(c) ?? 'Sin agrupar';
      map.set(g, [...(map.get(g) ?? []), c]);
    }
    return [...map.entries()];
  });
  const chosen = $derived(categories.find((c) => c.id === categoryId) ?? null);

  // ---- mover: la app decide si es transferencia o cambio ---------------------
  const isExchange = $derived(
    mode === 'move' && !!account && !!toAccount && account.unit !== toAccount.unit
  );

  // ADR-004, los dos lados del ciclo de la tarjeta. La app tiene que decirlos en
  // voz alta: son el caso donde es más fácil contar el mismo gasto dos veces.
  const onCard    = $derived(mode === 'expense' && account?.kind === 'liability');
  const payingOff = $derived(mode === 'move' && toAccount?.kind === 'liability');
  const rate = $derived(isExchange && amount && amount2 ? impliedRate(amount, amount2) : null);

  // OD-21. La base no puede validar un tipo de cambio -cualquier cociente es
  // aritmeticamente valido- asi que el unico lugar donde se puede mirar es acá,
  // mientras se tipea. La REGLA vive en plausibilidad.ts, no en esta pantalla.
  /**
   * Adónde volver: a la pantalla que te trajo, o a Inicio.
   *
   * Lo manda quien abre el formulario (`?volver=`). No se usa `history.back()`
   * porque la entrada anterior puede ser de afuera de la app, y volver ahí sería
   * sacarte de kipo — y el usuario pidió que, ante la duda, sea siempre Inicio.
   */
  const volver = $derived.by(() => {
    const v = page.url.searchParams.get('volver');
    // Solo rutas internas: un `volver` con una URL de afuera sería una puerta
    // para mandar a alguien a cualquier lado desde un enlace.
    return v && v.startsWith('/') && !v.startsWith('//') ? v : '/';
  });

  let cuotas = $state(1);

  /**
   * «Esto se repite» — OD-43.
   *
   * Una casilla y no un cuarto modo. Registrar dice lo que YA PASÓ; una regla
   * programa lo que VA A PASAR. Son actos distintos, y ponerlos a la misma
   * altura en la fila de modos alargaría el camino de tres toques, que es el
   * criterio de éxito del MVP.
   *
   * Como casilla, en cambio, sigue el flujo natural: pagué el alquiler, y esto
   * se repite. Un solo acto para vos, dos registros para la app.
   */
  let repite = $state(false);
  let frecuencia = $state<Frecuencia>('monthly');

  /**
   * «¿Ya lo pagaste?» — la pregunta que faltaba, y la que unifica los dos
   * formularios (OD-44).
   *
   * Agenda tenía su propio alta de gastos fijos, casi igual a esta: qué es,
   * cuánto, cada cuánto, con qué cuenta. Lo único que las diferenciaba era si
   * además se registraba el movimiento — y eso es UNA pregunta, no otra
   * pantalla.
   *
   *   ya lo pagué   -> se registra el movimiento Y queda agendado
   *   todavía no    -> solo queda agendado, y la fecha es la PRIMERA vez
   */
  let yaPague = $state(true);

  /**
   * Atajos de fecha — OD-38, mudados acá al unificar los formularios.
   *
   * Vivían en el alta de Agenda, que dejó de existir. «Fin de mes» NO es un
   * atajo que escribe una fecha: enciende una regla en la base, porque
   * `31-ene + 1 mes` da 28-feb y de ahí en adelante se queda en 28 para siempre.
   */
  const ATAJOS = [
    { id: 'hoy', label: 'Hoy' }, { id: 'dia1', label: 'Día 1' },
    { id: 'dia10', label: 'Día 10' }, { id: 'quince', label: 'Día 15' },
    { id: 'fin', label: 'Fin de mes' }
  ] as const;

  function atajo(id: (typeof ATAJOS)[number]['id']) {
    const h = new Date();
    const [y, m, d] = [h.getFullYear(), h.getMonth(), h.getDate()];
    const iso = (f: Date) =>
      `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`;
    // Si el día ya pasó este mes, apunta al que viene: agendar algo para ayer no
    // es lo que nadie quiso decir.
    const dia = (n: number) => iso(new Date(y, n < d ? m + 1 : m, n));
    date = id === 'hoy' ? iso(h)
         : id === 'dia1' ? dia(1)
         : id === 'dia10' ? dia(10)
         : id === 'quince' ? dia(15)
         : iso(new Date(y, m + 1, 0));
  }
  const soloAgendar = $derived(repite && !yaPague);

  /** El último día de su mes: entonces la regla es «fin de mes», no «el 31». */
  const esFinDeMes = $derived.by(() => {
    const d = new Date(date + 'T12:00:00');
    return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate() === d.getDate();
  });

  /** La próxima vez, que es una después de la que acabás de cargar. */
  const proxima = $derived.by(() => {
    const d = new Date(date + 'T12:00:00');
    const saltos: Record<string, number> = {
      weekly: 0, monthly: 1, bimonthly: 2, quarterly: 3, biannual: 6, yearly: 12
    };
    if (frecuencia === 'weekly') d.setDate(d.getDate() + 7);
    else d.setMonth(d.getMonth() + saltos[frecuencia]);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  });
  let cotizaciones = $state<Cotizacion[]>([]);
  let rateOk = $state(false);           // "ya lo miré, es correcto"

  const sospecha = $derived(
    rate && account && toAccount
      ? plausibilidad(rate, account.unit, toAccount.unit, cotizaciones)
      : { estado: 'ok' as const }
  );

  // Cambiar el monto invalida la confirmación anterior: si no, confirmás un
  // número y guardás otro.
  $effect(() => { void rate; rateOk = false; });

  const ready = $derived.by(() => {
    if (!amount || !accountId) return false;
    if (mode === 'expense' || mode === 'income') return !!categoryId;
    if (!toAccountId) return false;
    if (ajenaElegida) return true;
    if (!isExchange) return true;
    if (!amount2) return false;
    return sospecha.estado !== 'sospechoso' || rateOk;
  });

  const LAST = 'kipo:last-account';
  function remember(id: string) {
    try { localStorage.setItem(`${LAST}:${mode}`, id); } catch { /* modo privado */ }
  }
  function recall() {
    try {
      const id = localStorage.getItem(`${LAST}:${mode}`);
      accountId = id && sources.some((a) => a.id === id) ? id : (sources[0]?.id ?? null);
    } catch { accountId = sources[0]?.id ?? null; }
  }

  onMount(async () => {
    // Agenda manda acá con ?repite=1: es el MISMO formulario, no otro.
    if (page.url.searchParams.get('repite')) { repite = true; yaPague = false; }
    try {
      [accounts, categories] = await Promise.all([listAccounts(), listCategories()]);
      recall();
      // En segundo plano: si no hay cotizaciones, el aviso no aparece y cargar
      // sigue siendo igual de rápido. Nunca debe demorar el formulario.
      cotizacionesVigentes(date).then((c) => (cotizaciones = c)).catch(() => {});

      // Y las cuentas de tus otros libros, si tenés más de uno. También en
      // segundo plano: el 99% de los movimientos no cruzan libros.
      misLibros()
        .then(async (ls) => {
          const otros = ls.filter((l) => !l.activo);
          const todas = await Promise.all(
            otros.map(async (l) => (await cuentasDeLibro(l.ledger_id)).map((c) => ({
              id: c.id, name: c.name, unit: c.unit, libro: l.ledger_id, libroNombre: l.name
            })))
          );
          ajenas = todas.flat();
        })
        .catch(() => {});
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo cargar';
    } finally { loaded = true; }
  });

  function setMode(m: Mode) {
    mode = m; categoryId = null; toAccountId = null; raw2 = ''; cuotas = 1;
    repite = false; yaPague = true;
    showAllCats = false; search = '';
    recall();
  }

  /** Enfoca al montar. Equivale a autofocus pero sin el atributo, que confunde
      a los lectores de pantalla al saltar el foco sin avisar. */
  function focusOnMount(node: HTMLInputElement) {
    node.focus();
  }

  function pickCat(id: string) {
    categoryId = id;
    showAllCats = false;
    search = '';
  }

  function tap(k: string) {
    if (k === '⌫') { raw = raw.slice(0, -1); return; }
    if (k === ',') { if (!raw.includes(',')) raw += raw ? ',' : '0,'; return; }
    if (raw.includes(',') && raw.split(',')[1].length >= 2) return;
    if (raw === '0') raw = '';
    raw += k;
  }

  async function save() {
    if (!ready || !accountId) return;
    busy = true; error = null;
    try {
      const unit = account!.unit;
      const common = { date, description: note || null };

      // Solo agendar: no hay movimiento que registrar todavía, y la fecha que
      // pusiste es la PRIMERA vez, no una que ya pasó.
      if (soloAgendar && categoryId) {
        await createScheduled({
          description: note?.trim() || categories.find((c) => c.id === categoryId)?.name || 'Gasto fijo',
          category_id: categoryId,
          account_id: accountId,
          amount,
          currency: unit,
          frequency: frecuencia,
          next_on: date,
          month_end: esFinDeMes && frecuencia !== 'weekly'
        });
        goto(volver === '/' ? '/recurrentes' : volver);
        return;
      }

      // Hacia otro libro no hay UN movimiento: son dos, uno en cada libro, y los
      // arma la base. No puede pasar por create_transaction.
      if (ajenaElegida) {
        await aportarALibro({
          destino: ajenaElegida.libro,
          cuentaOrigen: accountId,
          cuentaDestino: ajenaElegida.id,
          monto: Math.abs(amount),
          fecha: date,
          detalle: note || null
        });
        bump(accountId);
        goto(volver);
        return;
      }
      const input =
        mode === 'expense' ? expense({ accountId, categoryId: categoryId!, amount, unit, ...common,
                                       installments: onCard && cuotas > 1 ? cuotas : null })
      : mode === 'income'  ? income({ accountId, categoryId: categoryId!, amount, unit, ...common })
      : isExchange
        ? exchange({ fromId: accountId, fromAmount: amount, fromUnit: unit,
                     toId: toAccountId!, toAmount: amount2, toUnit: toAccount!.unit,
                     asTrade: toAccount!.valuation === 'market', ...common })
        : transfer({ fromId: accountId, toId: toAccountId!, amount, unit, ...common });

      await createTransaction(input);

      // Y la regla, si dijiste que se repite. Va DESPUÉS del movimiento a
      // propósito: si fallara, quedó registrado lo que pasó, que es lo que no
      // se puede perder. Una regla se vuelve a crear; un gasto olvidado, no.
      if (repite && mode === 'expense' && categoryId) {
        try {
          await createScheduled({
            description: note?.trim() || categories.find((c) => c.id === categoryId)?.name || 'Gasto fijo',
            category_id: categoryId,
            account_id: accountId,
            amount,
            currency: unit,
            frequency: frecuencia,
            next_on: proxima,
            month_end: esFinDeMes && frecuencia !== 'weekly'
          });
        } catch {
          // No se cancela el movimiento por esto: se avisa y listo.
          error = 'Se registró el gasto, pero no se pudo agendar la repetición.';
        }
      }
      remember(accountId);
      if (categoryId) bump(categoryId);
      goto(volver);
    } catch (e) {
      error = e instanceof Error ? e.message : 'No se pudo guardar';
      busy = false;
    }
  }
</script>

<div class="page">
  <div class="spread top">
    <a href={volver} class="back" aria-label="Volver">←</a>
    <input class="date" type="date" bind:value={date} />
  </div>

  <div class="modes" role="tablist">
    {#each MODES as m}
      <button role="tab" aria-selected={mode === m.id} class:on={mode === m.id}
              onclick={() => setMode(m.id)}>{m.label}</button>
    {/each}
  </div>

  <div class="amount">
    <span class="cur">{account?.unit ?? ''}</span>
    <span class="val money" class:empty={!raw}>{raw || '0'}</span>
  </div>

  {#if isExchange}
    <div class="second">
      <span class="dim">Recibís</span>
      <input class="money" inputmode="decimal" bind:value={raw2} placeholder="0" />
      <span class="dim">{toAccount?.unit}</span>
    </div>
    {#if rate}
      <p class="rate" class:dim={sospecha.estado !== 'sospechoso'}
         class:alerta={sospecha.estado === 'sospechoso'}>
        Te queda a <strong>{money(rate, account?.unit)}</strong> por {toAccount?.unit}
      </p>
    {/if}

    {#if sospecha.estado === 'sospechoso'}
      <!-- No bloquea: un tipo de cambio raro puede ser real y el usuario es quien
           sabe. Pero sí obliga a mirarlo una vez. -->
      <div class="revisar">
        <p>
          Ese tipo de cambio está
          <b>{sospecha.veces > 1 ? `${sospecha.veces.toFixed(0)} veces por encima` : `${(1 / sospecha.veces).toFixed(0)} veces por debajo`}</b>
          de lo que se operó ese día ({money(sospecha.min, account?.unit)} a {money(sospecha.max, account?.unit)}).
          ¿Te faltó o te sobró un cero?
        </p>
        <label class="casilla">
          <input type="checkbox" bind:checked={rateOk} />
          <span>Lo miré, es correcto</span>
        </label>
      </div>
    {/if}
  {/if}

  {#if error}<p class="err" role="alert">{error}</p>{/if}

  {#if !loaded}
    <p class="dim">Cargando…</p>
  {:else}
    {#if mode !== 'move'}
      <section>
        <h2 class="lbl">{mode === 'income' ? 'Origen' : 'Categoría'}</h2>

        {#if chosen && !showAllCats}
          <!-- Elegida: una sola ficha, y el resto se va del camino -->
          <div class="wrap">
            <button class="chip on" onclick={() => (showAllCats = true)}>
              {chosen.name}
              {#if parentOf(chosen)}<span class="tag">{parentOf(chosen)}</span>{/if}
              <span class="tag">cambiar</span>
            </button>
          </div>
        {:else if !showAllCats}
          <!-- Las de siempre primero: un toque cubre casi todos los gastos -->
          <div class="wrap">
            {#each top as c}
              <button class="chip" onclick={() => pickCat(c.id)}>{c.name}</button>
            {/each}
            {#if leaves.length > top.length}
              <button class="chip more" onclick={() => (showAllCats = true)}>Todas ▾</button>
            {/if}
          </div>
        {:else}
          <!-- Todas, agrupadas y con buscador: es lo que escala cuando crecen -->
          <div class="all">
            <input class="search" bind:value={search} placeholder="Buscar categoría…" use:focusOnMount />
            <div class="groups">
              {#each groups as [g, items]}
                <div class="group">
                  <h3>{g}</h3>
                  <div class="wrap">
                    {#each items as c}
                      <button class="chip" class:on={categoryId === c.id}
                              onclick={() => pickCat(c.id)}>{c.name}</button>
                    {/each}
                  </div>
                </div>
              {:else}
                <p class="dim sm">Nada coincide con «{search}».</p>
              {/each}
            </div>
            <button class="link" onclick={() => { showAllCats = false; search = ''; }}>Cerrar</button>
          </div>
        {/if}

        {#if mode === 'expense'}
          <label class="repite">
            <input type="checkbox" bind:checked={repite} />
            <span>
              Esto se repite
              <span class="dim sm bloque">
                Además de registrarlo, queda agendado para la próxima.
              </span>
            </span>
          </label>

          {#if repite}
            <div class="wrap frec">
              {#each FRECUENCIAS as f}
                <button class="chip chico" class:on={frecuencia === f.id}
                        onclick={() => (frecuencia = f.id)}>{f.label}</button>
              {/each}
            </div>
            {#if !yaPague}
              <div class="wrap">
                {#each ATAJOS as a}
                  <button class="chip chico" onclick={() => atajo(a.id)}>{a.label}</button>
                {/each}
              </div>
            {/if}

            <div class="wrap pagado">
              {#each [[true, 'Ya lo pagué'], [false, 'Todavía no']] as [v, l]}
                <button class="chip chico" class:on={yaPague === v}
                        onclick={() => (yaPague = v as boolean)}>{l}</button>
              {/each}
            </div>

            <p class="dim sm">
              {#if yaPague}
                Se registra ahora y queda agendado: la próxima cae el <b>{shortDate(proxima)}</b>.
              {:else}
                No se registra nada todavía. Queda agendado para el
                <b>{shortDate(date)}</b>, y lo vas a ver en <a href="/recurrentes">Agenda</a>.
              {/if}
              {#if esFinDeMes && frecuencia !== 'weekly'}
                Como la fecha es fin de mes, va a seguir cayendo el último día de cada mes.
              {/if}
            </p>
          {/if}
        {/if}
      </section>
    {/if}

    <section>
      <h2 class="lbl">
        {mode === 'expense' ? 'Pagás con' : mode === 'income' ? 'Entra en' : 'Desde'}
      </h2>
      <div class="wrap">
        {#each sources as a}
          <button class="chip" class:on={accountId === a.id}
                  onclick={() => { accountId = a.id; if (toAccountId === a.id) toAccountId = null; }}>
            <Cuenta cuenta={a} ambigua={esAmbigua(a, repetidos)} />
          </button>
        {:else}
          <!-- Sin esto la pantalla mostraba un hueco mudo y el boton de guardar
               no se habilitaba nunca. Un formulario que no se puede completar
               tiene que decir POR QUE y adonde ir. -->
          <p class="salida">
            Todavía no tenés ninguna cuenta de donde sacar la plata.
            <a href="/comenzar">Empecemos por ahí →</a>
          </p>
        {/each}
      </div>

      <!-- Solo con tarjeta, para no tocar el camino rápido: el 90% de los gastos
           no son en cuotas y no tienen que ver este campo. OD-23. -->
      {#if onCard}
        <div class="cuotas">
          <span class="dim sm">¿En cuántas cuotas?</span>
          <div class="wrap">
            {#each [1, 3, 6, 9, 12, 18] as n}
              <button class="chip chico" class:on={cuotas === n}
                      onclick={() => (cuotas = n)}>{n === 1 ? 'Una' : n}</button>
            {/each}
          </div>
          {#if cuotas > 1 && amount}
            <p class="dim sm">
              {cuotas} de <b>{money(amount / cuotas, account?.unit)}</b>.
              La deuda entra entera hoy — esto sirve para ver en qué resumen cae cada una.
            </p>
          {/if}
        </div>
      {/if}
    </section>

    {#if mode === 'move'}
      <section>
        <h2 class="lbl">Hacia</h2>
        <div class="wrap">
          {#each destinations as a}
            <button class="chip" class:on={toAccountId === a.id}
                    onclick={() => (toAccountId = a.id)}>
              <Cuenta cuenta={a} ambigua={esAmbigua(a, repetidos)} />
            </button>
          {:else}
            <p class="dim sm">No tenés otra cuenta a dónde mover.</p>
          {/each}
        </div>

        <!-- Las de tus otros libros, aparte y dichas como lo que son. Solo las
             de la misma moneda: un aporte no es un cambio. -->
        {#if ajenasPosibles.length}
          <h2 class="lbl otro">En otro libro tuyo</h2>
          <div class="wrap">
            {#each ajenasPosibles as a}
              <button class="chip ajena" class:on={toAccountId === a.id}
                      onclick={() => (toAccountId = a.id)}>
                <Cuenta cuenta={{ name: a.name, unit: a.unit }} />
                <span class="tag libro">{a.libroNombre}</span>
              </button>
            {/each}
          </div>
        {/if}
        {#if ajenaElegida}
          <p class="what aviso">
            Va a <em>{ajenaElegida.libroNombre}</em>, que es otro libro. Acá sale como
            <strong>gasto</strong>: esa plata ya no la podés usar solo. Allá entra como
            ingreso. Se registran los dos movimientos.
          </p>
        {:else if payingOff}
          <p class="what dim sm">
            Pagás deuda de {toAccount?.name}. <strong>No es un gasto</strong>: ya lo contaste
            cuando compraste. Tu patrimonio no cambia — baja la plata y baja la deuda.
          </p>
        {:else if toAccount}
          <p class="what dim sm">
            {#if isExchange}
              Cambiás {account?.unit} por {toAccount.unit}. No es un gasto: tu patrimonio
              queda igual, solo cambia de moneda.
            {:else if account && !account.is_spendable && toAccount.is_spendable}
              Sacás plata del broker. No es un ingreso: tu patrimonio queda igual —
              pero <strong>sube lo disponible</strong>, porque vuelve a estar a mano.
            {:else if account?.is_spendable && !toAccount.is_spendable}
              <!-- Decia solo "tu patrimonio queda igual", que es cierto y deja
                   afuera lo que importa: esa plata deja de estar disponible.
                   El usuario lo marco mandando plata a una cuenta comitente. -->
              Tu patrimonio queda igual, pero <strong>baja lo disponible</strong>:
              esa plata deja de estar a mano para gastar.
            {:else}
              Movés plata entre tus cuentas. No es un gasto: tu patrimonio queda igual.
            {/if}
          </p>
        {/if}
      </section>
    {/if}

    {#if showNote}
      <input class="note" bind:value={note} placeholder="Nota (opcional)" />
    {:else}
      <button class="link" onclick={() => (showNote = true)}>+ agregar nota</button>
    {/if}
  {/if}

  <div class="pad">
    {#each ['1','2','3','4','5','6','7','8','9',',','0','⌫'] as k}
      <button class="key" onclick={() => tap(k)}>{k}</button>
    {/each}
  </div>

  <button class="btn-primary save" onclick={save} disabled={!ready || busy}>
    {busy ? 'Guardando…' : soloAgendar ? 'Agendar' : 'Guardar'}
  </button>
</div>

<style>
  /* Sin padding-bottom propio: el global ya reserva lo que tapa la barra, y
     pisarlo aca fue lo que dejo el boton de guardar debajo de ella. */
  .top { margin-bottom: .75rem; }
  .back { font-size: 1.5rem; text-decoration: none; min-width: var(--tap); }
  .date {
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); min-height: 38px; padding: 0 .6rem; font-size: .85rem;
  }

  .modes { display: grid; grid-template-columns: repeat(3, 1fr); gap: .35rem; margin-bottom: 1rem; }
  .modes button { min-height: 44px; font-size: .9rem; border-radius: 10px; }
  .modes button.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 650; }

  .amount { display: flex; align-items: baseline; justify-content: center; gap: .5rem; padding: 1.1rem 0 .5rem; }
  .cur { color: var(--text-dim); font-size: 1rem; }
  .val { font-size: 2.9rem; font-weight: 600; letter-spacing: -0.02em; }
  .val.empty { color: var(--text-dim); }

  .second { display: flex; align-items: center; gap: .5rem; justify-content: center; margin-bottom: .4rem; }
  .second input {
    width: 8rem; text-align: right; font-size: 1.3rem;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); min-height: 44px; padding: 0 .6rem;
  }
  .rate { text-align: center; font-size: .82rem; margin: 0 0 .6rem; }
  .rate.alerta { color: var(--warn); font-weight: 600; }
  .revisar {
    margin: 0 0 .7rem; padding: .7rem .85rem; border-radius: 10px;
    background: color-mix(in srgb, var(--warn) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--warn) 40%, transparent);
    font-size: .84rem;
  }
  .revisar p { margin: 0 0 .5rem; }
  .revisar .casilla { display: flex; align-items: center; gap: .55rem; min-height: 40px; }

  section { margin-bottom: .9rem; }
  .lbl { font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--text-dim); margin-bottom: .45rem; }

  .chip {
    min-height: 42px; padding: 0 .85rem; border-radius: 999px; font-size: .88rem;
    display: inline-flex; align-items: center; gap: .4rem;
  }
  .chip.on { background: var(--accent); color: var(--accent-fg); border-color: transparent; font-weight: 600; }
  .chip.more { border-style: dashed; }
  .chip.ajena { border-style: dashed; }
  .chip .tag.libro { font-size: .66rem; padding: .05rem .3rem; border-radius: 4px;
                     background: color-mix(in srgb, var(--accent) 22%, transparent); }
  .lbl.otro { margin-top: .7rem; }
  .what.aviso {
    padding: .6rem .8rem; border-radius: 10px;
    background: color-mix(in srgb, var(--warn) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--warn) 35%, transparent);
    color: var(--text);
  }
  .salida {
    margin: 0; padding: .7rem .85rem; border-radius: 10px; font-size: .86rem;
    background: color-mix(in srgb, var(--warn) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--warn) 40%, transparent);
  }
  .salida a { display: inline-block; margin-top: .3rem; }
  .repite { display: flex; align-items: flex-start; gap: .6rem; margin-top: .8rem; }
  .pagado { margin-top: .5rem; }
  .bloque { display: block; }
  .frec { margin-top: .5rem; }
  .cuotas { margin-top: .7rem; display: flex; flex-direction: column; gap: .35rem; }
  .cuotas .chip.chico { min-height: 36px; padding: 0 .7rem; font-size: .82rem; }
  .cuotas p { margin: 0; }
  .tag { font-size: .68rem; opacity: .7; }
  .sm { font-size: .85rem; }
  .what { margin: .55rem 0 0; }

  .all { background: var(--surface-2); border-radius: var(--radius); padding: .7rem; }
  .search {
    width: 100%; min-height: 44px; padding: 0 .8rem; margin-bottom: .6rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: 10px;
  }
  .groups { max-height: 42vh; overflow-y: auto; display: flex; flex-direction: column; gap: .75rem; }
  .group h3 {
    font-size: .72rem; text-transform: uppercase; letter-spacing: .06em;
    color: var(--text-dim); margin-bottom: .35rem;
  }
  .link { border: none; background: none; color: var(--accent); padding: .4rem 0 0; min-height: 32px; font-size: .85rem; text-align: left; }

  .note {
    width: 100%; min-height: var(--tap); padding: 0 .85rem;
    background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius);
  }

  .pad { display: grid; grid-template-columns: repeat(3, 1fr); gap: .5rem; margin: 1rem 0; }
  .key { min-height: 56px; font-size: 1.3rem; background: var(--surface-2); }
  .save { width: 100%; min-height: 56px; font-size: 1.05rem; }

</style>
