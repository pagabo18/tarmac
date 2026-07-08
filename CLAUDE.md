# CLAUDE.md — Proyecto TARMAC

Contexto completo para que Claude (o cualquier desarrollador) pueda continuar el trabajo en cualquier conversación futura. Última actualización: **2026-07-08** (portal ampliado: Ajustes, login por número/correo, telemetría editable, estado admin, consentimiento blindado, contacto por Instagram).

## Qué es Tarmac

Negocio de fotografía y video de motorsport de Gabriel Hernández (usuario: pagabo18) y Brian: coches de lujo, enduro, drift, pista y rally. Marca: **TARMAC — The Art of Motion**. La plataforma web muestra el portafolio público y da a cada corredor/cliente un portal privado con sus fotos, telemetría y descargas, más un panel de administración para gestionar proyectos, corredores y subir archivos.

## URLs y ubicaciones

- Sitio en producción: **https://tarmac.mx** (dominio propio vía `CNAME`) y https://pagabo18.github.io/tarmac/ — ambos sirven la rama `main` por GitHub Pages.
- Repositorio: https://github.com/pagabo18/tarmac (público)
- Archivo principal: `index.html` — TODO el sitio vive en un solo archivo autocontenido (~1.07 MB): HTML + CSS + JS + fotos en base64.
- `sql/` — copias de registro de cada migración/función aplicada a Supabase (la versión ejecutada va por el conector MCP; estos archivos son la referencia en git).
- `docs/superpowers/` — spec y plan de la 1ª feature (Ajustes + compartir).
- Supabase project ref: `hhjkhaogrzjzdqdpracm` (org: "tarmac", región us-west-2)
- Supabase URL: https://hhjkhaogrzjzdqdpracm.supabase.co
- Clave pública (publishable, NO secreta): `sb_publishable_yOtSabdEwOy6RY2gH6wKIg_M6i-HHNc`
- La clave `service_role` NUNCA se comparte ni se pone en el frontend.

> ⚠️ **Dos carpetas — cuidado.** El repo git real y fuente de verdad es `C:\Users\pagab\Documents\tarmac-app`. Existe una copia **vieja** en `C:\Users\pagab\Documents\IA\tarmac` (con un CLAUDE.md previo y los txt/zips de links) que **confunde** — NO abrir ni editar su `index.html`.

## Cómo publicar cambios

1. Editar `index.html` (o el SQL) en `tarmac-app`.
2. `git commit` + `git push origin main`. GitHub Pages republica en ~1 minuto (Ctrl+Shift+R si se ve viejo).
3. Verificar el commit publicado: `GET https://api.github.com/repos/pagabo18/tarmac/commits/main`.
4. **Probar antes de publicar (recomendado):** servir el `index.html` en un servidor local (ej. `python -m http.server 8000` o un pequeño server de node) y abrir `http://localhost:8000/`. Funciona contra el backend REAL de Supabase (prod), así que las pruebas son fieles sin exponer el frontend nuevo al público. Añadir cabecera `Cache-Control: no-store` evita recargar con Ctrl+Shift+R.
5. Validar la sintaxis del JS antes de subir (el sitio es un solo archivo; un error rompe todo): extraer los `<script>` internos y correrlos por `new vm.Script(...)` en node.

**Base de datos:** usar el **conector MCP de Supabase** (`apply_migration` para DDL/funciones, `execute_sql` para datos/consultas). Va directo a producción; solo cambios aditivos/no destructivos. `auth.uid()` es null vía MCP, así que las RPCs con `SECURITY DEFINER` que checan sesión/`soy_admin()` no se pueden probar por MCP — se prueban en el navegador.

Nota de entorno Claude: el sandbox de código solo alcanza `github.com`/`api.github.com`. NO alcanza `*.supabase.co`, SmugMug, Drive ni `tarmac.mx`. Por eso: la BD se toca por MCP, y descargar/subir fotos a Supabase lo hace Gabriel desde el navegador (o se prepara localmente y se sube por el panel).

## Diseño

- Paleta elegante: tinta `#0C0F14`, carbón `#131720`/`#1A2029`, acento champaña `#C9A96B`, marfil `#F2EFE7`, gris pizarra `#8B93A0`. (Antes naranja/negro; Gabriel pidió cambiarla — NO volver al naranja.)
- Tipografía: Archivo variable (itálica extendida, estilo dorsal) + JetBrains Mono para etiquetas técnicas.
- Vars CSS clave (usadas al editar): `--acc` (acento del portal), `--carbon`/`--carbon2`, `--linea`, `--hueso`, `--polvo`, `--gris`.
- Elementos: preloader con sonido, audio procedural, cursor con anillo, botones magnéticos, tilt 3D, hero slideshow, carrusel, texto cinético, showreel + reels, esquinas HUD "////". `SRC=""` en el JS = URL del video del showreel. Respeta `prefers-reduced-motion`.

## Arquitectura de datos (Supabase, esquema public — todas con RLS)

- `perfiles` (id = auth.users.id, nombre, es_admin) — se crea sola vía trigger `crear_perfil`. Consentimientos: `acepta_terminos`/`acepta_fecha` (uso de imagen, 1er login) y `acepta_compartir`/`acepta_compartir_fecha`/`revoca_compartir_fecha` (usar sus fotos en la web).
- `admins_autorizados` (email) — reciben es_admin al registrarse. Actuales: pagabo18@hotmail.com, brianrso@hotmail.com.
- `proyectos` (nombre, disciplina, fecha, ubicacion, estatus).
- `corredores` (proyecto_id, usuario_id, numero, nombre, email, **descarga_url**, moto, categoria, color_galeria, diseno_galeria, estatus, avance, posicion, mejor_vuelta, tiempo_total, velocidad_max, **fotos_totales**, **descarga_ultima**, **descarga_veces**).
  - `descarga_url` = link archive de SmugMug (botón "Descargar todas mis fotos").
  - `fotos_totales` = cuántos archivos hay en ese link (se muestra en el portal para que el corredor sepa cuándo se actualiza).
  - `descarga_ultima`/`descarga_veces` = seguimiento de clics en el botón de descarga.
- `vueltas` (corredor_id, numero, tiempo, diferencia, posicion).
- `fotos` (corredor_id, ruta, frame, es_video, favorita). Storage: bucket privado `fotos`, rutas `{corredor_id}/{timestamp}-{archivo}`, URLs firmadas 1h.

**Estatus y avance automático** (`ESTATUS` + `AVANCE_ESTATUS` en el JS): al cambiar el estatus en el panel, el avance salta solo. Sin contenido→0 · Sin editar→10 · **Seleccionando→25** · En edición→40 · Revisión→70 · Entregado→100.

Seguridad (RLS): admins (`soy_admin()`) todo; cada corredor solo SELECT de sus filas y UPDATE de color/diseño/favoritas. Todo lo demás que edita el corredor pasa por RPCs `SECURITY DEFINER` que actúan sobre `auth.uid()`.

## Acceso de corredores (login por número **o** correo)

El corredor entra con su **número _o_ su correo registrado** + evento + contraseña, en un solo campo (si el texto tiene `@` → busca por correo). El equipo entra con email+contraseña (toggle "Soy corredor / Equipo TARMAC"). No hay auto-registro.

- Todo detrás de un **email sintético** invisible: `{proyecto_id}_{numero}@tarmac.mx`. Trigger `vincular_por_email_sintetico` vincula `usuario_id` por proyecto+número.
- Login por número: RPC `eventos_por_numero(p_num)`. Login por correo: RPC `eventos_por_correo(p_email)` (devuelve proyecto_id+numero+nombre+fecha; ignora correos vacíos; insensible a may/min). Ambas SECURITY DEFINER, ejecutables por `anon`. Luego el corredor elige evento y hace `signInWithPassword` con el email sintético.
- **Contraseñas gestionadas por el admin** vía Edge Function **`provisionar_corredor`** (service_role server-side, `email_confirm:true`). Botón "🔑 Acceso" por corredor + botón **"Dar acceso a todos (con link)"** (loop con contraseña `Atemajac2026#<número>`).
- Consentimiento de uso de imagen: modal `consentModal` en el 1er login si `acepta_terminos` es falso → RPC `aceptar_terminos()`.

## RPCs y Edge Functions (todas en prod)

- Edge Function `provisionar_corredor` (ACTIVE, verify_jwt) — crea/resetea acceso (admin).
- `eventos_por_numero(int)` / `eventos_por_correo(text)` — login sin sesión (anon).
- `aceptar_terminos()` — consentimiento de imagen (authenticated).
- `actualizar_datos_corredor(nombre, email)` — el corredor edita su nombre/correo (todas sus fichas + perfiles.nombre).
- `actualizar_consentimiento_compartir(p_acepta)` — el corredor **SOLO puede aceptar** (rechaza `false`; para retirar debe escribir por Instagram).
- `admin_set_compartir(usuario_id, valor)` — solo el admin retira/reactiva el permiso de compartir (botón "(quitar)").
- `actualizar_telemetria(corredor_id, posicion, mejor_vuelta, tiempo_total, velocidad_max, vueltas jsonb)` — el corredor edita SU telemetría y vueltas (verifica `usuario_id=auth.uid()`, reemplaza vueltas).
- `registrar_descarga(corredor_id)` — cuenta los clics del corredor en el botón de descarga.
- `estado_corredores(proyecto_id)` — solo admin (`soy_admin()`); estado consolidado por corredor incl. última sesión real de `auth.users.last_sign_in_at`, fotos subidas, comparte, etc.

Archivos SQL de registro en `sql/`: `ajustes_compartir.sql`, `login_por_correo.sql`, `actualizar_telemetria.sql`, `fotos_totales.sql`, `estado_corredores.sql`, `compartir_solo_aceptar.sql`.

## Funcionalidad del sitio

**Portal del corredor:**
- Número dorsal gigante con **foto de portada propia** (una de sus fotos), tags, telemetría, tabla de vueltas.
- Galería: **click en foto → lightbox** (foto ampliada al centro), favoritas ★, descarga individual. Nota de "muestra" (si tiene 4+ fotos, avisa que la galería completa está en el link) y "seguimos subiendo más".
- **Botón "⬇ Descargar TODAS mis fotos (N)"** (N = `fotos_totales`); registra la descarga.
- **⚙️ Ajustes**: ve su número (solo lectura), edita **nombre** y **correo**, e interruptor de **compartir** (solo se puede ACEPTAR, con confirmación; para retirar debe escribir por Instagram — lo quita el admin).
- **🏁 Mis tiempos**: editor con inputs tipo flechitas (min:seg.déc) para cada vuelta, posición **manual** (input numérico, hay ~1000 corredores), botón agregar/quitar vuelta. **Mejor vuelta, tiempo total y diferencias se calculan solos** (módulo JS `TELE`). Posición opcional. Guarda vía `actualizar_telemetria`.

**Panel admin:** crear proyectos; por proyecto una lista de corredores con: **conteo de fotos**, **filtro por estatus**, estatus (select, mueve el avance solo), avance (%), y por corredor bajo el nombre un **estado**: correo, si ya entró (última sesión), cuántas veces descargó, y 🌐 comparte con enlace **"(quitar)"**. Botones por fila: **"👁 Ver portal"** (vista previa del portal del corredor sin loguearse — oculta Ajustes y Mis tiempos), "🔑 Acceso", "✎ Editar" (incl. `descarga_url` y `fotos_totales`), "Fotos ↑", "Tele", "✕". Arriba: filtro + **"🔑 Dar acceso a todos (con link)"**. Subir fotos: sueltas o ZIP (JSZip, original sin recompresión).

**Contacto:** el correo se reemplazó por Instagram **@tarmac_official_** (botón de contacto + avisos legales).

## Estado actual (2026-07-08)

- Proyecto: **Enduro 2026 Atemajac** (2026-06-28) con **25 corredores** (el #28 duplicado se resolvió; #532 y #730 tienen su número como nombre para que ellos lo pongan).
- **20 corredores** con `descarga_url` (link SmugMug), **acceso** creado (contraseña `Atemajac2026#<número>`) y **fotos de muestra** (2-4 c/u, reescaladas ~1600px). El #28 fue el de pruebas.
- **5 sin link/fotos**: #32, #417, #572, #811, #816 → pendientes de conseguir su link.
- Mensajes de Instagram (para los con y sin fotos) generados; copia en `C:\Users\pagab\Documents\IA\mensajes_instagram_atemajac.txt`.
- Admins: Gabriel (pagabo18@hotmail.com) y Brian (brianrso@hotmail.com).

## Convenciones y preferencias del cliente

- Todo en español (UI y comunicación).
- Gabriel no es programador: darle pasos concretos, hacer el trabajo técnico por él.
- Estética elegante, motorsport premium; NO naranja/negro.
- **Commitear `index.html` a git en cuanto un cambio quede estable** (lección 2026-07-07: se perdió trabajo de frontend por no commitear; solo sobrevivió lo server-side).
- Formato de respuestas: 👉 acción del usuario · 🧠 razonamiento.

## Roadmap sugerido (no iniciado)

1. Miniaturas automáticas (galerías lentas con cientos de originales).
2. Marca de agua en previews antes de "Entregado".
3. Video de showreel real (llenar `SRC`).
4. Notificación al corredor cuando su sesión pase a "Entregado".
5. Selector de proyecto en el portal si el corredor participa en varios.
6. Vigilar el límite de 1 GB de Supabase (plan gratis) — al crecer, mover originales a Cloudflare R2 manteniendo Supabase para auth/datos.
7. Botón "Ver mi galería" embebiendo SmugMug (patrón `umistudio.smugmug.com/ASINCRONO/ATEMAJAC/<número>`).
