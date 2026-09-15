-- SOLO PARA TESTS LOCALES. Supabase ya provee el esquema auth; esto lo imita
-- para poder correr las migraciones contra un Postgres pelado.
create schema if not exists auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text);
create role authenticated;
create role anon;
create or replace function auth.uid() returns uuid
  language sql stable as $$ select current_setting('test.uid', true)::uuid $$;
