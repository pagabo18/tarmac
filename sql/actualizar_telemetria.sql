-- El corredor edita SU propia telemetria y sus vueltas (solo su ficha).
create or replace function public.actualizar_telemetria(
  p_corredor_id uuid,
  p_posicion text,
  p_mejor_vuelta text,
  p_tiempo_total text,
  p_velocidad_max text,
  p_vueltas jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.corredores where id = p_corredor_id and usuario_id = auth.uid()) then
    raise exception 'No autorizado';
  end if;

  update public.corredores set
    posicion = nullif(trim(p_posicion), ''),
    mejor_vuelta = nullif(trim(p_mejor_vuelta), ''),
    tiempo_total = nullif(trim(p_tiempo_total), ''),
    velocidad_max = nullif(trim(p_velocidad_max), '')
  where id = p_corredor_id;

  delete from public.vueltas where corredor_id = p_corredor_id;

  insert into public.vueltas (corredor_id, numero, tiempo, diferencia, posicion)
  select p_corredor_id,
         row_number() over (order by ord)::int,
         tiempo, diferencia, posicion
  from (
    select t.ord as ord,
           nullif(trim(t.v->>'tiempo'), '')      as tiempo,
           nullif(trim(t.v->>'diferencia'), '')  as diferencia,
           nullif(trim(t.v->>'posicion'), '')    as posicion
    from jsonb_array_elements(coalesce(p_vueltas, '[]'::jsonb)) with ordinality as t(v, ord)
  ) s
  where s.tiempo is not null;
end;
$$;

revoke all on function public.actualizar_telemetria(uuid, text, text, text, text, jsonb) from public, anon;
grant execute on function public.actualizar_telemetria(uuid, text, text, text, text, jsonb) to authenticated;
