#!/usr/bin/env bash
# Corre las migraciones y toda la bateria contra un Postgres descartable en Docker.
# No toca ningun entorno real. Uso:  ./supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

# Una asercion que falla NO puede terminar en "TODO VERDE". Cada bloque escribe
# aca lo que imprime, y al final se revisa si aparecio algun FALLO.
FALLOS=$(mktemp); trap 'rm -f "$FALLOS"' EXIT
mirar() { tee -a "$FALLOS"; }

# Un ERROR de psql se iba por el desague. Estos archivos se leen con
# grep '^(ok|FALLO)' y el error empieza con "psql:archivo:linea: ERROR:", asi
# que no matchea: la asercion desaparecia de la lista y nadie lo notaba, porque
# el contador de aserciones solo sube.
#
# Paso de verdad: la vista `dolar_en_uso` quedo sin su GRANT y rls_probe no podia
# leerla. La unica senial fue una linea que no estaba.
#
# NO se puede fallar ante cualquier ERROR: en estos archivos los errores son
# parte de la prueba -'No tenes tantas unidades', una FK que tiene que saltar-.
# Lo que se busca es la otra clase: la prueba rota, no el modelo rechazando.
# Un permiso que falta, una tabla o columna que no existe, un error de sintaxis.
# Ninguno de esos lo puede producir una regla de negocio.
ROTO='permission denied|does not exist|no existe|syntax error|undefined|cannot be cast'

correr() {
  local archivo=$1
  local salida; salida=$(psql -h localhost -p "$PORT" -U postgres -qtA -f "$archivo" 2>&1)
  local rotos; rotos=$(grep -E "^psql:.*ERROR:.*($ROTO)" <<<"$salida" || true)
  if [ -n "$rotos" ]; then
    echo "FALLO  $archivo no corrio entero:" | mirar
    sed 's/^/         /' <<<"$rotos" | mirar
  fi
  grep -E '^(ok|FALLO)' <<<"$salida" | mirar
}

PORT=${PORT:-55432}
NAME=kipo-pg-test
export PGPASSWORD=x
psql_run() { psql -h localhost -p "$PORT" -U postgres -v ON_ERROR_STOP=1 -q -f "$1"; }

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" -e POSTGRES_PASSWORD=x -p "$PORT":5432 postgres:16-alpine >/dev/null

# pg_isready da verde mientras postgres todavia se reinicia durante initdb.
# La unica espera confiable es una consulta real que devuelva.
ready=0
for _ in $(seq 1 60); do
  if psql -h localhost -p "$PORT" -U postgres -tAc 'select 1' >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ] || { echo "postgres no levanto a tiempo"; exit 1; }

echo "== migraciones =="
psql_run supabase/tests/00_auth_stub.sql          # stub de auth, solo para tests
for f in supabase/migrations/*.sql; do
  echo "   $(basename "$f")"; psql_run "$f"
done

echo "== casos de uso (modelo-de-datos.md §5) =="
psql_run supabase/tests/01_use_cases.sql >/dev/null

echo "== saldos y resultado del mes =="
psql_run supabase/tests/02_assertions.sql 2>&1 | grep -oP '(?<=NOTICE:  ).*' | mirar

echo "== invariantes: lo que el modelo debe RECHAZAR =="
psql_run supabase/tests/03_invariants.sql 2>&1 | grep -oP '(?<=NOTICE:  ).*' | mirar

echo "== aislamiento entre usuarios (RLS) =="
psql_run supabase/tests/04_rls.sql 2>&1 | grep -oP '(?<=NOTICE:  ).*' | mirar

echo "== escritura atomica de movimientos (RPC) =="
# no usa ON_ERROR_STOP: los errores son parte del test (deben ocurrir)
# -tA: sin encabezados ni alineacion, para que los asserts salgan pelados.
# sin ON_ERROR_STOP: los errores son parte del test (deben ocurrir).
correr supabase/tests/05_rpc.sql


echo "== permisos del Data API (anon vs authenticated) =="
psql_run supabase/tests/06_grants.sql 2>&1 | grep -oP '(?<=NOTICE:  ).*' | mirar

echo "== renombrar y borrar cuentas y categorias =="
correr supabase/tests/07_borrado.sql

echo "== gastos recurrentes =="
correr supabase/tests/08_recurrentes.sql

echo "== plazos fijos =="
correr supabase/tests/09_plazos_fijos.sql

echo "== posiciones de mercado =="
correr supabase/tests/10_posiciones.sql

echo "== medicion en dolares y poder adquisitivo =="
correr supabase/tests/11_medicion.sql

echo "== flujos y valuacion de la cartera =="
correr supabase/tests/12_cartera.sql

echo "== CEDEARs: rendimiento del activo vs movimiento del dolar =="
correr supabase/tests/13_cedears.sql

echo "== el portafolio es el borde: que cuenta como aporte y que no =="
correr supabase/tests/14_portafolios.sql

echo "== libros compartidos: invitar, cambiar, y NO mezclar =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/15_libros.sql 2>&1 | grep -oP '^(ok|FALLO).*|(?<=NOTICE:  )(ok|FALLO).*' | mirar

# Un archivo de prueba que nadie invoca es una prueba que no existe, y el
# contador de aserciones no baja: se queda igual, que es peor. Paso de verdad:
# un bloque nuevo fue a parar a "09_recurrentes.sql" -que no existia- en vez de
# "08_recurrentes.sql", y la suite siguio en verde con cuatro aserciones menos de
# las que creia tener.
sueltos=0
for f in supabase/tests/[0-9][0-9]_*.sql; do
  case "$(basename "$f")" in 00_*) continue;; esac
  grep -q "$(basename "$f")" supabase/tests/run.sh || {
    echo "FALLO SUELTO: $(basename "$f") existe y nadie lo corre" | mirar
    sueltos=1
  }
done

echo
if grep -q 'FALLO' "$FALLOS"; then
  echo "HAY FALLOS:"
  grep 'FALLO' "$FALLOS" | sed 's/^/  /'
  exit 1
fi
echo "TODO VERDE"
