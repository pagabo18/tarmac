-- Total de archivos (fotos/videos) en el link de descarga de cada corredor.
-- Se muestra en su portal para que sepan cuando su galeria se actualiza.
-- Se poblo con el conteo real del contenido de cada ZIP archive de SmugMug.
alter table public.corredores add column if not exists fotos_totales integer;
