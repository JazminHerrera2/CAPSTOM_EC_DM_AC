# Registro de cambios: módulo Estacionamientos

**Rama:** `Estephany` · **Responsable:** Estephany Cárdenas (Arquitecta de Software y BD)

Este archivo reúne los cambios del módulo Estacionamientos. Cada cambio nuevo se agrega como una sección más, al final.

- **Alcance del módulo:** HU-15 a HU-21, RF-016 a RF-022, CU15 a CU21, épica EP-03 (planificado para el Sprint 4).
- **Reparto del trabajo:** Almendra Cifuentes hace el front y algunas reglas (al 11-nov todavía no están en GitHub). Este archivo registra la parte de arquitectura, base de datos e IA, y la integración de ambas partes.
- **Números de línea:** corresponden a la versión de cada archivo **en la fecha del cambio**. Si el archivo cambia después, pueden moverse.
- **Rutas:** todas son relativas a `Producto/tag_ok/`.

## Índice

| # | Fecha | Cambio | Requisito | Estado |
|---|---|---|---|---|
| 1 | 11-nov | [Reglas de Firestore para `estacionamientos`](#1-reglas-de-firestore-para-estacionamientos) | HU-15 a HU-21 / RF-016 a RF-022 | Tests OK en el emulador. **Publicado el 11-nov** (commit `10cc760`) |
| 2 | 11-nov | [Servicio de estacionamientos y "¿Dónde está mi auto?"](#2-servicio-de-estacionamientos-y-dónde-está-mi-auto) | HU-15 a HU-18 / RF-016 a RF-019 | Tests OK (commits `588841c` y `13fe939`). **Falta conectarlo a las pantallas** del módulo |
| 3 | 12-nov | [Seguimiento en vivo en el mapa y errores del GPS en el navegador](#3-seguimiento-en-vivo-en-el-mapa-y-errores-del-gps-en-el-navegador) | HU-18 / RF-019 / CU18 | Tests OK, sin commit |
| 4 | 12-nov | [Tope de 30 días en la duración guardada](#4-tope-de-30-días-en-la-duración-guardada) | HU-17 / RF-018 | Tests OK, sin commit |

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
- **`EstadoEstacionamiento`** (línea 5): `activo` (cronómetro corriendo) o `finalizado`. Un valor desconocido se lee como `finalizado`, para que nunca quede un registro abierto por error.
- **`duracionEnMinutos(entrada, salida)`** (línea 31): minutos completos entre las dos horas. Nunca es negativa y funciona aunque se cruce la medianoche.
- **`EstacionamientoModel`** (línea 43): los campos de las reglas publicadas.
  - **`estaActivo`** (línea 88) y **`tieneUbicacion`**.
  - **`minutosTranscurridos({ahora})`** (línea 101): si está activo, cuenta hasta ahora (para mostrar el cronómetro); si está finalizado, usa la duración guardada.
  - **`fromJson`** (línea 116) y **`toJson`** (línea 139): leen y escriben exactamente los campos que aceptan las reglas. La ubicación es un `GeoPoint`.

### Funciones: GPS (`lib/data/services/ubicacion_service.dart`, nuevo)
- **`MotivoErrorUbicacion`** (línea 8) y **`mensajeErrorUbicacion`** (línea 23): las excepciones del CU18, cada una con un mensaje listo para mostrar.

  | Motivo | Mensaje | CU18 |
  |---|---|---|
  | GPS apagado | "Activa la ubicación de tu dispositivo…" | E1 |
  | Sin señal o demora más de 15 s | "No se pudo obtener tu ubicación…" | E1 |
  | Permiso denegado | "Sin permiso de ubicación no se puede guardar…" | E2 |
  | Permiso bloqueado | "…Habilítalo en los ajustes de tu dispositivo o del navegador." | E2 |

- **`ErrorUbicacion`** (línea 41): el error que reciben las pantallas, con `.mensaje`.
- **`distanciaEnMetros(a, b)`** (línea 53): distancia en línea recta, con el paquete `latlong2`, que ya estaba instalado.
- **`textoDistancia(metros)`** (línea 62): "a 230 m" o "a 1,4 km".
- **`UbicacionService.obtenerUbicacionActual()`** (línea 77): revisa que la ubicación esté activa, pide el permiso si hace falta y devuelve la posición. Funciona en web y en Android con `geolocator`, el mismo paquete del mapa de TAG.

### Funciones: servicio (`lib/data/services/estacionamiento_service.dart`, nuevo)

| Función | Línea | Qué hace | Requisito |
|---|---|---|---|
| `registrarManual(...)` | 42 | Guarda un estacionamiento terminado y calcula la duración si vienen las dos horas. Rechaza una salida anterior a la entrada. También sirve para guardar lo confirmado con IA (`origenRegistro: 'ia'`) | HU-15, HU-21 |
| `iniciar(vehiculoId)` | 87 | Inicia el cronómetro: guarda la fecha y hora de entrada y deja el estacionamiento `activo`. **No permite dos activos en el mismo vehículo**, porque las reglas no pueden impedirlo | HU-16 |
| `finalizar(id, costo)` | 129 | Guarda la hora de salida, calcula la duración y el costo, y lo deja `finalizado`. Si el reloj del dispositivo quedó atrás de la entrada, usa la entrada, para no romper la regla | HU-17 |
| `guardarUbicacion(id, ubicacion)` | 147 | Asocia el GPS al estacionamiento. Se llama al presionar "Guardar ubicación". Solo funciona mientras está activo | HU-18 |
| `obtenerActivo` / `streamActivo` | 153 / 160 | El estacionamiento en curso del vehículo; la versión *stream* se actualiza sola, para el cronómetro y el botón del mapa | HU-16, HU-18 |
| `streamPorVehiculo` | 186 | Historial del vehículo, el más reciente primero | Consulta |
| `eliminar` / `eliminarDeVehiculo` | 197 / 201 | Borra uno, o todos los de un vehículo | — |

- **`_activoPorId`** (línea 114): antes de modificar, comprueba que el estacionamiento siga activo. Si no, el mensaje es *"El estacionamiento ya fue finalizado y no se puede modificar."*
- **Consultas sin índices compuestos:** todas usan solo igualdades (`uid`, `vehiculo_id`, `estado`), y el orden se aplica en la app, igual que en cargas.
- **No registra en `auditoria`.** Mantenciones y cargas sí lo hacen; agregarlo aquí queda como decisión pendiente.

**`lib/data/services/vehiculo_service.dart`** (línea 195): al eliminar un vehículo también se borran sus estacionamientos. Igual que las cargas, si falla no impide borrar el vehículo.

### Pantalla "¿Dónde está mi auto?" (`lib/screens/estacionamientos/mapa_auto_screen.dart`, nueva)
- **`MapaAutoScreen(ubicacionAuto, lugar)`** (línea 22): recibe la ubicación guardada y el lugar escrito por el usuario.
- **Mapa** (línea 107): el mismo de la pantalla de TAG, centrado en el auto, con:
  - **pin del auto** (`_PinAuto`, línea 188);
  - **tu posición**, el punto azul;
  - **dos botones** para centrar el mapa en el auto (`_centrarEnAuto`, línea 85) o en ti (`_centrarEnMi`, línea 87).
- **Tarjeta inferior** (`_TarjetaResumen`, línea 254): el lugar y *"Tu auto está a 230 m en línea recta"*.
- **`_buscarMiUbicacion`** (línea 63): tu posición es opcional. Si no hay permiso o señal, el mapa igual muestra el auto, avisa el motivo y ofrece "Reintentar".
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
- **`seguirUbicacion({metrosMinimos})`** (línea 111): entrega la posición del usuario cada vez que se mueve al menos 3 metros, con `Geolocator.getPositionStream`, la misma técnica con que el mapa de TAG sigue al usuario en la autopista. Los errores llegan traducidos a `ErrorUbicacion`.
- **`traducirErrorUbicacion(error)`** (línea 126): convierte los errores de `geolocator` en un motivo del CU18:
  - ubicación apagada → `gpsDesactivado`;
  - permiso denegado → `permisoDenegado`;
  - "posición no disponible", tiempo agotado u otro → `sinSenal`.

  Ahora la usan tanto `obtenerUbicacionActual()` (línea 101) como el seguimiento en vivo.

### Funciones (`lib/screens/estacionamientos/mapa_auto_screen.dart`)
- **`_buscarMiUbicacion`** (línea 79): obtiene la primera posición, que es cuando se pide el permiso, y luego inicia el seguimiento.
- **`_seguirEnVivo`** (línea 97): cada posición nueva mueve el punto azul y recalcula la distancia. Si se pierde la señal, se mantiene el último punto conocido, se muestra el aviso y el seguimiento sigue intentando.
- **`dispose`** (línea 70): **detiene el seguimiento al cerrar el mapa**, para no seguir usando el GPS ni la batería.
- **Tarjeta inferior** (línea 341): bajo la distancia dice *"Se actualiza mientras caminas."*, o el aviso si se perdió la señal.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_test.dart`: nuevo test `traducirErrorUbicacion convierte los errores de geolocator` (línea 136) | 12 OK |

### Prueba manual (12-nov, web local)
- Se inició y se finalizó un estacionamiento: se guardaron bien la entrada, la salida, la duración y el costo.
- El mapa no se abrió porque **ese estacionamiento no tenía ubicación**: no se guardó antes de finalizar. Se confirmó en Firestore que no hubo ninguna escritura entre iniciar y finalizar.
- Se comprobó que **el cronómetro sigue corriendo aunque se cierre la ventana**: el inicio queda en Firestore y la duración se calcula al volver a abrir.

**Pantalla de prueba:** para probar sin el front del módulo se usa `lib/screens/estacionamientos/prueba_estacionamiento_screen.dart`, más un cambio temporal en la acción rápida "Estacionamiento" del Inicio. **Ninguno de los dos se sube a GitHub:** la pantalla está excluida en `.git/info/exclude`, y el cambio del Inicio se deshace con `git checkout -- Producto/tag_ok/lib/screens/inicio_dashboard_screen.dart`.

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
- **`duracionMaximaMin = 43200`** (`lib/data/models/estacionamiento_model.dart`, línea 38): el mismo máximo de las reglas. Si se cambia en `firestore.rules`, hay que cambiarlo aquí también.
- **`duracionParaGuardar(entrada, salida)`** (línea 44): la duración real, pero con tope de 30 días. `duracionEnMinutos` sigue entregando la duración real, sin tope, para mostrar el tiempo transcurrido.
- **`EstacionamientoService`** (`lib/data/services/estacionamiento_service.dart`): `registrarManual` (línea 70) y `finalizar` (línea 140) usan ahora `duracionParaGuardar`. Las horas de entrada y salida se guardan igual, con su valor real.

### Pruebas
| Pruebas | Resultado |
|---|---|
| `test/estacionamiento_test.dart`: nuevo test `duracionParaGuardar` (línea 31). Comprueba que 34 días se guardan como 30, que 30 días o menos se guardan tal cual, y que `duracionEnMinutos` sigue entregando la duración real | 13 OK |

---

## Pendiente

| Pendiente | Quién |
|---|---|
| **Subir el front** a una rama propia, aunque no esté terminado | Almendra |
| **Comparar reglas** con las de Almendra y acordar los nombres de campos con su front | Ambas |
| **Conectar las pantallas** del módulo al servicio (cambio 2) y la acción rápida del Inicio (HU-46) | Al integrar |
| **Probar en la app** el GPS y el mapa "¿Dónde está mi auto?" | Al integrar |
| **Decidir si estacionamientos se registra en `auditoria`**, como mantenciones y cargas | Equipo |
| **iOS:** `ios/Runner/Info.plist` no tiene el texto de permiso de ubicación (`NSLocationWhenInUseUsageDescription`). Solo importa si se compila para iPhone | — |
| **IA del ticket** (HU-19 a HU-21): agregar el tipo "ticket de estacionamiento" al componente de IA | Estephany |
| **Diccionario de datos:** agregar el dueño (`uid`) y cambiar `hora_entrada` y `hora_salida` a fecha y hora | Estephany |
| **Plantillas de casos de uso:** CU19 dice "Gemini API"; la app usa OpenAI | Documentación |
