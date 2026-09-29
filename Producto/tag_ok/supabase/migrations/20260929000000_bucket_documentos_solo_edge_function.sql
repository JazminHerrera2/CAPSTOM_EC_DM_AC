-- Deja el bucket "documentos" accesible SOLO vía la Edge Function
-- secure-document-upload (que usa la Service Role Key y se salta RLS).
--
-- Ejecutar en el SQL Editor de Supabase (o con psql). Es idempotente.

-- 1) Bucket privado.
update storage.buckets
   set public = false
 where id = 'documentos';

-- 2) Elimina toda policy sobre storage.objects que le dé acceso directo a
--    anon/public (o que apunte al bucket 'documentos'), sea cual sea su
--    nombre. Sin policies para anon/authenticated, RLS deniega todo.
do $$
declare
  pol record;
begin
  for pol in
    select policyname
      from pg_policies
     where schemaname = 'storage'
       and tablename  = 'objects'
       and (
             roles && array['anon', 'public']::name[]
          or coalesce(qual, '')       ilike '%documentos%'
          or coalesce(with_check, '') ilike '%documentos%'
       )
  loop
    execute format('drop policy %I on storage.objects', pol.policyname);
    raise notice 'policy eliminada: %', pol.policyname;
  end loop;
end $$;

-- 3) Verificación: no debe quedar ninguna fila para anon/public.
--    select policyname, roles, cmd from pg_policies
--     where schemaname = 'storage' and tablename = 'objects';
