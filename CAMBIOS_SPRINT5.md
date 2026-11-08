# Registro de cambios: Sprint 5 (9 al 22-nov-2026)

**Rama:** `Estephany` · **Responsable:** Estephany Cárdenas (Arquitecta de Software y BD)

Este archivo reúne los cambios del Sprint 5. Cada cambio nuevo se agrega como una sección más, al final.

- La tarea 1 del sprint (la clave de OpenAI sale de la app y el `.env` deja de publicarse) está documentada aparte en [`CAMBIOS_SPRINT5_SEGURIDAD_IA.md`](CAMBIOS_SPRINT5_SEGURIDAD_IA.md) y corresponde al commit `cf71c45`.
- Los números de línea corresponden a la versión de cada archivo **en la fecha del cambio**. Si el archivo cambia después, pueden moverse.
- Todas las rutas son relativas a `Producto/tag_ok/`.

## Índice

| # | Fecha | Cambio | Requisito | Estado |
|---|---|---|---|---|
| 1 | 8-nov | [El Inicio muestra la próxima mantención programada](#1-el-inicio-muestra-la-próxima-mantención-programada) | HU-42 / RF-045 | Probado, sin commit |
| 2 | 8-nov | [El kilometraje del vehículo se actualiza solo](#2-el-kilometraje-del-vehículo-se-actualiza-solo) | Base de HU-11 / HU-48 | Probado, sin commit |
| 3 | 8-nov | [Avisos de mantención por kilometraje](#3-avisos-de-mantención-por-kilometraje) | HU-11 / HU-48 / RF-011 / RF-012 | Probado en parte, sin commit |
| 4 | 8-nov | [Los formularios de carga y mantención perdían el foco al escribir](#4-los-formularios-de-carga-y-mantención-perdían-el-foco-al-escribir) | Corrección de error | Falta probar |

---

## 1. El Inicio muestra la próxima mantención programada

### Para qué
La tarjeta **"Próxima mantención"** del Inicio no mostraba ninguna mantención programada. Mostraba una **estimación**: el kilometraje actual del vehículo más 10.000 km, con el texto incompleto "A tus". Ese número no tenía relación con lo que el usuario había programado, y si el vehículo no tenía km la tarjeta decía "Sin kilometraje registrado".

La función que sí calcula la próxima mantención programada (`calcularProximaMantencion`) ya existía, pero nadie la usaba.

**Ahora** la tarjeta muestra la mantención que el usuario programó en "Próximas mantenciones":

| Caso | Valor (derecha) | Detalle (debajo del título) |
|---|---|---|
| Programada con fecha | `17/10/2026` | `Frenos` |
| Con fecha y km | `17/10/2026` | `Frenos · a los 75.000 km` |
| Fecha ya pasada | `17/10/2026` | `Frenos · Atrasada` |
| Solo con km | `75.000 km` | `Cambio de aceite` |
| Sin programadas | `--` | `Sin mantenciones programadas` |

Si hay varias programadas, se muestra la de **fecha más cercana**. Si ninguna tiene fecha, se muestra la de **menor kilometraje**.

### Funciones

**`calcularProximaMantencion(lista)`**: existente, no se modificó. Está en `lib/screens/dashboard/dashboard_logica.dart:261`.
- Recibe las mantenciones de un vehículo y se queda con las programadas.
- Si alguna tiene fecha, devuelve la de fecha más cercana.
- Si ninguna tiene fecha, devuelve la de menor kilometraje programado.
- Si no hay programadas, devuelve `null`.

**`TextoProximaMantencion`** y **`textoProximaMantencion(m, {ahora})`**: nuevas. Están en `lib/screens/dashboard/dashboard_logica.dart:273` y `:281`.
- `TextoProximaMantencion` es un registro `({String valor, String detalle})` con los dos textos de la tarjeta.
- `textoProximaMantencion` recibe la mantención que devolvió `calcularProximaMantencion` y arma esos textos según la tabla de arriba.
- Para marcar "Atrasada", compara solo el día, sin la hora, para que una mantención programada para hoy no aparezca atrasada.
- El parámetro `ahora` existe para poder probarla con una fecha fija. En la app se usa la fecha actual.
- Es una función pura: no lee Firestore ni widgets, por eso se puede probar con tests.

**`_mantencionesDe(v)`**: nueva. Está en `lib/screens/inicio_dashboard_screen.dart:217`.
- Devuelve las mantenciones cargadas en el Inicio que pertenecen al vehículo `v`.
- Antes, ese filtro estaba escrito en línea en el cálculo de gastos. Ahora lo usan el gasto (línea 234) y la próxima mantención (línea 586).

**Tarjeta "Próxima mantención"**: modificada. Está en `lib/screens/inicio_dashboard_screen.dart:585`.
- Ahora usa `textoProximaMantencion(calcularProximaMantencion(_mantencionesDe(v)))`.

**`intervaloMantencionKm`** y **`kilometrajeProximaMantencion(...)`**: eliminadas de `dashboard_logica.dart`.
- Eran la estimación "km actual + 10.000". Ya no se usaban en ninguna otra parte.

### Pruebas
En `test/dashboard_logica_test.dart`, grupo `textoProximaMantencion` (línea 183), se reemplazaron los tests de la estimación por 5 tests nuevos:
- sin programadas;
- solo fecha;
- fecha y km;
- solo km;
- fecha pasada ("Atrasada"), comparada con una fecha que es hoy, que no se marca.

---

## 2. El kilometraje del vehículo se actualiza solo

### Para qué
El kilometraje del vehículo (`vehiculos.kilometraje_actual`) solo cambiaba si el usuario editaba el vehículo a mano. Las cargas de combustible y las mantenciones guardan el km del auto en ese momento, pero ese dato no llegaba al vehículo. Para avisar por kilometraje (cambio 3), el sistema necesita conocer el km real del auto.

**Ahora**, al guardar:
- una **carga de combustible** con kilometraje, o
- una **mantención realizada** con kilometraje,

el vehículo queda con ese km **si es mayor** que el que tenía. **Nunca baja**, porque una carga o mantención antigua registrada tarde puede traer menos km, y eso no significa que el auto haya retrocedido.

Da lo mismo si el km se escribió a mano o se leyó con **"Fotografiar velocímetro con IA"**: la foto solo llena el campo y la actualización ocurre al guardar.

Las mantenciones **programadas** no actualizan el km del vehículo, porque su km es el de la *próxima* mantención, no el actual.

En **"Editar vehículo"** el km se guarda directamente, aunque sea menor, porque ahí el usuario está corrigiendo el dato (RF-003 / CU2).

### Funciones

**`kilometrajeNuevoDelVehiculo({actual, registrado})`**: nueva. Está en `lib/data/services/vehiculo_service.dart:36`.
- Decide qué km debe quedar en el vehículo.
- Devuelve `registrado` si es mayor que `actual`, o si el vehículo no tenía km.
- Devuelve `null`, que significa "no cambiar", si `registrado` es nulo, cero, negativo, igual o menor al actual.
- Es una función pura y tiene tests.

**`VehiculoService.actualizarKilometrajeSiEsMayor(vehiculoId, kilometraje)`**: nueva. Está en `lib/data/services/vehiculo_service.dart:147`.
- Lee el vehículo y le aplica `kilometrajeNuevoDelVehiculo`. Si corresponde, actualiza `kilometraje_actual`.
- Lo hace dentro de una **transacción de Firestore**: si dos dispositivos guardan al mismo tiempo, no se pisa un valor mayor con uno menor.
- Si el km subió, revisa los avisos por kilometraje (cambio 3).
- Devuelve `true` si actualizó y `false` si no cambió nada o si falló.
- Es *best effort*: si falla, por ejemplo por falta de conexión, la carga o mantención que la llamó **ya quedó guardada**. El error solo se informa en la consola y no se muestra al usuario.

**`AbastecimientoService.crear(...)`**: modificada. Está en `lib/data/services/abastecimiento_service.dart:28`.
- Después de guardar la carga, llama a `actualizarKilometrajeSiEsMayor` (línea 66).

**`MantencionService.crear(...)`**: modificada. Está en `lib/data/services/mantencion_service.dart:39`.
- Si la mantención es **realizada**, llama a `actualizarKilometrajeSiEsMayor` (línea 95).

Las reglas de Firestore no cambiaron: el dueño del vehículo ya podía actualizar `kilometraje_actual`.

### Pruebas
`test/kilometraje_vehiculo_test.dart` (nuevo) tiene 4 tests:
- un km mayor actualiza el del vehículo;
- un vehículo sin km toma el registrado;
- nunca baja, ni con un km igual ni con uno menor;
- un valor nulo, cero o negativo no cambia nada.

---

## 3. Avisos de mantención por kilometraje

### Para qué
RF-011 permite programar una mantención **"por fecha, kilometraje o ambos"**, y HU-11 / HU-48 piden que el conductor reciba el aviso de esa mantención. Antes solo existían avisos **por fecha** (7 días antes y el mismo día). Una mantención programada solo por km no generaba ningún aviso, y la pantalla lo decía: *"Sin una fecha no se generan recordatorios"*.

**Ahora** una mantención programada por kilometraje genera dos avisos. El margen de **1.000 km** lo eligió el equipo, porque los requisitos no fijan un valor.

| Km del vehículo (mantención a los 75.000) | Aviso |
|---|---|
| Menos de 74.000 | Ninguno todavía |
| De 74.000 a 74.999 | **"Faltan 600 km para la mantención Cambio de aceite (ABCD12) (a los 75.000 km)."** |
| 75.000 o más | **"Tu vehículo llegó a los 75.000 km: toca la mantención Cambio de aceite (ABCD12)."** |

**Diferencia con los avisos por fecha:** un aviso por fecha se conoce con anticipación y se **agenda**. Un aviso por km no se puede agendar, porque no se sabe cuándo el auto llegará a ese km. Por eso se **genera en el momento en que sube el km**, es decir, cuando se cumple alguno de estos casos:
1. se guarda una carga o una mantención realizada con más km (cambio 2);
2. se edita el km en "Editar vehículo";
3. se crea o modifica una mantención programada por km, por si el auto ya estaba cerca.

**Reglas:**
- Cada aviso se crea **una sola vez**. Si el usuario sigue cargando combustible, el aviso no se repite, y si ya lo leyó, sigue leído.
- Si la mantención programada se **elimina**, sus avisos se borran.
- Si se **cambia su km, su nombre o su estado**, sus avisos se borran y se vuelven a evaluar.
- Los avisos llegan por los mismos medios que los de fecha:
  - la **campana** (bandeja de la app);
  - la **notificación del teléfono** (Android/iOS);
  - la **notificación del navegador** (web).
- El título del aviso es **"Mantención por kilometraje"**. Al tocarlo se abre el detalle de la mantención.

### Funciones: tipo de aviso
Archivo: `lib/data/models/notificacion_config_model.dart`.

**`tipoAvisoMantencionKm = 'mantencion_km'`** (línea 9): nueva.
- Es el valor del campo `tipo` en la colección `notificaciones` para estos avisos.
- Se usa un tipo propio, distinto de `mantencion_programada`, para poder distinguirlos, por ejemplo en el panel admin o en estadísticas.

**`tiposAvisoEntregables`** (línea 12): modificada.
- Se agregó el tipo nuevo.
- Los servicios de entrega (teléfono y navegador) solo muestran los tipos que están en este conjunto.

**`esAvisoDeMantencion(tipo)`** (línea 20): nueva.
- Devuelve `true` para los dos tipos de aviso de mantención (fecha y km).
- La usan la bandeja, para elegir el ícono y abrir el detalle de la mantención al tocarlo, y el teléfono, para elegir el canal de Android "Mantenciones programadas".

**`tituloAviso(tipo)`** (línea 24): modificada.
- Ahora devuelve **"Mantención por kilometraje"** para el tipo nuevo.

### Funciones: cálculo y creación del aviso
Archivo: `lib/data/services/notificacion_service.dart`.

**`_queMantencion(nombre, patente)`** (línea 42): nueva.
- Arma el texto "Cambio de aceite (ABCD12)", o solo el nombre si no hay patente.
- Antes ese código estaba dentro de `avisosMantencion`. Se sacó a una función para que lo compartan los avisos por fecha y por km.

**`margenAvisoKilometraje = 1000`** (línea 49): nueva.
- Cuántos km antes se avisa. Si el equipo decide cambiarlo, basta con modificar este valor; los textos de la app se actualizan solos.

**`sufijosAvisoMantencionKm`** (línea 53): nueva.
- Vale `['km_cerca', 'km_alcanzado']`.
- Los avisos se guardan con id `{idMantención}_km_cerca` y `{idMantención}_km_alcanzado`.
- Como el id es fijo, se puede saber si el aviso ya existe y borrarlo sin buscarlo.

**`avisoMantencionKm({...})`** (línea 62): nueva y pura.
- Recibe el km programado y el km actual del vehículo, y devuelve el aviso que corresponde: `km_alcanzado` si ya llegó, `km_cerca` si faltan 1.000 km o menos, o `null` si falta más.
- La fecha del aviso es `ahora`, el momento en que subió el km.
- Tiene tests.

**`NotificacionService.configurarAvisoKilometrajeMantencion({...})`** (línea 180): nueva.
1. Lee el vehículo para obtener la patente, el dueño y su km (si no se le pasa uno).
2. Calcula el aviso con `avisoMantencionKm`. Si no corresponde ninguno, termina.
3. **Si el aviso ya existe en Firestore, no hace nada.** Así se cumple la regla de "una sola vez".
4. Si no existe, lo guarda en `notificaciones` y lo programa como notificación del teléfono.
5. **En web lo muestra de inmediato en el navegador** (línea 223), sin esperar la revisión periódica (ver *Problema encontrado al probar*).

**`eliminarRecordatoriosMantencion(id)`** (línea 232): modificada.
- Antes borraba solo los avisos por fecha. Ahora borra **todos** los avisos de la mantención: fecha y km.
- La usan "eliminar mantención" y "eliminar vehículo".

**`eliminarRecordatoriosFechaMantencion(id)`** (línea 238) y **`eliminarAvisosKilometrajeMantencion(id)`** (línea 242): nuevas.
- Borran solo un grupo de avisos.
- Hacen falta porque una mantención puede dejar de tener fecha y seguir teniendo km, o al revés.

**`_eliminarAvisos(referenciaId, sufijos)`** (línea 245): nueva y privada.
- Borra de Firestore y del teléfono los avisos `{referenciaId}_{sufijo}`.
- También la usa `eliminarNotificacionesDocumento` (línea 328), que antes repetía el mismo código. Su comportamiento no cambió.

### Funciones: cuándo se generan
Archivo: `lib/data/services/mantencion_service.dart`.

**`MantencionService.crear(...)`** (línea 39): modificada.
- Antes, los recordatorios solo se generaban si la programada tenía **fecha**.
- Ahora también se generan si tiene **km** (línea 87).

**`_sincronizarRecordatorios(m)`** (línea 110): modificada. Deja los avisos de una mantención de acuerdo con su estado, y tiene dos partes independientes:
- **Fecha:** si es programada con fecha, crea o reprograma los avisos por fecha. Si no, los borra.
- **Km:** borra los avisos por km y, si es programada con km, crea el que ya corresponda según el km actual del vehículo.

Cada parte tiene su propio manejo de errores: si falla una, la otra se ejecuta igual.

**`revisarAvisosKilometraje(vehiculoId, kilometraje)`** (línea 149): nueva.
- Busca las mantenciones **programadas** del vehículo que tienen km y, para cada una, llama a `configurarAvisoKilometrajeMantencion` con el km nuevo.
- Si falla una, sigue con las demás.
- Es *best effort*: un error no interrumpe al usuario.

**`actualizar(id, cambios)`** (línea 253): modificada.
- Se agregó `proximo_kilometraje` a los campos que obligan a rehacer los avisos.
- Hoy ninguna pantalla llama a `actualizar`. Queda listo para cuando exista "editar mantención".

Archivo: `lib/data/services/vehiculo_service.dart`.

**`actualizarKilometrajeSiEsMayor(...)`** (línea 147): modificada.
- Si el km subió, llama a `revisarAvisosKilometraje` (línea 170).
- La transacción ahora devuelve el km nuevo (`int?`) en vez de `bool`, para saber con qué valor revisar los avisos.

**`actualizarVehiculo(...)`** (línea 100): modificada.
- Si se guardó un km, llama a `revisarAvisosKilometraje` (línea 130).
- Así también se avisa cuando el usuario corrige el km a mano en "Editar vehículo".

### Funciones: entrega y textos en pantalla

**`_canalDe(tipo)`**: modificada. Está en `lib/data/services/recordatorio_local_service.dart:48`.
- Usa `esAvisoDeMantencion`, así que los avisos por km van al canal de Android "Mantenciones programadas". El usuario puede silenciarlo desde los ajustes del teléfono.

**Bandeja de notificaciones**: modificada. Está en `lib/screens/notificaciones/notificaciones_screen.dart`.
- Usa `esAvisoDeMantencion` en dos lugares:
  - al tocar el aviso se abre el detalle de la mantención (línea 180);
  - se muestra el ícono de llave (línea 310).
- El mensaje de bandeja vacía ahora también menciona los avisos por kilometraje (línea 123).

**Textos de "Próximas mantenciones"**: modificados. Están en `lib/screens/mantenimiento/proximas_mantenciones_screen.dart`.
- **`_cabecera()`** (línea 82) explica los dos tipos de aviso.
- **`_avisoRecordatorios()`** (línea 617), en el formulario "Programar mantención", muestra qué avisos se generarán según el modo elegido:
  - **Por fecha:** "Se generarán recordatorios 7 días antes y el mismo día de la fecha programada."
  - **Por kilometraje:** "Te avisaremos cuando falten 1.000 km y al llegar al kilometraje programado. El kilometraje del vehículo se actualiza al registrar cargas y mantenciones."
  - **Ambos:** combina los dos textos.
- Antes, en modo km decía *"Sin una fecha no se generan recordatorios"*, que ya no es cierto.
- Los textos toman el margen de `margenAvisoKilometraje`, así que no quedan desactualizados si el valor cambia.

Las **reglas de Firestore no cambiaron**: `notificaciones` acepta cualquier `tipo` de hasta 50 caracteres y exige `vehiculo_id` del dueño, y estos avisos cumplen las dos condiciones.

### Problema encontrado al probar: la notificación del navegador no aparecía
En la prueba manual, el aviso "llegó a los…" aparecía en la campana, pero **no salía la notificación de Windows** aunque el permiso estaba activado.

**Causa:** el servicio del navegador (`lib/data/services/aviso_navegador_service.dart:47`) revisa los avisos al abrir la web y después **cada 15 minutos**. Eso basta para los avisos por fecha, que se conocen con días de anticipación. Un aviso por km nace en el momento, así que podía tardar hasta 15 minutos en aparecer.

**Solución:** al crear un aviso por km en web, `configurarAvisoKilometrajeMantencion` llama de inmediato a `AvisoNavegadorService.instance.revisar(...)` (`notificacion_service.dart:223`).

**Regla que no cambió:** todos los avisos del navegador y del teléfono salen **desde las 9:00**. Un aviso por km creado antes de esa hora aparece en la campana de inmediato, pero la notificación emergente sale a las 9:00.

### Pruebas automáticas
En `test/recordatorio_mantencion_test.dart`, grupo `avisoMantencionKm` (línea 54), hay 6 tests nuevos:
- con más de 1.000 km por delante no se avisa;
- a 1.000 km o menos se avisa "Faltan…";
- al llegar o pasar el km se avisa "llegó a los…";
- la fecha del aviso es el momento en que sube el km;
- sin patente no aparecen paréntesis vacíos;
- los ids coinciden con los sufijos que se borran.

El test `tipos y títulos de aviso` (línea 108) también se amplió con el tipo nuevo y `esAvisoDeMantencion`.

---

## 4. Los formularios de carga y mantención perdían el foco al escribir

### Para qué
En las pruebas se encontró un error que ya existía antes de este sprint: en **"Registrar carga"**, al escribir **una letra** en cualquier campo, el cursor se salía del campo. Había que volver a hacer clic para cada letra. **"Registrar mantención"** tenía el mismo error.

**Causa:**
1. Cada letra escrita llama a `setState`, que redibuja la pantalla.
2. La pantalla obtenía la lista de vehículos con `StreamBuilder(stream: _vehiculoService.streamVehiculosUsuario(...))`, escrito **dentro de `build()`**. Por eso, cada redibujo creaba una **consulta nueva** a Firestore.
3. Mientras llegaba la respuesta, el `StreamBuilder` mostraba un instante el indicador de carga **en lugar del formulario**. El campo de texto se destruía y se volvía a crear, y perdía el foco.

**Solución:** la consulta se crea **una sola vez** y se guarda en un campo de la pantalla:

```dart
late final Stream<List<VehiculoModel>> _vehiculos =
    _vehiculoService.streamVehiculosUsuario(_usuarioId);
...
StreamBuilder<List<VehiculoModel>>(stream: _vehiculos, ...)
```

| Archivo | Campo nuevo | Uso |
|---|---|---|
| `lib/screens/combustible/registrar_combustible_screen.dart` | línea 69 | línea 398 |
| `lib/screens/mantenimiento/registrar_mantenimiento_screen.dart` | línea 64 | línea 425 |

La lista de vehículos se sigue actualizando en tiempo real. Lo único que cambia es que ya no se vuelve a pedir en cada letra.

> Otras pantallas tienen el mismo patrón: `combustible_screen.dart`, `mantenimiento_screen.dart`, `audit_screen.dart` y `live_map_screen.dart`. Ahí no se notaba porque no tienen campos de texto que redibujen la pantalla en cada letra. No se modificaron.

---

## Pruebas manuales (8-nov, web local con `flutter run -d web-server`)

Las pruebas se hicieron con el vehículo de prueba **PRUE01**:

| Prueba | Resultado |
|---|---|
| A. Programar "Cambio de aceite" a 500 km del km actual | ✅ Apareció "Faltan 500 km para la mantención Cambio de aceite (PRUE01) (a los 50.500 km)." |
| B. Tarjeta "Próxima mantención" del Inicio | ✅ Muestra "17/10/2026 · Frenos · Atrasada" |
| C. Carga con km mayor al programado | ✅ Subió el km del vehículo y apareció "llegó a los…" en la campana. ❌ No salió la notificación emergente: se corrigió (cambio 3) y **falta volver a probar** |
| Escribir en "Registrar carga" | ❌ El campo perdía el foco: se corrigió (cambio 4) y **falta volver a probar** |

Pruebas que faltan:
- **D:** que el aviso no se repita con otra carga.
- **E:** que el km nunca baje.
- **F:** el aviso al editar el km del vehículo.
- **G:** que al eliminar la programación se borren sus avisos.

**Resultado de las pruebas automáticas:** 338 tests OK (`flutter test`). `flutter analyze` no muestra problemas nuevos en los archivos modificados.

## Limitaciones conocidas (no se cambiaron)
- Al registrar una mantención **realizada** se puede escribir "próxima fecha" o "próximo km", pero eso **no genera avisos**. Solo las programadas los generan, y eso ya era así antes con la fecha.
- Una mantención programada **no se puede marcar como realizada**, solo eliminar. Si el usuario hace la mantención y no la elimina, el aviso "llegó a los…" queda en la bandeja hasta que lo lea.
- Las mantenciones realizadas y las cargas **no se pueden editar ni eliminar** desde la app, y ningún RF, CU ni HU lo pide. Si se guardó un km equivocado, se corrige en "Editar vehículo".
- En web, la notificación del navegador solo aparece **con la página abierta**. Para avisar con la página cerrada haría falta push (FCM y una Cloud Function).

## Archivos modificados

| Archivo | Cambios |
|---|---|
| `lib/screens/dashboard/dashboard_logica.dart` | 1 |
| `lib/screens/inicio_dashboard_screen.dart` | 1 |
| `lib/data/services/vehiculo_service.dart` | 2, 3 |
| `lib/data/services/abastecimiento_service.dart` | 2 |
| `lib/data/services/mantencion_service.dart` | 2, 3 |
| `lib/data/services/notificacion_service.dart` | 3 |
| `lib/data/models/notificacion_config_model.dart` | 3 |
| `lib/data/services/recordatorio_local_service.dart` | 3 |
| `lib/screens/notificaciones/notificaciones_screen.dart` | 3 |
| `lib/screens/mantenimiento/proximas_mantenciones_screen.dart` | 3 |
| `lib/screens/combustible/registrar_combustible_screen.dart` | 4 |
| `lib/screens/mantenimiento/registrar_mantenimiento_screen.dart` | 4 |
| `test/dashboard_logica_test.dart` | 1 |
| `test/kilometraje_vehiculo_test.dart` (nuevo) | 2 |
| `test/recordatorio_mantencion_test.dart` | 3 |
