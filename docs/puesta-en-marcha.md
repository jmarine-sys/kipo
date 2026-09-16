# Puesta en marcha

Guía para dejar kipo funcionando. Unos 20 minutos.

> **Ojo con el orden.** El paso 6 (crear los usuarios) tiene que ir **después** del 4
> (aplicar las migraciones): el alta de usuario dispara un trigger que crea el libro y
> las categorías. Si creás un usuario antes, se queda sin nada.

---

## 1. Crear el proyecto en Supabase

1. Entrá a [supabase.com](https://supabase.com) y creá una cuenta.
2. **New project**. Plan **Free**.
3. Elegí la región más cercana — **South America (São Paulo)** para Argentina.
4. Guardá la contraseña de la base que te muestra: **la vas a necesitar en el paso 8 y no
   se vuelve a mostrar.**

Tarda un par de minutos en aprovisionarse.

## 2. Copiar las credenciales

En **Project Settings → API Keys**:

| Qué copiar | Dónde va |
|---|---|
| **Project URL** (`https://xxxx.supabase.co`) | `PUBLIC_SUPABASE_URL` |
| **Publishable key** (`sb_publishable_…`) | `PUBLIC_SUPABASE_PUBLISHABLE_KEY` |

**No copies la `secret key`.** Esa nunca entra al navegador.

> Si el panel todavía muestra `anon` y `service_role`, son las claves legadas —
> Supabase las da de baja a fines de 2026. Usá la publishable; hace exactamente lo mismo.

Y una aclaración que importa: **la publishable key es pública por diseño.** Va compilada
dentro del JavaScript que sirve el navegador y cualquiera puede leerla. La seguridad no
viene de ocultarla, viene de RLS aplicado en la base
([ADR-007](ADRs.md#adr-007--el-backend-es-supabase)). Si dependiera del secreto de la
clave, el modelo estaría mal.

## 2 bis. Ajustar la exposición de la base — [ADR-020](ADRs.md#adr-020--los-permisos-del-data-api-son-explícitos-y-anon-no-tiene-ninguno)

En **Project Settings → Data API**. **Dos de los tres van al revés de como vienen:**

| Interruptor | De fábrica | Dejalo en | Por qué |
|---|---|---|---|
| **Enable Data API** | activado | ✅ **activado** | `supabase-js` lo necesita. No hay servidor propio por el que pasar |
| **Automatically expose new tables** | activado | ❌ **desactivado** | De fábrica, un pedido **sin autenticar** tiene privilegios sobre tus tablas y lo único que lo detiene es RLS. Los permisos los da `20260915120000_grants.sql` |
| **Enable automatic RLS** | apagado | ✅ **activado** | Hace imposible crear una tabla sin RLS. Es gratis |

**Por qué importa el del medio.** La publishable key es pública por diseño: va compilada
dentro del JavaScript que cualquiera puede leer. Con la configuración de fábrica, cualquiera
con tu URL queda a **un solo error de política** de tus finanzas. Desactivándolo hay dos
candados: `anon` no llega ni a la tabla, y recién después RLS decide qué filas ve un usuario.

> El RLS automático solo afecta a las tablas **nuevas**. Las 11 actuales ya lo tienen
> activado explícitamente en `20260915100200_rls.sql`; el interruptor es una red para el futuro.

> Con la exposición automática apagada, **toda tabla nueva necesita su `GRANT` en una
> migración**. Si te olvidás, la app falla con *permiso denegado*. Es el modo correcto de
> fallar: ruidoso en desarrollo, en vez de silencioso y expuesto.

## 3. Crear el archivo `.env`

```bash
cp .env.example .env
```

Y completalo con lo del paso 2. **`.env` está en `.gitignore`: nunca se sube.**

## 4. Aplicar las migraciones

Son todos los archivos de `supabase/migrations/`, **en orden alfabético** — el nombre empieza con
la fecha justamente para que ordenar por nombre sea ordenar por tiempo.

> **No los enumero acá a propósito.** Esta lista ya se desactualizó una vez y la aplicación rompió en
> producción con *Could not find the table `public.upcoming`*. Una lista escrita a mano al lado de un
> directorio que crece se desincroniza siempre; la pregunta es solo cuándo.

### Opción A — el CLI de Supabase *(recomendada)*

```bash
npm i -g supabase
supabase login
supabase link --project-ref <la-ref-de-tu-proyecto>   # está en la URL del panel
supabase db push
```

### Opción B — a mano, desde el panel

En **SQL Editor**, pegá y ejecutá cada archivo en orden alfabético. Si ya tenés una base andando y
solo faltan las últimas, generá el paquete:

```bash
./scripts/pendientes.sh 20260916140000   # la primera que te falta
```

Deja `supabase/pendientes.sql` con esas migraciones concatenadas y con la lista en el encabezado.
Se pega entero y es idempotente: correrlo dos veces no rompe nada.

## 5. Comprobar que quedó bien

En el **SQL Editor**:

```sql
select count(*) from information_schema.tables
 where table_schema = 'public' and table_type = 'BASE TABLE';
-- tiene que dar 11

select count(*) from pg_policies where schemaname = 'public';
-- tiene que dar 11: una por tabla. Si da menos, RLS no aplicó en alguna.

select count(*) from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public';
-- tiene que dar 0. Si da más, anon llega a tus tablas.
```

Los dos últimos son los que importan. **Una tabla sin política es una tabla que cualquiera
puede leer**, y **un privilegio para `anon` es una puerta antes de la puerta.**

## 6. Crear los usuarios

En **Authentication → Users → Add user**, uno por persona (son tres).
Marcá **Auto Confirm User** para saltear la confirmación por correo.

Cada alta dispara el trigger de `20260915100300_bootstrap.sql`, que crea automáticamente
su libro, sus 20 categorías y la cuenta *Efectivo ARS*. Comprobalo:

```sql
select count(*) from ledger;    -- uno por usuario
select count(*) from category;  -- 20 por usuario
```

## 7. Opcionales de acceso — [ADR-008](ADRs.md#adr-008--la-autenticación-ofrece-email-contraseña-google-y-totp-opcional)

**Google:** en **Authentication → Providers → Google**, activalo y cargá el Client ID y
Secret de Google Cloud Console. En Google, la *Authorized redirect URI* es
`https://xxxx.supabase.co/auth/v1/callback`.

**Segundo factor (TOTP):** en **Authentication → Multi-Factor**, activá TOTP. Cada persona
decide si lo usa; el acceso ya lo detecta y pide el código solo a quien lo tenga.

## 8. El respaldo — [OD-16](ODs.md)

**Esto no es opcional.** El plan gratuito de Supabase **no incluye backups ni recuperación
punto-en-el-tiempo**. Sin este paso, tu historial financiero no tiene ninguna red.

### 8.1 Conseguir la cadena de conexión

En el panel, botón **Connect** arriba a la derecha *(antes estaba en Project Settings →
Database; Supabase lo movió)*. Se abre un modal con varias cadenas.

> ### ⚠️ Elegí la del **Session pooler**, no la *Direct connection*
>
> La *Direct connection* (`db.xxxx.supabase.co`) resuelve a **IPv6**, salvo que pagues el
> complemento de IPv4. **Los runners de GitHub Actions son IPv4 únicamente**, así que el
> respaldo fallaría con *network unreachable* — en silencio, todos los días, hasta que un
> día la necesites.
>
> La del **Session pooler** es compatible con IPv4 y se ve así:
>
> ```
> postgresql://postgres.<project-ref>:[YOUR-PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres
> ```
>
> **El puerto tiene que ser 5432.** Si ves `6543` estás mirando el *Transaction pooler*, que
> no sirve para `pg_dump`: no mantiene la sesión que el volcado necesita.

Reemplazá `[YOUR-PASSWORD]` por la contraseña de la base del paso 1.

### 8.2 Cargarla como secreto

En GitHub: **Settings → Secrets and variables → Actions → New repository secret**

- Nombre: `SUPABASE_DB_URL`
- Valor: la cadena completa del session pooler

### 8.3 Las cotizaciones usan el mismo secreto

El flujo **Cotizaciones** guarda a diario el dólar y la UVA, que es lo que permite
medir el rendimiento en dólares o en poder adquisitivo. Usa el mismo
`SUPABASE_DB_URL`, así que no hace falta configurar nada más.

**Una vez, al empezar**, conviene cargar el histórico: pestaña **Actions →
Cotizaciones → Run workflow**, y en *desde* poné la fecha de tu movimiento de
inversión más viejo. Trae todas las fechas intermedias.

### 8.4 Probarlo

Pestaña **Actions → Respaldo de la base → Run workflow**.

El flujo vuelca la base, **la restaura en una base limpia y comprueba que las 11 tablas
estén** antes de guardar nada. Un respaldo que nunca restauraste no es un respaldo.
Después corre solo todos los días y conserva los últimos 30.

Si falla con *network unreachable* o *connection timed out*, casi seguro copiaste la
*Direct connection*. Volvé a 8.1.

## 9. Levantar la aplicación

```bash
npm install
npm run dev
```

En `http://localhost:5173`. Entrá con uno de los usuarios del paso 6.

**La prueba de fuego** — abrila en el celular y cronometrate:

> Registrar un gasto cotidiano tiene que llevarte **menos de diez segundos**.

Si no lo logra, el problema está en la interfaz y hay que arreglarlo ahí. Ese número, y no
otro, es el criterio de éxito del MVP.

## 10. Publicar en Cloudflare Workers

### Qué es, en dos minutos

Cloudflare hace acá **una sola cosa**: guarda archivos estáticos y los sirve rápido desde
todas partes.

La analogía que mejor funciona: **Cloudflare es la vidriera, Supabase es la caja fuerte.**
La vidriera está replicada en cientos de ciudades para que abra rápido desde donde estés;
la caja fuerte es una sola, en São Paulo, y es donde están las cosas de valor.

Lo que pasa al publicar:

1. Conectás el repositorio de GitHub.
2. En **cada push a `main`**, Cloudflare clona el repo, corre `npm run build` y se queda con
   lo que quedó en `build/` — HTML, CSS y JS. Nada más.
3. Copia esos archivos a sus centros de datos repartidos por el mundo.
4. Cuando abrís la app, te llegan del más cercano.

**Cloudflare nunca ve tus datos.** No hay servidor ni base de datos ahí: los archivos llegan
al navegador, y desde ahí el navegador habla directo con Supabase. Por eso el plan gratuito
alcanza y va a seguir alcanzando — servir archivos quietos es baratísimo y el ancho de banda
es ilimitado en todos sus planes.

> ### Por qué Workers y no Pages
>
> Si buscás **"Workers & Pages"** en el panel **no lo vas a encontrar**: Cloudflare
> reorganizó. Textual de su documentación:
>
> > *"¿Seguro que querés usar Pages? Workers cubre la mayoría de los casos de Pages y ofrece
> > más funcionalidad. Es la plataforma principal de Cloudflare. **Empezá los proyectos
> > nuevos con Workers.**"*
>
> Pages sigue funcionando pero está en mantenimiento. Buscá **Workers** en la barra lateral
> (Cloudflare le cambió el nombre hace poco, así que puede decir *Compute*).

### Opción A — conectar el repositorio *(recomendada)*

En [dash.cloudflare.com](https://dash.cloudflare.com) → **Workers** → **Create** →
**Import a repository** → elegí `kipo`.

| Campo | Valor |
|---|---|
| Build command | `npm run build` |
| Deploy command | `npx wrangler deploy` |
| Path / root directory | *(vacío)* |

Y las variables de entorno, que son lo que más se olvida:

| Nombre | Valor |
|---|---|
| `PUBLIC_SUPABASE_URL` | tu URL de Supabase |
| `PUBLIC_SUPABASE_PUBLISHABLE_KEY` | tu `sb_publishable_…` |
| `NODE_VERSION` | `22` |

**Las dos primeras no son opcionales.** SvelteKit las incrusta **en el momento de compilar**,
no al ejecutar: sin ellas la compilación falla. La tercera evita que Cloudflare use una
versión de Node vieja.

Desde ahí, **cada push a `main` publica solo**.

#### Las dos opciones del formulario

| Opción | Viene | Dejala en | Por qué |
|---|---|---|---|
| **Builds for non-production branches** | activada | ✅ **como viene** | Hoy no hace nada porque solo hay `main`. El día que quieras probar un cambio sin tocar la app que usás a diario, una rama con su URL propia vale oro |
| **Protect with Cloudflare Access** | apagada | ✅ **prendela** | Sin ella cada rama genera una URL **pública**. Solo afecta a los previews: **no** agrega un segundo login en producción |

> ### ⚠️ Un preview NO es un sandbox
>
> Los builds de ramas usan **las mismas variables de entorno** que producción, así que una
> rama de prueba **escribe en tu base real**.
>
> Sirve perfecto para probar interfaz. **No** la uses para probar migraciones, borrados ni
> nada que escriba distinto — eso va contra tus datos de verdad. Un sandbox real exigiría un
> segundo proyecto de Supabase con sus propias variables. Registrado en
> [OD-25](ODs.md).

### Opción B — desde tu máquina

Si los nombres del panel no coinciden con lo de arriba —Cloudflare los mueve seguido— este
camino no depende de ninguna etiqueta:

```bash
npx wrangler login      # abre el navegador para autorizar
npm run build
npx wrangler deploy
```

Sirve para publicar la primera vez y verificar que todo anda. Después conviene igual
conectar el repositorio para no depender de tu máquina.

### El archivo que hace que funcione

`wrangler.jsonc` ya está en el repositorio y tiene lo único que Cloudflare necesita saber:

```jsonc
"assets": {
  "directory": "./build",
  "not_found_handling": "single-page-application"
}
```

Fijate que **no hay `main`**: no existe ningún script de Worker, solo archivos. Eso es lo que
corresponde según [ADR-017](ADRs.md#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa)
y además no genera invocaciones facturables.

Y `not_found_handling` es lo que evita un síntoma desconcertante: **sin eso, entrar por la
home anda pero recargar en `/movimientos` devuelve 404** — porque ese archivo no existe, la
app decide qué mostrar del lado del cliente.

> ### No agregues un archivo `_redirects`
>
> Es el mecanismo equivalente en Netlify, y en Cloudflare **rompe el despliegue**: la regla
> `/* /index.html 200` se rechaza con *"Infinite loop detected"*, porque Cloudflare normaliza
> `/index.html` a `/` y la regla vuelve a matchearse a sí misma.
>
> Este proyecto tuvo ese archivo y hubo que sacarlo. **Si algún día publicás en Netlify**,
> creá ahí un `static/_redirects` con `/*  /index.html  200` — pero solo entonces, y sacando
> `not_found_handling`. Dos mecanismos para lo mismo no son redundancia: son un conflicto
> esperando.

### Después de publicar

**Si activaste Google** (paso 7): en Supabase, **Authentication → URL Configuration**, agregá
tu URL de `.workers.dev` a *Redirect URLs*. Si no, el acceso con Google vuelve a ningún lado.

**Instalala en el celular:** abrí la URL y usá *Agregar a pantalla de inicio*. Queda como una
app, con su ícono y sin barra de direcciones.

---

## Lo que conviene saber antes de empezar a usarla en serio

| | |
|---|---|
| **Se pausa sola** | Si nadie la abre durante 7 días, Supabase pausa el proyecto y **hay que reactivarlo a mano desde el panel** ([OD-10](ODs.md), [OD-15](ODs.md)) |
| **Los saldos son estimados** | No hay conciliación bancaria. La app lo dice en pantalla ([ADR-005](ADRs.md#adr-005--los-saldos-son-aproximados-no-hay-conciliación-bancaria)) |
| **Necesita señal** | Es PWA instalable, no funciona sin conexión ([ADR-006](ADRs.md#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first)) |
| **Borrar todo es un comando** | `supabase/reset_ledger.sql` sirve **solo en la etapa de prueba**. Después de la puesta en marcha, nada impide correrlo y perder todo ([OD-22](ODs.md)) |
