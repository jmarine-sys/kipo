-- Saca de la base lo que ADR-023 dejo sin uso.
--
-- `20260916140000_cotizaciones.sql` fue la primera version de la medicion: creaba
-- `en_usd()` y `cotizacion_faltante`. El mismo dia, ADR-023 generalizo la idea -la
-- unidad de medida es apenas un divisor- y esos dos objetos quedaron reemplazados
-- por `convertir()` y `medicion_faltante`. Nadie en el repositorio los nombra.
--
-- Ademas ese archivo compartia timestamp con `..._medicion.sql`, y dos migraciones
-- con la misma version es una bomba de tiempo: el orden pasa a depender del orden
-- alfabetico del nombre, que hoy da bien de pura casualidad. Se borro el archivo.
--
-- Estos DROP son por si en alguna base llego a aplicarse antes de borrarse. Si
-- nunca existieron, no hacen nada: para eso esta el `if exists`.

drop view if exists cotizacion_faltante;
drop function if exists en_usd(numeric, text, date, text);
