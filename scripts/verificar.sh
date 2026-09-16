#!/usr/bin/env bash
# Todo lo que tiene que estar bien antes de subir.  ./scripts/verificar.sh
#
# Existe porque dos veces subí código roto por encadenar el chequeo y el push
# sin que el segundo dependiera del primero. Un comando, un código de salida.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "── tipos ──"
npx svelte-check --tsconfig ./tsconfig.json 2>&1 | grep -E 'ERRORS|error' | tail -2
npx svelte-check --tsconfig ./tsconfig.json 2>&1 | grep -q ' 0 ERRORS' || {
  echo "✗ hay errores de tipos"; exit 1; }

echo "── unitarios ──"
npm test 2>&1 | grep -E 'ℹ (pass|fail)'
npm test 2>&1 | grep -q 'ℹ fail 0' || { echo "✗ tests que fallan"; exit 1; }

echo "── base de datos ──"
./supabase/tests/run.sh >/tmp/db_test.log 2>&1 || {
  echo "✗ la suite de base falló:"; tail -12 /tmp/db_test.log; exit 1; }
grep -c '^ok' /tmp/db_test.log | xargs echo "  aserciones ok:"

echo
echo "TODO VERDE — se puede subir"
