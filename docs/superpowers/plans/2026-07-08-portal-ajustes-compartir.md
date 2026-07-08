# Portal del corredor: Ajustes + consentimiento para compartir — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el corredor edite su nombre y correo desde su portal y autorice (con registro y fecha) que TARMAC use sus fotos/videos en la página principal; que el admin vea quién autorizó.

**Architecture:** Sitio autocontenido en un solo `index.html` + Supabase (auth/DB/RPC). Los datos sensibles se editan con funciones RPC `SECURITY DEFINER` que actúan solo sobre `auth.uid()` (mismo patrón que `aceptar_terminos`). No hay framework de pruebas: la verificación es por SQL (conector MCP de Supabase) y por prueba E2E en el navegador.

**Tech Stack:** HTML/CSS/JS vanilla, supabase-js v2 (CDN), Supabase Postgres + RPC, GitHub Pages.

## Global Constraints

- Todo el texto de UI en **español**.
- Paleta: acento champaña `#C9A96B`; NO usar naranja.
- El login del corredor es por **número + email sintético** `{proyecto_id}_{numero}@tarmac.mx`. Cambiar el correo de contacto NO debe afectar el acceso.
- Un corredor puede tener varias fichas (varios eventos): editar nombre/correo actualiza **todas** sus fichas (`where usuario_id = auth.uid()`).
- **Commitear `index.html` en cuanto cada tarea quede estable** (lección: se perdió trabajo por no commitear).
- Supabase project ref: `hhjkhaogrzjzdqdpracm`. Migraciones se aplican con el conector MCP (`apply_migration`), van directo a producción; solo cambios aditivos/no-destructivos.
- Trabajar en la rama `ajustes-compartir` (ya creada, contiene el spec).

## File Structure

- `sql/ajustes_compartir.sql` — **crear**: copia de la migración (columnas + 2 RPCs) para dejar registro en el repo. La versión ejecutada va por MCP.
- `index.html` — **modificar**:
  - Portal del corredor: nuevo panel "⚙️ Ajustes" (insertar tras el panel de galería, ~línea 822).
  - `RIDER.init` (~1155): precargar nombre/correo/consentimiento.
  - Listeners globales del portal (~línea 1231, junto a `swatches`/`layoutSeg`): guardar datos y consentimiento.
  - `ADMIN.loadClients` (~1277): etiqueta "🌐 comparte" en la lista.

---

### Task 1: Base de datos — columnas de consentimiento + 2 RPCs

**Files:**
- Create: `sql/ajustes_compartir.sql`
- Aplicar en Supabase vía MCP `apply_migration` (name: `ajustes_compartir`)

**Interfaces:**
- Consumes: tabla `perfiles(id, nombre, es_admin, acepta_terminos, acepta_fecha)`; tabla `corredores(usuario_id, nombre, email, ...)`; función `auth.uid()`.
- Produces:
  - Columnas `perfiles.acepta_compartir boolean` (default false) y `perfiles.acepta_compartir_fecha timestamptz`.
  - RPC `actualizar_datos_corredor(p_nombre text, p_email text) returns void` — actualiza nombre/email de todas las fichas del usuario y el nombre en su perfil.
  - RPC `actualizar_consentimiento_compartir(p_acepta boolean) returns void` — fija el flag y la fecha en su perfil.

- [ ] **Step 1: Escribir el SQL en el repo**

Crear `sql/ajustes_compartir.sql` con exactamente este contenido:

```sql
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
```

- [ ] **Step 2: Aplicar la migración en Supabase (MCP)**

Usar la herramienta MCP `apply_migration` con `project_id: hhjkhaogrzjzdqdpracm`, `name: ajustes_compartir` y el mismo SQL del Step 1.

- [ ] **Step 3: Verificar columnas y funciones (MCP `execute_sql`)**

```sql
select column_name, data_type, column_default
from information_schema.columns
where table_schema='public' and table_name='perfiles'
  and column_name in ('acepta_compartir','acepta_compartir_fecha');

select proname, pg_get_function_identity_arguments(oid) as args
from pg_proc
where proname in ('actualizar_datos_corredor','actualizar_consentimiento_compartir');

select proname, grantee
from information_schema.role_routine_grants
where routine_name in ('actualizar_datos_corredor','actualizar_consentimiento_compartir');
```

Expected: 2 columnas (`acepta_compartir` bool default false, `acepta_compartir_fecha` timestamptz); 2 funciones con sus args; `grant` a `authenticated`.

- [ ] **Step 4: Commit**

```bash
git add sql/ajustes_compartir.sql
git commit -m "DB: columnas acepta_compartir + RPCs actualizar_datos_corredor/actualizar_consentimiento_compartir"
```

---

### Task 2: Portal del corredor — panel "⚙️ Ajustes" (nombre, correo, consentimiento)

**Files:**
- Modify: `index.html` (HTML del portal ~822; `RIDER.init` ~1155; listeners ~1231)

**Interfaces:**
- Consumes: RPCs `actualizar_datos_corredor(p_nombre, p_email)` y `actualizar_consentimiento_compartir(p_acepta)` (Task 1); objetos globales `SB`, `$`, `APP.perfil`, `RIDER.corredor`.
- Produces: elementos DOM `#setNombre`, `#setEmail`, `#setGuardar`, `#setCompartir`, `#setMsg`.

- [ ] **Step 1: Insertar el panel HTML de Ajustes**

En `index.html`, justo **después** del cierre del panel de galería (la línea `</div>` que cierra el segundo `panel` del portal, ~línea 822) y **antes** del `</div>` que cierra `.portal-body` (~línea 823), insertar:

```html
    <div class="panel">
      <div class="panel-head">
        <span class="t">⚙️ Ajustes</span>
        <span class="r" id="setMsg"></span>
      </div>
      <div class="panel-body">
        <div style="display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));align-items:end;margin-bottom:20px">
          <div class="field" style="margin:0"><label>Tu nombre</label><input id="setNombre" type="text" placeholder="Tu nombre"></div>
          <div class="field" style="margin:0"><label>Tu correo (para avisos)</label><input id="setEmail" type="email" autocomplete="email" placeholder="tucorreo@ejemplo.com"></div>
          <button class="btn solid" type="button" id="setGuardar" style="height:46px">Guardar mis datos</button>
        </div>
        <div class="chk" style="align-items:flex-start">
          <input type="checkbox" id="setCompartir">
          <label for="setCompartir">Permito que TARMAC use mis fotos y videos en su <b>página principal</b> y redes oficiales, con fines de portafolio y publicidad, conforme al <a href="#legal" onclick="closePortals()">aviso de privacidad</a>. Puedo revocarlo cuando quiera.</label>
        </div>
        <div class="mini" style="margin-top:10px">//// Tu nombre y correo son solo para contacto — sigues entrando con tu número.</div>
      </div>
    </div>
```

- [ ] **Step 2: Precargar los campos en `RIDER.init`**

En `RIDER.init`, en la rama donde SÍ hay ficha, justo después de `const c = cs[0]; this.corredor = c;` (~línea 1155), agregar:

```js
    /* Ajustes: precargar nombre, correo y consentimiento */
    $("setNombre").value = c.nombre || "";
    $("setEmail").value  = c.email || "";
    $("setCompartir").checked = !!APP.perfil.acepta_compartir;
    $("setMsg").textContent = "";
```

Y en la rama SIN ficha (dentro del `if(!cs || !cs.length){ ... }`, antes de su `return;` en ~línea 1153), agregar:

```js
      $("setNombre").value = APP.perfil.nombre || "";
      $("setEmail").value = "";
      $("setCompartir").checked = !!APP.perfil.acepta_compartir;
```

- [ ] **Step 3: Agregar los listeners de guardado**

Justo después del listener de `#layoutSeg` (termina en ~línea 1231, antes del comentario `/* ---------- PANEL ADMIN ---------- */`), agregar:

```js
/* Ajustes del corredor: guardar nombre + correo */
$("setGuardar").addEventListener("click", async () => {
  const msg = $("setMsg"); msg.style.color = "";
  const nombre = $("setNombre").value.trim();
  const email  = $("setEmail").value.trim();
  if(!nombre){ msg.style.color = "#D97B7B"; msg.textContent = "// Escribe tu nombre."; return; }
  const btn = $("setGuardar"); btn.disabled = true; btn.textContent = "Guardando…";
  const { error } = await SB.rpc("actualizar_datos_corredor", { p_nombre: nombre, p_email: email });
  btn.disabled = false; btn.textContent = "Guardar mis datos";
  if(error){ msg.style.color = "#D97B7B"; msg.textContent = "// " + error.message; return; }
  msg.style.color = "var(--polvo)"; msg.textContent = "✓ Datos guardados";
  if(APP.perfil) APP.perfil.nombre = nombre;
  if(RIDER.corredor){ RIDER.corredor.nombre = nombre; RIDER.corredor.email = email; }
  $("rNombre").innerHTML = nombre.replace(" ", "<br>");
  $("riderWho").innerHTML = "Sesión iniciada — <b>" + nombre + "</b>";
});

/* Ajustes del corredor: consentimiento para compartir en la web */
$("setCompartir").addEventListener("change", async e => {
  const msg = $("setMsg"); msg.style.color = "";
  const val = e.target.checked;
  const { error } = await SB.rpc("actualizar_consentimiento_compartir", { p_acepta: val });
  if(error){ e.target.checked = !val; msg.style.color = "#D97B7B"; msg.textContent = "// " + error.message; return; }
  if(APP.perfil) APP.perfil.acepta_compartir = val;
  msg.style.color = "var(--polvo)"; msg.textContent = val ? "✓ Gracias, autorizaste compartir tus fotos" : "✓ Preferencia guardada (no compartir)";
});
```

- [ ] **Step 4: Verificar en el navegador (local)**

Abrir `index.html` local, entrar como corredor con acceso (ej. #28, contraseña que ya tiene). Comprobar:
- Aparece el panel "⚙️ Ajustes" con nombre y correo precargados y el check reflejando el estado actual.
- Cambiar el nombre → "Guardar mis datos" → sale "✓ Datos guardados" y el nombre grande del dorsal se actualiza.
- Recargar → el nombre nuevo persiste.
- Marcar el check → sin recargar, sale el mensaje de confirmación.

Confirmar en BD (MCP `execute_sql`):
```sql
select numero, nombre, email from corredores where numero = 28;
select nombre, acepta_compartir, acepta_compartir_fecha from perfiles
where id = (select usuario_id from corredores where numero = 28);
```
Expected: nombre/email nuevos en `corredores`; `perfiles.nombre` igual; `acepta_compartir=true` con fecha.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "Portal: seccion Ajustes (editar nombre/correo + consentimiento compartir)"
```

---

### Task 3: Panel admin — etiqueta "🌐 comparte" en la lista de corredores

**Files:**
- Modify: `index.html` (`ADMIN.loadClients` ~1277-1284)

**Interfaces:**
- Consumes: `SB.from("perfiles").select("id, acepta_compartir")` (admin tiene acceso completo a `perfiles` vía `soy_admin()`); columna `acepta_compartir` (Task 1).
- Produces: badge visual en la celda del nombre.

- [ ] **Step 1: Cargar el estado de "compartir" al inicio de `loadClients`**

Reemplazar el inicio de `async loadClients(){` (líneas ~1277-1279):

```js
  async loadClients(){
    const { data: cs } = await SB.from("corredores").select("*").eq("proyecto_id", this.proyecto.id).order("numero");
    const tb = $("clientRows"); tb.innerHTML = "";
```

por:

```js
  async loadClients(){
    const { data: cs } = await SB.from("corredores").select("*").eq("proyecto_id", this.proyecto.id).order("numero");
    /* quién autorizó compartir sus fotos en la web */
    const ids = (cs || []).map(c => c.usuario_id).filter(Boolean);
    const comparte = {};
    if(ids.length){
      const { data: pfs } = await SB.from("perfiles").select("id, acepta_compartir").in("id", ids);
      (pfs || []).forEach(p => { comparte[p.id] = p.acepta_compartir; });
    }
    const tb = $("clientRows"); tb.innerHTML = "";
```

- [ ] **Step 2: Mostrar el badge en la celda del nombre**

Reemplazar la línea del nombre (línea ~1284):

```js
        '<td>' + c.nombre + '<div class="mini">' + (c.usuario_id ? 'con acceso ✓' : 'sin acceso aún') + (c.descarga_url ? ' · link ✓' : '') + '</div></td>' +
```

por:

```js
        '<td>' + c.nombre + '<div class="mini">' + (c.usuario_id ? 'con acceso ✓' : 'sin acceso aún') + (c.descarga_url ? ' · link ✓' : '') + ((c.usuario_id && comparte[c.usuario_id]) ? ' · <span style="color:#C9A96B">🌐 comparte</span>' : '') + '</div></td>' +
```

- [ ] **Step 3: Verificar en el navegador**

Con el corredor #28 marcado como "comparte" (de Task 2), entrar como admin → abrir el proyecto Atemajac → en la fila del #28 debe verse "🌐 comparte" en dorado. Desmarcar el consentimiento como corredor y recargar la lista admin → el badge desaparece.

- [ ] **Step 4: Commit**

```bash
git add index.html
git commit -m "Admin: etiqueta 'comparte' para corredores que autorizaron uso en la web"
```

---

### Task 4: Publicar a producción + prueba E2E en vivo

**Files:** ninguno (git + verificación)

- [ ] **Step 1: Fusionar la rama a `main`**

```bash
git checkout main
git merge --ff-only ajustes-compartir
```
Expected: fast-forward limpio.

- [ ] **Step 2: Publicar**

```bash
git push origin main
```
GitHub Pages republica en ~1 min.

- [ ] **Step 3: Verificar el commit publicado (API de GitHub)**

`GET https://api.github.com/repos/pagabo18/tarmac/commits/main` → el SHA/HEAD debe ser el de Task 3.

- [ ] **Step 4: Prueba E2E en vivo (guiar a Gabriel)**

En https://pagabo18.github.io/tarmac/ (Ctrl+Shift+R):
- Entrar como corredor #28 → "⚙️ Ajustes" → cambiar nombre/correo (verifica persistencia recargando) → activar el consentimiento.
- Confirmar en BD (`corredores` y `perfiles`) los cambios y la fecha.
- Confirmar que el login por número sigue funcionando tras cambiar el correo.
- Entrar como admin → ver "🌐 comparte" en el #28.
- Confirmar que el botón "Descargar todas mis fotos" sigue funcionando (los 20 links ya cargados).

- [ ] **Step 5: Actualizar memoria + CLAUDE.md**

Anotar en la memoria del proyecto que la feature Ajustes + consentimiento compartir quedó EN PROD y verificada, y actualizar `CLAUDE.md` con las 2 columnas nuevas de `perfiles` y las 2 RPCs.

---

## Self-Review

- **Cobertura del spec:** columnas `perfiles` → Task 1. RPCs (datos + consentimiento) → Task 1. Sección Ajustes (nombre/correo/toggle) → Task 2. Badge admin → Task 3. Fotos híbridas (botón descarga ya cargado; muestra = subida manual del admin, sin código) → cubierto/fuera de alcance. Publicar + E2E → Task 4. Sin huecos.
- **Sin placeholders:** todo el SQL/HTML/JS está completo y literal.
- **Consistencia de tipos:** nombres de RPC (`actualizar_datos_corredor`, `actualizar_consentimiento_compartir`) y de DOM (`setNombre`, `setEmail`, `setGuardar`, `setCompartir`, `setMsg`) iguales en todas las tareas. `comparte` map indexado por `usuario_id`. Coincide con `APP.perfil.acepta_compartir` que `route()` ya trae con `select("*")`.
