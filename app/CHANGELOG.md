# Novedades de la app EcoResiduos

Cada versión publicada en [Releases](https://github.com/C3RLOSMORENO/EcoResiduos/releases) muestra la sección que le corresponde. El encabezado de cada sección debe ser `## X.Y.Z`, igual a la versión de `pubspec.yaml`.

## 1.2.0

- En Cuenta, el generador puede cambiar su nombre, documento, teléfono y correo de acceso. El correo nuevo se confirma con un enlace que llega a ese correo; hasta entonces se sigue entrando con el anterior.
- El recorrido de primera vez empieza con una bienvenida que explica en cuatro pasos cómo funciona la app, y luego señala cada parte de la pantalla de inicio. Se avanza y retrocede con Siguiente y Anterior, se puede saltar en cualquier momento y se repite desde Cuenta, en Ver el recorrido de nuevo.
- El recorrido se marca como visto al terminarlo o saltarlo; si la app se cierra a mitad, vuelve a aparecer. El botón Atrás del teléfono lo cierra, y cada paso tiene etiquetas para lectores de pantalla como TalkBack.
- Al editar un dato en Cuenta o al filtrar materiales para publicar, el teclado ya no tapa lo que se está escribiendo.
- Los textos de los recorridos describen mejor qué solicitudes ve cada empresa gestora, las secciones de la barra inferior y los datos que se piden al publicar.
- Al entrar, la app confirma con «Iniciaste sesión.». Si el inicio de sesión falla, el aviso aparece junto al botón Entrar y se quita en cuanto corriges el correo o la contraseña. Sin internet, la app lo dice en español en lugar de mostrar el error técnico.
- En el registro y al recuperar la contraseña, el error del envío sale encima del botón, a la vista aunque hayas bajado por el formulario. La regla de la contraseña se lee debajo del campo desde antes de escribir.
- La contraseña nueva que se crea al recuperarla también debe tener una letra, como la del registro.
- En Cuenta, los avisos de guardado se ven dentro de la hoja; antes quedaban tapados por ella. Cada uno dice qué dato cambió.
- El correo de soporte es el mismo en toda la app: soporte@ecoresiduos.com.

## 1.1.0 (30 de octubre de 2026)

- Para crear una cuenta hay que autorizar el tratamiento de datos personales (Ley 1581 de 2012). La política completa se puede leer desde el registro, y quien ya tenía cuenta la acepta la próxima vez que entra.
- Los teléfonos se validan: celular o fijo de 10 dígitos, fijo de 7 dígitos (se guarda con el indicativo 607) o línea 01 8000. Si el NIT trae dígito de verificación, se comprueba.
- Las contraseñas nuevas deben tener al menos 8 caracteres, con letras y números.
- Primer recorrido guiado para quien entra por primera vez.
- La guía de residuos muestra subcategorías con ejemplos y enlaces a las normas oficiales.
- Ajustes en las pantallas de publicar, detalle de la solicitud, ofertas y solicitudes disponibles.

## 1.0.0 (16 de octubre de 2026)

Primera versión publicada.

- Identificación de residuos con la cámara, sin conexión, en 8 categorías según la Resolución 2184 de 2019.
- Publicación de solicitudes de recolección con foto, cantidad, dirección y ubicación.
- Ofertas de las empresas gestoras autorizadas, elección de una y confirmación de la entrega.
- Certificados de disposición final o aprovechamiento en PDF.
- Directorio de empresas gestoras, guía de residuos y avisos de cada cambio en una solicitud.
