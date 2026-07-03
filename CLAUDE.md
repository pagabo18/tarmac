# CLAUDE.md — Proyecto TARMAC

Contexto completo para que Claude (o cualquier desarrollador) pueda continuar el trabajo en cualquier conversación futura. Última actualización: 2026-07-03.

## Qué es Tarmac

Negocio de fotografía y video de motorsport de Gabriel Hernández (usuario: pagabo18) y Brian: coches de lujo, enduro, drift, pista y rally. Marca: **TARMAC — The Art of Motion**. La plataforma web muestra el portafolio público y da a cada corredor/cliente un portal privado con sus fotos, telemetría y descargas, más un panel de administración para gestionar proyectos, corredores y subir archivos.

## URLs y ubicaciones

- Sitio en producción: https://pagabo18.github.io/tarmac/ (GitHub Pages, rama `main`)
- Repositorio: https://github.com/pagabo18/tarmac (público)
- Archivo principal: `index.html` — TODO el sitio vive en un solo archivo autocontenido (~317 KB): HTML + CSS + JS + 2 fotos en base64
- Supabase project ref: `hhjkhaogrzjzdqdpracm` (org: "tarmac", región us-west-2)
- Supabase URL: https://hhjkhaogrzjzdqdpracm.supabase.co
- Clave pública usada en el sitio (publishable, NO es secreta): `sb_publishable_yOtSabdEwOy6RY2gH6wKIg_M6i-HHNc`
- La clave `service_role` NUNCA se comparte ni se pone en el frontend.

## Cómo publicar cambios

1. Editar/regenerar `index.html`
2. Subirlo al repo (commit a `main`) — vía token de GitHub con scope `repo` (pedirlo a Gabriel, temporal) o manualmente por la web de GitHub ("Add file → Upload files")
3. GitHub Pages republica solo en ~1 minuto. Si se ve la versión vieja: recargar con Ctrl+Shift+R
4. Verificar la versión publicada por API (el raw cachea ~5 min):
   `GET https://api.github.com/repos/pagabo18/tarmac/contents/index.html` con `Accept: application/vnd.github.raw`

Nota de entorno Claude: el sandbox de código solo puede acceder a dominios permitidos. `github.com` y `api.github.com` están permitidos por defecto; `api.vercel.com`, `*.supabase.co` y `pagabo18.github.io` NO (salvo que Gabriel los agregue en Settings → Capabilities → Dominios permitidos adicionales; los cambios solo aplican a chats nuevos). Para tocar la base de datos usar el **conector MCP de Supabase** (activarlo en el menú de herramientas del chat), que funciona del lado del servidor y no depende del sandbox.

## Diseño (v actual)

- Paleta elegante: tinta `#0C0F14`, carbón `#131720`/`#1A2029`, acento champaña `#C9A96B`, marfil `#F2EFE7`, gris pizarra `#8B93A0`. (Antes era naranja/negro; Gabriel pidió cambiarla — NO volver al naranja.)
- Tipografía: Archivo variable (itálica extendida ~118-125% para display, estilo dorsal de carrera) + JetBrains Mono para etiquetas técnicas.
- Referencia de experiencia: labs.noomoagency.com — preloader con % y elección de sonido, mucho movimiento.
- Elementos clave: preloader ("Iniciar con sonido / Sin sonido"), motor de audio procedural (Web Audio, revoluciona con la velocidad de scroll), cursor personalizado con anillo, botones magnéticos, tilt 3D en tarjetas, hero slideshow con crossfade, carrusel "Selección del mes" con swipe, texto cinético que se mueve con el scroll, doble marquee, sección showreel 16:9 + 4 slots de reels 9:16, esquinas HUD estilo "////".
- Se quitaron las partículas 3D (three.js) a petición de Gabriel.
- El showreel no tiene video aún: en el JS hay una constante `SRC = ""` — al poner ahí la URL de un MP4 se reproduce inline.
- Respetar `prefers-reduced-motion` (ya implementado).

## Arquitectura de datos (Supabase, esquema public)

Tablas (todas con RLS activado):
- `perfiles` (id = auth.users.id, nombre, es_admin) — se crea sola al registrarse vía trigger `crear_perfil`
- `admins_autorizados` (email) — emails que reciben es_admin automáticamente al registrarse. Actuales: pagabo18@hotmail.com, brianrso@hotmail.com
- `proyectos` (nombre, disciplina, fecha, ubicacion, estatus)
- `corredores` (proyecto_id, usuario_id, numero, nombre, email, moto, categoria, color_galeria, diseno_galeria, estatus, avance, posicion, mejor_vuelta, tiempo_total, velocidad_max)
- `vueltas` (corredor_id, numero, tiempo, diferencia, posicion)
- `fotos` (corredor_id, ruta, frame, es_video, favorita)

Storage: bucket privado `fotos`. Rutas: `{corredor_id}/{timestamp}-{nombre_archivo}`. El corredor ve sus fotos con URLs firmadas de 1 hora.

Vinculación corredor↔cuenta: el admin pone el email en la fila del corredor; cuando ese email se registra, el trigger lo vincula (y viceversa, trigger `vincular_corredor` al insertar/editar email). Estatus posibles: Sin editar, En edición, Revisión, Entregado.

Seguridad (RLS): los admins (perfiles.es_admin, vía función `soy_admin()`) tienen todo; cada corredor solo SELECT de sus filas (proyecto, corredor, vueltas, fotos) y UPDATE de su color/diseño/favoritas. Bucket: admin todo, corredor solo lectura de sus archivos.

## Estado actual (2026-07-03)

- Proyecto cargado: **Enduro 2026 Atemajac** (2026-06-28, Atemajac, JAL) con 26 corredores: 22 "En edición" (avance 25%), 4 "Sin editar" (números 32, 572, 811, 816).
- Detalles a resolver: #28 está duplicado (Jossue Larios / José Luis Larios — confirmar si es la misma persona); "@pepopartp" #532 y "Señor amigo de Tato" #730 necesitan nombre real; Paco GRV corre #212 pero con camisa 512 (no confundir con Capi Saeb #512); equipo Giovanni Navarro: Karol #811, Toto #433, Uriel #138, Efrén #235.
- Admins: Gabriel (pagabo18@hotmail.com, activo, confirmado) y Brian (brianrso@hotmail.com, pre-autorizado, pendiente de registrarse).
- **Pendiente inmediato: mañana suben el primer ZIP de fotos de Atemajac** desde el panel admin (pestaña "Subir fotos" → elegir proyecto y corredor → soltar ZIP; se descomprime en el navegador con JSZip y sube cada archivo en calidad original, sin recompresión).

## Funcionalidad del sitio

- Público: hero slideshow, disciplinas, tira de contactos, showreel, carrusel, sección de acceso, servicios, contacto.
- Registro/login reales (supabase-js v2 por CDN jsdelivr; JSZip por cdnjs). Al iniciar sesión, enruta por `perfiles.es_admin`: admin → panel admin, corredor → su portal. Sesión persistente (auto-abre el portal al recargar).
- Portal corredor: número dorsal gigante, tags (moto, categoría, proyecto), telemetría (posición, mejor vuelta, tiempo total, vel. máx), tabla de vueltas (mejor vuelta resaltada ★), galería con favoritas ★ (persisten), descarga en original, y personalización de color (5 swatches) y diseño (mosaico/rollo) que SE GUARDAN en su fila.
- Panel admin: crear proyectos; por proyecto: lista de corredores con estatus (select), avance (%), botón "Tele" (edita telemetría + vueltas en formato "tiempo, diferencia, posición" una por línea), eliminar; agregar corredor (nombre, nº, email, moto, categoría); subir archivos sueltos o ZIP con progreso.

## Convenciones y preferencias del cliente

- Todo en español (UI y comunicación).
- Gabriel no es programador: darle pasos concretos, hacer el trabajo técnico por él cuando sea posible.
- Estética: elegante, motorsport premium, mucho movimiento y sonido; NO naranja/negro.
- Tokens: siempre pedirlos temporales y recordarle revocarlos al terminar.

## Roadmap sugerido (no iniciado)

1. Miniaturas automáticas (las galerías cargarán lento con cientos de fotos originales)
2. Dominio propio (p. ej. tarmac.mx) — GitHub Pages o migrar a Vercel (repo ya listo para importar en vercel.com/new)
3. Marca de agua en previews antes de "Entregado"
4. Video de showreel real (llenar `SRC`)
5. Notificación al corredor cuando su sesión pase a "Entregado"
6. Selector de proyecto en el portal del corredor si participa en varios
7. Vigilar límites del plan gratuito de Supabase (1 GB storage) — al crecer, migrar originales a Cloudflare R2 (~$0.015/GB/mes, egreso gratis) manteniendo Supabase para auth y datos
