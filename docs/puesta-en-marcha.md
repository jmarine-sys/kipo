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

## 3. Crear el archivo `.env`

```bash
cp .env.example .env
```

Y completalo con lo del paso 2. **`.env` está en `.gitignore`: nunca se sube.**

## 4. Aplicar las migraciones

Son seis archivos en `supabase/migrations/`, y **hay que aplicarlos en orden**.

### Opción A — el CLI de Supabase *(recomendada)*

```bash
npm i -g supabase
supabase login
supabase link --project-ref <la-ref-de-tu-proyecto>   # está en la URL del panel
supabase db push
```

### Opción B — a mano, desde el panel

En **SQL Editor**, pegá y ejecutá cada archivo **en este orden**:

1. `20260915100000_schema.sql` — las 11 tablas
2. `20260915100100_invariants.sql` — triggers y la vista de saldos
3. `20260915100200_rls.sql` — el aislamiento entre usuarios
4. `20260915100300_bootstrap.sql` — el alta de usuario
5. `20260915110000_rpc.sql` — escritura atómica
6. `20260915110100_views.sql` — la vista de lectura

## 5. Comprobar que quedó bien

En el **SQL Editor**:

```sql
select count(*) from information_schema.tables
 where table_schema = 'public' and table_type = 'BASE TABLE';
-- tiene que dar 11

select count(*) from pg_policies where schemaname = 'public';
-- tiene que dar 11: una por tabla. Si da menos, RLS no aplicó en alguna.
```

Ese segundo número es el importante. **Una tabla sin política es una tabla que cualquiera
puede leer.**

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

1. **Project Settings → Database → Connection string → URI**. Copiala y reemplazá
   `[YOUR-PASSWORD]` por la contraseña del paso 1.
2. En GitHub: **Settings → Secrets and variables → Actions → New repository secret**
   - Nombre: `SUPABASE_DB_URL`
   - Valor: la cadena completa
3. Probalo a mano: pestaña **Actions → Respaldo de la base → Run workflow**.

El flujo vuelca la base, **la restaura en una base limpia y comprueba que las 11 tablas
estén** antes de guardar nada. Un respaldo que nunca restauraste no es un respaldo.
Después corre solo todos los días y conserva los últimos 30.

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

## 10. Publicar

```bash
npm run build     # queda en build/
```

Es un sitio estático: se sube igual a Cloudflare Pages, Vercel o GitHub Pages
([ADR-017](ADRs.md#adr-017--el-frontend-es-sveltekit-con-adapter-static-en-modo-spa)).
Acordate de cargar las dos variables de entorno también en el hosting.

Y si activaste Google, agregá la URL publicada en **Authentication → URL Configuration →
Redirect URLs**.

---

## Lo que conviene saber antes de empezar a usarla en serio

| | |
|---|---|
| **Se pausa sola** | Si nadie la abre durante 7 días, Supabase pausa el proyecto y **hay que reactivarlo a mano desde el panel** ([OD-10](ODs.md), [OD-15](ODs.md)) |
| **Los saldos son estimados** | No hay conciliación bancaria. La app lo dice en pantalla ([ADR-005](ADRs.md#adr-005--los-saldos-son-aproximados-no-hay-conciliación-bancaria)) |
| **Necesita señal** | Es PWA instalable, no funciona sin conexión ([ADR-006](ADRs.md#adr-006--la-app-requiere-conexión-pwa-instalable-pero-no-offline-first)) |
| **Borrar todo es un comando** | `supabase/reset_ledger.sql` sirve **solo en la etapa de prueba**. Después de la puesta en marcha, nada impide correrlo y perder todo ([OD-22](ODs.md)) |
