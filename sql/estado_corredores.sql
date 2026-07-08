-- Seguimiento: cuando el corredor descarga y estado consolidado para el admin.
alter table public.corredores
  add column if not exists descarga_ultima timestamptz,
  add column if not exists descarga_veces integer not null default 0;

-- El corredor registra que dio clic en "Descargar todas mis fotos" (solo su ficha).
create or replace function public.registrar_descarga(p_corredor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.corredores
    set descarga_ultima = now(), descarga_veces = coalesce(descarga_veces, 0) + 1
    where id = p_corredor_id and usuario_id = auth.uid();
end;
$$;
grant execute on function public.registrar_descarga(uuid) to authenticated;

-- Estado consolidado por corredor para el panel admin (incluye ultima sesion real de auth).
create or replace function public.estado_corredores(p_proyecto_id uuid)
returns table(
  id uuid, numero integer, nombre text, email text, moto text, categoria text,
  estatus text, avance integer, descarga_url text, fotos_totales integer,
  usuario_id uuid, acepta_compartir boolean, acepta_terminos boolean,
  ultimo_acceso timestamptz, descarga_ultima timestamptz, descarga_veces integer,
  fotos_subidas bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.soy_admin() then
    raise exception 'Solo administradores';
  end if;
  return query
    select c.id, c.numero, c.nombre, c.email, c.moto, c.categoria,
           c.estatus, c.avance, c.descarga_url, c.fotos_totales,
           c.usuario_id, pf.acepta_compartir, pf.acepta_terminos,
           u.last_sign_in_at, c.descarga_ultima, c.descarga_veces,
           (select count(*) from public.fotos f where f.corredor_id = c.id)
    from public.corredores c
    left join public.perfiles pf on pf.id = c.usuario_id
    left join auth.users u on u.id = c.usuario_id
    where c.proyecto_id = p_proyecto_id
    order by c.numero;
end;
$$;
grant execute on function public.estado_corredores(uuid) to authenticated;
