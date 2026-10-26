# Cambios Sprint 3: recordatorios de mantenciones programadas (RF-012)

**Rama:** `Estephany` · **Fecha:** 17-oct-2026 · **Estado:** probado; pendiente de revisión del equipo

Este documento resume la implementación de los **recordatorios de mantención**. Las mantenciones programadas con fecha ahora generan avisos, igual que los documentos del vehículo generan avisos de vencimiento.

Cambio anterior del mismo sprint: [CAMBIOS_SPRINT3_MANTENCIONES.md](CAMBIOS_SPRINT3_MANTENCIONES.md) (comprobante en el historial, RF-010).

---

## 1. Requerimiento trabajado: RF-012 "Generar recordatorios de mantención"

**Texto actual del RF** (Módulo 2 de la lista de requerimientos):

| Campo | Texto |
|---|---|
| Descripción | Permite generar recordatorios asociados a la próxima mantención. |
| Criterio de aceptación | El usuario recibe el recordatorio según la fecha o kilometraje configurado. |

Requerimientos relacionados:
- **RF-011** (programar próxima mantención): su criterio dice que la programación *"permite generar recordatorios según los parámetros configurados"*.
- **RF-052** (gestionar notificaciones): pide notificaciones de *"vencimientos de documentos, próximas mantenciones y beneficios"*.

### El problema
- La app ya permitía **programar** mantenciones por fecha, kilometraje o ambos (RF-011), pero **no generaba ningún aviso**.
- Las vías de entrega (bandeja, teléfono y navegador) **solo aceptaban avisos de documentos**. Aunque se hubiera creado un aviso de mantención, se habría ignorado.

### Qué se implementó
Al programar una mantención **con fecha** (Mantenciones → "Programar mantenciones"), la app crea **dos avisos**, a las 9:00:

| Aviso | Cuándo | Mensaje (ejemplo) |
|---|---|---|
| 1 | 7 días antes de la fecha programada | "Mantención programada en 7 días: Cambio de aceite (PRUE01)." |
| 2 | El mismo día | "Hoy tienes una mantención programada: Cambio de aceite (PRUE01)." |

Se entregan por las mismas tres vías que los avisos de documentos:

| Vía | Cuándo funciona |
|---|---|
| Bandeja de la app (campana con contador), con ícono 🔧 | Siempre, también en la web |
| Notificación del teléfono | Android/iOS, aunque la app esté cerrada |
| Notificación del navegador | Web, con la pestaña abierta |

Además:
- Si se **elimina la mantención** o **el vehículo**, sus avisos se borran.
- Si se **cambia la fecha, el estado o el tipo** de la mantención, los avisos se rehacen.

### Decisiones tomadas
| Decisión | Motivo |
|---|---|
| **7 días antes y el mismo día** (no 30/15/7 como en documentos) | Una mantención no requiere trámites con tanta anticipación como un documento |
| **Solo por fecha; el aviso por kilometraje queda para el Sprint 4** | Para avisar por kilometraje, la app necesita saber cuántos km tiene el auto hoy, y `vehiculos.kilometraje_actual` solo cambia si el usuario edita el vehículo a mano. Hacerlo bien implica actualizarlo al registrar mantenciones y cargas de combustible (módulo 3) |
| **Las mantenciones programadas antes de este cambio no tienen avisos** | No se recalculan automáticamente; para que tengan avisos hay que volver a programarlas |

### Redacción propuesta para RF-012 (por validar con el equipo)
| Campo | Texto propuesto |
|---|---|
| Descripción | Permite generar recordatorios asociados a la próxima mantención programada. |
| Criterio de aceptación | Por fecha: el usuario recibe un aviso 7 días antes y otro el mismo día, en la bandeja de la app y como notificación del dispositivo. Por kilometraje: el usuario recibe un aviso cuando el kilometraje actual del vehículo se acerca al programado *(pendiente, Sprint 4)*. |

---

## 2. Cómo se guardan en la base de datos

Se guardan en **la misma colección `notificaciones`, con los mismos campos** que los avisos de documentos. **No se agregó ninguna colección ni campo.** Los dos tipos de aviso se distinguen por el **valor** de dos campos:

| Campo | Aviso de documento (ya existía) | Aviso de mantención (nuevo) |
|---|---|---|
| `tipo` | `"vencimiento_documento"` | `"mantencion_programada"` |
| `referencia_id` | Id del documento en `documentos_vehiculares` | Id de la mantención en `mantenciones` |
| Id del documento | `{documentoId}_30dias`, `_15dias`, `_7dias` | `{mantencionId}_7dias`, `_dia` |

### Ejemplo
```
notificaciones/H52lx..._7dias
  usuario_id:       "DONDYqaab..."
  vehiculo_id:      "1slJFWQgDdLIe5S5WClm"
  tipo:             "mantencion_programada"
  referencia_id:    "H52lx..."            → mantenciones/H52lx...
  mensaje:          "Mantención programada en 7 días: Batería (PRUE01)."
  fecha_programada: 23-oct-2026
  fecha_generacion: 17-oct-2026
  leida:            false
  estado:           "pendiente"
```

### Por qué no hubo que cambiar la tabla
La tabla **NOTIFICACIONES del modelo relacional ya tenía `tipo` y `referencia_id`**, pensados para que una sola tabla sirva para varios tipos de aviso (RF-052). Hasta ahora solo se usaba un tipo. En el Sprint 5, los beneficios podrían ser un tercer tipo sin tocar la estructura.

**Las reglas de Firestore tampoco cambian:** ya aceptan cualquier `tipo` (hasta 50 caracteres), siempre que el aviso sea del usuario y de un vehículo suyo.

### Para el diccionario de datos (NOTIFICACIONES)
Conviene agregar los valores de `tipo` y a qué apunta `referencia_id` en cada caso, porque **`referencia_id` no es una FK fija: depende de `tipo`**.

| `tipo` | `referencia_id` apunta a | Avisos que genera |
|---|---|---|
| `vencimiento_documento` | `documentos_vehiculares` | 30, 15 y 7 días antes del vencimiento |
| `mantencion_programada` | `mantenciones` | 7 días antes y el mismo día de `proxima_fecha` |

---

## 3. Archivos modificados y por qué

| Archivo | Qué se modificó | Por qué era necesario |
|---|---|---|
| [notificacion_config_model.dart](Producto/tag_ok/lib/data/models/notificacion_config_model.dart) | Constantes de los dos tipos de aviso y su título ("Documento por vencer" / "Mantención programada") | Un solo lugar para los nombres que usan la bandeja, el teléfono y el navegador |
| [notificacion_service.dart](Producto/tag_ok/lib/data/services/notificacion_service.dart) | Nuevas funciones `avisosMantencion()` (fechas y mensajes), `configurarRecordatoriosMantencion()` y `eliminarRecordatoriosMantencion()`. La lógica de guardar avisos pasó a una función común con los documentos | Crear y borrar los recordatorios reutilizando el mismo mecanismo de los documentos, sin duplicar código |
| [mantencion_service.dart](Producto/tag_ok/lib/data/services/mantencion_service.dart) | Al crear una programada con fecha, se crean sus avisos. Al editar fecha, estado o tipo, se rehacen. Al eliminar la mantención o el vehículo, se borran | Que los avisos siempre correspondan a mantenciones que existen, sin avisos "fantasma" |
| [recordatorio_local_service.dart](Producto/tag_ok/lib/data/services/recordatorio_local_service.dart) | Acepta avisos de mantención, con título propio y canal de Android propio ("Mantenciones programadas") | Antes solo programaba avisos de documentos en el teléfono. Con canal propio, el usuario puede silenciar uno sin perder el otro |
| [aviso_navegador_service.dart](Producto/tag_ok/lib/data/services/aviso_navegador_service.dart) | Acepta avisos de mantención, con su título | Antes solo mostraba avisos de documentos en el navegador |
| [notificaciones_screen.dart](Producto/tag_ok/lib/screens/notificaciones/notificaciones_screen.dart) | Ícono 🔧 para los avisos de mantención. Nuevos textos para la bandeja vacía y para el banner "Activa los avisos del navegador", que antes solo mencionaban documentos | Distinguir los tipos de aviso en la bandeja e informar al usuario de qué se le avisará |
| [recordatorio_mantencion_test.dart](Producto/tag_ok/test/recordatorio_mantencion_test.dart) (nuevo) | Pruebas: fechas (7 días antes y el mismo día), mensajes, ids y títulos | Comprobar el cálculo de los avisos |
| [aviso_navegador_test.dart](Producto/tag_ok/test/aviso_navegador_test.dart) | Prueba: el navegador muestra también los avisos de mantención | Comprobar la entrega en la web |
| [rules.test.js](Producto/tag_ok/tools/rules_test/rules.test.js) | Pruebas 9a–9c de `notificaciones`: crear, leer, marcar como leído y borrar recordatorios propios; bloquear los de otro usuario o de un vehículo ajeno; borrar un aviso inexistente | `notificaciones` no tenía pruebas de reglas. Confirman que las reglas publicadas permiten lo que hace la app |

---

## 4. Publicación

**No hay que publicar reglas:** las publicadas ya permiten estos avisos (pruebas 9a–9c).

Para publicar la app web (cuando se resuelva lo del `.env`; ver pendientes):
```
flutter build web --release
firebase deploy --only hosting --project tag-ok-v2
```

---

## 5. Verificación

| Prueba | Resultado |
|---|---|
| Pruebas de Dart (`recordatorio_mantencion_test`, `aviso_navegador_test`, `recordatorio_local_test`, `mantencion_model_test`, `mantencion_extraction_test`) | ✅ 27 de 27 pasan |
| Análisis estático (`flutter analyze`) de los archivos modificados | ✅ Sin observaciones |
| Pruebas de reglas en el emulador (`rules.test.js`) | ✅ 32 de 32 pasan, incluidas las nuevas 9a, 9b y 9c |
| Prueba manual en la app: aviso del mismo día | ✅ 17-oct-2026, en local (Edge) contra `tag-ok-v2`: al programar "Frenos" para hoy se creó `G1Rotb2FvveJdSSz0XnE_dia` en `notificaciones` (`tipo: "mantencion_programada"`, `referencia_id` = la mantención), sin `_7dias` porque ya pasó, y el aviso apareció en la bandeja de Inicio con el ícono 🔧 |
| Prueba manual en la app: aviso de 7 días antes y notificación del navegador | ✅ 17-oct-2026: al programar "Preventiva" para dentro de 7 días, Edge mostró la notificación "Mantención programada — Mantención programada en 7 días: Preventiva (PRUE01)." |

**Prueba manual sugerida** (Mantenciones → "Programar mantenciones"):
1. Programar una mantención **para hoy** → en la campana debe aparecer "Hoy tienes una mantención programada…" con el ícono 🔧. Si es antes de las 9:00, aparece a esa hora.
2. Programar otra **para dentro de 7 días** → el aviso "Mantención programada en 7 días…" también debe aparecer hoy en la campana.
3. En la consola de Firebase → `notificaciones`, deben existir `<id>_dia` y `<id>_7dias` con `tipo: "mantencion_programada"`.

---

## 6. Pendientes

- [x] Prueba manual: aviso del mismo día (sección 5).
- [x] Prueba manual: aviso de 7 días antes y notificación del navegador (sección 5).
- [ ] Actualizar la redacción de RF-012 en la lista de requerimientos (sección 1).
- [ ] Agregar al diccionario de datos los valores de `tipo` de NOTIFICACIONES y a qué apunta `referencia_id` (sección 2).
- [ ] **Aviso por kilometraje** (Sprint 4): mantener al día `vehiculos.kilometraje_actual` y avisar cuando se acerque al `proximo_kilometraje`.
- [ ] Mejora opcional: al registrar una mantención realizada, ofrecer "¿Programar la próxima?".
- [ ] ⚠️ Antes de volver a publicar la web: sacar la clave de OpenAI del `.env`, que se publica junto con el sitio.

---

## 7. Mensaje de commit sugerido

```
feat: recordatorios de mantenciones programadas (RF-012)

- Al programar una mantención con fecha se crean dos avisos en
  notificaciones (7 días antes y el mismo día, 9:00), que llegan a la
  bandeja, al teléfono y al navegador igual que los de documentos.
- Mismos campos de notificaciones: se distinguen por tipo
  "mantencion_programada" y referencia_id = id de la mantención. Las
  reglas publicadas ya los permiten.
- Los avisos se rehacen al editar la mantención y se borran al eliminarla
  o eliminar el vehículo.
- El aviso por kilometraje queda para el Sprint 4: requiere mantener al
  día el kilometraje actual del vehículo.
- Pruebas de cálculo de avisos, entrega en navegador y reglas de
  notificaciones (32/32).
```
