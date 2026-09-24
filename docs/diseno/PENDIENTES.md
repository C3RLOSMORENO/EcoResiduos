# Pendientes del rediseño

| Pendiente | Situación actual | Qué haría falta |
| :--- | :--- | :--- |
| Notificaciones completas (leído/no leído, descartar, push) | «Novedades» se calcula con los datos de los últimos 7 días. | Tabla `notificaciones` y Firebase Cloud Messaging. |
| Historial de estados con fecha | La fecha de «En negociación» se pierde al pasar a Recolectado (se muestra «—»). | Tabla de historial de cambios de estado. |
| Horario de los gestores | Se muestra si `perfiles_gestor` tiene columna `horario` u `horario_atencion`; hoy no se confirma que exista. | Agregar la columna y el campo en el admin-panel. |
| Distancia a las solicitudes | Se calcula con la ubicación del teléfono al publicar; publicaciones anteriores no tienen coordenadas. | Nada, se completa con el uso. |
| Publicar sin conexión | «Publicar» se deshabilita sin red. | Cola local de publicaciones pendientes. |
| Advertencia técnica por material | Se muestra si `materiales_residuos` tiene la columna `advertencia_manejo`; el admin-panel no la edita. | Agregar la columna y el campo en el admin-panel. |
| Fotos reemplazadas en Storage | Al cambiar la foto de una publicación, la anterior queda en el bucket: «Publicar de nuevo» y los escaneos pueden compartir el mismo archivo, así que la app no la borra. | Edge Function programada que borre, con la API de Storage, los archivos que ninguna fila de `solicitudes_recoleccion` ni `historial_escaneos_ia` referencia. |
