-- Consentimiento de compartir: el corredor SOLO puede aceptar; retirar lo hace el admin.
alter table public.perfiles add column if not exists revoca_compartir_fecha timestamptz;

-- El corredor solo puede ACEPTAR (no desactivar desde el portal).
create or replace function public.actualizar_consentimiento_compartir(p_acepta boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_acepta is not true then
    raise exception 'Para retirar tu permiso escríbenos por Instagram; no se puede desactivar desde aquí';
  end if;
  update public.perfiles
    set acepta_compartir = true, acepta_compartir_fecha = now()
    where id = auth.uid();
end;
$$;

-- Solo el admin retira (o reactiva) el permiso, cuando el corredor lo solicita.
create or replace function public.admin_set_compartir(p_usuario_id uuid, p_valor boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.soy_admin() then
    raise exception 'Solo administradores';
  end if;
  update public.perfiles
    set acepta_compartir = p_valor,
        acepta_compartir_fecha = case when p_valor then now() else acepta_compartir_fecha end,
        revoca_compartir_fecha = case when p_valor then revoca_compartir_fecha else now() end
    where id = p_usuario_id;
end;
$$;
grant execute on function public.admin_set_compartir(uuid, boolean) to authenticated;
