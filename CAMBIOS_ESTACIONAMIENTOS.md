# Registro de cambios: módulo Estacionamientos

**Rama:** `Estephany` · **Responsable:** Estephany Cárdenas (Arquitecta de Software y BD)

Este archivo reúne los cambios del módulo Estacionamientos. Cada cambio nuevo se agrega como una sección más, al final.

- **Alcance del módulo:** HU-15 a HU-21, RF-016 a RF-022, CU15 a CU21, épica EP-03 (planificado para el Sprint 4).
- **Reparto del trabajo:** Almendra Cifuentes hace el front y algunas reglas (al 11-nov todavía no están en GitHub). Este archivo registra la parte de arquitectura, base de datos e IA, y la integración de ambas partes.
- **Números de línea:** revisados el 12-nov contra el código actual, después de agregar comentarios a todas las funciones del módulo. Si un archivo cambia después, pueden moverse. La sección [Mapa del código](#mapa-del-código) reúne la ubicación de todas las funciones.
- **Rutas:** todas son relativas a `Producto/tag_ok/`.

## Índice

| # | Fecha | Cambio | Requisito | Estado |
|---|---|---|---|---|
| 1 | 11-nov | [Reglas de Firestore para `estacionamientos`](#1-reglas-de-firestore-para-estacionamientos) | HU-15 a HU-21 / RF-016 a RF-022 | Tests OK en el emulador. **Publicado el 11-nov** (commit `10cc760`) |
| 2 | 11-nov | [Servicio de estacionamientos y "¿Dónde está mi auto?"](#2-servicio-de-estacionamientos-y-dónde-está-mi-auto) | HU-15 a HU-18 / RF-016 a RF-019 | Tests OK (commits `588841c` y `13fe939`). Se usa desde la pantalla de prueba (cambio 8); **falta conectarlo a las pantallas reales** |
| 3 | 12-nov | [Seguimiento en vivo en el mapa y errores del GPS en el navegador](#3-seguimiento-en-vivo-en-el-mapa-y-errores-del-gps-en-el-navegador) | HU-18 / RF-019 / CU18 | Tests OK |
| 4 | 12-nov | [Tope de 30 días en la duración guardada](#4-tope-de-30-días-en-la-duración-guardada) | HU-17 / RF-018 | Tests OK |
| 5 | 12-nov | [Registro con IA desde el ticket](#5-registro-con-ia-desde-el-ticket) | HU-19 a HU-21 / RF-020 a RF-022 / CU19 a CU21 | Tests OK (commit `a29012c`) y probado con 3 tickets simulados. **Falta el formulario definitivo** (front) |
| 6 | 12-nov | [Dirección escrita del auto en el mapa](#6-dirección-escrita-del-auto-en-el-mapa) | HU-18 / RF-019 | Tests OK (commit `1adbea3`). Token de Mapbox reemplazado el 12-nov en el `.env` de Estephany |
| 7 | 12-nov | [Nombre de las calles en la tarjeta y el historial](#7-nombre-de-las-calles-en-la-tarjeta-y-el-historial) | HU-18 / RF-019 | Tests OK, sin commit |
| 8 | 12-nov | [Pantalla de prueba del módulo en el repositorio](#8-pantalla-de-prueba-del-módulo-en-el-repositorio) | Apoyo a HU-15 a HU-21 | Sin commit |
| 9 | 12-nov | [Conexión TEMPORAL del botón "Estacionamiento" a la pantalla de prueba](#9-conexión-temporal-del-botón-estacionamiento-a-la-pantalla-de-prueba) | Apoyo a HU-46 | Sin commit. **⚠️ Se debe quitar** antes de unir la rama a `develop`/`main` o de publicar |

## Qué piden los requisitos

| HU / CU | RF | Qué pide |
|---|---|---|
| HU-15 / CU15 | RF-016 | Registrar manualmente: vehículo, fecha, lugar, hora de entrada, hora de salida, costo y observación |
| HU-16 / CU16 | RF-017 | **Iniciar estacionamiento:** registra el inicio y empieza a contar el tiempo. El estacionamiento queda **activo** hasta finalizarlo |
| HU-17 / CU17 | RF-018 | **Finalizar estacionamiento:** registra la hora de término y calcula la duración. Exige un estacionamiento iniciado antes |
| HU-18 / CU18 | RF-019 | Guardar la ubicación GPS para recordar dónde quedó el vehículo |
| HU-19 / CU19 | RF-020 | Registrar con IA desde la foto del ticket o boleta: lugar, fecha, entrada, salida, duración y monto **cuando estén disponibles** |
| HU-20 / CU20 | RF-021 | Completar o corregir a mano lo que la IA no reconoció. Un campo no obligatorio se puede dejar vacío |
| HU-21 / CU21 | RF-022 | Confirmar explícitamente antes de guardar un registro hecho con IA |

Fuente: `Lista de C. U. __ Historias de Usuario, Épicas, Sprint, etc (1).xlsx`, `Plantillas de C.U. por cada C.U (1).docx` y `Lista de requerimientos funcionales y no funcionales`.

**Relacionados fuera del módulo:**
- **HU-45 / RF-048:** gastos por categoría en el dashboard. Ya leen la colección `estacionamientos`.
- **HU-46 / RF-049:** acción rápida "Registrar estacionamiento" en el Inicio. Hoy abre una pantalla de "próximamente".

---

## 1. Reglas de Firestore para `estacionamientos`

### Para qué
Firestore deniega todo lo que no está en las reglas, así que sin ellas la app no puede guardar ni leer estacionamientos. Las reglas se escribieron desde la arquitectura y la base de datos; cuando Almendra suba su parte, se comparan con las suyas y se unifican.

### Decisiones (11-nov, Estephany)
- **Dueño en `uid`:** igual que mantenciones y cargas, y es el nombre con el que el Inicio y Gastos ya buscan los estacionamientos (`lib/screens/inicio_dashboard_screen.dart:132` y `lib/screens/dashboard/gastos_historial.dart:111`). El diccionario de datos no tiene un campo de dueño para ESTACIONAMIENTOS: hay que agregarlo.
- **`hora_entrada` y `hora_salida` guardan fecha y hora completas** (timestamp), no solo la hora como dice el diccionario (`TIME`). Así el cronómetro sobrevive al cierre de la app y la duración se calcula bien aunque pase la medianoche.
- **Un estacionamiento finalizado no se modifica**, igual que las cargas. Si hay un error, se borra y se registra de nuevo.
- **El cronómetro solo se inicia con "Iniciar estacionamiento"** (CU16). Un registro hecho con IA se guarda siempre como `finalizado`, con lo que se leyó o se completó a mano (CU19 a CU21). Esto se contrastó con las plantillas de casos de uso:
  - el flujo de IA termina en confirmar y guardar, y nunca inicia un cronómetro;
  - si falta un dato, el usuario lo completa o lo deja vacío (CU19 E1, CU20 E1).

### Campos

| Campo | Obligatorio | Tipo y validación |
|---|---|---|
| `uid` | Sí | Texto. Tiene que ser el usuario que guarda. No se puede cambiar |
| `vehiculo_id` | Sí | Texto. El vehículo tiene que ser del usuario. No se puede cambiar |
| `fecha` | Sí | Fecha y hora. No se puede cambiar |
| `estado` | Sí | `activo` (cronómetro corriendo) o `finalizado` |
| `origen_registro` | Sí | `manual` o `ia`. No se puede cambiar |
| `hora_entrada` | No | Fecha y hora. No se puede cambiar |
| `hora_salida` | No | Fecha y hora; no puede ser anterior a la entrada |
| `duracion_min` | No | Entero entre 0 y 43.200 (30 días) |
| `costo` | No | Pesos, entero entre 0 y 10.000.000 |
| `lugar` | No | Texto de hasta 100 caracteres |
| `observacion` | No | Texto de hasta 500 caracteres |
| `ubicacion` | No | Coordenadas GPS (GeoPoint) |
| `fecha_captura` | No | Fecha y hora en que se leyó el ticket |
| `confianza_ia` | No | Número entre 0 y 100 |

Los campos no obligatorios pueden faltar o ser `null`, para permitir registros parciales. No hay `archivo_path`, porque no se guarda la foto del ticket (RF-055).

### Funciones (`firestore.rules`)
- **Encabezado** (línea 62): describe la colección, sus campos y tipos, junto a las demás colecciones.
- **`estacionamientoValido(d)`** (línea 453): valida el documento completo.
  - Solo acepta los campos de la tabla; cualquier otro hace fallar el registro.
  - Revisa los obligatorios, los tipos y los límites de cada campo.
  - Con las dos horas, la salida no puede ser anterior a la entrada.
  - **`activo`** exige `hora_entrada`, no permite `hora_salida` y solo puede ser `manual`.
- **`match /estacionamientos/{estacionamientoId}`** (línea 480):
  - **Leer y borrar:** solo el dueño.
  - **Crear:** con el `uid` propio y en un vehículo propio (`vehiculoEsDe`).
  - **Modificar** (línea 491): **solo mientras está `activo`**.
    - Se pueden cambiar `hora_salida`, `duracion_min`, `costo`, `estado`, `lugar`, `observacion` y `ubicacion`.
    - Para pasar a `finalizado` es obligatoria la `hora_salida` (RF-018).
    - `uid`, `vehiculo_id`, `fecha`, `hora_entrada` y `origen_registro` no se pueden cambiar.
- **Lo que las reglas no pueden exigir:** "un solo estacionamiento activo por vehículo". Lo tiene que controlar la app.

### Pruebas (`tools/rules_test/rules.test.js`, "Prueba 11", línea 381)

| Test | Qué comprueba |
|---|---|
| 11a | Crear manual propio pasa; con `uid` ajeno, sin sesión o con vehículo ajeno falla |
| 11b | Registro parcial: solo fecha, estado y origen son obligatorios |
| 11c | Con IA se crea finalizado; la IA no puede crear uno activo |
| 11d | Cronómetro: activo con entrada y sin salida pasa; sin entrada o con salida falla |
| 11e | Fallan: estado u origen inventados, costo negativo o con decimales, duración excesiva, salida antes de la entrada, ubicación en texto, hora como texto ("10:30"), campos extra y lugar demasiado largo |
| 11f | Finalizar con hora de salida pasa; sin ella, o cambiando `uid`, vehículo, fecha, entrada u origen, falla |
| 11g | Un estacionamiento finalizado no se modifica |
| 11h | El dueño lee, lista por `uid` (la misma consulta del Inicio y Gastos) y borra; otro usuario no lee, no edita ni borra |

**Resultado:** las 8 pruebas nuevas pasan (49 de 50 en total). La que falla, `8g` (mantenciones), ya fallaba antes de este cambio: espera que se rechace un tipo de mantención inventado, pero las reglas aceptan títulos libres desde el Sprint 3.

**Cómo ejecutarlas** (desde `tools/rules_test`, con el emulador):
```
firebase emulators:exec --only firestore --project demo-tag-ok --config firebase.json "node --test --test-concurrency=1 rules.test.js"
```

### Publicación (11-nov, 23:34)
1. **Antes de publicar** se descargaron las reglas publicadas en Firebase y se compararon:
   - eran idénticas a las del repositorio antes de este cambio, así que nadie había publicado otras;
   - lo que se iba a publicar solo **agregaba** líneas (77) y no quitaba ninguna.
2. **Se publicó** con `firebase deploy --only firestore:rules --project tag-ok-v2`.
3. **Se verificó** que las reglas publicadas son idénticas al archivo del commit `10cc760`.

> **Regla de Danae sin publicar:** `develop` tiene una regla nueva para la colección `concesionarias` (commit `976efb8`, panel admin), que no estaba publicada antes y sigue sin publicar. No se incluyó porque es un cambio de otra rama. Se suma al integrar `develop`; mientras tanto, la página de concesionarias del panel admin no podrá leer ni escribir esa colección.

---

## 2. Servicio de estacionamientos y "¿Dónde está mi auto?"

### Para qué
- **Localizar el vehículo (HU-18, CU18, RF-019):** guardar dónde quedó el auto y poder consultarlo después.
- **Para eso tiene que existir un estacionamiento.** Por eso se dejó listo el servicio completo del módulo, que es lo que las pantallas le piden a la base de datos. El front de Almendra solo tiene que conectar sus botones a estas funciones, sin escribir código de Firestore, y todo calza con las reglas publicadas (cambio 1).

### Decisiones (11-nov, Estephany)
- **El mapa se muestra dentro de TAG OK**, no en Google Maps. Se reutiliza el mapa que ya usa la pantalla de TAG (`flutter_map` con mapas de Mapbox y el token `MAPBOX_ACCESS_TOKEN` del `.env`), así que no se agregan dependencias ni costos.
- **La ubicación se guarda cuando el usuario presiona "Guardar ubicación"**, como dice el CU18. No se guarda automáticamente al iniciar el cronómetro.
- **La pantalla del mapa la hace Estephany**, como pieza independiente: el front solo agrega el botón que la abre.

### Funciones: modelo (`lib/data/models/estacionamiento_model.dart`, nuevo)
- **`EstadoEstacionamiento`** (línea 5): `activo` (cronómetro corriendo) o `finalizado`. **`fromFirestore`** (línea 23) lee el valor guardado; uno desconocido se lee como `finalizado`, para que nunca quede un registro abierto por error.
- **`duracionEnMinutos(entrada, salida)`** (línea 33): minutos completos entre las dos horas. Nunca es negativa y funciona aunque se cruce la medianoche.
- **`EstacionamientoModel`** (línea 58): los campos de las reglas publicadas.
  - **`estaActivo`** (línea 104): `true` si el cronómetro está corriendo. **`tieneUbicacion`** (línea 107): `true` si se guardó dónde quedó el auto. **`titulo`** (línea 110): el lugar, o "Estacionamiento" si no hay.
  - **`minutosTranscurridos({ahora})`** (línea 118): si está activo, cuenta hasta ahora (para mostrar el cronómetro); si está finalizado, usa la duración guardada.
  - **`fromJson`** (línea 133) y **`toJson`** (línea 158): leen y escriben exactamente los campos que aceptan las reglas. La ubicación es un `GeoPoint`.

### Funciones: GPS (`lib/data/services/ubicacion_service.dart`, nuevo)
- **`MotivoErrorUbicacion`** (línea 8) y **`mensajeErrorUbicacion`** (línea 23): las excepciones del CU18, cada una con un mensaje listo para mostrar.

  | Motivo | Mensaje | CU18 |
  |---|---|---|
  | GPS apagado | "Activa la ubicación de tu dispositivo…" | E1 |
  | Sin señal o demora más de 15 s | "No se pudo obtener tu ubicación…" | E1 |
  | Permiso denegado | "Sin permiso de ubicación no se puede guardar…" | E2 |
  | Permiso bloqueado | "…Habilítalo en los ajustes de tu dispositivo o del navegador." | E2 |

- **`ErrorUbicacion`** (línea 41): el error que reciben las pantallas, con `.mensaje`.
- **`distanciaEnMetros(a, b)`** (línea 54): distancia en línea recta, con el paquete `latlong2`, que ya estaba instalado.
- **`textoDistancia(metros)`** (línea 63): "a 230 m" o "a 1,4 km".
- **`UbicacionService.obtenerUbicacionActual()`** (línea 78): revisa que la ubicación esté activa, pide el permiso si hace falta y devuelve la posición. Funciona en web y en Android con `geolocator`, el mismo paquete del mapa de TAG.

### Funciones: servicio (`lib/data/services/estacionamiento_service.dart`, nuevo)

| Función | Línea | Qué hace | Requisito |
|---|---|---|---|
| `registrarManual(...)` | 49 | Guarda un estacionamiento terminado y calcula la duración si vienen las dos horas. Rechaza una salida anterior a la entrada. También sirve para guardar lo confirmado con IA (`origenRegistro: 'ia'`) | HU-15, HU-21 |
| `iniciar(vehiculoId)` | 95 | Inicia el cronómetro: guarda la fecha y hora de entrada y deja el estacionamiento `activo`. **No permite dos activos en el mismo vehículo**, porque las reglas no pueden impedirlo | HU-16 |
| `finalizar(id, costo)` | 137 | Guarda la hora de salida, calcula la duración y el costo, y lo deja `finalizado`. Si el reloj del dispositivo quedó atrás de la entrada, usa la entrada, para no romper la regla | HU-17 |
| `guardarUbicacion(id, ubicacion)` | 156 | Asocia el GPS al estacionamiento. Se llama al presionar "Guardar ubicación". Solo funciona mientras está activo | HU-18 |
| `obtenerActivo` / `streamActivo` | 162 / 169 | El estacionamiento en curso del vehículo; la versión *stream* se actualiza sola, para el cronómetro y el botón del mapa | HU-16, HU-18 |
| `streamPorVehiculo` | 197 | Historial del vehículo, el más reciente primero | Consulta |
| `eliminar` / `eliminarDeVehiculo` | 209 / 213 | Borra uno, o todos los de un vehículo | — |

- **`_activoPorId`** (línea 122): antes de modificar, comprueba que el estacionamiento siga activo. Si no, el mensaje es *"El estacionamiento ya fue finalizado y no se puede modificar."*
- **Funciones de apoyo:**
  - **`_uidActual`** (línea 30): el usuario con sesión; sin sesión lanza un error, porque las reglas no permiten guardar sin dueño.
  - **`_limpio`** (línea 39): quita espacios sobrantes; un texto vacío se guarda como `null`.
  - **`_consultaActivo`** (línea 175): la consulta del estacionamiento activo de un vehículo, compartida por `obtenerActivo` y `streamActivo`.
  - **`_primeroActivo`** (línea 184): si por algún motivo hubiera más de uno activo, toma el más reciente.
- **Consultas sin índices compuestos:** todas usan solo igualdades (`uid`, `vehiculo_id`, `estado`), y el orden se aplica en la app, igual que en cargas.
- **No registra en `auditoria`.** Mantenciones y cargas sí lo hacen; agregarlo aquí queda como decisión pendiente.

**`lib/data/services/vehiculo_service.dart`** (línea 195): al eliminar un vehículo también se borran sus estacionamientos. Igual que las cargas, si falla no impide borrar el vehículo.

### Pantalla "¿Dónde está mi auto?" (`lib/screens/estacionamientos/mapa_auto_screen.dart`, nueva)
- **`MapaAutoScreen(ubicacionAuto, lugar)`** (línea 26): recibe la ubicación guardada y el lugar escrito por el usuario.
- **Mapa** (línea 175): el mismo de la pantalla de TAG, centrado en el auto (`_puntoAuto`, línea 76), con:
  - **pin del auto** (`_PinAuto`, línea 258);
  - **tu posición**, el punto azul (`_PuntoUsuario`, línea 292);
  - **dos botones** para centrar el mapa en el auto (`_centrarEnAuto`, línea 151) o en ti (`_centrarEnMi`, línea 155).
- **Tarjeta inferior** (`_TarjetaResumen`, línea 326): el lugar y *"Tu auto está a 230 m en línea recta"*.
- **`_buscarMiUbicacion`** (línea 111): tu posición es opcional. Si no hay permiso o señal, el mapa igual muestra el auto, avisa el motivo y ofrece "Reintentar".
- **Cómo se abre** (para el front):
  ```dart
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => MapaAutoScreen(ubicacionAuto: e.ubicacion!, lugar: e.lugar),
  ));
  ```
- **No muestra la ruta caminando paso a paso.** Se podría agregar después con el servicio de rutas de Mapbox.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_test.dart` (nuevo, 11 tests): duración (incluso cruzando la medianoche), campos del `toJson` iguales a los de las reglas, lectura de la ubicación, estado desconocido, cronómetro, distancia, texto de distancia y mensajes de error | 11 OK |
| App completa (`flutter test`) | 354 OK. `flutter analyze` sin errores |
| Reglas, emulador: nuevo test `11i` (`rules.test.js`, línea 480) con **exactamente lo que escribe el servicio**: iniciar con los opcionales en `null`, guardar solo la ubicación, finalizar sin costo, y que después de finalizar ya no se pueda guardar la ubicación | OK (50 de 51; `8g` ya fallaba) |

**Lo que no se puede probar sin pantallas:** el GPS real y el mapa. Se prueban en la app cuando el módulo tenga los botones "Iniciar", "Guardar ubicación", "Ver dónde está mi auto" y "Finalizar".

---

## 3. Seguimiento en vivo en el mapa y errores del GPS en el navegador

### Para qué
Al probar el cambio 2 en la app (12-nov) aparecieron dos cosas:
- **El punto azul no seguía al usuario.** La posición se leía una sola vez, al abrir el mapa. Si el usuario caminaba con el mapa abierto, el punto azul y la distancia ("a 230 m") quedaban congelados. Para buscar el auto lo útil es que la distancia vaya bajando mientras se camina.
- **Un error del navegador no tenía mensaje claro.** Con la ubicación de Windows apagada, el navegador responde "posición no disponible" (`PositionUpdateException`), y ese error no se traducía a un mensaje para el usuario.

### Decisión (12-nov, Estephany)
- **Activar el seguimiento en vivo** de la posición del usuario en "¿Dónde está mi auto?".
- **El punto del auto queda fijo:** es la ubicación guardada con "Guardar ubicación". Solo cambia si se vuelve a guardar mientras el estacionamiento sigue activo.

### Funciones (`lib/data/services/ubicacion_service.dart`)
- **`seguirUbicacion({metrosMinimos})`** (línea 112): entrega la posición del usuario cada vez que se mueve al menos 3 metros, con `Geolocator.getPositionStream`, la misma técnica con que el mapa de TAG sigue al usuario en la autopista. Los errores llegan traducidos a `ErrorUbicacion`.
- **`traducirErrorUbicacion(error)`** (línea 127): convierte los errores de `geolocator` en un motivo del CU18:
  - ubicación apagada → `gpsDesactivado`;
  - permiso denegado → `permisoDenegado`;
  - "posición no disponible", tiempo agotado u otro → `sinSenal`.

  Ahora la usan tanto `obtenerUbicacionActual()` (dentro de ella, en la línea 103) como el seguimiento en vivo.

### Funciones (`lib/screens/estacionamientos/mapa_auto_screen.dart`)
- **`_buscarMiUbicacion`** (línea 111): obtiene la primera posición, que es cuando se pide el permiso, y luego inicia el seguimiento.
- **`_seguirEnVivo`** (línea 131): cada posición nueva mueve el punto azul y recalcula la distancia. Si se pierde la señal, se mantiene el último punto conocido, se muestra el aviso y el seguimiento sigue intentando.
- **`dispose`** (línea 102): **detiene el seguimiento al cerrar el mapa**, para no seguir usando el GPS ni la batería.
- **Tarjeta inferior** (línea 404): bajo la distancia dice *"Se actualiza mientras caminas."*, o el aviso si se perdió la señal.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_test.dart`: nuevo test `traducirErrorUbicacion convierte los errores de geolocator` (línea 147) | 12 OK |

### Prueba manual (12-nov, web local)
- Se inició y se finalizó un estacionamiento: se guardaron bien la entrada, la salida, la duración y el costo.
- El mapa no se abrió porque **ese estacionamiento no tenía ubicación**: no se guardó antes de finalizar. Se confirmó en Firestore que no hubo ninguna escritura entre iniciar y finalizar.
- Se comprobó que **el cronómetro sigue corriendo aunque se cierre la ventana**: el inicio queda en Firestore y la duración se calcula al volver a abrir.

**Pantalla de prueba:** para probar sin el front del módulo se usa `lib/screens/estacionamientos/prueba_estacionamiento_screen.dart`, más un cambio temporal en la acción rápida "Estacionamiento" del Inicio. Al principio ninguno de los dos se subió a GitHub. El 12-nov se subieron la pantalla (cambio 8) y la conexión del botón, esta última de forma temporal (cambio 9).

---

## 4. Tope de 30 días en la duración guardada

### Para qué
Las reglas publicadas (cambio 1) aceptan `duracion_min` hasta 43.200 minutos (30 días), para rechazar datos absurdos. Si alguien inicia el cronómetro y se olvida de finalizarlo por más de un mes, al presionar "Finalizar":
1. la duración calculada supera el máximo (por ejemplo, 34 días = 48.960 minutos);
2. las reglas rechazan la escritura;
3. el estacionamiento **queda activo para siempre**, y como sigue activo, **tampoco se puede iniciar otro** en ese vehículo. Solo quedaría eliminarlo.

Lo mismo pasaría al registrar a mano un estacionamiento con la entrada y la salida separadas por más de 30 días.

### Decisión (12-nov, Estephany)
**Opción A:** guardar la duración con un tope de 30 días desde el servicio. Un estacionamiento de más de un mes es casi seguro un olvido, así que el número exacto no importa. **No se modificaron las reglas publicadas.** La opción descartada era subir el máximo de las reglas y volver a publicarlas.

### Funciones
- **`duracionMaximaMin = 43200`** (`lib/data/models/estacionamiento_model.dart`, línea 40): el mismo máximo de las reglas. Si se cambia en `firestore.rules`, hay que cambiarlo aquí también.
- **`duracionParaGuardar(entrada, salida)`** (línea 46): la duración real, pero con tope de 30 días. `duracionEnMinutos` sigue entregando la duración real, sin tope, para mostrar el tiempo transcurrido.
- **`EstacionamientoService`** (`lib/data/services/estacionamiento_service.dart`): `registrarManual` (línea 49) y `finalizar` (línea 137, en la línea 148) usan ahora `duracionParaGuardar`. Las horas de entrada y salida se guardan igual, con su valor real.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_test.dart`: nuevo test `duracionParaGuardar` (línea 31). Comprueba que 34 días se guardan como 30, que 30 días o menos se guardan tal cual, y que `duracionEnMinutos` sigue entregando la duración real | 13 OK |

---

## 5. Registro con IA desde el ticket

### Para qué
- **HU-19 / CU19 / RF-020:** el usuario sube la foto o el PDF del ticket o boleta y la IA lee el lugar, la fecha, las horas de entrada y salida, la duración y el monto, **cuando estén disponibles**.
- **HU-20 / CU20 / RF-021:** lo que la IA no reconoció queda para completar a mano, o vacío si no es obligatorio.
- **HU-21 / CU21 / RF-022:** nada se guarda sin la confirmación explícita del usuario.

### Decisiones (12-nov, Estephany)
- **Alcance:** se hace definitivo el componente de IA (lectura, validación y tests), que es la parte de arquitectura e IA. **El formulario definitivo de revisión es el mismo del registro manual (CU15), precargado con lo que leyó la IA**, igual que en combustible. Es del front de Almendra y se conecta al integrar. Para probar ahora se agregó un formulario simple en la pantalla de prueba local.
- **Ticket sin hora de salida** (por ejemplo, el de entrada de un mall): se guarda **finalizado**, con lo que haya. El usuario puede completar la salida a mano o dejarla vacía (CU19 E1, CU20 E1). El cronómetro solo se inicia con "Iniciar estacionamiento" (cambio 1).
- **Ticket con tarifa pero sin total pagado:** el monto queda vacío para que el usuario lo complete. **No se calcula**, porque sería inferir un valor que el ticket no dice.

### Cómo funciona
Es el mismo patrón que combustible (`combustible_extraction.dart`) y **no requiere cambios en la Edge Function** `ia-extraccion`, porque acepta cualquier esquema:
```
Foto/PDF → prepararImagenParaIa → Edge Function ia-extraccion → OpenAI
        → JSON con los campos → parseEstacionamientoExtraido (valida) → revisión → registrarManual(origen 'ia')
```

### Funciones (`lib/features/registro_inteligente/estacionamiento_extraction.dart`, nuevo)
- **Claves de campos dudosos** (líneas 15 a 20): `lugar`, `fecha`, `hora_entrada`, `hora_salida`, `duracion` y `costo`. La revisión resalta estos campos. **`_clavesDudosas`** (línea 23) las reúne: es lo único que se acepta como "dudoso".
- **`HoraDelDia`** (línea 33): una hora leída del ticket, sin fecha.
- **`EstacionamientoExtraido`** (línea 39): lo que leyó la IA. Todo es opcional.
  - **`vacia`** (línea 76): `true` si la IA no leyó ningún dato; la pantalla ofrece entonces el registro manual.
  - **`entrada`** (línea 85): fecha y hora completas de entrada.
  - **`salida`** (línea 91): fecha y hora completas de salida. Si el ticket no trae fecha de salida, se usa la de entrada. Si así la salida queda antes que la entrada, se asume que pasó la medianoche.
- **`_esquemaEstacionamiento`** (línea 118): el formato JSON estricto que debe devolver la IA. Todo campo puede ser `null`. Usa **`_campoTexto`** (línea 111) para cada campo de texto.
- **`_promptEstacionamiento`** (línea 154): las instrucciones a la IA, para tickets chilenos (malls, Saba, Central Parking, República, parquímetros municipales).
  - Lo que no se lee con certeza vuelve `null`: **nunca se inventa, se calcula ni se infiere**.
  - Las fechas chilenas son día/mes/año y en el monto el punto separa los miles. Las horas se piden en formato de 24 horas ("3:15 PM" es "15:15").
  - Si solo aparece una tarifa y no el total pagado, el monto vuelve `null`.
  - **Privacidad:** se ignoran la patente, el nombre, el RUT, el correo y el teléfono.
- **`interpretarHora`** (línea 201): entiende "10:30", "09:05:59", "15.45" y "15h30". Descarta horas imposibles como "25:00".
- **`minutosDeTexto`** (línea 213): entiende "95", "1:35", "1 h 35 min", "2 horas" y "45 min".
- **Funciones de apoyo para leer la respuesta:**
  - **`_combinar`** (línea 104): une fecha y hora en una fecha y hora completas;
  - **`_entero`** (línea 190): número entero de un texto como "$3.500";
  - **`_fechaPlausible`** (línea 234) y **`_fecha`** (línea 243): descartan fechas imposibles, futuras o anteriores a 1990;
  - **`_texto`** (línea 250): limpia y recorta un texto al largo que aceptan las reglas.
- **`parseEstacionamientoExtraido`** (línea 263): valida lo que devolvió la IA, con los mismos límites de las reglas publicadas, para que siempre se pueda guardar:
  - **Fecha:** se descarta si es futura o anterior a 1990, y se marca como dudosa. Es obligatoria para guardar.
  - **Salida antes que la entrada:** sin fecha de salida, se asume que pasó la medianoche y la salida se marca como dudosa. Con fecha de salida explícita anterior a la entrada, es un error de lectura: se marca y no se calcula la duración.
  - **Duración:** si el ticket la trae y no cuadra con las horas (tolerancia de 2 minutos, `toleranciaDuracionMin`, línea 258), **no se elige una**: se muestra la del ticket marcada como dudosa. Si el ticket no la trae, se calcula con las horas leídas. Siempre con tope de 30 días (cambio 4).
  - **Monto:** entero de hasta $10.000.000. **Lugar:** hasta 100 caracteres.
  - **Campos dudosos:** de la lista que entrega la IA, solo se aceptan las claves conocidas.
  - **Confianza:** la proporción de campos leídos sin duda (de 0 a 1), igual que en combustible. Se guarda en `confianza_ia`.
- **`extraerEstacionamiento`** (línea 365): prepara la imagen, la envía a la IA con la misma cascada de modelos y reintentos del Registro Inteligente, e interpreta la respuesta. Si la IA falla, lanza el error para que la pantalla ofrezca el registro manual (CU19 E2).

### Funciones: servicio (`lib/data/services/estacionamiento_service.dart`)
- **`registrarManual`**: nuevo parámetro opcional **`duracionMin`** (línea 55). Antes, un ticket con la duración pero sin las horas (por ejemplo, un parquímetro que solo dice "60 min · $1.200") perdía la duración. Ahora:
  - si vienen las dos horas, la duración se calcula con ellas;
  - si no, se usa `duracionMin` (línea 79), con tope de 30 días.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_extraction_test.dart` (nuevo, 14 tests, **sin llamar a OpenAI**: respuestas simuladas): formatos de hora y duración; ticket completo; duración que cuadra y que no cuadra; ticket solo de entrada; cruce de medianoche; fecha de salida explícita y una anterior a la entrada; fecha chilena, futura o ilegible; tarifa sin total; límites de las reglas; claves dudosas desconocidas; respuesta vacía | 14 OK |
| App completa (`flutter test`) | 370 OK. `flutter analyze` sin errores |

**Prueba local:** la pantalla de prueba (cambio 8) tiene ahora el botón **"Registrar con IA (foto o PDF del ticket)"** y un formulario simple de revisión, con los campos dudosos en naranja y botones para confirmar o cancelar. Sirve para probar con tickets reales; **cada lectura consume una llamada a OpenAI**.

### Prueba manual con tickets simulados (12-nov)
Se generaron 3 tickets de un estacionamiento **ficticio** ("Parking Demo SPA", con la leyenda "DOCUMENTO DE PRUEBA – SIN VALOR"), en `C:\Users\estef\Documents\tickets_prueba_tagok`, fuera del repositorio. Se cargaron desde la pantalla de prueba y se revisó en Firestore lo guardado:

| Ticket | Qué probaba | Resultado |
|---|---|---|
| 1. Completo | Lectura normal | ✅ Entrada 10:30, salida 12:05, 95 min, $3.500, confianza 100 % |
| 2. Medianoche | Salida 00:25 sin fecha de salida | ✅ Salida marcada para revisar; guardada el 12/11 a las 00:25, 45 min, $1.800, confianza 83 % |
| 3. Solo entrada | Ticket de ingreso con tarifa y sin total | ✅ Entrada 09:15; salida, duración y costo vacíos (la tarifa no se convirtió en monto) |

- **En los tres:** se guardaron con `origen_registro: 'ia'` y la hora de captura, y la patente del ticket **no apareció en ningún campo**.
- **El nombre del lugar varía:** a veces la IA lee "Parking Demo SPA" (el membrete) y otras "Estacionamiento Plaza Ficticia" (el subtítulo). Las dos lecturas son válidas, porque ambos textos están en el ticket.

---

## 6. Dirección escrita del auto en el mapa

### Para qué
En "¿Dónde está mi auto?" se veían el pin y la distancia, pero no una dirección que el usuario pueda leer. Ahora la tarjeta inferior dice, por ejemplo, **"Quedó en Avenida Providencia 1234, Providencia"**.

### Decisión (12-nov, Estephany)
**Solo se agrega la dirección escrita.** Otros dos ajustes propuestos no se hicieron:
- guardar la ubicación más rápido en el computador (precisión media en la web);
- dibujar el punto azul del usuario encima del pin del auto, con "Estás junto a tu auto" a menos de 20 m.

### Funciones
- **`GeocodingService.direccionDe(latitud, longitud)`** (`lib/data/services/geocoding_service.dart`, línea 67): búsqueda inversa de Mapbox (de coordenadas a dirección), con el mismo servicio y token que ya usaba la búsqueda de lugares. Pide `types=address,poi` y `language=es`. Si no hay conexión o Mapbox no encuentra nada, devuelve `null` y el mapa funciona igual.
- **`direccionCorta(placeName)`** (línea 92): deja calle, número y comuna, y quita el código postal, la región y el país. Por ejemplo, *"Avenida Providencia 1234, 7500000 Providencia, Región Metropolitana, Chile"* queda como *"Avenida Providencia 1234, Providencia"*.
- **`MapaAutoScreen`** (`lib/screens/estacionamientos/mapa_auto_screen.dart`):
  - **`_buscarDireccionAuto`** (línea 89) busca la dirección **una sola vez** al abrir el mapa, porque el auto no se mueve;
  - la tarjeta muestra *"Buscando la dirección…"* y luego *"Quedó en …"* (línea 380); si no se encuentra, no muestra nada;
  - el parámetro opcional `buscarDireccion` (línea 47) sirve para pruebas.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/direccion_corta_test.dart` (nuevo, 4 tests): dirección de calle, **formato real de Mapbox** (código postal al final de la región: *"Plaza de Armas 442, Santiago, Región Metropolitana de Santiago 8320000, Chile"* queda como *"Plaza de Armas 442, Santiago"*), lugar con nombre (POI) y respuesta sin datos útiles | 4 OK |

### Problema encontrado: el token de Mapbox es inválido
Al probar la búsqueda inversa con una llamada real, Mapbox respondió **"Not Authorized - Invalid Token"** (HTTP 401). Se comprobó que:
- **también fallan las imágenes del mapa** (las teselas) y **la búsqueda de lugares que ya usaba la app**, así que no es un problema de este cambio;
- **la web publicada** (`tag-ok-v2.web.app`) tiene el **mismo token**. Se comparó por huella, sin mostrar el token, y también es rechazado.

**Consecuencias:**
- el mapa de "¿Dónde está mi auto?" se ve sin calles;
- el **mapa de TAG** tampoco muestra calles;
- la **búsqueda de lugares** al armar una ruta no funciona;
- la dirección escrita no aparecerá hasta que se reemplace el token.

**Qué hay que hacer:**
1. Crear un token público nuevo en account.mapbox.com, con la cuenta del proyecto.
2. Reemplazar `MAPBOX_ACCESS_TOKEN` en el `.env` de cada integrante.
3. Recompilar y volver a publicar la web (`flutter build web ... --dart-define-from-file=.env` y `firebase deploy --only hosting`), y generar un APK nuevo si corresponde.

Conviene restringir el token nuevo a las URL de la app (localhost y `tag-ok-v2.web.app`).

**12-nov: token reemplazado en el `.env` de Estephany.** Se comprobó, sin mostrar el token, que responde HTTP 200 en las imágenes del mapa, en la búsqueda de lugares y en la búsqueda inversa. Falta:
- actualizar el `.env` del resto del equipo;
- volver a publicar la web;
- restringir el token por URL (hoy funciona desde cualquier origen).

---

## 7. Nombre de las calles en la tarjeta y el historial

### Para qué
Al probar con el token nuevo, la tarjeta del estacionamiento en curso mostraba solo las coordenadas ("Ubicación guardada: -33.4…, -70.7…"), que no le dicen nada al usuario. Se pidió que también aparezca **el nombre de las calles**, en la tarjeta y en cada registro del historial.

### Opciones evaluadas (12-nov)
| | **A. Guardar la dirección** al presionar "Guardar ubicación" | **B. Buscar la dirección al mostrarla** (elegida) |
|---|---|---|
| Se ve igual | ✅ | ✅ |
| Aparece al instante | ✅ | Tras uno o dos segundos la primera vez; al instante si ya se buscó |
| Cambia las reglas publicadas | Sí: campo nuevo `direccion`, con nueva publicación | **No** |
| Sin internet | Muestra la calle | No muestra la calle (lo demás funciona) |
| Dirección guardada en Firestore (panel admin, informes) | Sí | No |
| Consultas a Mapbox | Una por estacionamiento | Una por punto cada vez que se abre la app. Muy por debajo de las 100.000 gratis al mes |

### Decisión (12-nov, Estephany)
- **Opción B "de momento":** no cambia la base ni las reglas publicadas. Si más adelante se necesita la dirección en Firestore, se puede pasar a la opción A sin perder lo hecho: el componente seguiría sirviendo.
- **Se mantienen las coordenadas** en la tarjeta y se agrega la dirección debajo, como se pidió.

### Funciones (`lib/screens/estacionamientos/direccion_de_ubicacion.dart`, nuevo)
Es un componente reutilizable: lo usan la tarjeta, el historial y el mapa, y **el front del módulo lo puede usar tal cual**:
```dart
if (e.tieneUbicacion) DireccionDeUbicacion(ubicacion: e.ubicacion!)
```
- **`BuscarDireccion`** (línea 8): el tipo de la función que busca la dirección. Por defecto es `GeocodingService.direccionDe` (cambio 6).
- **`_direccionesEnMemoria`** (línea 15): las direcciones ya buscadas **mientras la app está abierta**. Se borran al cerrarla.
  - Guarda la consulta en curso, no solo el resultado. Así, si la tarjeta y el historial piden la misma dirección al mismo tiempo, **se hace una sola consulta a Mapbox**.
- **`claveDireccion(ubicacion)`** (línea 19): las coordenadas con 5 decimales (~1 metro), para que el mismo punto use la misma entrada desde cualquier pantalla.
- **`direccionConMemoria(ubicacion)`** (línea 26): devuelve la dirección consultando a Mapbox solo la primera vez. **Si falla o no encuentra nada, no se recuerda**, para reintentar la próxima vez (por ejemplo, cuando vuelva la conexión).
- **`olvidarDireccionesEnMemoria()`** (línea 45): vacía la memoria. Solo se usa en los tests.
- **`DireccionDeUbicacion`** (línea 56): muestra *"📍 Buscando la dirección…"* (línea 93) y luego *"📍 Quedó en Av. Ejemplo 1234, Comuna"*. Si no hay dirección, no muestra nada, porque es un dato de ayuda.

**`MapaAutoScreen`** (`mapa_auto_screen.dart`, `_buscarDireccionAuto`, línea 89): ahora usa la misma memoria. Si la dirección ya se mostró en el historial, en el mapa aparece al instante, sin otra consulta.

**Pantalla de prueba (cambio 8):** la tarjeta "En curso" muestra las coordenadas y debajo la dirección. Cada registro del historial con ubicación muestra su dirección; los que no tienen siguen diciendo "sin ubicación".

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/direccion_de_ubicacion_test.dart` (nuevo, 5 tests, **sin llamar a Mapbox**): redondeo de la clave; **una sola consulta** aunque se pida varias veces, incluso al mismo tiempo; si falla o no hay resultado, no se recuerda y se reintenta; la pantalla muestra "Buscando…" y luego "Quedó en …"; sin dirección no muestra nada | 5 OK |
| App completa (`flutter test`) | 379 OK. `flutter analyze` sin errores |

---

## 8. Pantalla de prueba del módulo en el repositorio

### Para qué
La pantalla de prueba se creó para probar el servicio, el mapa y la IA sin el front del módulo, y al principio se dejó solo en el PC de Estephany. Se decidió subirla a la rama `Estephany` para que:
- **el equipo pueda probar** las funciones del módulo mientras no esté el front de Almendra;
- **quede como evidencia** de las pruebas para el informe;
- **sirva de ejemplo** de cómo conectar las pantallas reales con el servicio, el registro con IA, el mapa y la dirección.

### Decisión (12-nov, Estephany)
- **Se sube la pantalla** `lib/screens/estacionamientos/prueba_estacionamiento_screen.dart`. Se quitó de `.git/info/exclude` y se cambió su comentario inicial, que decía "NO SUBIR A GITHUB".
- Al principio no se subió la conexión del botón "Estacionamiento" del Inicio. Luego se decidió subirla también, **de forma temporal** (ver cambio 9).

### Qué tiene
| Parte | Qué permite probar | Requisito |
|---|---|---|
| Selector de vehículo | Elegir el vehículo del usuario | — |
| "Iniciar estacionamiento" | El cronómetro (`iniciar`), con lugar opcional | HU-16 |
| Tarjeta "En curso" | Tiempo transcurrido, coordenadas y dirección escrita (`DireccionDeUbicacion`) | HU-16, HU-18 |
| "Guardar ubicación" | GPS y `guardarUbicacion`, con los mensajes de error del CU18 | HU-18 |
| "Ver dónde está mi auto" | `MapaAutoScreen` | HU-18 |
| "Finalizar estacionamiento" | `finalizar`, pidiendo el costo | HU-17 |
| "Registrar con IA (foto o PDF del ticket)" | `extraerEstacionamiento` y una revisión simple (`_RevisionIaScreen`), con los dudosos en naranja, confirmar o cancelar | HU-19 a HU-21 |
| Historial | `streamPorVehiculo`, con la dirección, el mapa al tocar y eliminar | HU-15, HU-18 |

### Funciones (`lib/screens/estacionamientos/prueba_estacionamiento_screen.dart`)
| Función | Línea | Qué hace |
|---|---|---|
| `PruebaEstacionamientoScreen` | 26 | La pantalla. Un reloj interno actualiza el cronómetro cada segundo |
| `_elegirVehiculo` | 67 | Al elegir un vehículo, escucha su estacionamiento activo y su historial |
| `_mensaje` | 76 | Aviso abajo: verde si salió bien, rojo si hubo un error |
| `_hacer` | 85 | Ejecuta una acción del servicio bloqueando los botones y muestra el resultado o el error (con el mensaje del GPS si aplica) |
| `_iniciar` | 100 | "Iniciar estacionamiento" (HU-16) |
| `_guardarUbicacion` | 106 | "Guardar ubicación" (HU-18): lee el GPS y lo guarda |
| `_finalizar` | 112 | "Finalizar estacionamiento" (HU-17): pide el costo y finaliza |
| `_registrarConIa` | 136 | "Registrar con IA" (HU-19): elige la foto o PDF, la IA la lee y abre la revisión. Si falla, avisa para registrar a mano (CU19 E2) |
| `_verMapa` | 175 | Abre "¿Dónde está mi auto?" |
| `_duracion` / `_hora` | 185 / 192 | Formatos cortos: "1 h 35 min" y "12/11 09:15" |
| `_RevisionIaScreen` | 356 | Formulario simple para revisar lo que leyó la IA (HU-20) |
| `_campo` | 386 | Un campo del formulario; si la IA dudó, se pinta en naranja con "Revisa este dato" |
| `_confirmar` | 409 | "Confirmar y guardar" (HU-21): arma fecha y hora completas (con el cruce de medianoche) y guarda como registro de la IA |

### Cómo usarla
Con `flutter run`, en el Inicio presionar la acción rápida **"Estacionamiento"** (conexión temporal del cambio 9).

### Al integrar el front del módulo
Cuando esté la pantalla real de Almendra, esta pantalla de prueba se puede borrar, o dejar solo como referencia de desarrollo.

---

## 9. Conexión TEMPORAL del botón "Estacionamiento" a la pantalla de prueba

> ⚠️ **SE DEBE QUITAR** antes de unir la rama `Estephany` a `develop` o `main`, y antes de publicar la web o generar un APK. Si no se quita, los usuarios verán la pantalla "(PRUEBA)" al presionar "Estacionamiento".

### Para qué
Con la pantalla de prueba en el repositorio (cambio 8), hacía falta una forma de abrirla sin modificar código. El equipo, y Estephany desde cualquier PC, pueden ahora probar el módulo presionando "Estacionamiento" en el Inicio.

### Decisión (12-nov, Estephany)
- **Se sube la conexión directa** a la rama `Estephany`. El front del módulo no es responsabilidad de Estephany, y la conexión solo sirve para probar mientras no esté la pantalla real de Almendra.
- **Alternativa descartada:** abrirla solo en modo desarrollo (`kDebugMode`). En ese caso la web publicada y el APK seguirían mostrando "Próximamente" sin tener que quitar nada. Se prefirió la conexión directa, **dejando registrado que se debe quitar**.

### Cambio (`lib/screens/inicio_dashboard_screen.dart`)
- **Línea 23:** import de `prueba_estacionamiento_screen.dart`, con el comentario "TEMPORAL: quitar junto con la acción rápida".
- **Línea 720, en `_accionesRapidas`:** la acción rápida "Estacionamiento" abre `PruebaEstacionamientoScreen` en vez de la pantalla de "Próximamente". El comentario "TEMPORAL … SE DEBE QUITAR" explica qué hacer.

### Cómo quitarlo
1. En `_accionesRapidas`, reemplazar el `onTap` de "Estacionamiento" por la pantalla real del módulo cuando exista. Si todavía no existe, volver a:
   ```dart
   onTap: () => _abrirPlaceholder(
       'Estacionamiento', Icons.local_parking_outlined, 'Sprint 4'),
   ```
2. Borrar el import de `prueba_estacionamiento_screen.dart` (línea 23).
3. Buscar "TEMPORAL" en `inicio_dashboard_screen.dart` para comprobar que no quede nada.

Cuando el front esté integrado, la pantalla de prueba (cambio 8) se puede borrar.

---

## Mapa del código

Ubicación actual (12-nov) de todo lo creado para el módulo, con **qué hace** y **por qué existe**. Todas las funciones tienen además un comentario breve en el propio código.

### Datos: `lib/data/models/estacionamiento_model.dart`
| Función | Línea | Qué hace | Por qué existe |
|---|---|---|---|
| `EstadoEstacionamiento` | 5 | `activo` o `finalizado` | El cronómetro necesita distinguir un estacionamiento en curso de uno terminado (HU-16, HU-17) |
| `duracionEnMinutos` | 33 | Minutos entre entrada y salida | Mostrar y calcular la duración, incluso cruzando la medianoche |
| `duracionMaximaMin` / `duracionParaGuardar` | 40 / 46 | Tope de 30 días | Que un estacionamiento olvidado se pueda finalizar sin que lo rechacen las reglas (cambio 4) |
| `EstacionamientoModel` | 58 | Un registro de estacionamiento | Leer y escribir Firestore con los mismos campos que aceptan las reglas |
| `minutosTranscurridos` | 118 | Tiempo que lleva o que duró | Mostrar el cronómetro en vivo |
| `fromJson` / `toJson` | 133 / 158 | Leer y escribir Firestore | Convertir entre la app y la base |

### Lógica: `lib/data/services/estacionamiento_service.dart`
| Función | Línea | Qué hace | Por qué existe |
|---|---|---|---|
| `registrarManual` | 49 | Guarda un estacionamiento terminado | HU-15 y HU-21 (lo confirmado con IA) |
| `iniciar` | 95 | Inicia el cronómetro | HU-16. Impide dos activos en el mismo vehículo, porque las reglas no pueden |
| `finalizar` | 137 | Hora de salida, duración y costo | HU-17 |
| `guardarUbicacion` | 156 | Asocia el GPS | HU-18 |
| `obtenerActivo` / `streamActivo` | 162 / 169 | El estacionamiento en curso | Mostrar el cronómetro y el botón del mapa |
| `streamPorVehiculo` | 197 | Historial | Consultar los estacionamientos de un vehículo |
| `eliminar` / `eliminarDeVehiculo` | 209 / 213 | Borrar | Corregir errores y no dejar datos huérfanos al borrar un vehículo |
| `_uidActual`, `_limpio`, `_activoPorId`, `_consultaActivo`, `_primeroActivo` | 30, 39, 122, 175, 184 | Apoyo interno | Dueño obligatorio, textos limpios, no modificar uno finalizado y consulta compartida del activo |

`lib/data/services/vehiculo_service.dart`, línea 195: al borrar un vehículo se borran sus estacionamientos.

### GPS y distancia: `lib/data/services/ubicacion_service.dart`
| Función | Línea | Qué hace | Por qué existe |
|---|---|---|---|
| `MotivoErrorUbicacion` / `mensajeErrorUbicacion` | 8 / 23 | Motivos de error con su mensaje | Excepciones E1 y E2 del CU18 |
| `ErrorUbicacion` | 41 | El error que reciben las pantallas | Mostrar un mensaje claro en vez de un error técnico |
| `distanciaEnMetros` / `textoDistancia` | 54 / 63 | Distancia al auto y su texto | "Tu auto está a 230 m" |
| `obtenerUbicacionActual` | 78 | Pide permiso y lee el GPS | HU-18: "Guardar ubicación" |
| `seguirUbicacion` | 112 | Sigue tu posición en vivo | Que la distancia baje mientras caminas (cambio 3) |
| `traducirErrorUbicacion` | 127 | Traduce los errores de `geolocator` | Un solo lugar para convertir errores en mensajes del CU18 |

### Dirección escrita
| Función | Archivo y línea | Qué hace | Por qué existe |
|---|---|---|---|
| `direccionDe` | `lib/data/services/geocoding_service.dart`, 67 | Búsqueda inversa en Mapbox | Mostrar la calle en vez de solo coordenadas (cambio 6) |
| `direccionCorta` | `geocoding_service.dart`, 92 | Deja calle, número y comuna | Un texto corto y legible |
| `direccionConMemoria`, `claveDireccion`, `olvidarDireccionesEnMemoria` | `lib/screens/estacionamientos/direccion_de_ubicacion.dart`, 26, 19, 45 | Busca cada punto una sola vez | Opción B: no guardar la dirección en Firestore sin repetir consultas (cambio 7) |
| `DireccionDeUbicacion` | `direccion_de_ubicacion.dart`, 56 | Muestra "Quedó en …" | Componente reutilizable para la tarjeta, el historial, el mapa y el front |

### IA del ticket: `lib/features/registro_inteligente/estacionamiento_extraction.dart`
| Función | Línea | Qué hace | Por qué existe |
|---|---|---|---|
| `EstacionamientoExtraido` | 39 | Lo que leyó la IA | Precargar la revisión (HU-20) |
| `entrada` / `salida` | 85 / 91 | Fecha y hora completas | Guardar horas con fecha, incluso cruzando la medianoche |
| `_esquemaEstacionamiento` / `_promptEstacionamiento` | 118 / 154 | Formato e instrucciones para la IA | Que la IA devuelva solo lo pedido, sin inventar ni datos personales (HU-19) |
| `interpretarHora` / `minutosDeTexto` | 201 / 213 | Leer horas y duraciones | Los tickets escriben las horas de muchas formas |
| `parseEstacionamientoExtraido` | 263 | Valida y marca los dudosos | Que lo leído siempre se pueda guardar y que el usuario revise lo dudoso |
| `extraerEstacionamiento` | 365 | Envía la foto a la IA | Punto de entrada que usan las pantallas |
| `_combinar`, `_campoTexto`, `_entero`, `_fechaPlausible`, `_fecha`, `_texto` | 104, 111, 190, 234, 243, 250 | Apoyo interno | Convertir y limpiar lo que responde la IA |

### Pantallas
| Pantalla | Archivo y línea | Para qué |
|---|---|---|
| `MapaAutoScreen` | `lib/screens/estacionamientos/mapa_auto_screen.dart`, 26 | "¿Dónde está mi auto?" (HU-18): mapa, tu posición en vivo, distancia y dirección. Funciones en las secciones 2, 3 y 6 |
| `PruebaEstacionamientoScreen` | `lib/screens/estacionamientos/prueba_estacionamiento_screen.dart`, 26 | Pantalla de prueba del módulo (cambio 8). Funciones en la sección 8 |
| Conexión temporal | `lib/screens/inicio_dashboard_screen.dart`, 23 y 720 | ⚠️ Se debe quitar (cambio 9) |

### Reglas y pruebas
| Qué | Dónde |
|---|---|
| Reglas de `estacionamientos` | `firestore.rules`: encabezado línea 62, `estacionamientoValido` línea 453, `match` línea 480, modificar línea 491 |
| Pruebas de reglas | `tools/rules_test/rules.test.js`, "Prueba 11" desde la línea 381 (11a a 11i) |
| Pruebas de la app | `test/estacionamiento_test.dart`, `test/estacionamiento_extraction_test.dart`, `test/direccion_corta_test.dart`, `test/direccion_de_ubicacion_test.dart` |

---

## Pendiente

| Pendiente | Quién |
|---|---|
| **Subir el front** a una rama propia, aunque no esté terminado | Almendra |
| **Comparar reglas** con las de Almendra y acordar los nombres de campos con su front | Ambas |
| **⚠️ Quitar la conexión temporal** del botón "Estacionamiento" a la pantalla de prueba (cambio 9), antes de unir la rama a `develop`/`main` o de publicar | Estephany, al integrar |
| **Conectar las pantallas** del módulo al servicio (cambio 2) y la acción rápida del Inicio (HU-46) | Al integrar |
| **Probar en la app** el GPS y el mapa "¿Dónde está mi auto?" | Al integrar |
| **Decidir si estacionamientos se registra en `auditoria`**, como mantenciones y cargas | Equipo |
| **iOS:** `ios/Runner/Info.plist` no tiene el texto de permiso de ubicación (`NSLocationWhenInUseUsageDescription`). Solo importa si se compila para iPhone | — |
| **Formulario definitivo de revisión con IA:** el registro manual del front, precargado con `EstacionamientoExtraido` y con los campos dudosos resaltados (cambio 5) | Al integrar |
| **Token de Mapbox nuevo** (ya funciona en el `.env` de Estephany): actualizar el `.env` del resto del equipo, volver a publicar la web y restringir el token por URL (cambio 6) | Equipo |
| **Probar la dirección escrita** en el mapa, la tarjeta y el historial (cambios 6 y 7) | Estephany |
| **Decidir si se pasa a la opción A** (guardar la dirección en Firestore), por ejemplo si el panel admin o los informes la necesitan (cambio 7) | Equipo |
| **Ocultar las coordenadas** en la pantalla real del módulo y mostrar solo la dirección: son un dato personal y no le sirven al usuario | Al integrar |
| **Diccionario de datos:** agregar el dueño (`uid`) y cambiar `hora_entrada` y `hora_salida` a fecha y hora | Estephany |
| **Plantillas de casos de uso:** CU19 dice "Gemini API"; la app usa OpenAI | Documentación |
