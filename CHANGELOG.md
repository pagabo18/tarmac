# Changelog — TARMAC

Registro de cambios publicados en producción (tarmac.mx / GitHub Pages, rama `main`).

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
