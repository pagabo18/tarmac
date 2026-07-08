-- Login alternativo por correo: dado un correo registrado, devuelve sus eventos + numero
-- (gemela de eventos_por_numero; incluye numero porque el frontend no lo conoce en este flujo).
create or replace function public.eventos_por_correo(p_email text)
returns table(proyecto_id uuid, numero integer, nombre text, fecha date)
language sql
security definer
set search_path to 'public'
as $function$
  select p.id, c.numero, p.nombre, p.fecha
  from public.corredores c
  join public.proyectos p on p.id = c.proyecto_id
  where lower(c.email) = lower(trim(p_email))
    and c.numero is not null
  group by p.id, c.numero, p.nombre, p.fecha
  order by max(p.creado) desc;
$function$;

grant execute on function public.eventos_por_correo(text) to anon, authenticated;
