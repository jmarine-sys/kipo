#!/usr/bin/env bash
# Arma supabase/pendientes.sql con las migraciones desde una version en adelante.
#
# Existe porque este archivo se armaba a mano y se desactualizo: la app rompio en
# produccion con "Could not find the table 'public.upcoming'". Un archivo que se
# copia y pega a mano se desincroniza; uno que se genera, no.
#
#   ./scripts/pendientes.sh 20260916140000
set -euo pipefail
cd "$(dirname "$0")/.."

desde="${1:?uso: ./scripts/pendientes.sh <version-desde>   (ej: 20260916140000)}"
salida=supabase/pendientes.sql

archivos=()
for f in supabase/migrations/*.sql; do
  v="$(basename "$f" | cut -d_ -f1)"
  [ "$v" -ge "$desde" ] && archivos+=("$f")
done

[ ${#archivos[@]} -gt 0 ] || { echo "no hay migraciones desde $desde"; exit 1; }

{
  echo "-- GENERADO POR scripts/pendientes.sh — no editar a mano."
  echo "--"
  echo "-- Migraciones desde $desde, en orden. Pegar entero en el SQL Editor de"
  echo "-- Supabase, en orden. Los ALTER llevan IF NOT EXISTS y los CREATE VIEW van"
  echo "-- precedidos de DROP, asi que volver a correrlo no rompe nada; un INSERT de"
  echo "-- datos semilla si podria duplicar, y por eso se avisa en vez de prometer."
  echo "--"
  for f in "${archivos[@]}"; do echo "--   $(basename "$f")"; done
  echo
  for f in "${archivos[@]}"; do
    echo "-- ==========================================================================="
    echo "-- $(basename "$f")"
    echo "-- ==========================================================================="
    echo
    cat "$f"
    echo
  done
} > "$salida"

echo "$salida — ${#archivos[@]} migraciones, $(wc -l < "$salida") lineas"
