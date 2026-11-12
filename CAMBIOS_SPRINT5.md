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
| 5 | 8-nov | [Auditoría de mantenciones y cargas, visible en el panel admin](#5-auditoría-de-mantenciones-y-cargas-visible-en-el-panel-admin) | RF-054 / HU-39 | Tests OK, prueba manual postergada (falta acceso al panel), sin commit |
| 6 | 8-nov | [El dueño de cada registro se llama `usuario_id` en todas las colecciones (etapa 1 de 3)](#6-el-dueño-de-cada-registro-se-llama-usuario_id-en-todas-las-colecciones-etapa-1-de-3) | Diccionario de datos / modelo relacional (decisión 2.1 del 25-oct) | **Revertido el 9-nov** por decisión del equipo. La base, las reglas y el código quedaron como antes (ver [Reversión](#reversión-9-nov)) |

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

## 5. Auditoría de mantenciones y cargas, visible en el panel admin

> En esta sección hay archivos de dos proyectos. Las rutas que empiezan con `admin/` son relativas a `Producto/` (panel admin). El resto, como en todo el documento, son relativas a `Producto/tag_ok/`.

### Para qué
RF-054 pide *"mantener registros de trazabilidad sobre las capturas y operaciones relevantes"* y *"conservar la información necesaria para identificar origen y fecha de las capturas"*. HU-39 pide que *"la operación quede disponible para efectos de trazabilidad y auditoría"*.

Había dos problemas.

**1. Mantenciones y cargas no dejaban registro.** Solo auditaban **Documentos** (crear y eliminar) y **eliminar vehículo**. Una mantención o una carga, manual o con IA, no quedaba en la colección `auditoria`.

**2. El panel admin no entendía los registros de la app.** La colección `auditoria` recibe registros con **dos formatos distintos**:

| Quién escribe | Campos |
|---|---|
| App (`AuditoriaService`, formato del diccionario de datos) | `usuario_id`, `accion`, `tipo_entidad`, `entidad_id`, `detalle`, `origen`, `fecha` |
| Panel admin (`AdminFirestoreService.logAction`) | `adminEmail`, `action`, `target`, `details`, `fecha` |

La bitácora del panel solo leía sus propios campos. Por eso los registros de la app aparecían como **"Sistema"**, con la acción, el objetivo y el detalle **vacíos**.

**Ahora:**
- La app audita al **crear una mantención** (realizada o programada), al **eliminar una mantención** y al **crear una carga**. Cada registro indica si fue `manual` o `ia`.
- La bitácora del panel entiende **los dos formatos** y muestra quién lo hizo (correo del usuario), de dónde viene, la acción, sobre qué y el detalle.
- **No se modificó ningún dato guardado ni las reglas de Firestore:** solo cambió cómo se escriben los registros nuevos y cómo se muestran.

**Qué se ve en la bitácora:**

| Fecha | Responsable | Fuente | Acción | Objetivo | Detalles |
|---|---|---|---|---|---|
| 2026-11-08 18:40 | conductor@correo.cl | App · IA | Crear | Mantención | Mantención realizada registrada con IA (revisada y confirmada por el usuario): Frenos |
| 2026-11-08 18:42 | conductor@correo.cl | App · Manual | Crear | Carga de combustible | Carga de combustible registrada |
| 2026-11-08 18:50 | admin@tagok.cl | Panel admin | Eliminar Pórtico | Pórtico P1 | (igual que antes) |

### Respaldo en los requisitos y decisión (8-nov)
Ningún RF, CU ni HU dice textualmente "auditar mantenciones" o "auditar abastecimientos". El respaldo es este:

| Documento | Qué dice |
|---|---|
| **HU-39 / CU39** (Registro inteligente con IA) | Lo confirmado desde la IA se guarda en su módulo, y *"la operación queda disponible para efectos de trazabilidad y auditoría"*. Mantenciones (RF-013/014/015, boleta o factura del taller) y combustible (RF-027/028/029, boleta de la bencinera) **son módulos de registro inteligente**. |
| **RF-054** (actores: Sistema / Administrador) | *"Registros de trazabilidad sobre las capturas y **operaciones relevantes**."* |
| **RF-042 / RNF-006** | Cada captura inteligente conserva su origen y fecha. Esto **ya se cumplía**: cada mantención y carga guarda `origen_registro`, `fecha_captura` y `confianza_ia` en su propio documento. |

En estos dos módulos la IA se usa de dos formas:
- **Desde la boleta o factura:** la IA prellena el formulario completo y el registro queda con `origen = 'ia'`.
- **Con la foto del velocímetro:** la IA solo llena el campo de kilometraje, y el registro queda con `origen = 'manual'`.

**Decisión (opción A, elegida por Estephany):** se auditan **todos** los registros de mantención y combustible, **manuales y con IA**.
- Cumple HU-39 para los registros que vienen de la IA.
- Usa "operaciones relevantes" (RF-054) para los manuales.
- Es coherente con Documentos, que ya auditaba ambos orígenes.

En la bitácora del panel, el filtro "Fuente" permite ver solo los registros de IA cuando haga falta.

La alternativa descartada (opción B) era auditar solo los registros con origen `ia`, tal como dice HU-39 al pie de la letra.

### Funciones: app
Archivo: `lib/data/services/auditoria_service.dart`.

**`entidadAuditoriaMantencion = 'MANTENCION'`** y **`entidadAuditoriaAbastecimiento = 'ABASTECIMIENTO'`** (líneas 9 y 10): nuevas.
- Son los valores de `tipo_entidad` de los registros nuevos. Se suman a los que ya existían, `VEHICULO` y `DOCUMENTO_VEHICULAR`.

**`detalleAuditoriaMantencionCreada({estado, nombre, origen})`** (línea 17): nueva y pura.
- Arma el texto del detalle, por ejemplo "Mantención realizada registrada: Cambio de aceite".
- Si el origen es IA, agrega "con IA (revisada y confirmada por el usuario)", porque en la app ningún dato de la IA se guarda sin que el usuario lo confirme (RF-014 / RF-029).

**`detalleAuditoriaMantencionEliminada({estado, nombre})`** (línea 29): nueva y pura.
- Arma el texto "Mantención programada eliminada: Frenos".

**`detalleAuditoriaAbastecimientoCreado({tipo, origen})`** (línea 41): nueva y pura.
- Arma el texto "Carga de combustible registrada" o "Carga eléctrica registrada", más el agregado de IA si corresponde.

**`AuditoriaService.registrarSinInterrumpir(...)`** (línea 88): nueva.
- Hace lo mismo que `registrar`, pero si falla solo lo informa en la consola.
- Se usa **después** de guardar la mantención o la carga. Si la auditoría fallara y se mostrara un error, el usuario pensaría que no se guardó, lo volvería a ingresar y quedaría **duplicado**.

**`MantencionService.crear(...)`**: modificada. Está en `lib/data/services/mantencion_service.dart:41`.
- Después de guardar, registra `CREAR` / `MANTENCION` con el origen de la mantención (línea 89).

**`MantencionService.eliminar(id)`**: modificada. Está en `lib/data/services/mantencion_service.dart:281`.
- Antes de borrar, lee la mantención para conocer su nombre.
- Después de borrar, registra `ELIMINAR` / `MANTENCION` con origen `manual` (línea 285).

**`AbastecimientoService.crear(...)`**: modificada. Está en `lib/data/services/abastecimiento_service.dart:30`.
- Después de guardar, registra `CREAR` / `ABASTECIMIENTO` con el origen de la carga (línea 68).

**Lo que no se audita y por qué:**
- **Editar** una mantención o carga: la app no lo permite.
- **Eliminar una carga**: no hay pantalla para hacerlo.
- **Borrado en bloque** al eliminar un vehículo: queda auditado como "Vehículo eliminado", igual que ya pasaba con los documentos.

### Funciones: panel admin
**`RegistroAuditoria`**: archivo nuevo, `admin/lib/registro_auditoria.dart`.
- Es una clase pura que deja **un registro de cualquiera de los dos formatos** en un formato común para la tabla: `fecha`, `esDeLaApp`, `responsable`, `accion`, `objetivo`, `detalle` y `fuente`.
- **`RegistroAuditoria.desde(data, {correosUsuarios})`** (línea 48):
  - Si el registro trae `tipo_entidad` o `accion`, es de la app. El responsable es el correo del usuario (si no se conoce, "Usuario {uid}"), el objetivo es el nombre de la entidad y la fuente es "App · Manual/IA/Sistema".
  - Si no, es del panel y se muestra **igual que antes**, con fuente "Panel admin".
- **`coincideCon(busqueda)`** (línea 82): la búsqueda de la bitácora revisa el responsable, el objetivo, el detalle y la fuente.
- **`etiquetaEntidadAuditoria(...)`** (línea 95) y **`etiquetaOrigenAuditoria(...)`** (línea 105) traducen los códigos a texto legible. Por ejemplo, `ABASTECIMIENTO` se muestra como "Carga de combustible" e `ia` como "IA".

**Bitácora de Auditoría (`AuditLogPage`)**: modificada. Está en `admin/lib/main.dart`.
- **`_cargarCorreosUsuarios()`** (línea 5018), nueva:
  - lee una vez la colección `usuarios` y arma el mapa uid → correo (el id del documento de `usuarios` es el uid);
  - si falla, la bitácora funciona igual y muestra el uid.
- **`_matchesFilters(registro)`** (línea 5032), modificada:
  - ahora filtra un `RegistroAuditoria` en vez de los datos crudos;
  - se agregó el filtro por fuente.
- **Tabla:**
  - cada documento se convierte con `RegistroAuditoria.desde` (línea 5152);
  - la columna "Administrador" pasa a llamarse **"Responsable"** (línea 5211);
  - hay una columna nueva **"Fuente"** (línea 5238).
- **`_getActionBadge`**: tiene etiquetas para las acciones de la app, **"Crear"** en verde y **"Eliminar"** en rojo (línea 5093).
- **Filtros:**
  - en "Tipo de Acción" se agregaron "Crear (app)" y "Eliminar (app)" (línea 5359);
  - hay un selector nuevo, **"Fuente"**, con las opciones Todas, Panel admin y App (línea 5384).
- **`_filtrosAdaptables(...)`** (línea 5415), nueva: en pantallas de menos de 700 px, por ejemplo un celular, los filtros se apilan uno debajo del otro.
- El subtítulo de la página ahora menciona los registros de la app (línea 5132).

### Pruebas
- App: `test/auditoria_detalle_test.dart` (nuevo) tiene 5 tests de los textos de detalle y del largo de las entidades, que debe caber en la regla de Firestore (máximo 60). Resultado: 343 tests OK.
- Panel: `admin/test/registro_auditoria_test.dart` (nuevo) tiene 6 tests:
  - el registro del panel se muestra igual que antes;
  - "Sistema" cuando no hay correo;
  - el registro de la app se traduce;
  - el uid aparece cuando no se conoce el correo;
  - los nombres de entidades y orígenes;
  - la búsqueda.

  Resultado: 6 OK.

> Para ejecutar los tests del panel hace falta un archivo `Producto/admin/.env`, porque el `pubspec.yaml` del admin lo declara como asset. Sin él, `flutter test` falla con *"No file or variants found for asset: .env"*. Para correrlos se creó un `.env` vacío temporal y se borró después.

### Pendiente
- **Diccionario de datos:** en la tabla AUDITORIA, agregar `'MANTENCION'` y `'ABASTECIMIENTO'` a los valores de `tipo_entidad`.
- **Diccionario de datos:** documentar que el panel admin escribe en la misma colección con otro formato (`adminEmail`, `action`, `target`, `details`).
- **Prueba manual (postergada):** registrar una mantención y una carga en la app, y verlas en la bitácora del panel admin (Auditoría → Fuente = App).

### Acceso al panel admin para la prueba (revisado el 8-nov)
- El panel inicia sesión con **correo y contraseña de Firebase Authentication**. Además, exige que la cuenta esté en la colección **`administradores`**, buscándola por uid o por correo (`admin/lib/login_screen.dart:52-77`).
- La sección **Auditoría** del menú requiere el rol **`super_admin`** (`admin/lib/main.dart:118-165`).
- En `administradores` hay **una sola cuenta: `tagokv2@gmail.com`** (`super_admin`).
- La cuenta de prueba que describe `Producto/Base de datos/README.md` (`admin.tagok@example.com`) **no existe** en el proyecto, porque nunca se ejecutó el script `poblar_bd.js`. Su contraseña no sirve.
- **Para entrar, hay dos opciones:**
  - **Opción recomendada:** agregar la cuenta propia como administradora.
    1. En Authentication, copiar el UID.
    2. En Firestore → `administradores`, crear un documento **con ese UID como id**.
    3. Agregarle los campos `email`, `nombre` y `rol = "super_admin"` (todos string).

    Es un cambio en la base compartida: hay que avisar al equipo.
  - **Opción alternativa:** recuperar la contraseña de `tagokv2@gmail.com`.
    - Solo es posible si la cuenta usa el proveedor "Correo electrónico/contraseña". Si usa Google, no tiene contraseña de Firebase y el panel no la acepta.
    - El cambio afecta a todo el equipo, así que hay que coordinarlo antes.
- Para correr el panel en local hace falta `Producto/admin/.env`. Tiene las mismas variables que el de la app y apunta al mismo proyecto `tag-ok-v2`:
  ```
  cd Producto/admin
  copy ..\tag_ok\.env .env
  flutter run -d web-server --web-port 8091
  ```

---

## 6. El dueño de cada registro se llama `usuario_id` en todas las colecciones (etapa 1 de 3)

> **REVERTIDO el 9-nov.** La etapa 2 se alcanzó a aplicar y luego el equipo decidió dejar los nombres como estaban. Hoy la base, las reglas publicadas y el código están **igual que antes de este cambio**. Lo que sigue describe lo que se hizo y queda como referencia por si se retoma después de la entrega. El detalle está en [Reversión](#reversión-9-nov).

### Para qué
El mismo dato, el usuario dueño del registro, tenía **tres nombres y dos tipos** según la colección:

| Colección | Antes | Después |
|---|---|---|
| `documentos_vehiculares`, `mantenciones`, `abastecimientos` | `uid` (texto) | `usuario_id` (texto) |
| `vehiculos` | `id_usuario` (referencia) | `usuario_id` (**sigue siendo referencia**, por decisión del 8-nov) |
| `notificaciones`, `auditoria` | `usuario_id` (texto) | sin cambios |
| `estacionamientos` (aún no existe) | el Inicio la buscaba por `uid` | nace con `usuario_id` |

El diccionario de datos y el modelo relacional ya decían `usuario_id`: fue la decisión 2.1 del 25-oct, con la migración planificada para el Sprint 4, que no se hizo. Que convivan varios nombres provoca **errores silenciosos**: una consulta o una regla con el nombre equivocado no muestra ningún error, solo no encuentra el registro. Un ejemplo concreto es `estacionamientos`: si se hubiera creado con `usuario_id`, como dice el diccionario, sus gastos no habrían aparecido en el Inicio.

### Cómo se hace sin perder registros: tres etapas
Firestore no puede renombrar un campo en todos los documentos de una vez. Por eso, durante un tiempo, cada registro tiene **los dos nombres con el mismo valor**. Así, la app anterior (que busca el nombre viejo) y la nueva (que busca `usuario_id`) ven todo:

```
Hoy:         { uid: "ktz3..." }
Transición:  { uid: "ktz3...", usuario_id: "ktz3..." }
Final:       { usuario_id: "ktz3..." }
```

| Etapa | Qué | Estado |
|---|---|---|
| **1. Preparar** | Reglas que aceptan los dos nombres, app que guarda los dos y busca por `usuario_id`, script de migración y tests | ✅ Hecha (este cambio) |
| **2. Migrar** | Publicar las reglas, ejecutar el script (primero en prueba, luego con `--apply`) y comprobar | ⏳ Pendiente |
| **3. Limpiar** | Cuando nadie use la versión anterior, quitar el nombre viejo de la base (`--quitar-antiguo`), de las reglas y del código | ⏳ Al final del sprint (integración) |

> **Orden importante:** la app nueva busca por `usuario_id`. Si se ejecuta contra la base real **antes** de la etapa 2, los registros antiguos no aparecen (no se pierden, siguen en la base). Por eso primero se publican las reglas y se migra, y recién después se usa la app nueva.

### Funciones: app
**Archivo nuevo `lib/data/models/campo_dueno.dart`.** Reúne en un solo lugar el nombre del campo y todo lo que tiene que ver con la transición. En la etapa 3 basta con editar este archivo.
- **`campoUsuarioId = 'usuario_id'`** (línea 10): el nombre del campo. Lo usan todas las consultas.
- **`campoUidAntiguo`** y **`campoIdUsuarioAntiguo`** (líneas 27 y 30): los nombres antiguos. Se borran en la etapa 3.
- **`camposDuenoTexto(usuarioId)`** (línea 34): devuelve `{usuario_id, uid}` con el mismo valor. Se usa al crear documentos, mantenciones y cargas.
- **`leerDuenoTexto(datos)`** (línea 41): lee `usuario_id` y, si no está, `uid`.
- **`camposDuenoVehiculo(ref)`** (línea 48) y **`leerDuenoVehiculo(datos)`** (línea 57): hacen lo mismo para vehículos, con la referencia.

**Modelos.** La propiedad de Dart también se renombró, para que el código use el mismo nombre que la base:
- `DocumentoVehicularModel`, `MantencionModel` y `AbastecimientoModel`: `uid` → **`usuarioId`**.
  - `fromJson` usa `leerDuenoTexto`.
  - `toJson` escribe los dos nombres.
- `VehiculoModel`: `idUsuario` → **`usuarioId`**, que sigue siendo `DocumentReference`. Usa `leerDuenoVehiculo` y `camposDuenoVehiculo`.

**Consultas** (`.where('uid' | 'id_usuario', …)` → `.where(campoUsuarioId, …)`):

| Archivo | Consultas |
|---|---|
| `documento_vehicular_service.dart` | 3 consultas y la creación manual (`...camposDuenoTexto`) |
| `mantencion_service.dart` | 3 |
| `abastecimiento_service.dart` | 2 |
| `vehiculo_service.dart` | 2. La variable local `idUsuario` pasa a llamarse `refUsuario`. Al eliminar un vehículo, el dueño se lee con `leerDuenoVehiculo` |
| `history_service.dart` | 2 (vehículos del usuario) |
| `notificacion_service.dart` | `_resolverUsuarioId` (línea 403) lee el dueño del vehículo con `leerDuenoVehiculo` |
| `inicio_dashboard_screen.dart` | 3 (documentos, mantenciones y la función genérica de gastos, que incluye estacionamientos) |
| `dashboard/gastos_historial.dart` | 3 (mantenciones, cargas y estacionamientos) |
| `mi_vehiculo/mi_vehiculo_screen.dart` | 2 |
| `mi_vehiculo/detalle_vehiculo_screen.dart` | 1 |
| `vehiculos_screen.dart` (Fase 1) | Crea con los dos nombres y busca por `usuario_id`. La consulta de respaldo con el texto `'/usuarios/{uid}'` sigue usando `id_usuario`, porque solo existe para vehículos antiguos de Fase 1 creados a mano |

### Funciones: reglas de Firestore (`firestore.rules`)
- **Encabezado** (línea 20): explica la transición y qué hay que quitar en la etapa 3.
- **Dueño en texto** (documentos, mantenciones y cargas):
  - **`esDuenoTexto(d)`** (línea 146): eres el dueño si `usuario_id` **o** `uid` es tu usuario. Se usa para leer, editar y borrar.
  - **`duenoTextoNuevoValido(d)`** (línea 153): para crear, el registro debe traer al menos uno de los dos nombres, y **todos los que traiga** deben ser tu usuario. Así no se puede crear un registro con un nombre propio y el otro ajeno.
  - **`duenoTextoFormatoValido(d)`** (línea 161): reemplaza a `reqStr(d, 'uid', 128)` en las validaciones de las tres colecciones.
- **Vehículos:**
  - **`vehiculoEsDe` / `vehiculoDuenoEs`** (líneas 167 y 172): comprueban que el vehículo es tuyo por `usuario_id` o por `id_usuario`. Las usan documentos, mantenciones, cargas y notificaciones.
  - **`esDuenoVehiculo(d)`** (línea 302) y **`duenoVehiculoNuevoValido(d)`** (línea 309): lo mismo para la colección `vehiculos`.
- **Listas de campos permitidos** de las 4 colecciones: se agregó `usuario_id`. Los dos nombres siguen siendo **inmutables**, porque no están en la lista de campos que se pueden editar.

### Script de migración (`tools/migrar_usuario_id.js`)
- **Modo de prueba por defecto:** muestra, por colección, cuántos documentos migraría, cuántos ya están y la lista de documentos raros. **No escribe nada.**
- **`--apply --respaldo=C:\ruta\fuera-del-repo\respaldo.json`:**
  - antes de escribir, guarda un **respaldo** con todos los documentos de las 4 colecciones;
  - se niega a escribir sin respaldo, con el respaldo dentro del repositorio o si el archivo ya existe;
  - agrega `usuario_id` con el mismo valor del nombre viejo y **no toca ningún otro campo**.
- **Documentos raros:** los que no tienen dueño, tienen un formato inesperado (por ejemplo `vehiculo_JHGK50`, con un texto) o tienen los dos nombres con valores distintos **no se tocan** y se listan para decidir qué hacer.
- **Cambios simultáneos:** cada escritura exige que el documento no haya cambiado desde que se leyó (precondición `lastUpdateTime`).
- **Se puede ejecutar varias veces:** los documentos ya migrados se saltan.
- **`--quitar-antiguo` (etapa 3):** borra el nombre viejo solo donde `usuario_id` existe y tiene el mismo valor. También tiene modo de prueba y exige respaldo.
- **Credenciales:** usa la llave de cuenta de servicio, guardada fuera del repositorio, igual que `backfill_uid_documentos.js`.
- **Emulador:** si `FIRESTORE_EMULATOR_HOST` está definido, trabaja contra el emulador local con el proyecto `demo-tag-ok` y lo indica en pantalla.

### Pruebas
| Pruebas | Resultado |
|---|---|
| App (`flutter test`), con `test/campo_dueno_test.dart` nuevo (8 tests: escritura de los dos nombres, lectura de los tres formatos y vehículos con referencia) | 351 OK |
| Reglas, emulador (`rules_test/rules.test.js`): 9 tests nuevos en la sección "Prueba 11" (línea 381), con los tres formatos, dueño ajeno en cualquiera de los nombres, editar un documento migrado, consultas por `usuario_id` y por el nombre viejo, y una mantención en un vehículo que ya solo tiene `usuario_id` | 50 OK. Los tests 1 a 10 siguen usando el formato viejo, así que confirman que **la app anterior sigue funcionando**. El que falla, `8g`, **ya fallaba antes de este cambio**: espera que un tipo de mantención inventado se rechace, pero hoy las reglas aceptan títulos libres. Hay que actualizar ese test |
| Viajes, emulador (`rules_test/trips.test.js`) | 15 OK |
| Script, emulador (`rules_test/migracion.test.js`, nuevo, 5 tests): el modo de prueba no escribe; se rechaza sin respaldo o con respaldo dentro del repo; agrega sin tocar otros campos; deja intactos los raros; se puede ejecutar de nuevo; la etapa 3 limpia solo lo coincidente | 5 OK |

Notas para correr los tests de reglas:
- **`beneficios.test.js` no arranca en esta versión de Node.** Usa un `before()` que no se espera, el mismo problema que `rules.test.js` ya resolvió. Esto ya pasaba antes de este cambio.
- **Los archivos de tests hay que ejecutarlos uno por uno** (`--test-concurrency=1`), porque comparten el emulador.
- **`package.json` apunta a `firebase.rules-test.json`**, que la CLI rechaza (*"is outside of project directory"*). Funciona con `--config firebase.json` y la variable `RULES=../../firestore.rules`.

### Pendiente
- **Etapa 2:**
  1. Generar la llave de cuenta de servicio y guardarla fuera del repo.
  2. Publicar las reglas (`firebase deploy --only firestore:rules --project tag-ok-v2`), avisando al equipo.
  3. Ejecutar el script en modo de prueba y revisar el informe.
  4. Ejecutarlo con `--apply` y comprobar que diga "0 por migrar".
  5. Probar la app.
- **Etapa 3:** web y APK nuevos, ramas del equipo actualizadas, volver a ejecutar el script, `--quitar-antiguo`, y quitar el nombre viejo de `campo_dueno.dart` y de las reglas.
- **Avisar al equipo** (sobre todo a Almendra, por `estacionamientos`) que el dueño se llama `usuario_id`.
- **Scripts de datos de ejemplo:** `Producto/Base de datos/poblar_bd.js` y la copia distinta en `tools/poblar_bd/`, que no está en git, todavía escriben solo `uid` / `id_usuario`. Solo cargan datos en el emulador. **No se modificaron, a la espera de decisión.**
- **Diccionario y modelo relacional:**
  - quitar las notas *"se unificará en el Sprint 4"*;
  - agregar una nota: *"en VEHICULOS, `usuario_id` es una referencia a `usuarios/{uid}`"*;
  - agregar `usuario_id` a ABASTECIMIENTOS y ESTACIONAMIENTOS.

### Etapa 2 aplicada (9-nov)
1. **Credenciales:** en vez de una llave de cuenta de servicio se usó `gcloud auth application-default login` con tagokv2@gmail.com, y se revocó al terminar (`gcloud auth application-default revoke`).
2. **Reglas:** antes de publicar se comprobó que las reglas publicadas eran idénticas a las del último commit y que ninguna rama tenía reglas más nuevas. Luego se publicaron las reglas de transición.
3. **Migración:** se aplicó a 35 documentos (15 documentos vehiculares, 9 mantenciones, 2 cargas y 9 vehículos). El respaldo quedó en `C:\Users\estef\Documents\respaldos_tagok\respaldo_etapa2_2026-11-09.json`.
4. **Verificación contra el respaldo:** 0 registros perdidos; todos los campos sin cambios, salvo `usuario_id` agregado con el mismo valor.
5. **Vehículos demo:** `vehiculo_ABBD23`, `vehiculo_CLPM99` y `vehiculo_JHGK50` (dueño guardado como texto `demo_user_*`) no se tocaron, por decisión de Estephany.
6. **Prueba en la app:** el vehículo PRUE02 y una carga de combustible se guardaron con los dos nombres, y la auditoría (cambio 5) registró la carga.

### Reversión (9-nov)
**Por qué:** el equipo prefirió no cambiar el nombre a esta altura del proyecto, con la app casi terminada, para no arriesgar fallas antes de la entrega. Quedarse en la transición tampoco era opción para el equipo, y volver atrás requería dos cosas: las reglas anteriores tienen una lista cerrada de campos sin `usuario_id`, y al editar un registro revisan el documento completo. Por eso, si se publicaban sin limpiar antes la base, las mantenciones y los documentos migrados no se habrían podido editar.

**Qué se hizo, en este orden:**
1. **Código:** los archivos de la etapa 1 volvieron a su versión del último commit, y se borraron `campo_dueno.dart` y `campo_dueno_test.dart`. En `mantencion_service.dart` y `abastecimiento_service.dart` se quitó solo la parte de `usuario_id`: **la auditoría del cambio 5 se mantiene**.
2. **Base de datos:** se quitó el campo `usuario_id` de 37 documentos (los 35 migrados, el vehículo PRUE02 y la carga de prueba), solo donde era igual al nombre antiguo. No se borró ningún registro. Notificaciones y auditoría no se tocaron, porque allí `usuario_id` siempre fue el único nombre. Se usó un script de un solo uso, fuera del repositorio, probado antes en el emulador. Respaldo previo: `C:\Users\estef\Documents\respaldos_tagok\respaldo_reversion_2026-11-09.json`.
3. **Reglas:** se publicaron otra vez las reglas anteriores, idénticas a las del último commit. Se publicaron **después** de limpiar la base, para que ningún registro quedara bloqueado.

**Verificación:**
- Los 38 documentos que existían antes de la migración están **idénticos** al respaldo previo a la etapa 2.
- Los 2 creados en la prueba (PRUE02 y la carga) tienen solo el nombre antiguo.
- Las reglas publicadas son idénticas a las de antes.
- `flutter test`: 343 OK, los mismos que antes de la etapa 1. `flutter analyze` no muestra errores.

**Qué se conserva:**
- `tools/migrar_usuario_id.js` y `tools/rules_test/migracion.test.js` (sin commit), por si se retoma la unificación después de la entrega.
- Todos los cambios de código de la etapa 1, guardados como parche en `C:\Users\estef\Documents\respaldos_tagok\etapa1_usuario_id_codigo\`.

> Los respaldos contienen datos personales: están fuera del repositorio y conviene borrarlos cuando ya no hagan falta.

**Pendiente, solo si se retoma:** decidir los nombres en el diccionario de datos y el modelo relacional, que dicen `usuario_id` mientras la base usa `uid` e `id_usuario`, y avisar a Almendra qué nombre usar en `estacionamientos`.

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
| `lib/data/services/auditoria_service.dart` | 5 |
| `test/auditoria_detalle_test.dart` (nuevo) | 5 |
| `admin/lib/registro_auditoria.dart` (nuevo, panel admin) | 5 |
| `admin/lib/main.dart` (panel admin) | 5 |
| `admin/test/registro_auditoria_test.dart` (nuevo, panel admin) | 5 |

> `mantencion_service.dart` y `abastecimiento_service.dart`, que ya están en la tabla, también cambiaron en el cambio 5.

**Cambio 6** (revertido el 9-nov: todos estos archivos volvieron a su versión del último commit, salvo los dos de `tools/`, que se conservan sin commit):

| Archivo | Tipo |
|---|---|
| `lib/data/models/campo_dueno.dart` | nuevo |
| `lib/data/models/documento_vehicular_model.dart`, `mantencion_model.dart`, `abastecimiento_model.dart`, `vehiculo_model.dart` | modificados |
| `lib/data/services/documento_vehicular_service.dart`, `mantencion_service.dart`, `abastecimiento_service.dart`, `vehiculo_service.dart`, `history_service.dart`, `notificacion_service.dart` | modificados |
| `lib/screens/inicio_dashboard_screen.dart`, `dashboard/gastos_historial.dart`, `mi_vehiculo/mi_vehiculo_screen.dart`, `mi_vehiculo/detalle_vehiculo_screen.dart`, `vehiculos_screen.dart` | modificados |
| `firestore.rules` | modificado |
| `tools/migrar_usuario_id.js` | nuevo |
| `tools/rules_test/rules.test.js` | modificado |
| `tools/rules_test/migracion.test.js` | nuevo |
| `test/campo_dueno_test.dart` | nuevo |
| `test/busqueda_mantencion_test.dart`, `dashboard_logica_test.dart`, `detalle_mantenimiento_test.dart`, `mantencion_model_test.dart`, `validaciones_mantencion_test.dart` | modificados (`uid:` → `usuarioId:`) |
