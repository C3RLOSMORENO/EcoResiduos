# Pendientes del rediseño

| Pendiente | Situación actual | Qué haría falta |
| :--- | :--- | :--- |
| Notificaciones push | Las novedades se guardan en la tabla `notificaciones` y la campana se actualiza en tiempo real mientras la app está abierta. Con la app cerrada no llega aviso. | Proyecto de Firebase (`google-services.json` / `GoogleService-Info.plist`), Firebase Cloud Messaging en la app y un Database Webhook que llame a una Edge Function al insertar en `notificaciones`. |
| Distancia a las solicitudes | Se calcula con la ubicación del teléfono al publicar; publicaciones anteriores no tienen coordenadas. | Nada, se completa con el uso. |
| Identificador de la app | `applicationId` sigue siendo `com.example.ecoresiduos`. | Cambiarlo antes de publicar en tiendas (reinstala la app en los teléfonos de prueba). |
