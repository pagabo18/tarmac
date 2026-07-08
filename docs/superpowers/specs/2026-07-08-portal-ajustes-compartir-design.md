# Diseño — Portal del corredor: Ajustes + consentimiento para compartir + fotos híbridas

**Fecha:** 2026-07-08
**Proyecto:** TARMAC (`C:\Users\pagab\Documents\tarmac-app`, repo `pagabo18/tarmac`, rama `main`)
**Archivo principal a tocar:** `index.html` (sitio autocontenido) + migraciones Supabase (project ref `hhjkhaogrzjzdqdpracm`)

> ⚠️ Nota de carpetas: el repo git real es `Documents\tarmac-app`. Existe una copia vieja en `Documents\IA\tarmac` (solo usada para el txt de links). Todo el trabajo va en `tarmac-app`.

## Contexto (por qué)

El portal del corredor ya permite entrar por número, ver telemetría, galería, descargar todo (botón `descarga_url`) y personalizar color/diseño. Gabriel quiere tres cosas nuevas:

1. **Fotos híbridas**: que el corredor *vea* algunas fotos dentro de su portal (muestra) **y** pueda *descargar* todas (botón externo a SmugMug). Las galerías completas NO se suben a Supabase (límite de 1 GB del plan gratis; las originales se quedan en SmugMug).
2. **Sección de Ajustes**: que el corredor edite su **nombre** y su **correo** desde su portal. Es especialmente útil porque varios corredores comparten nombre a propósito (un mismo usuario de Instagram pidió fotos de varios números) y podrán corregirlo ellos mismos.
3. **Consentimiento para compartir**: un interruptor donde el corredor autoriza que Tarmac use sus fotos/videos en la **página principal**. Se guarda con fecha (registro legal). La publicación en la web la **cura Gabriel a mano** (no hay auto-publicación); el sistema solo registra el permiso y se lo muestra en el panel admin.

## Estado ya resuelto (operativo, fuera de este build)

- 20/25 corredores ya tienen su `descarga_url` cargado (links archive de SmugMug). El botón "Descargar todas mis fotos" ya funciona para ellos.
- Faltan 5 links (operativo, se cargan cuando Gabriel los consiga): #32, #572, #816 (link propio), #417 (galería incompleta), #811 Karol (archive real).

## Alcance de este diseño

### 1. Cambios de base de datos (1 migración)

Agregar a la tabla `perfiles` (una fila por persona; ya guarda `acepta_terminos`/`acepta_fecha`):

```sql
alter table perfiles
  add column if not exists acepta_compartir boolean not null default false,
  add column if not exists acepta_compartir_fecha timestamptz;
```

No se necesitan columnas nuevas para fotos: la muestra usa la tabla `fotos` y el bucket `fotos` que ya existen. El download usa `corredores.descarga_url` que ya existe.

### 2. Funciones RPC (2, `SECURITY DEFINER`, solo `authenticated`)

Cada RPC actúa **solo sobre las filas del usuario que la llama** (`auth.uid()`), sin recibir a quién editar → un corredor nunca puede tocar datos de otro. Mismo patrón que `aceptar_terminos()`.

**`actualizar_datos_corredor(p_nombre text, p_email text)`**
- Valida: `p_nombre` no vacío (trim); `p_email` vacío o con formato básico de correo.
- `update corredores set nombre = trim(p_nombre), email = nullif(trim(p_email),'') where usuario_id = auth.uid();` (actualiza todas sus fichas / eventos).
- `update perfiles set nombre = trim(p_nombre) where id = auth.uid();` (mantiene el nombre de display en sync).
- El correo aquí es **solo de contacto**; el login sigue siendo por número con email sintético, así que cambiar este correo no afecta el acceso.

**`actualizar_consentimiento_compartir(p_acepta boolean)`**
- `update perfiles set acepta_compartir = p_acepta, acepta_compartir_fecha = now() where id = auth.uid();`
- Se guarda la fecha en cada cambio (registro de cuándo aceptó o revocó).

`grant execute` de ambas a `authenticated`.

### 3. Frontend (`index.html`)

**Portal del corredor — nueva sección "⚙️ Ajustes"** (dentro del portal, después de la galería):
- Campo **Nombre** (precargado con el nombre actual) + botón Guardar → llama `actualizar_datos_corredor`. Al guardar, refresca el nombre visible (dorsal/encabezado).
- Campo **Correo** (precargado) + Guardar (puede ir en el mismo botón que el nombre).
- **Interruptor** "Permito que Tarmac use mis fotos y videos en su página principal" (precargado desde `perfiles.acepta_compartir`) con una línea explicativa breve → llama `actualizar_consentimiento_compartir`. Da feedback de confirmación ("✓ Preferencia guardada").

**Portal del corredor — "Mis fotos" (híbrido)**: sin cambios estructurales. La galería ya renderiza las fotos del bucket `fotos`; la "muestra" son las pocas fotos que el admin suba por corredor. Si no hay fotos, solo se ve el botón de descarga (comportamiento actual). Verificar que se vea bien con pocas fotos.

**Panel admin — lista de corredores**: mostrar una etiqueta **"🌐 Comparte"** en la fila del corredor cuyo perfil vinculado tenga `acepta_compartir = true`. Requiere, al cargar la lista de corredores del proyecto, traer también `perfiles.acepta_compartir` por `usuario_id` (el admin tiene acceso completo a `perfiles` vía `soy_admin()`).

## Fuera de alcance (para no complicar)

- No subir galerías completas a Supabase (solo la muestra pequeña, subida por el admin).
- No auto-publicación en la página principal: la curaduría es manual (Gabriel elige qué publicar en hero/carrusel como ya lo hace hoy).
- Botón "Ver mi galería" con el patrón `umistudio.smugmug.com/ASINCRONO/ATEMAJAC/<número>` → posible mejora futura, no ahora.
- Carga de los 5 links faltantes → operativo, se hace aparte cuando Gabriel los consiga.

## Verificación (cómo se prueba de extremo a extremo)

1. **Migración**: `list_migrations` muestra la nueva; `perfiles` tiene las 2 columnas.
2. **RPCs**: existen y con `grant` a `authenticated`.
3. **E2E en navegador** (con el sitio en vivo tras publicar):
   - Entrar como corredor (ej. #28) → abrir "⚙️ Ajustes".
   - Cambiar el **nombre** → recargar → el nombre persiste (verificar también en la BD: `corredores` y `perfiles`).
   - Cambiar el **correo** → verificar en `corredores.email`.
   - Activar el **interruptor de compartir** → verificar en BD `perfiles.acepta_compartir = true` y `acepta_compartir_fecha` con hora.
   - Desactivarlo → verificar que vuelve a `false`.
   - Confirmar que **el login sigue funcionando** después de cambiar el correo (no debe afectar, es email sintético).
   - Entrar como **admin** → ver la etiqueta "🌐 Comparte" en la fila de ese corredor.
   - Confirmar que el **botón de descarga** sigue funcionando (`descarga_url`).
4. **Publicar** a `main`/GitHub Pages y repetir la prueba en vivo (Ctrl+Shift+R).

## Riesgos / notas

- **Commitear `index.html` en cuanto quede estable** (lección: en la 1ª sesión se perdió trabajo de frontend por no commitear; solo sobrevivió lo server-side).
- La muestra de fotos requiere que Gabriel las suba desde el navegador (yo no puedo descargar de SmugMug ni subir a Supabase desde el entorno). Es incremental y opcional por corredor.
