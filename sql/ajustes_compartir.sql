-- Consentimiento para compartir fotos/videos en la pagina publica
alter table public.perfiles
  add column if not exists acepta_compartir boolean not null default false,
  add column if not exists acepta_compartir_fecha timestamptz;

-- El corredor edita su propio nombre y correo (todas sus fichas)
create or replace function public.actualizar_datos_corredor(p_nombre text, p_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nombre text := nullif(trim(p_nombre), '');
  v_email  text := nullif(trim(p_email), '');
begin
  if v_nombre is null then
    raise exception 'El nombre no puede estar vacio';
  end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'El correo no tiene un formato valido';
  end if;
  update public.corredores
    set nombre = v_nombre, email = v_email
    where usuario_id = auth.uid();
  update public.perfiles
    set nombre = v_nombre
    where id = auth.uid();
end;
$$;

-- El corredor activa/desactiva el consentimiento de compartir
create or replace function public.actualizar_consentimiento_compartir(p_acepta boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.perfiles
    set acepta_compartir = coalesce(p_acepta, false),
        acepta_compartir_fecha = now()
    where id = auth.uid();
end;
$$;

revoke all on function public.actualizar_datos_corredor(text, text) from public, anon;
revoke all on function public.actualizar_consentimiento_compartir(boolean) from public, anon;
grant execute on function public.actualizar_datos_corredor(text, text) to authenticated;
grant execute on function public.actualizar_consentimiento_compartir(boolean) to authenticated;
