-- Galería pública de la última carrera en la página principal (tarmac.mx).
-- El admin marca fotos con 🌐 (fotos.publica). Solo se muestran si el corredor
-- ya aceptó la autorización de uso de imagen al entrar a su portal (perfiles.acepta_terminos)
-- y no ha pedido retirar el permiso de compartir (revoca_compartir_fecha nulo, o acepta_compartir true).
--
-- Cómo aplicar: Supabase → SQL Editor → pegar todo este archivo → Run.
-- Es aditivo y se puede volver a ejecutar sin problema.

alter table public.fotos add column if not exists publica boolean not null default false;
create index if not exists fotos_publica_idx on public.fotos (corredor_id) where publica;

-- ¿Esta ruta del bucket corresponde a una foto visible al público?
-- SECURITY DEFINER para que la política de storage pueda consultar fotos/corredores/perfiles
-- aunque quien pregunte sea anon (esas tablas tienen RLS).
create or replace function public.foto_publica_por_ruta(p_ruta text)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.fotos f
    join public.corredores c on c.id = f.corredor_id
    left join public.perfiles pf on pf.id = c.usuario_id
    where f.ruta = p_ruta
      and f.publica
      and coalesce(pf.acepta_terminos, false)
      and (coalesce(pf.acepta_compartir, false) or pf.revoca_compartir_fecha is null)
  );
$$;
grant execute on function public.foto_publica_por_ruta(text) to anon, authenticated;

-- Lista de fotos públicas (para la página principal, sin sesión). Solo expone el número del
-- corredor y los datos del evento; nunca nombre ni correo.
create or replace function public.fotos_publicas()
returns table(
  id uuid, ruta text, es_video boolean, numero integer,
  proyecto_id uuid, proyecto text, disciplina text, fecha date, ubicacion text,
  creado timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select f.id, f.ruta::text, coalesce(f.es_video, false), c.numero::integer,
         p.id, p.nombre::text, p.disciplina::text, p.fecha::date, p.ubicacion::text,
         f.creado::timestamptz
  from public.fotos f
  join public.corredores c on c.id = f.corredor_id
  join public.proyectos p on p.id = c.proyecto_id
  left join public.perfiles pf on pf.id = c.usuario_id
  where f.publica
    and coalesce(pf.acepta_terminos, false)
    and (coalesce(pf.acepta_compartir, false) or pf.revoca_compartir_fecha is null)
  order by p.fecha desc nulls last, p.creado desc, c.numero, f.creado;
$$;
grant execute on function public.fotos_publicas() to anon, authenticated;

-- Storage: el público (anon) puede leer/firmar SOLO los archivos que son fotos públicas.
-- Los demás archivos del bucket privado 'fotos' siguen igual de privados.
drop policy if exists "fotos publicas visibles" on storage.objects;
create policy "fotos publicas visibles"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'fotos' and public.foto_publica_por_ruta(name));
