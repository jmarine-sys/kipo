#!/usr/bin/env bash
# Corre las migraciones y toda la bateria contra un Postgres descartable en Docker.
# No toca ningun entorno real. Uso:  ./supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

# Una asercion que falla NO puede terminar en "TODO VERDE". Cada bloque escribe
# aca lo que imprime, y al final se revisa si aparecio algun FALLO.
FALLOS=$(mktemp); trap 'rm -f "$FALLOS"' EXIT
mirar() { tee -a "$FALLOS"; }

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
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/05_rpc.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar


echo "== permisos del Data API (anon vs authenticated) =="
psql_run supabase/tests/06_grants.sql 2>&1 | grep -oP '(?<=NOTICE:  ).*' | mirar

echo "== renombrar y borrar cuentas y categorias =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/07_borrado.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== gastos recurrentes =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/08_recurrentes.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== plazos fijos =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/09_plazos_fijos.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== posiciones de mercado =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/10_posiciones.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== medicion en dolares y poder adquisitivo =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/11_medicion.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== flujos y valuacion de la cartera =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/12_cartera.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo "== CEDEARs: rendimiento del activo vs movimiento del dolar =="
psql -h localhost -p "$PORT" -U postgres -qtA -f supabase/tests/13_cedears.sql 2>&1 | grep -E '^(ok|FALLO)' | mirar

echo
if grep -q 'FALLO' "$FALLOS"; then
  echo "HAY FALLOS:"
  grep 'FALLO' "$FALLOS" | sed 's/^/  /'
  exit 1
fi
echo "TODO VERDE"
