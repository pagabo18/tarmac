# Changelog — TARMAC

Registro de cambios publicados en producción (tarmac.mx / GitHub Pages, rama `main`).

## 2026-09-20

### Página principal
- **Fotos y textos cruzados corregidos**: el carrusel "Destacados" mostraba fotos distintas a sus títulos porque `data-bg` pisaba las fotos `data-pic`; ahora cada slide muestra su foto y los textos describen lo que se ve (Supra de frente, barrido en el bosque, paddock, curva de tierra roja). La tira de contactos pasó de 5 a **7 fotos únicas** con etiqueta correcta (ENDURO / LUJO / PADDOCK) y **se abren en lightbox**.
- **Nueva sección "Última carrera"** (`#galeria` + link "Galería" en el menú): galería pública en mosaico con las fotos que el admin marcó 🌐 de corredores que aceptaron la autorización de uso de imagen. Filtros por número de corredor, "Ver más" (24 en 24) y lightbox. Se oculta sola si no hay fotos públicas.
- **Lightbox nuevo** para todo el sitio: ← → , teclado, swipe, contador, leyenda, botón de descarga (solo en el portal), soporte de video.

### Portal del corredor
- Galería en **mosaico con proporción real** (ya no recorta a cuadrados); "Rollo" sigue siendo horizontal. Badge 🌐 en las fotos publicadas en la página.

### Panel admin
- En **👁 Ver portal**: por foto **↺ ↻ girar y guardar** (arregla las que se subieron volteadas), **🌐 publicar/ocultar** y **✕ eliminar**; barra con el permiso del corredor y "Publicar todas / Ocultar todas".
- En el proyecto: **"🌐 Publicar todas en la web" / "Ocultar de la web"**; en cada fila `✓ autorizó uso de imagen` y `🖼 N en la web`. Aviso en rojo si falta aplicar la migración.

### Base de datos (`sql/galeria_publica.sql`, **pendiente de aplicar** — el MCP no tuvo permiso en esta sesión)
- `fotos.publica`, RPC `fotos_publicas()` (anon), helper `foto_publica_por_ruta(text)` y política de storage `fotos publicas visibles` para que el público solo pueda firmar las fotos públicas.

## 2026-07-08

Sesión grande. Todo lo de abajo quedó **en producción** y probado.

### Portal del corredor
- **⚙️ Ajustes**: el corredor ve su número (solo lectura) y edita su **nombre** y **correo**. (`actualizar_datos_corredor`)
- **Login por número _o_ correo**: un solo campo acepta el número o el correo registrado (`eventos_por_correo`).
- **Consentimiento para compartir en la web**: interruptor que **solo se puede aceptar** (con confirmación). Para retirarlo, el corredor escribe por Instagram y el admin lo quita. Se guardan fechas de aceptación y revocación. (`actualizar_consentimiento_compartir` solo-true, `admin_set_compartir`)
- **Foto de portada propia** por corredor (usa una de sus fotos) + **lightbox** (click en foto → ampliada al centro).
- **Botón de descarga** muestra el total de archivos del link (`fotos_totales`) y **registra** cada descarga (`registrar_descarga`).
- **🏁 Mis tiempos**: editor de telemetría con inputs tipo flechitas (min:seg.déc), posición manual, agregar/quitar vueltas. Mejor vuelta, tiempo total y diferencias **automáticos**. (`actualizar_telemetria`)
- Mensajes de "muestra" / "seguimos subiendo más contenido".

### Panel admin
- **Conteo de fotos** por corredor y **filtro por estatus**.
- **Estatus → avance automático** (nuevo estatus "Seleccionando" = 25%).
- **"👁 Ver portal"**: vista previa del portal de cada corredor sin iniciar sesión como él.
- **"🔑 Dar acceso a todos (con link)"**: crea el acceso de todos los que tengan link (contraseña `Atemajac2026#<número>`).
- **Estado por corredor**: correo, si ya entró (última sesión real), cuántas veces descargó, y 🌐 comparte con enlace **"(quitar)"**. (`estado_corredores`)

### Contenido / datos
- Contacto del sitio cambiado de correo a **Instagram @tarmac_official_** (botón + avisos legales).
- 20 corredores de Atemajac con link de descarga, acceso y fotos de muestra (2-4 c/u).
- #28 duplicado resuelto; #532 y #730 con su número como nombre provisional.

### Migraciones SQL (en `sql/`)
`ajustes_compartir`, `login_por_correo`, `actualizar_telemetria`, `fotos_totales`, `estado_corredores`, `compartir_solo_aceptar`.

## 2026-07-07

- Login por número reconstruido + descarga por `descarga_url` + provisión de acceso por admin (Edge Function `provisionar_corredor`).

## 2026-07-03

- Esquema inicial (perfiles, proyectos, corredores, vueltas, fotos), RLS, bucket `fotos`, panel admin y portal base. Proyecto Enduro 2026 Atemajac cargado.
